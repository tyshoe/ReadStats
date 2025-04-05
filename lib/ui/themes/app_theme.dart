import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import '/viewmodels/SettingsViewModel.dart';

class AppTheme {
  static const Color lightBackground = CupertinoColors.systemBackground;
  static const Color darkBackground = Color(0xFF121212);

  static CupertinoThemeData lightTheme(SettingsViewModel settings) {
    return CupertinoThemeData(
      brightness: Brightness.light,
      primaryColor: CupertinoColors.systemGrey,
      scaffoldBackgroundColor: lightBackground,
      barBackgroundColor: CupertinoColors.systemGrey5,
      applyThemeToAll: true,
      textTheme: CupertinoTextThemeData(
        textStyle: GoogleFonts.getFont(
          settings.selectedFontNotifier.value,
          color: CupertinoColors.label,
        ),
        primaryColor: CupertinoColors.systemGrey,
      ),
    );
  }

  static CupertinoThemeData darkTheme(SettingsViewModel settings) {
    return CupertinoThemeData(
      brightness: Brightness.dark,
      primaryColor: CupertinoColors.systemGrey,
      scaffoldBackgroundColor: darkBackground,
      barBackgroundColor: Color(0xFF0C0C0C),
      applyThemeToAll: true,
      textTheme: CupertinoTextThemeData(
        textStyle: GoogleFonts.getFont(
          settings.selectedFontNotifier.value,
          color: CupertinoColors.label,
        ),
        primaryColor: CupertinoColors.systemGrey,
      ),
    );
  }

  static CupertinoThemeData systemTheme(
      Brightness brightness, SettingsViewModel settings) {
    return brightness == Brightness.dark
        ? darkTheme(settings)
        : lightTheme(settings);
  }
}
