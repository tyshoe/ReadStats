import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'data/database/database_helper.dart';
import 'data/repositories/book_repository.dart';
import 'data/repositories/session_repository.dart';
import 'ui/pages/library_page/library_page.dart';
import 'ui/pages/settings_page.dart';
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
    final sortOption = await SettingsViewModel.getLibrarySortOption();
    final isAscending = await SettingsViewModel.getLibrarySortAscending();
    final bookFormat = await SettingsViewModel.getLibraryBookFormatFilter();
    final bookView = await SettingsViewModel.getLibraryBookView();

    if (kDebugMode) {
      print(
          "Loading Prefrences: {Default Book Type: $defaultBookType,"
              " Library Sort Option: $sortOption,"
              " Library Sort Ascending: $isAscending,"
              " Library Book Format Filter: $bookFormat}"
              " Library Book View: $bookView}");
    }

    _settingsViewModel = SettingsViewModel(
      themeMode: widget.themeMode,
      accentColor: accentColor,
      defaultBookType: defaultBookType,
      sortOption: sortOption,
      isAscending: isAscending,
      bookFormat: bookFormat,
      bookView: bookView,
    );
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
        return CupertinoApp(
          theme: themeMode == ThemeMode.system
              ? AppTheme.systemTheme(MediaQuery.of(context).platformBrightness)
              : themeMode == ThemeMode.dark
                  ? AppTheme.darkTheme
                  : AppTheme.lightTheme,
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
  }
}

class NavigationMenu extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: settingsViewModel.accentColorNotifier,
      builder: (context, accentColor, child) {
        return CupertinoTabScaffold(
          tabBar: CupertinoTabBar(
            activeColor: accentColor,
            inactiveColor: CupertinoColors.systemGrey,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.book),
                activeIcon: Icon(CupertinoIcons.book_fill),
                label: 'Library',
              ),
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.time),
                activeIcon: Icon(CupertinoIcons.time_solid),
                label: 'Sessions',
              ),
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.chart_bar),
                activeIcon: Icon(CupertinoIcons.chart_bar_fill),
                label: 'Stats',
              ),
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.settings),
                activeIcon: Icon(CupertinoIcons.settings_solid),
                label: 'Settings',
              ),
            ],
          ),
          tabBuilder: (context, index) {
            switch (index) {
              case 0:
                return LibraryPage(
                  books: books,
                  refreshBooks: refreshBooks,
                  refreshSessions: refreshSessions,
                  settingsViewModel: settingsViewModel,
                  sessionRepository: sessionRepository,
                );
              case 1:
                return SessionsPage(
                  books: books,
                  sessions: sessions,
                  refreshSessions: refreshSessions,
                  settingsViewModel: settingsViewModel,
                  sessionRepository: sessionRepository,
                );
              case 2:
                return StatisticsPage(
                  bookRepository: bookRepository,
                  sessionRepository: sessionRepository,
                  settingsViewModel: settingsViewModel,
                );
              case 3:
              default:
                return SettingsPage(
                  toggleTheme: toggleTheme,
                  themeMode: themeMode,
                  bookRepository: bookRepository,
                  sessionRepository: sessionRepository,
                  refreshBooks: refreshBooks,
                  refreshSessions: refreshSessions,
                  settingsViewModel: settingsViewModel,
                );
            }
          },
        );
      },
    );
  }
}
