import 'package:flutter/cupertino.dart';
import 'pages/library_page.dart';
import 'pages/add_book_page.dart';
import 'pages/log_session_page.dart';
import 'pages/settings_page.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDarkMode = false;
  final List<Map<String, dynamic>> _books = []; // List to store books

  void _toggleTheme(bool value) {
    setState(() {
      _isDarkMode = value;
    });
  }

  void _addBook(Map<String, dynamic> book) {
    setState(() {
      _books.add(book);
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
      ),
    );
  }
}

class NavigationMenu extends StatelessWidget {
  final Function(bool) toggleTheme;
  final Function(Map<String, dynamic>) addBook;
  final bool isDarkMode;
  final List<Map<String, dynamic>> books;

  const NavigationMenu({
    super.key,
    required this.toggleTheme,
    required this.isDarkMode,
    required this.books,
    required this.addBook,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.book), label: 'Library'),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.book), label: 'Add Book'),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.chart_bar), label: 'Log Session'),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.settings), label: 'Settings'),
        ],
      ),
      tabBuilder: (context, index) {
        switch (index) {
          case 0:
            return HomePage(books: books);
          case 1:
            return AddBookPage(addBook: addBook);
          case 2:
            return const LogSessionPage();
          case 3:
          default:
            return SettingsPage(toggleTheme: toggleTheme, isDarkMode: isDarkMode);
        }
      },
    );
  }
}
