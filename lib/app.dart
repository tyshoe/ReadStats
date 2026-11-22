import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:read_stats/data/database/database_helper.dart';
import 'package:read_stats/data/repositories/book_repository.dart';
import 'package:read_stats/data/repositories/goal_repository.dart';
import 'package:read_stats/data/repositories/session_repository.dart';
import 'package:read_stats/data/repositories/tag_repository.dart';
import 'package:read_stats/data/services/analytics_service.dart';
import 'package:read_stats/data/services/cover_service.dart';
import 'package:read_stats/data/services/goal_achievement_service.dart';
import 'package:read_stats/data/services/import_export_service.dart';
import 'package:read_stats/data/services/library_snapshot_service.dart';
import 'package:read_stats/data/services/milestone_service.dart';
import 'package:read_stats/data/services/notification_service.dart';
import 'package:read_stats/data/services/reading_timer_service.dart';
import 'package:read_stats/domain/monthly_recap.dart';
import 'package:read_stats/domain/reading_stats.dart';
import 'package:read_stats/domain/seasons.dart';
import 'package:read_stats/domain/year_wrapped.dart';
import 'package:read_stats/ui/navigation_menu.dart';
import 'package:read_stats/ui/pages/onboarding/onboarding_page.dart';
import 'package:read_stats/ui/pages/profile/milestone_celebration_page.dart';
import 'package:read_stats/ui/pages/profile/profile_page.dart';
import 'package:read_stats/ui/pages/statistics/monthly_recap_page.dart';
import 'package:read_stats/ui/pages/statistics/statistics_page.dart';
import 'package:read_stats/ui/pages/wrapped/wrapped_page.dart';
import 'package:read_stats/ui/settings_view_model.dart';
import 'package:read_stats/ui/themes/app_theme.dart';
import 'package:read_stats/ui/widgets/app_snackbar.dart';
import 'package:read_stats/ui/widgets/import_progress_dialog.dart';

/// The root widget: loads the books and sessions every tab shares, keeps them
/// fresh, and hands them to the tab shell (or onboarding on first run).
class ReadStatsApp extends StatefulWidget {
  final ThemeMode themeMode;
  final BookRepository bookRepository;
  final SessionRepository sessionRepository;
  final TagRepository tagRepository;
  final GoalRepository goalRepository;
  final ImportExportService importExportService;
  final bool hasSeenOnboarding;
  final ReadingTimerService timerService;

  const ReadStatsApp({
    super.key,
    required this.themeMode,
    required this.bookRepository,
    required this.sessionRepository,
    required this.tagRepository,
    required this.goalRepository,
    required this.importExportService,
    required this.hasSeenOnboarding,
    required this.timerService,
  });

  @override
  State<ReadStatsApp> createState() => _ReadStatsAppState();
}

/// Tracks how deep the navigation stack is so a queued milestone celebration
/// can wait for the reader to close whatever sits above the tab shell.
///
/// Counts pushes and pops itself rather than asking [NavigatorState.canPop],
/// which is ambiguous while a pop is still animating — the route being
/// dismissed can still be counted, and the celebration would stall until the
/// next unrelated navigation.
class _StackUnwindObserver extends NavigatorObserver {
  _StackUnwindObserver(this.onSettled);

  final VoidCallback onSettled;

  /// Routes on the stack, including the tab shell itself — so one, not zero,
  /// is what "nothing on top" looks like. Dialogs and modal sheets go through
  /// the same navigator and count here too.
  int _depth = 0;

  bool get isSettled => _depth <= 1;

  void _onStackShrank() {
    // After the frame, so the celebration is never pushed from inside another
    // route's own pop handling.
    if (isSettled) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onSettled());
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _depth++;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _depth--;
    _onStackShrank();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _depth--;
    _onStackShrank();
  }
}

