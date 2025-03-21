import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsViewModel {
  final ValueNotifier<bool> isDarkModeNotifier;
  final ValueNotifier<Color> accentColorNotifier;
  final ValueNotifier<int> defaultBookTypeNotifier;

  SettingsViewModel({
    required bool isDarkMode,
    required Color accentColor,
    required int defaultBookType,
  })  : isDarkModeNotifier = ValueNotifier(isDarkMode),
        accentColorNotifier = ValueNotifier(accentColor),
        defaultBookTypeNotifier = ValueNotifier(defaultBookType);

  Future<void> toggleTheme(bool isDark) async {
    isDarkModeNotifier.value = isDark;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool('isDarkMode', isDark);
  }

  Future<void> setAccentColor(Color color) async {
    accentColorNotifier.value = color;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setInt('accentColor', color.value);
  }

  static Future<Color> getAccentColor() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final int colorValue = prefs.getInt('accentColor') ?? CupertinoColors.systemPurple.value;
    return Color(colorValue);
  }

  Future<void> setDefaultBookType(int bookTypeId) async {
    defaultBookTypeNotifier.value = bookTypeId;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('defaultBookType', bookTypeId);
  }

  static Future<int> getDefaultBookType() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt('defaultBookType') ?? 1;
  }
}