import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsViewModel {
  final ValueNotifier<bool> isDarkModeNotifier;
  final ValueNotifier<Color> accentColorNotifier;

  SettingsViewModel({required bool isDarkMode, required Color accentColor})
      : isDarkModeNotifier = ValueNotifier(isDarkMode),
        accentColorNotifier = ValueNotifier(accentColor);

  Future<void> toggleTheme(bool isDark) async {
    isDarkModeNotifier.value = isDark;
    // Save theme preference
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool('isDarkMode', isDark);
  }

  Future<void> setAccentColor(Color color) async {
    accentColorNotifier.value = color;
    // Save accent color preference
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setInt('accentColor', color.value);
  }

  static Future<Color> getAccentColor() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final int colorValue = prefs.getInt('accentColor') ?? CupertinoColors.systemPurple.value;
    return Color(colorValue);
  }
}