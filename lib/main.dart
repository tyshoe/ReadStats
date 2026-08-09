import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stylish_bottom_bar/stylish_bottom_bar.dart';
import 'data/database/database_helper.dart';
import 'data/repositories/book_repository.dart';
import 'data/repositories/goal_repository.dart';
import 'data/repositories/session_repository.dart';
import 'data/repositories/tag_repository.dart';
import 'data/services/cover_service.dart';
import 'data/services/import_export_service.dart';
import 'data/services/reading_timer_service.dart';
import 'data/services/rating_service.dart';
import 'data/services/milestone_service.dart';
import 'data/services/notification_prefs_store.dart';
import 'data/services/notification_service.dart';
import 'ui/pages/profile/milestone_celebration_page.dart';
import 'ui/pages/profile/reading_stats.dart';
import 'ui/pages/library/library_page.dart';
import 'ui/pages/onboarding/onboarding_page.dart';
import 'ui/pages/profile/profile_page.dart';
import 'ui/pages/settings/settings_page.dart';
import 'ui/pages/sessions/sessions_page.dart';
import 'ui/pages/statistics/statistics_page.dart';
import 'ui/themes/app_theme.dart';
import 'viewmodels/SettingsViewModel.dart';
import 'ui/widgets/app_snackbar.dart';
import 'app_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await AppConfig.init();
  await RatingService.instance.registerAppStart();

  final dbHelper = DatabaseHelper();
  await dbHelper.database;

  final bookRepository = BookRepository(dbHelper);
  final sessionRepository = SessionRepository(dbHelper);
  final tagRepository = TagRepository(dbHelper);
  final goalRepository = GoalRepository(dbHelper);

  final importExportService = ImportExportService(
    bookRepository: bookRepository,
    sessionRepository: sessionRepository,
    tagRepository: tagRepository,
    goalRepository: goalRepository,
  );

  final themeMode = await SettingsViewModel.loadSavedThemeMode();
  final hasSeenOnboarding = await SettingsViewModel.getHasSeenOnboarding();
  SettingsViewModel.setHasSeenOnboarding();

  final timerService = ReadingTimerService();
  await timerService.restore();

  // Reminders are re-registered on every launch. Alarms don't survive an app
  // update, a force stop, or a timezone change, and none of those tell the app
  // to fix things up — rescheduling at launch covers all of them.
  await NotificationPrefsStore.instance.load();
  NotificationService.instance.configure(goalRepository: goalRepository);
  await NotificationService.instance.init();
  // Arms the reminders that need no data. The ones that quote live numbers
  // follow once the first books/sessions load reaches updateData below.
  await NotificationService.instance.rescheduleAll();

  runApp(MyApp(
    dbHelper: dbHelper,
    themeMode: themeMode,
    bookRepository: bookRepository,
    sessionRepository: sessionRepository,
    tagRepository: tagRepository,
    goalRepository: goalRepository,
    importExportService: importExportService,
    hasSeenOnboarding: hasSeenOnboarding,
    timerService: timerService,
  ));
}

class MyApp extends StatefulWidget {
  final DatabaseHelper dbHelper;
  final ThemeMode themeMode;
  final BookRepository bookRepository;
  final SessionRepository sessionRepository;
  final TagRepository tagRepository;
  final GoalRepository goalRepository;
  final ImportExportService importExportService;
  final bool hasSeenOnboarding;
  final ReadingTimerService timerService;

