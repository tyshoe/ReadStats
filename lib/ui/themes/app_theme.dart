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

  // Build a scheme whose `primary` is the user's *exact* accent color.
  //
  // ColorScheme.fromSeed only uses the seed as a hue anchor and regenerates
  // `primary` at a fixed tone, which threw away the specific shade the user
  // picked — so the accent looked the same no matter which shade they chose.
  // We keep fromSeed for the harmonious surfaces/containers, then override
  // `primary` to the literal color. `onPrimary` is chosen by the accent's own
  // luminance so labels/icons stay legible on both pale and dark accents.
  static ColorScheme _accentScheme(Color accent, Brightness brightness) {
    final base =
        ColorScheme.fromSeed(seedColor: accent, brightness: brightness);
    final onPrimary =
        ThemeData.estimateBrightnessForColor(accent) == Brightness.dark
            ? Colors.white
            : Colors.black;
    return base.copyWith(primary: accent, onPrimary: onPrimary);
  }

  static ThemeData lightTheme(SettingsViewModel settings) {
    final fontName = settings.selectedFontNotifier.value;
    final accent = settings.accentColorNotifier.value;

    return ThemeData(
      brightness: Brightness.light,
      primaryColor: accent,
      scaffoldBackgroundColor: Colors.white,
      colorScheme: _accentScheme(accent, Brightness.light),
      cardColor: Colors.black12,
      textTheme: _buildTextTheme(fontName),
      useMaterial3: true,
    );
  }

  static ThemeData darkTheme(SettingsViewModel settings) {
    final fontName = settings.selectedFontNotifier.value;
    final accent = settings.accentColorNotifier.value;

    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: accent,
      scaffoldBackgroundColor: const Color(0xFF121212),
      colorScheme: _accentScheme(accent, Brightness.dark),
      textTheme: _buildTextTheme(fontName),
      useMaterial3: true,
    );
  }
}
