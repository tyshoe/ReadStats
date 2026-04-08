import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../viewmodels/SettingsViewModel.dart';

class AppTheme {
  static TextTheme _buildTextTheme(String fontName) {
    final font = GoogleFonts.getFont(fontName);
    return TextTheme(
      displayLarge: font,
      displayMedium: font,
      displaySmall: font,
      headlineLarge: font,
      headlineMedium: font,
      headlineSmall: font,
      titleLarge: font,
      titleMedium: font,
      titleSmall: font,
      bodyLarge: font,
      bodyMedium: font,
      bodySmall: font,
      labelLarge: font,
      labelMedium: font,
      labelSmall: font,
    );
  }

  static ThemeData lightTheme(SettingsViewModel settings) {
    final fontName = settings.selectedFontNotifier.value;

    return ThemeData(
      brightness: Brightness.light,
      primaryColor: settings.accentColorNotifier.value,
      scaffoldBackgroundColor: Colors.white,
      colorScheme: ColorScheme.fromSeed(
        seedColor: settings.accentColorNotifier.value,
        brightness: Brightness.light,
      ),
      cardColor: Colors.black12,
      textTheme: _buildTextTheme(fontName),
      useMaterial3: true,
    );
  }

  static ThemeData darkTheme(SettingsViewModel settings) {
    final fontName = settings.selectedFontNotifier.value;

    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: settings.accentColorNotifier.value,
      scaffoldBackgroundColor: const Color(0xFF121212),
      colorScheme: ColorScheme.fromSeed(
        seedColor: settings.accentColorNotifier.value,
        brightness: Brightness.dark,
      ),
      textTheme: _buildTextTheme(fontName),
      useMaterial3: true,
    );
  }
}
