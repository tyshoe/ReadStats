import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsViewModel {
  final ValueNotifier<bool> isDarkModeNotifier;

  SettingsViewModel({required bool isDarkMode})
      : isDarkModeNotifier = ValueNotifier(isDarkMode);

  Future<void> toggleTheme(bool isDark) async {
    isDarkModeNotifier.value = isDark;
    // Save theme preference
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool('isDarkMode', isDark);
  }
}