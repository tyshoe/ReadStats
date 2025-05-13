import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../viewmodels/SettingsViewModel.dart';

class AppTheme {
  static ThemeData lightTheme(SettingsViewModel settings) {
    final font = GoogleFonts.getFont(settings.selectedFontNotifier.value);

    return ThemeData(
      brightness: Brightness.light,
      primaryColor: settings.accentColorNotifier.value,
      scaffoldBackgroundColor: Colors.white,
      fontFamily: font.toString(),
      colorScheme: ColorScheme.fromSeed(
        seedColor: settings.accentColorNotifier.value,
        brightness: Brightness.light,
      ),
      cardColor: Colors.black12,
      textTheme: TextTheme(
        bodyLarge: font,
        bodyMedium: font,
        labelLarge: font,
      ),
      useMaterial3: true,
    );
  }

  static ThemeData darkTheme(SettingsViewModel settings) {
    final font = GoogleFonts.getFont(settings.selectedFontNotifier.value);

    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: settings.accentColorNotifier.value,
      scaffoldBackgroundColor: const Color(0xFF121212),
      colorScheme: ColorScheme.fromSeed(
        seedColor: settings.accentColorNotifier.value,
        brightness: Brightness.dark,
      ),
      textTheme: TextTheme(
        bodyLarge: font,
        bodyMedium: font,
        labelLarge: font,
      ),
      useMaterial3: true,
    );
  }
}
