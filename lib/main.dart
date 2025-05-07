import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'data/database/database_helper.dart';
import 'data/repositories/book_repository.dart';
import 'data/repositories/session_repository.dart';
import 'ui/pages/library/library_page.dart';
import 'ui/pages/settings/settings_page.dart';
import 'ui/pages/sessions_page.dart';
import 'ui/pages/statistics_page.dart';
import 'ui/themes/app_theme.dart';
import 'viewmodels/SettingsViewModel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize database and repositories
  final dbHelper = DatabaseHelper();
  await dbHelper.database;

  final bookRepository = BookRepository(dbHelper);
  final sessionRepository = SessionRepository(dbHelper);

  // Load saved theme preference
  final themeMode = await SettingsViewModel.loadSavedThemeMode();

  runApp(MyApp(
    dbHelper: dbHelper,
    themeMode: themeMode,
    bookRepository: bookRepository,
    sessionRepository: sessionRepository,
  ));
}

class MyApp extends StatefulWidget {
  final DatabaseHelper dbHelper;
  final ThemeMode themeMode;
  final BookRepository bookRepository;
  final SessionRepository sessionRepository;

  const MyApp({
    super.key,
    required this.dbHelper,
    required this.themeMode,
    required this.bookRepository,
    required this.sessionRepository,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late SettingsViewModel _settingsViewModel;
  List<Map<String, dynamic>> _books = [];
  List<Map<String, dynamic>> _sessions = [];

  @override
  void initState() {
    super.initState();
    _initializeSettingsViewModel();
    _loadBooks();
    _loadSessions();
  }

  Future<void> _initializeSettingsViewModel() async {
    final accentColor = await SettingsViewModel.getAccentColor();
    final defaultBookType = await SettingsViewModel.getDefaultBookType();
    final defaultRatingStyle = await SettingsViewModel.getDefaultRatingStyle();
    final sortOption = await SettingsViewModel.getLibrarySortOption();
    final isAscending = await SettingsViewModel.getLibrarySortAscending();
    final bookFormat = await SettingsViewModel.getLibraryBookFormatFilter();
    final bookView = await SettingsViewModel.getLibraryBookView();
    final tabNameVisibility = await SettingsViewModel.getTabNameVisibility();
    final defaultTab = await SettingsViewModel.getDefaultTab();
    final defaultDateFormat = await SettingsViewModel.getDefaultDateFormat();
    final selectedFont = await SettingsViewModel.getSelectedFont();

    if (kDebugMode) {
      print("Loading Preferences: {Default Book Type: $defaultBookType,"
          " Library Sort Option: $sortOption,"
          " Library Sort Ascending: $isAscending,"
          " Library Book Format Filter: $bookFormat}"
          " Library Book View: $bookView}");
    }

    _settingsViewModel = SettingsViewModel(
        themeMode: widget.themeMode,
        accentColor: accentColor,
        defaultBookType: defaultBookType,
        defaultRatingStyle: defaultRatingStyle,
        sortOption: sortOption,
        isAscending: isAscending,
        bookFormat: bookFormat,
        bookView: bookView,
        tabNameVisibility: tabNameVisibility,
        defaultTab: defaultTab,
        defaultDateFormat: defaultDateFormat,
        selectedFont: selectedFont);
  }

  Future<void> _loadBooks() async {
    final books = await widget.dbHelper.getBooks();
    setState(() {
      _books = books;
    });
    if (kDebugMode) {
      print('Books: $_books');
    }
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

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _settingsViewModel.themeModeNotifier,
      builder: (context, themeMode, child) {
      return ValueListenableBuilder<String>(
        valueListenable: _settingsViewModel.selectedFontNotifier,
        builder: (context, font, child) {
          return CupertinoApp(
            theme: themeMode == ThemeMode.system
                ? AppTheme.systemTheme(
                    MediaQuery.of(context).platformBrightness,
                    _settingsViewModel, // Pass the ViewModel here
                  )
                : themeMode == ThemeMode.dark
                    ? AppTheme.darkTheme(_settingsViewModel) // Pass to dark theme
                    : AppTheme.lightTheme(_settingsViewModel), // Pass to l
            home: NavigationMenu(
              toggleTheme: _settingsViewModel.toggleTheme,
              themeMode: themeMode,
              books: _books,
              addBook: _addBook,
              refreshBooks: _loadBooks,
              refreshSessions: _loadSessions,
              sessions: _sessions,
              bookRepository: widget.bookRepository,
              sessionRepository: widget.sessionRepository,
              settingsViewModel: _settingsViewModel,
            ),
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
        return ValueListenableBuilder<String>(
          valueListenable: widget.settingsViewModel.tabNameVisibilityNotifier,
          builder: (context, tabVisibility, child) {
            return CupertinoTabScaffold(
              tabBar: CupertinoTabBar(
                currentIndex: _activeTabIndex,
                activeColor: accentColor,
                inactiveColor: CupertinoColors.systemGrey,
                onTap: (index) {
                  setState(() {
                    _activeTabIndex = index;
                  });
                },
                items: [
                  BottomNavigationBarItem(
                    icon: Icon(CupertinoIcons.book),
                    activeIcon: Icon(CupertinoIcons.book_fill),
                    label: _getTabLabel('Library', tabVisibility),
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(CupertinoIcons.time),
                    activeIcon: Icon(CupertinoIcons.time_solid),
                    label: _getTabLabel('Sessions', tabVisibility),
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(CupertinoIcons.chart_bar),
                    activeIcon: Icon(CupertinoIcons.chart_bar_fill),
                    label: _getTabLabel('Stats', tabVisibility),
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(CupertinoIcons.settings),
                    activeIcon: Icon(CupertinoIcons.settings_solid),
                    label: _getTabLabel('Settings', tabVisibility),
                  ),
                ],
              ),
              tabBuilder: (context, index) {
                switch (index) {
                  case 0:
                    return LibraryPage(
                      books: widget.books,
                      refreshBooks: widget.refreshBooks,
                      refreshSessions: widget.refreshSessions,
                      settingsViewModel: widget.settingsViewModel,
                      sessionRepository: widget.sessionRepository,
                    );
                  case 1:
                    return SessionsPage(
                      books: widget.books,
                      sessions: widget.sessions,
                      refreshSessions: widget.refreshSessions,
                      settingsViewModel: widget.settingsViewModel,
                      sessionRepository: widget.sessionRepository,
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
                      bookRepository: widget.bookRepository,
                      sessionRepository: widget.sessionRepository,
                      refreshBooks: widget.refreshBooks,
                      refreshSessions: widget.refreshSessions,
                      settingsViewModel: widget.settingsViewModel,
                    );
                }
              },
            );
          },
        );
      },
    );
  }

  String _getTabLabel(String tabName, String tabVisibility) {
    if (tabVisibility == 'Always') {
      return tabName; // Always show the label
    } else if (tabVisibility == 'Selected' && _isTabActive(tabName)) {
      return tabName; // Show label if tab is active
    } else {
      return ''; // Hide the label for other cases
    }
  }

  bool _isTabActive(String tabName) {
    // Check if the tabName matches the active tab index
    switch (tabName) {
      case 'Library':
        return _activeTabIndex == 0;
      case 'Sessions':
        return _activeTabIndex == 1;
      case 'Stats':
        return _activeTabIndex == 2;
      case 'Settings':
        return _activeTabIndex == 3;
      default:
        return false;
    }
  }
}
