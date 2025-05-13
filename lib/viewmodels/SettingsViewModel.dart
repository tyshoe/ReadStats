import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsViewModel {
  final ValueNotifier<ThemeMode> themeModeNotifier;
  final ValueNotifier<Color> accentColorNotifier;
  final ValueNotifier<int> defaultBookTypeNotifier;
  final ValueNotifier<int> defaultRatingStyleNotifier;
  final ValueNotifier<String> libraryBookViewNotifier;
  final ValueNotifier<String> tabNameVisibilityNotifier;
  final ValueNotifier<int> defaultTabNotifier;
  final ValueNotifier<String> defaultDateFormatNotifier;
  final ValueNotifier<String> selectedFontNotifier;
  // Library Filters
  final ValueNotifier<String> librarySortOptionNotifier;
  final ValueNotifier<bool> isLibrarySortAscendingNotifier;
  final ValueNotifier<List<String>> libraryBookTypeFilterNotifier;
  final ValueNotifier<bool> libraryFavoriteFilterNotifier;
  final ValueNotifier<List<String>> libraryFinishedYearFilterNotifier;

  SettingsViewModel({
    required ThemeMode themeMode,
    required Color accentColor,
    required int defaultBookType,
    required int defaultRatingStyle,
    required String bookView,
    required String tabNameVisibility,
    required int defaultTab,
    required String defaultDateFormat,
    required String selectedFont,
    required String sortOption,
    required bool isAscending,
    required List<String> bookTypes,
    required bool isFavorite,
    required List<String> finishedYears,
  })  : themeModeNotifier = ValueNotifier(themeMode),
        accentColorNotifier = ValueNotifier(accentColor),
        defaultBookTypeNotifier = ValueNotifier(defaultBookType),
        defaultRatingStyleNotifier = ValueNotifier(defaultRatingStyle),
        libraryBookViewNotifier = ValueNotifier(bookView),
        tabNameVisibilityNotifier = ValueNotifier(tabNameVisibility),
        defaultTabNotifier = ValueNotifier(defaultTab),
        defaultDateFormatNotifier = ValueNotifier(defaultDateFormat),
        selectedFontNotifier = ValueNotifier(selectedFont),
        librarySortOptionNotifier = ValueNotifier(sortOption),
        isLibrarySortAscendingNotifier = ValueNotifier(isAscending),
        libraryBookTypeFilterNotifier = ValueNotifier(bookTypes),
        libraryFavoriteFilterNotifier = ValueNotifier(isFavorite),
        libraryFinishedYearFilterNotifier = ValueNotifier(finishedYears);

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
    final int colorValue = prefs.getInt('accentColor') ?? 0xFF2196F3;
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

  Future<void> setLibraryIsFavorite(bool isFavorite) async {
    libraryFavoriteFilterNotifier.value = isFavorite;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool('libraryIsFavorite', isFavorite);
  }

  static Future<bool> getLibraryIsFavorite() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool('libraryIsFavorite') ?? false;
  }

  // Save book format filter
  Future<void> setLibraryBookTypeFilter(List<String> bookTypes) async {
    libraryBookTypeFilterNotifier.value = bookTypes;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (bookTypes.isEmpty) {
      await prefs.setString('libraryBookTypes', 'All');
    } else {
      await prefs.setString('libraryBookTypes', bookTypes.join(','));
    }
  }

  // Load saved book type filters
  static Future<List<String>> getLibraryBookTypes() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? typesString = prefs.getString('libraryBookTypes');

    if (typesString == null || typesString.isEmpty) {
      return []; // Empty list represents "All" types
    }
    return typesString.split(',');
  }

  // Load saved book format filter
  static Future<String> getLibraryBookView() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('libraryBookView') ?? 'row_expanded';
  }

  // Save finished year filter
  Future<void> setLibraryFinishedYearFilter(List<String> years) async {
    libraryFinishedYearFilterNotifier.value = years;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (years.isEmpty) {
      await prefs.setString('libraryFinishedYears', 'All');
    } else {
      await prefs.setString('libraryFinishedYears', years.join(','));
    }
  }

// Load saved finished year filters
  static Future<List<String>> getLibraryFinishedYears() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? yearsString = prefs.getString('libraryFinishedYears');

    if (yearsString == null || yearsString.isEmpty || yearsString == 'All') {
      return []; // Empty list represents "All" years
    }
    return yearsString.split(',');
  }

  Future<void> setLibraryBookView(String view) async {
    libraryBookViewNotifier.value = view;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('libraryBookView', view);
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
