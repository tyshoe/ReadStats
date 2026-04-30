import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:stylish_bottom_bar/stylish_bottom_bar.dart';
import 'data/database/database_helper.dart';
import 'data/repositories/book_repository.dart';
import 'data/repositories/goal_repository.dart';
import 'data/repositories/session_repository.dart';
import 'data/repositories/tag_repository.dart';
import 'data/services/cover_service.dart';
import 'data/services/import_export_service.dart';
import 'ui/pages/library/library_page.dart';
import 'ui/pages/onboarding/onboarding_page.dart';
import 'ui/pages/settings/settings_page.dart';
import 'ui/pages/sessions/sessions_page.dart';
import 'ui/pages/statistics/statistics_page.dart';
import 'ui/themes/app_theme.dart';
import 'viewmodels/SettingsViewModel.dart';
import 'app_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.init();

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
  );

  final themeMode = await SettingsViewModel.loadSavedThemeMode();
  final hasSeenOnboarding = await SettingsViewModel.getHasSeenOnboarding();
  SettingsViewModel.setHasSeenOnboarding();

  runApp(MyApp(
    dbHelper: dbHelper,
    themeMode: themeMode,
    bookRepository: bookRepository,
    sessionRepository: sessionRepository,
    tagRepository: tagRepository,
    goalRepository: goalRepository,
    importExportService: importExportService,
    hasSeenOnboarding: hasSeenOnboarding,
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
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
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
    final pinnedBookIds = await SettingsViewModel.getPinnedBookIds();
    final shelfId = await SettingsViewModel.getLibraryShelfFilter();

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
        pinnedBookIds: pinnedBookIds,
        shelfId: shelfId,
      );
      _isReady = true;
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
    setState(() {
      _books = resolvedBooks;
    });
    if (kDebugMode) print('Books: $_books');
  }

  Future<void> _addBook(Map<String, dynamic> book) async {
    await widget.dbHelper.insertBook(book);
    await _loadBooks();
  }

  Future<void> _loadSessions() async {
    final sessions = await widget.dbHelper.getSessionsWithBooks();
    setState(() {
      _sessions = sessions;
    });
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
        icon: Icon(FluentIcons.settings_24_filled),
        selectedIcon: Icon(FluentIcons.settings_24_filled, color: accentColor),
        title: Text('Settings'),
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
        );
      case 2:
        return StatisticsPage(
          bookRepository: widget.bookRepository,
          sessionRepository: widget.sessionRepository,
          settingsViewModel: widget.settingsViewModel,
        );
      case 3:
      default:
        return SettingsPage(
          toggleTheme: widget.toggleTheme,
          themeMode: widget.themeMode,
          importExportService: widget.importExportService,
          refreshBooks: widget.refreshBooks,
          refreshSessions: widget.refreshSessions,
          settingsViewModel: widget.settingsViewModel,
        );
    }
  }
}