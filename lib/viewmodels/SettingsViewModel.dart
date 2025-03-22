import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsViewModel {
  final ValueNotifier<ThemeMode> themeModeNotifier;
  final ValueNotifier<Color> accentColorNotifier;
  final ValueNotifier<int> defaultBookTypeNotifier;

  SettingsViewModel({
    required ThemeMode themeMode,
    required Color accentColor,
    required int defaultBookType,
  })  : themeModeNotifier = ValueNotifier(themeMode),
        accentColorNotifier = ValueNotifier(accentColor),
        defaultBookTypeNotifier = ValueNotifier(defaultBookType);

  // Method to toggle theme mode (light, dark, system)
  Future<void> toggleTheme(ThemeMode themeMode) async {
    themeModeNotifier.value = themeMode;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('themeMode', themeMode.toString());
  }

  // Load saved theme preference and return ThemeMode
  static Future<ThemeMode> loadSavedThemeMode() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String themeMode = prefs.getString('themeMode') ?? 'system'; // Default to 'system'

    switch (themeMode) {
      case 'ThemeMode.light':
        return ThemeMode.light;
      case 'ThemeMode.dark':
        return ThemeMode.dark;
      case 'ThemeMode.system':
      default:
        return ThemeMode.system;
    }
  }

  // Set accent color
  Future<void> setAccentColor(Color color) async {
    accentColorNotifier.value = color;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setInt('accentColor', color.value);
  }

  // Get accent color
  static Future<Color> getAccentColor() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final int colorValue = prefs.getInt('accentColor') ?? CupertinoColors.systemPurple.value;
    return Color(colorValue);
  }

  // Set default book type
  Future<void> setDefaultBookType(int bookTypeId) async {
    defaultBookTypeNotifier.value = bookTypeId;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('defaultBookType', bookTypeId);
  }

  // Get default book type
  static Future<int> getDefaultBookType() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt('defaultBookType') ?? 1;
  }
}
