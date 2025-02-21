import 'package:flutter/cupertino.dart';
import 'database/database_helper.dart';
import 'pages/library_page.dart';
import 'pages/settings_page.dart';
import 'pages/sessions_page.dart';
import 'pages/session_stats_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dbHelper = DatabaseHelper();
  await dbHelper.database;
  runApp(MyApp(dbHelper: dbHelper));
}

class MyApp extends StatefulWidget {
  final DatabaseHelper dbHelper;

  const MyApp({super.key, required this.dbHelper});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDarkMode = false;
  List<Map<String, dynamic>> _books = [];
  List<Map<String, dynamic>> _sessions = [];

  void _toggleTheme(bool isDark) {
    setState(() {
      _isDarkMode = isDark;
    });
  }

  Future<void> _loadBooks() async {
    final books = await widget.dbHelper.getBooks();
    setState(() {
      _books = books;
    });
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
  void initState() {
    super.initState();
    _loadBooks();
    _loadSessions();
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

  const NavigationMenu({
    super.key,
    required this.toggleTheme,
    required this.isDarkMode,
    required this.books,
    required this.addBook,
    required this.refreshBooks,
    required this.sessions,
    required this.refreshSessions,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.book), label: 'Library'),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.time), label: 'Sessions'),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.chart_bar), label: 'Stats'),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.settings), label: 'Settings'),
        ],
      ),
      tabBuilder: (context, index) {
        switch (index) {
          case 0:
            return LibraryPage(books: books, refreshBooks: refreshBooks);
          case 1:
            return SessionsPage(books: books, sessions: sessions, refreshSessions: refreshSessions);
          case 2:
            return SessionStatsPage();
          case 3:
          default:
            return SettingsPage(
              onThemeSelected: toggleTheme,
              isDarkMode: isDarkMode,
            );
        }
      },
    );
  }
}
