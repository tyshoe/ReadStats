import 'package:flutter/cupertino.dart';
import 'pages/library_page.dart';
import 'pages/log_session_page.dart';
import 'pages/settings_page.dart';
import 'pages/sessions_page.dart';
import 'database_helper.dart';

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

  void _toggleTheme(bool value) {
    setState(() {
      _isDarkMode = value;
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
    await _loadBooks(); // Refresh the book list
  }

  @override
  void initState() {
    super.initState();
    _loadBooks(); // Load books when the app starts
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
        refreshBooks: _loadBooks, // Pass refresh function
      ),
    );
  }
}

class NavigationMenu extends StatelessWidget {
  final Function(bool) toggleTheme;
  final Function(Map<String, dynamic>) addBook;
  final Function() refreshBooks;
  final bool isDarkMode;
  final List<Map<String, dynamic>> books;

  const NavigationMenu({
    super.key,
    required this.toggleTheme,
    required this.isDarkMode,
    required this.books,
    required this.addBook,
    required this.refreshBooks,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.book), label: 'Library'),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.add), label: 'Sessions'),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.chart_bar), label: 'Log Session'),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.settings), label: 'Settings'),
        ],
      ),
      tabBuilder: (context, index) {
        switch (index) {
          case 0:
            return LibraryPage(books: books, refreshBooks: refreshBooks);
          case 1:
          // Return an empty container or the LibraryPage again
            return SessionsPage();
          case 2:
            return LogSessionPage(books: books);
          case 3:
          default:
            return SettingsPage(toggleTheme: toggleTheme, isDarkMode: isDarkMode);
        }
      },
    );
  }
}