import 'package:flutter/cupertino.dart';

class AppTheme {
  static const Color lightBackground = CupertinoColors.systemBackground;
  static const Color darkBackground = Color(0xFF121212);

  static final CupertinoThemeData lightTheme = CupertinoThemeData(
    brightness: Brightness.light,
    primaryColor: CupertinoColors.systemGrey,
    scaffoldBackgroundColor: lightBackground,
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
    scaffoldBackgroundColor: darkBackground,
    barBackgroundColor: Color(0xFF0C0C0C),
    applyThemeToAll: true,
    textTheme: CupertinoTextThemeData(
      textStyle: TextStyle(color: CupertinoColors.label),
      primaryColor: CupertinoColors.systemGrey,
    ),
  );
}
