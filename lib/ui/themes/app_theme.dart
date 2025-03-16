import 'package:flutter/cupertino.dart';

class AppTheme {
  static final CupertinoThemeData lightTheme = CupertinoThemeData(
    brightness: Brightness.light,
    primaryColor: CupertinoColors.systemGrey,
    scaffoldBackgroundColor: CupertinoColors.systemBackground,
    barBackgroundColor: CupertinoColors.systemGrey5,
    applyThemeToAll: true,
    textTheme: CupertinoTextThemeData(
      textStyle: TextStyle(color: CupertinoColors.label),
      primaryColor: CupertinoColors.systemGrey,
    ),
  );

  static final CupertinoThemeData darkTheme = CupertinoThemeData(
    brightness: Brightness.dark,
    primaryColor: CupertinoColors.systemGrey,
    scaffoldBackgroundColor: Color(0xFF121212),
    barBackgroundColor: Color(0xFF0C0C0C),
    applyThemeToAll: true,
    textTheme: CupertinoTextThemeData(
      textStyle: TextStyle(color: CupertinoColors.label),
      primaryColor: CupertinoColors.systemGrey,
    ),
  );
}