class _ReadStatsAppState extends State<ReadStatsApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final _StackUnwindObserver _stackObserver = _StackUnwindObserver(
    _flushMilestones,
  );
  late SettingsViewModel _settingsViewModel;
  bool _isReady = false;
  late bool _hasSeenOnboarding;
  List<Map<String, dynamic>> _books = [];
  List<Map<String, dynamic>> _sessions = [];

  @override
  void initState() {
    super.initState();
    _hasSeenOnboarding = widget.hasSeenOnboarding;
    _initializeSettingsViewModel();
    _loadBooks();
    _loadSessions();
    // Safety net: reload whenever anything writes to the books/sessions tables,
    // so a screen that saves without calling refreshBooks/refreshSessions still
    // can't leave the app showing stale data. The explicit refresh callbacks
    // stay — they're awaited where a caller needs the fresh list immediately.
    DatabaseHelper.booksChanged.addListener(_scheduleBooksReload);
    DatabaseHelper.sessionsChanged.addListener(_scheduleSessionsReload);
    // A tapped recap notification should land on the recap itself. The tap may
    // already have happened — a cold start records it before this widget
    // exists — so the pending value is checked as well as listened to.
    NotificationService.instance.tappedPayload.addListener(
      _handleNotificationTap,
    );
    // Warm the Profile goals and Statistics caches at launch so they are ready
    // before those tabs are ever opened, instead of popping in after
    // navigation.
    ProfilePage.preloadGoals(widget.goalRepository);
    SettingsViewModel.getStatsYearFilter().then((year) {
      StatisticsPage.preload(
        bookRepo: widget.bookRepository,
        sessionRepo: widget.sessionRepository,
        year: year,
      );
    });
  }

  Future<void> _initializeSettingsViewModel() async {
    final accentColor = await SettingsViewModel.getAccentColor();
    final defaultBookType = await SettingsViewModel.getDefaultBookType();
    final defaultRatingStyle = await SettingsViewModel.getDefaultRatingStyle();
    final bookView = await SettingsViewModel.getLibraryBookView();
    final navStyle = await SettingsViewModel.getNavStyle();
    final defaultTab = await SettingsViewModel.getDefaultTab();
    final defaultDateFormat = await SettingsViewModel.getDefaultDateFormat();
    final selectedFont = await SettingsViewModel.getSelectedFont();
    final sortOption = await SettingsViewModel.getLibrarySortOption();
    final isAscending = await SettingsViewModel.getLibrarySortAscending();
    final bookTypes = await SettingsViewModel.getLibraryBookTypes();
    final isFavorite = await SettingsViewModel.getLibraryIsFavorite();
    final finishedYears = await SettingsViewModel.getLibraryFinishedYears();
    final tagFilterMode = await SettingsViewModel.getLibraryTagFilterMode();
    final isReviewed = await SettingsViewModel.getLibraryReviewed();
    final groupSeries = await SettingsViewModel.getLibraryGroupSeries();
    final seriesOnly = await SettingsViewModel.getLibrarySeriesOnly();
    final coverFilter = await SettingsViewModel.getLibraryCoverFilter();
    final pinnedBookIds = await SettingsViewModel.getPinnedBookIds();
    final shelfId = await SettingsViewModel.getLibraryShelfFilter();
    final statsYearFilter = await SettingsViewModel.getStatsYearFilter();
    final statsChartStyle = await SettingsViewModel.getStatsChartStyle();

    if (kDebugMode) {
      final preferencesDebugMessage =
          '''
      ═══════════════════════════════════════════
       LOADING USER PREFERENCES
      ───────────────────────────────────────────
      • Accent Color: ${accentColor.toARGB32().toRadixString(16)}
      • Default Book Type: $defaultBookType
      • Default Rating Style: $defaultRatingStyle
      • Default Tab: $defaultTab
      • Date Format: "$defaultDateFormat"
      • Selected Font: "$selectedFont"
      • Nav Style: "$navStyle"
      • Book View: "$bookView"
      
       LIBRARY FILTER SETTINGS
      ───────────────────────────────────────────
      • Sort Option: "$sortOption"
      • Sort Direction: ${isAscending ? 'Ascending' : 'Descending'}
      • Favorite Filter: ${isFavorite ? 'ON' : 'OFF'}
      • Book Types: ${bookTypes.isEmpty ? 'All' : bookTypes.join(', ')}
      • Finished Years: ${finishedYears.isEmpty ? 'All' : finishedYears.join(', ')}
      • Tag filter mode: $tagFilterMode
      • Reviewed Filter: ${isReviewed ? 'ON' : 'OFF'}
      ═══════════════════════════════════════════
      ''';
      debugPrint(preferencesDebugMessage);
    }

    setState(() {
      _settingsViewModel = SettingsViewModel(
        themeMode: widget.themeMode,
        accentColor: accentColor,
        defaultBookType: defaultBookType,
        defaultRatingStyle: defaultRatingStyle,
        bookView: bookView,
        navStyle: navStyle,
        defaultTab: defaultTab,
        defaultDateFormat: defaultDateFormat,
        selectedFont: selectedFont,
        sortOption: sortOption,
        isAscending: isAscending,
        bookTypes: bookTypes,
        isFavorite: isFavorite,
        finishedYears: finishedYears,
        tagFilterMode: tagFilterMode,
        isReviewed: isReviewed,
        pinnedBookIds: pinnedBookIds,
        shelfId: shelfId,
        statsYearFilter: statsYearFilter,
        statsChartStyle: statsChartStyle,
        groupSeries: groupSeries,
        seriesOnly: seriesOnly,
        coverFilter: coverFilter,
      );
      _isReady = true;
    });

    // Anyone already past onboarding never passes through the request there,
    // so the first launch after updating is where they get asked. Deferred to
    // after the frame that _isReady unblocks, so the system dialog lands over
    // the app rather than over the blank scaffold shown while settings load.
    if (_hasSeenOnboarding) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => NotificationService.instance.ensurePermissionRequested(),
      );
    }
  }

  @override
  void dispose() {
    DatabaseHelper.booksChanged.removeListener(_scheduleBooksReload);
    DatabaseHelper.sessionsChanged.removeListener(_scheduleSessionsReload);
    NotificationService.instance.tappedPayload.removeListener(
      _handleNotificationTap,
    );
    super.dispose();
  }

  /// Open the month a tapped recap notification was announcing.
  ///
  /// Does nothing until both lists are in: the recap is computed from them, and
  /// opening early would show an empty month and then leave it empty. The tap
  /// is left pending instead, and every load calls back here.
  void _handleNotificationTap() {
    final payload = NotificationService.instance.tappedPayload.value;
    if (payload != NotificationService.monthlyRecapPayload &&
        payload != NotificationService.yearlyWrappedPayload) {
      return;
    }
    if (!_booksLoaded || !_sessionsLoaded || !_hasSeenOnboarding) return;
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;

    // Cleared first, so a rebuild or a second load can't push a second copy.
    NotificationService.instance.tappedPayload.value = null;
    if (payload == NotificationService.yearlyWrappedPayload) {
      navigator.push(
        WrappedPage.route(
          books: _books,
          sessions: _sessions,
          year: YearWrapped.featuredYear(),
        ),
      );
      return;
    }
    final month = MonthlyRecap.previousMonthOf(DateTime.now());
    navigator.push(
      MaterialPageRoute(
        builder: (_) => MonthlyRecapPage(
          books: _books,
          sessions: _sessions,
          initialMonth: month,
        ),
      ),
    );
  }

  bool _booksReloadQueued = false;
  bool _sessionsReloadQueued = false;

  // Milestones are checked against both lists at once, so neither can be
  // consulted until both have loaded. Checking early would seed the snapshot
  // from half the data on a first run and then celebrate the rest of it.
  bool _booksLoaded = false;
  bool _sessionsLoaded = false;
  bool _checkingMilestones = false;
  bool _milestoneRecheckQueued = false;
  List<Celebration> _pendingCelebrations = const [];

  /// Diff the new stats against the stored snapshot. Runs after every reload,
  /// so anything that earns a badge — a session, a finished book, an edit that
  /// changes the numbers — is caught without each screen having to remember.
  Future<void> _checkMilestones() async {
    if (!_booksLoaded || !_sessionsLoaded) return;
    // Books and sessions land separately, so a check often starts while the
    // other list is still arriving. Queue rather than drop, or the stats the
    // in-flight check snapshotted would be the last word until something else
    // happened to touch the database.
    if (_checkingMilestones) {
      _milestoneRecheckQueued = true;
      return;
    }

    _checkingMilestones = true;
    try {
      do {
        _milestoneRecheckQueued = false;
        final stats = ReadingStats.from(books: _books, sessions: _sessions);
        final unlocks = await MilestoneService.check(stats);
        // Goals ride the same check: whatever earns a badge can meet a goal.
        // Kept apart from it, though: the badge snapshot is already written
        // by now, so a goal-check failure must not throw away the medals.
        List<GoalAchievement> goalsMet;
        try {
          goalsMet = await GoalAchievementService.check(widget.goalRepository);
        } catch (e) {
          debugPrint('Goal achievement check failed: $e');
          goalsMet = const [];
        }
        // Seasonal medals ride it too, and are kept apart for the same
        // reason.
        final season = Season.of(DateTime.now());
        final inSeason = seasonStats(season, _books, _sessions);
        List<MilestoneUnlock> seasonal;
        try {
          seasonal = await MilestoneService.checkSeason(season, inSeason);
        } catch (e) {
          debugPrint('Seasonal milestone check failed: $e');
          seasonal = const [];
        }
        // Goals first, so a night that does both builds toward the medal;
        // the season's before the lifetime ones, which are the rarer.
        _pendingCelebrations = [
          ..._pendingCelebrations,
          for (final a in goalsMet) Celebration.goal(a),
          for (final u in seasonal)
            Celebration.seasonBadge(u, inSeason, season),
          for (final u in unlocks) Celebration.badge(u, stats),
        ];
      } while (_milestoneRecheckQueued);
      _flushMilestones();
    } finally {
      _checkingMilestones = false;
    }
  }

  /// Keep the reminders that quote live numbers in step with the library.
  ///
  /// Same gate as the milestone check: both lists have to be in before the
  /// reminders are worth recomputing, or a half-loaded snapshot would schedule
  /// a streak warning against no sessions at all.
  void _syncNotificationData() {
    if (!_booksLoaded || !_sessionsLoaded) return;
    NotificationService.instance.updateData(books: _books, sessions: _sessions);
  }

  /// Show queued celebrations, but only once the reader is back at the tab
  /// shell. A finishing session leaves the rating dialog open above it, and a
  /// full-screen celebration dropped on top would bury a form mid-save.
  void _flushMilestones() {
    if (_pendingCelebrations.isEmpty) return;
    final navigator = _navigatorKey.currentState;
    if (navigator == null || !_stackObserver.isSettled) return;

    final celebrations = _pendingCelebrations;
    _pendingCelebrations = const [];
    navigator.push(MilestoneCelebrationPage.route(celebrations: celebrations));
  }

  // A single save can touch several rows (book + cover path, session + book
  // dates), so coalesce the burst into one reload instead of one per write.
  void _scheduleBooksReload() {
    if (_booksReloadQueued) return;
    _booksReloadQueued = true;
    Future.microtask(() {
      _booksReloadQueued = false;
      if (mounted) _loadBooks();
    });
  }

  void _scheduleSessionsReload() {
    if (_sessionsReloadQueued) return;
    _sessionsReloadQueued = true;
    Future.microtask(() {
      _sessionsReloadQueued = false;
      if (mounted) _loadSessions();
    });
  }

  Future<void> _loadBooks() async {
    final books = await widget.bookRepository.getBookRows();
    // Resolve cover paths to current absolute paths. Stored values may be
    // filenames ("42.jpg") or legacy absolute paths from before this fix.
    // On iOS the sandbox UUID changes on app update, making old absolute paths
    // stale — resolveFullPath always rebuilds from the current documents dir.
    final resolvedBooks = <Map<String, dynamic>>[];
    for (final book in books) {
      if (book['cover_path'] != null) {
        final mutable = Map<String, dynamic>.from(book);
        mutable['cover_path'] = await CoverService.resolveFullPath(
          book['cover_path'] as String,
        );
        resolvedBooks.add(mutable);
      } else {
        resolvedBooks.add(book);
      }
    }
    if (!mounted) return;
    setState(() {
      _books = resolvedBooks;
    });
    _booksLoaded = true;
    AnalyticsService.instance.setLibrary(_books);
    LibrarySnapshotService.instance.updateBooks(_books);
    // Goals have no change stream of their own, but restores and demo loads
    // reload the books too; the goal sheet and Goals tab report the rest.
    widget.goalRepository.getGoals().then(
          (goals) => AnalyticsService.instance.setHasGoal(goals.isNotEmpty),
          onError: (_) {},
        );
    _checkMilestones();
    _syncNotificationData();
    _handleNotificationTap();
  }

  Future<void> _addBook(Map<String, dynamic> book) async {
    await widget.bookRepository.addBookRow(book);
    await _loadBooks();
  }

  Future<void> _loadSessions() async {
    final sessions = await widget.sessionRepository.getSessionRows();
    if (!mounted) return;
    setState(() {
      _sessions = sessions;
    });
    _sessionsLoaded = true;
    AnalyticsService.instance.setSessionCount(_sessions.length);
    LibrarySnapshotService.instance.updateSessions(_sessions);
    _checkMilestones();
    _syncNotificationData();
    _handleNotificationTap();
  }

  Future<void> _refreshBooks() async => await _loadBooks();
  Future<void> _refreshSessions() async => await _loadSessions();

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return const MaterialApp(home: Scaffold(body: SizedBox.shrink()));
    }

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _settingsViewModel.themeModeNotifier,
      builder: (context, themeMode, _) {
        return ValueListenableBuilder<Color>(
          valueListenable: _settingsViewModel.accentColorNotifier,
          builder: (context, accentColor, _) {
            return ValueListenableBuilder<String>(
              valueListenable: _settingsViewModel.selectedFontNotifier,
              builder: (context, fontName, _) {
                return MaterialApp(
                  title: 'ReadStats',
                  debugShowCheckedModeBanner: false,
                  scaffoldMessengerKey: scaffoldMessengerKey,
                  navigatorKey: _navigatorKey,
                  navigatorObservers: [_stackObserver],
                  builder: (context, child) =>
                      ImportBannerHost(child: child ?? const SizedBox.shrink()),
                  theme: AppTheme.lightTheme(_settingsViewModel),
                  darkTheme: AppTheme.darkTheme(_settingsViewModel),
                  themeMode: themeMode,
                  home: _hasSeenOnboarding
                      ? NavigationMenu(
                          toggleTheme: _settingsViewModel.toggleTheme,
                          themeMode: themeMode,
                          books: _books,
                          addBook: _addBook,
                          refreshBooks: _refreshBooks,
                          refreshSessions: _refreshSessions,
                          sessions: _sessions,
                          bookRepository: widget.bookRepository,
                          sessionRepository: widget.sessionRepository,
                          tagRepository: widget.tagRepository,
                          goalRepository: widget.goalRepository,
                          importExportService: widget.importExportService,
                          settingsViewModel: _settingsViewModel,
                          timerService: widget.timerService,
                        )
                      : OnboardingPage(
                          onDone: () {
                            setState(() => _hasSeenOnboarding = true);
                            _refreshBooks();
                          },
                          importExportService: widget.importExportService,
                          hasBooks: _books.isNotEmpty,
                        ),
                );
              },
            );
          },
        );
      },
    );
  }
}
