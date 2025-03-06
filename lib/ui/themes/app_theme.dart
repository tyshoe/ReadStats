import 'package:flutter/cupertino.dart';

class AppTheme {
  static final CupertinoThemeData lightTheme = CupertinoThemeData(
    brightness: Brightness.light,
    primaryColor: CupertinoColors.systemGrey,
    scaffoldBackgroundColor: CupertinoColors.systemBackground,
    barBackgroundColor: CupertinoColors.systemBackground,
    textTheme: CupertinoTextThemeData(
      textStyle: TextStyle(color: CupertinoColors.label),
      primaryColor: CupertinoColors.systemGrey,
    ),
  );

  static final CupertinoThemeData darkTheme = CupertinoThemeData(
    brightness: Brightness.dark,
    primaryColor: CupertinoColors.systemGrey,
    scaffoldBackgroundColor: CupertinoColors.black,
    barBackgroundColor: CupertinoColors.black,
    textTheme: CupertinoTextThemeData(
      textStyle: TextStyle(color: CupertinoColors.label),
      primaryColor: CupertinoColors.systemGrey,
    ),
  );
}