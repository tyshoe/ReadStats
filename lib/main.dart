import 'package:flutter/cupertino.dart';
import 'pages/home_page.dart';
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

  void _toggleTheme(bool value) {
    setState(() {
      _isDarkMode = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      theme: CupertinoThemeData(
        brightness: _isDarkMode ? Brightness.dark : Brightness.light,
      ),
      home: NavigationMenu(toggleTheme: _toggleTheme, isDarkMode: _isDarkMode),
    );
  }
}

class NavigationMenu extends StatelessWidget {
  final Function(bool) toggleTheme;
  final bool isDarkMode;

  const NavigationMenu({super.key, required this.toggleTheme, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.book), label: 'Add Book'),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.chart_bar), label: 'Log Session'),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.settings), label: 'Settings'),
        ],
      ),
      tabBuilder: (context, index) {
        switch (index) {
          case 0:
            return const HomePage();
          case 1:
            return const AddBookPage();
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
