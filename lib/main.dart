import 'package:flutter/cupertino.dart';
import 'package:read_stats/repositories/book_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database/database_helper.dart';
import 'pages/library_page.dart';
import 'pages/settings_page.dart';
import 'pages/sessions_page.dart';
import 'pages/session_stats_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dbHelper = DatabaseHelper();
  await dbHelper.database;

  final bookRepository = BookRepository(dbHelper);

  // Load saved theme preference
  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool isDarkMode = prefs.getBool('isDarkMode') ?? false;

  runApp(MyApp(dbHelper: dbHelper, isDarkMode: isDarkMode, bookRepository: bookRepository));
}

class MyApp extends StatefulWidget {
  final DatabaseHelper dbHelper;
  final bool isDarkMode;
  final BookRepository bookRepository;

  const MyApp({super.key, required this.dbHelper, required this.isDarkMode, required this.bookRepository});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late bool _isDarkMode;
  List<Map<String, dynamic>> _books = [];
  List<Map<String, dynamic>> _sessions = [];

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.isDarkMode; // Initialize _isDarkMode with saved value
    _loadBooks();
    _loadSessions();
  }

  void _toggleTheme(bool isDark) async {
    setState(() {
      _isDarkMode = isDark;
    });
    // Save theme preference
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool('isDarkMode', isDark);
  }

  Future<void> _loadBooks() async {
    final books = await widget.dbHelper.getBooks();
    setState(() {
      _books = books;
    });
    print('Books: $_books');
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
    return CupertinoApp(
      theme: CupertinoThemeData(
        brightness: _isDarkMode ? Brightness.dark : Brightness.light,
      ),
      home: NavigationMenu(
        toggleTheme: _toggleTheme,
        isDarkMode: _isDarkMode,
        books: _books,
        addBook: _addBook,
        refreshBooks: _loadBooks,
        refreshSessions: _loadSessions,
        sessions: _sessions,
        bookRepository: widget.bookRepository,
      ),
    );
  }
}

class NavigationMenu extends StatelessWidget {
  final Function(bool) toggleTheme;
  final Function(Map<String, dynamic>) addBook;
  final Function() refreshBooks;
  final Function() refreshSessions;
  final bool isDarkMode;
  final List<Map<String, dynamic>> books;
  final List<Map<String, dynamic>> sessions;
  final BookRepository bookRepository;

  const NavigationMenu({
    super.key,
    required this.toggleTheme,
    required this.isDarkMode,
    required this.books,
    required this.addBook,
    required this.refreshBooks,
    required this.refreshSessions,
    required this.sessions,
    required this.bookRepository,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        activeColor: CupertinoColors.systemPurple,
        inactiveColor: CupertinoColors.systemGrey,
        items: [
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
            return LibraryPage(books: books, refreshBooks: refreshBooks, refreshSessions: refreshSessions);
          case 1:
            return SessionsPage(books: books, sessions: sessions, refreshSessions: refreshSessions);
          case 2:
            return SessionStatsPage();
          case 3:
          default:
            return SettingsPage(
              onThemeSelected: toggleTheme,
              isDarkMode: isDarkMode,
              bookRepository: bookRepository,
              refreshBooks: refreshBooks,
              refreshSessions: refreshSessions
            );
        }
      },
    );
  }
}
