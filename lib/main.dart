import 'package:flutter/cupertino.dart';

void main() => runApp(const FormSectionApp());

class FormSectionApp extends StatelessWidget {
  const FormSectionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      theme: CupertinoThemeData(brightness: Brightness.light),
      home: NavigationMenu(),
    );
  }
}

class NavigationMenu extends StatelessWidget {
  const NavigationMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.add), label: 'Add Book'),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.chart_bar), label: 'Log Session'),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.settings), label: 'Settings'),
        ],
      ),
      tabBuilder: (context, index) {
        switch (index) {
          case 0:
            return const CupertinoPageScaffold(
              navigationBar: CupertinoNavigationBar(middle: Text('Home')),
              child: Center(child: Text('Home Page')),
            );
          case 1:
            return const CupertinoPageScaffold(
              navigationBar: CupertinoNavigationBar(middle: Text('Add Book')),
              child: Center(child: Text('Add Book Page')),
            );
          case 2:
            return const CupertinoPageScaffold(
              navigationBar: CupertinoNavigationBar(middle: Text('Log Session')),
              child: Center(child: Text('Log Session Page')),
            );
          case 3:
          default:
            return const CupertinoPageScaffold(
              navigationBar: CupertinoNavigationBar(middle: Text('Settings')),
              child: Center(child: Text('Settings Page')),
            );
        }
      },
    );
  }
}