  const MyApp({
    super.key,
    required this.dbHelper,
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
  State<MyApp> createState() => _MyAppState();
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

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final _StackUnwindObserver _stackObserver =
      _StackUnwindObserver(_flushMilestones);
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
    final pinnedBookIds = await SettingsViewModel.getPinnedBookIds();
    final shelfId = await SettingsViewModel.getLibraryShelfFilter();
    final statsYearFilter = await SettingsViewModel.getStatsYearFilter();
    final statsChartStyle = await SettingsViewModel.getStatsChartStyle();

    if (kDebugMode) {
      final preferencesDebugMessage = '''
      ═══════════════════════════════════════════
       LOADING USER PREFERENCES
      ───────────────────────────────────────────
      • Accent Color: ${accentColor.value.toRadixString(16)}
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
    super.dispose();
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
  List<MilestoneUnlock> _pendingUnlocks = const [];

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
        final unlocks = await MilestoneService.check(
          ReadingStats.from(books: _books, sessions: _sessions),
        );
        if (unlocks.isNotEmpty) {
          _pendingUnlocks = [..._pendingUnlocks, ...unlocks];
        }
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
    NotificationService.instance
        .updateData(books: _books, sessions: _sessions);
  }

  /// Show queued celebrations, but only once the reader is back at the tab
  /// shell. A finishing session leaves the rating dialog open above it, and a
  /// full-screen celebration dropped on top would bury a form mid-save.
  void _flushMilestones() {
    if (_pendingUnlocks.isEmpty) return;
    final navigator = _navigatorKey.currentState;
    if (navigator == null || !_stackObserver.isSettled) return;

    final unlocks = _pendingUnlocks;
    _pendingUnlocks = const [];
    navigator.push(
      MilestoneCelebrationPage.route(
        unlocks: unlocks,
        stats: ReadingStats.from(books: _books, sessions: _sessions),
      ),
    );
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
    final books = await widget.dbHelper.getBooks();
    // Resolve cover paths to current absolute paths. Stored values may be
    // filenames ("42.jpg") or legacy absolute paths from before this fix.
    // On iOS the sandbox UUID changes on app update, making old absolute paths
    // stale — resolveFullPath always rebuilds from the current documents dir.
    final resolvedBooks = <Map<String, dynamic>>[];
    for (final book in books) {
      if (book['cover_path'] != null) {
        final mutable = Map<String, dynamic>.from(book);
        mutable['cover_path'] = await CoverService.resolveFullPath(book['cover_path'] as String);
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
    _checkMilestones();
    _syncNotificationData();
    if (kDebugMode) print('Books: $_books');
  }

  Future<void> _addBook(Map<String, dynamic> book) async {
    await widget.dbHelper.insertBook(book);
    await _loadBooks();
  }

  Future<void> _loadSessions() async {
    final sessions = await widget.dbHelper.getSessionsWithBooks();
    if (!mounted) return;
    setState(() {
      _sessions = sessions;
    });
    _sessionsLoaded = true;
    _checkMilestones();
    _syncNotificationData();
  }

  Future<void> _refreshBooks() async => await _loadBooks();
  Future<void> _refreshSessions() async => await _loadSessions();

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return const MaterialApp(
        home: Scaffold(
          body: SizedBox.shrink(),
        ),
      );
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

class NavigationMenu extends StatefulWidget {
  final Function(ThemeMode) toggleTheme;
  final ThemeMode themeMode;
  final Function(Map<String, dynamic>) addBook;
  final Function() refreshBooks;
  final Function() refreshSessions;
  final List<Map<String, dynamic>> books;
  final List<Map<String, dynamic>> sessions;
  final BookRepository bookRepository;
  final SessionRepository sessionRepository;
  final TagRepository tagRepository;
  final GoalRepository goalRepository;
  final ImportExportService importExportService;
  final SettingsViewModel settingsViewModel;
  final ReadingTimerService timerService;

  const NavigationMenu({
    super.key,
    required this.toggleTheme,
    required this.themeMode,
    required this.books,
    required this.addBook,
    required this.refreshBooks,
    required this.refreshSessions,
    required this.sessions,
    required this.bookRepository,
    required this.sessionRepository,
    required this.tagRepository,
    required this.goalRepository,
    required this.importExportService,
    required this.settingsViewModel,
    required this.timerService,
  });

  @override
  State<NavigationMenu> createState() => _NavigationMenuState();
}

class _NavigationMenuState extends State<NavigationMenu> {
  late int _activeTabIndex;

  @override
  void initState() {
    super.initState();
    _activeTabIndex = widget.settingsViewModel.defaultTabNotifier.value;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: widget.settingsViewModel.accentColorNotifier,
      builder: (context, accentColor, child) {
        return ValueListenableBuilder<IconStyle>(
          valueListenable: widget.settingsViewModel.navStyleNotifier,
          builder: (context, tabVisibility, child) {
            return Scaffold(
              body: _getPage(_activeTabIndex),
              bottomNavigationBar: Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(context).dividerColor.withAlpha(128),
                      width: .25,
                    ),
                  ),
                ),
                child: StylishBottomBar(
                  items: _buildBottomBarItems(accentColor),
                  currentIndex: _activeTabIndex,
                  onTap: (index) {
                    setState(() {
                      _activeTabIndex = index;
                    });
                  },
                  option: AnimatedBarOptions(
                    iconSize: 28,
                    iconStyle: widget.settingsViewModel.navStyleNotifier.value,
                    opacity: 0.3,
                  ),
                  backgroundColor: Theme.of(context).colorScheme.surface,
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<BottomBarItem> _buildBottomBarItems(Color accentColor) {
    return [
      BottomBarItem(
        icon: Icon(FluentIcons.library_16_filled),
        selectedIcon: Icon(FluentIcons.library_16_filled, color: accentColor),
        title: Text('Library'),
        unSelectedColor: Colors.grey,
        selectedColor: accentColor,
      ),
      BottomBarItem(
        icon: Icon(FluentIcons.calendar_16_filled),
        selectedIcon: Icon(FluentIcons.calendar_16_filled, color: accentColor),
        title: Text('Tracking'),
        unSelectedColor: Colors.grey,
        selectedColor: accentColor,
      ),
      BottomBarItem(
        icon: Icon(FluentIcons.data_pie_16_filled),
        selectedIcon: Icon(FluentIcons.data_pie_16_filled, color: accentColor),
        title: Text('Stats'),
        unSelectedColor: Colors.grey,
        selectedColor: accentColor,
      ),
      BottomBarItem(
        icon: Icon(FluentIcons.person_16_filled),
        selectedIcon: Icon(FluentIcons.person_16_filled, color: accentColor),
        title: Text('Profile'),
        unSelectedColor: Colors.grey,
        selectedColor: accentColor,
      ),
    ];
  }

  Widget _getPage(int index) {
    switch (index) {
      case 0:
        return LibraryPage(
          books: widget.books,
          refreshBooks: widget.refreshBooks,
          refreshSessions: widget.refreshSessions,
          settingsViewModel: widget.settingsViewModel,
          sessionRepository: widget.sessionRepository,
          bookRepository: widget.bookRepository,
        );
      case 1:
        return SessionsPage(
          books: widget.books,
          sessions: widget.sessions,
          refreshSessions: widget.refreshSessions,
          refreshBooks: widget.refreshBooks,
          settingsViewModel: widget.settingsViewModel,
          sessionRepository: widget.sessionRepository,
          bookRepository: widget.bookRepository,
          goalRepository: widget.goalRepository,
          timerService: widget.timerService,
        );
      case 2:
        return StatisticsPage(
          bookRepository: widget.bookRepository,
          sessionRepository: widget.sessionRepository,
          settingsViewModel: widget.settingsViewModel,
        );
      case 3:
      default:
        return ProfilePage(
          books: widget.books,
          sessions: widget.sessions,
          settingsViewModel: widget.settingsViewModel,
          goalRepository: widget.goalRepository,
          onOpenSettings: (ctx) => Navigator.of(ctx).push(
            MaterialPageRoute(
              builder: (_) => SettingsPage(
                toggleTheme: widget.toggleTheme,
                themeMode: widget.themeMode,
                importExportService: widget.importExportService,
                refreshBooks: widget.refreshBooks,
                refreshSessions: widget.refreshSessions,
                settingsViewModel: widget.settingsViewModel,
                timerService: widget.timerService,
              ),
            ),
          ),
        );
    }
  }
}