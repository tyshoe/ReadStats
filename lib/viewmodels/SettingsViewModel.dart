import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsViewModel {
  final ValueNotifier<ThemeMode> themeModeNotifier;
  final ValueNotifier<Color> accentColorNotifier;
  final ValueNotifier<int> defaultBookTypeNotifier;
  final ValueNotifier<int> defaultRatingStyleNotifier;
  final ValueNotifier<String> librarySortOptionNotifier;
  final ValueNotifier<bool> isLibrarySortAscendingNotifier;
  final ValueNotifier<String> libraryBookFormatFilterNotifier;
  final ValueNotifier<String> libraryBookViewNotifier;
  final ValueNotifier<String> tabNameVisibilityNotifier;
  final ValueNotifier<int> defaultTabNotifier;
  final ValueNotifier<String> defaultDateFormatNotifier;
  final ValueNotifier<String> selectedFontNotifier; // Added for font selection

  SettingsViewModel({
    required ThemeMode themeMode,
    required Color accentColor,
    required int defaultBookType,
    required int defaultRatingStyle,
    required String sortOption,
    required bool isAscending,
    required String bookFormat,
    required String bookView,
    required String tabNameVisibility,
    required int defaultTab,
    required String defaultDateFormat,
    required String selectedFont, // Added for font selection
  })  : themeModeNotifier = ValueNotifier(themeMode),
        accentColorNotifier = ValueNotifier(accentColor),
        defaultBookTypeNotifier = ValueNotifier(defaultBookType),
        defaultRatingStyleNotifier = ValueNotifier(defaultRatingStyle),
        librarySortOptionNotifier = ValueNotifier(sortOption),
        isLibrarySortAscendingNotifier = ValueNotifier(isAscending),
        libraryBookFormatFilterNotifier = ValueNotifier(bookFormat),
        libraryBookViewNotifier = ValueNotifier(bookView),
        tabNameVisibilityNotifier = ValueNotifier(tabNameVisibility),
        defaultTabNotifier = ValueNotifier(defaultTab),
        defaultDateFormatNotifier = ValueNotifier(defaultDateFormat),
        selectedFontNotifier = ValueNotifier(selectedFont);

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

  // Save sort option
  Future<void> setLibrarySortOption(String sortOption) async {
    librarySortOptionNotifier.value = sortOption;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('librarySortOption', sortOption);
  }

  // Load saved sort option
  static Future<String> getLibrarySortOption() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('librarySortOption') ?? 'Title';
  }

  // Save ascending/descending order
  Future<void> setLibrarySortAscending(bool isAscending) async {
    isLibrarySortAscendingNotifier.value = isAscending;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool('isLibrarySortAscending', isAscending);
  }

  // Load saved order preference
  static Future<bool> getLibrarySortAscending() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLibrarySortAscending') ?? true;
  }

  // Save book format filter
  Future<void> setLibraryBookFormatFilter(String bookFormat) async {
    libraryBookFormatFilterNotifier.value = bookFormat;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('libraryBookFormatFilter', bookFormat);
  }

  // Load saved book format filter
  static Future<String> getLibraryBookFormatFilter() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('libraryBookFormatFilter') ?? 'All';
  }

  // Save book format filter
  Future<void> setLibraryBookView(String bookFormat) async {
    libraryBookFormatFilterNotifier.value = bookFormat;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('libraryBookView', bookFormat);
  }

  // Load saved book format filter
  static Future<String> getLibraryBookView() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('libraryBookView') ?? 'row_expanded';
  }

  // Save tab name visibility (using string values)
  Future<void> setTabNameVisibility(String visibility) async {
    tabNameVisibilityNotifier.value = visibility;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('tabNameVisibility', visibility);
  }

  // Load saved tab name visibility
  static Future<String> getTabNameVisibility() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('tabNameVisibility') ?? 'Always'; // Default to 'Always'
  }

  Future<void> setDefaultRatingStyle(int ratingStyle) async {
    defaultRatingStyleNotifier.value = ratingStyle;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('defaultRatingStyle', ratingStyle);
  }

  static Future<int> getDefaultRatingStyle() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt('defaultRatingStyle') ?? 0;
  }

  Future<void> setDefaultTab(int defaultTab) async {
    defaultTabNotifier.value = defaultTab;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('defaultTab', defaultTab);
  }

  static Future<int> getDefaultTab() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt('defaultTab') ?? 0;
  }

  Future<void> setDefaultDateFormat(String visibility) async {
    defaultDateFormatNotifier.value = visibility;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('defaultDateFormat', visibility);
  }

  static Future<String> getDefaultDateFormat() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('defaultDateFormat') ?? 'MMM dd, yyyy';
  }

  // Set the selected font
  Future<void> setSelectedFont(String font) async {
    selectedFontNotifier.value = font;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('selectedFont', font);
  }

  // Get the selected font
  static Future<String> getSelectedFont() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('selectedFont') ?? 'Roboto'; // Default to 'Roboto'
  }
}
