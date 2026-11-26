import 'package:flutter/material.dart';
import 'package:read_stats/data/utils/money.dart';
import 'package:read_stats/domain/library_filter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stylish_bottom_bar/stylish_bottom_bar.dart';

class SettingsViewModel {
  final ValueNotifier<ThemeMode> themeModeNotifier;
  final ValueNotifier<Color> accentColorNotifier;
  final ValueNotifier<int> defaultBookTypeNotifier;
  final ValueNotifier<int> defaultRatingStyleNotifier;
  final ValueNotifier<String> libraryBookViewNotifier;
  final ValueNotifier<IconStyle> navStyleNotifier;
  final ValueNotifier<int> defaultTabNotifier;
  final ValueNotifier<String> defaultDateFormatNotifier;
  final ValueNotifier<String> selectedFontNotifier;
  // Library Filters
  // Library sort, per shelf: each shelf's sort as the reader left it, keyed
  // by shelf id ('all' for the whole library), as 'option|asc' or
  // 'option|desc'. A shelf not in here sorts by its default — see
  // LibraryFilter.defaultSort.
  final ValueNotifier<Map<String, String>> libraryShelfSortsNotifier;
  final ValueNotifier<List<String>> libraryBookTypeFilterNotifier;
  final ValueNotifier<bool> libraryFavoriteFilterNotifier;
  final ValueNotifier<List<String>> libraryFinishedYearFilterNotifier;
  final ValueNotifier<String> libraryTagFilterModeNotifier;
  final ValueNotifier<bool> libraryReviewedFilterNotifier;
  // Series: shown as one row each (on by default), and an only-series filter.
  final ValueNotifier<bool> libraryGroupSeriesNotifier;
  final ValueNotifier<bool> librarySeriesOnlyNotifier;
  // Cover filter: 'all', 'with' or 'without'.
  final ValueNotifier<String> libraryCoverFilterNotifier;
  // The measure filters: rating in stars, page count, and listening time in
  // minutes — each a range with open ends, or "no value" only.
  final ValueNotifier<MeasureRange> libraryRatingFilterNotifier;
  final ValueNotifier<MeasureRange> libraryPagesFilterNotifier;
  final ValueNotifier<MeasureRange> libraryListeningFilterNotifier;
  // Pinned Books
  final ValueNotifier<List<int>> pinnedBookIdsNotifier;
  // Library Shelf Filter
  final ValueNotifier<int?> libraryShelfFilterNotifier;
  // Statistics
  final ValueNotifier<int> statsYearFilterNotifier;
  // Stats chart style: 'bars' (per-period) or 'cumulative' (running-total line)
  final ValueNotifier<String> statsChartStyleNotifier;
  // Profile (loaded asynchronously after construction; default to empty)
  final ValueNotifier<String> profileNameNotifier = ValueNotifier('');
  final ValueNotifier<String?> profileAvatarNotifier =
      ValueNotifier<String?>(null);
  // Spending: whether books carry a price at all — off unless the reader
  // turns it on, and nothing about money shows while it is — and the one
  // currency every amount is in. Loaded like the profile.
  final ValueNotifier<bool> spendingEnabledNotifier = ValueNotifier(false);
  final ValueNotifier<String> currencyNotifier = ValueNotifier('USD');

  SettingsViewModel({
    required ThemeMode themeMode,
    required Color accentColor,
    required int defaultBookType,
    required int defaultRatingStyle,
    required String bookView,
    required IconStyle navStyle,
    required int defaultTab,
    required String defaultDateFormat,
    required String selectedFont,
    required List<String> bookTypes,
    required bool isFavorite,
    required List<String> finishedYears,
    required String tagFilterMode,
    required bool isReviewed,
    required List<int> pinnedBookIds,
    required int? shelfId,
    required int statsYearFilter,
    required String statsChartStyle,
    bool groupSeries = true,
    bool seriesOnly = false,
    String coverFilter = 'all',
    Map<String, String> shelfSorts = const {},
    MeasureRange ratingFilter = MeasureRange.any,
    MeasureRange pagesFilter = MeasureRange.any,
    MeasureRange listeningFilter = MeasureRange.any,
  })  : libraryGroupSeriesNotifier = ValueNotifier(groupSeries),
        librarySeriesOnlyNotifier = ValueNotifier(seriesOnly),
        libraryCoverFilterNotifier = ValueNotifier(coverFilter),
        libraryRatingFilterNotifier = ValueNotifier(ratingFilter),
        libraryPagesFilterNotifier = ValueNotifier(pagesFilter),
        libraryListeningFilterNotifier = ValueNotifier(listeningFilter),
        themeModeNotifier = ValueNotifier(themeMode),
        accentColorNotifier = ValueNotifier(accentColor),
        defaultBookTypeNotifier = ValueNotifier(defaultBookType),
        defaultRatingStyleNotifier = ValueNotifier(defaultRatingStyle),
        libraryBookViewNotifier = ValueNotifier(bookView),
        navStyleNotifier = ValueNotifier(navStyle),
        defaultTabNotifier = ValueNotifier(defaultTab),
        defaultDateFormatNotifier = ValueNotifier(defaultDateFormat),
        selectedFontNotifier = ValueNotifier(selectedFont),
        libraryTagFilterModeNotifier = ValueNotifier(tagFilterMode),
        libraryShelfSortsNotifier = ValueNotifier(shelfSorts),
        libraryBookTypeFilterNotifier = ValueNotifier(bookTypes),
        libraryFavoriteFilterNotifier = ValueNotifier(isFavorite),
        libraryFinishedYearFilterNotifier = ValueNotifier(finishedYears),
        libraryReviewedFilterNotifier = ValueNotifier(isReviewed),
        pinnedBookIdsNotifier = ValueNotifier(pinnedBookIds),
        libraryShelfFilterNotifier = ValueNotifier(shelfId),
        statsYearFilterNotifier = ValueNotifier(statsYearFilter),
        statsChartStyleNotifier = ValueNotifier(statsChartStyle) {
    _loadProfile();
  }

  // ── Profile ────────────────────────────────────────────────────────────────

  // Hydrate the profile notifiers from storage. Kept out of the constructor's
  // required params since a brief async load is fine for non-critical chrome.
  Future<void> _loadProfile() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    profileNameNotifier.value = prefs.getString('profileName') ?? '';
    profileAvatarNotifier.value = prefs.getString('profileAvatar');
    spendingEnabledNotifier.value = prefs.getBool('spendingEnabled') ?? false;
    currencyNotifier.value =
        prefs.getString('spendingCurrency') ?? Money.deviceDefault();
  }

  Future<void> setSpendingEnabled(bool enabled) async {
    spendingEnabledNotifier.value = enabled;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('spendingEnabled', enabled);
  }

  /// Changes the symbol amounts are shown with. Nothing is converted: the
  /// numbers already entered stay as they are.
  Future<void> setCurrency(String code) async {
    currencyNotifier.value = code;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('spendingCurrency', code);
  }

  Future<void> setProfileName(String name) async {
    final trimmed = name.trim();
    profileNameNotifier.value = trimmed;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('profileName', trimmed);
  }

  // Stores the avatar filename only (resolved to a path at display time).
  Future<void> setProfileAvatar(String? filename) async {
    profileAvatarNotifier.value = filename;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (filename == null) {
      await prefs.remove('profileAvatar');
    } else {
      await prefs.setString('profileAvatar', filename);
    }
  }

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
    prefs.setInt('accentColor', color.toARGB32());
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

  static String _shelfSortKey(int? shelfId) => shelfId?.toString() ?? 'all';

  /// [shelfId]'s sort as the reader left it (null: the whole library) — the
  /// option and whether it runs ascending — or null if they never changed it.
  (String, bool)? libraryShelfSort(int? shelfId) {
    final saved = libraryShelfSortsNotifier.value[_shelfSortKey(shelfId)];
    final split = saved?.lastIndexOf('|') ?? -1;
    if (saved == null || split <= 0) return null;
    return (saved.substring(0, split), saved.substring(split + 1) == 'asc');
  }

  /// Remembers [shelfId]'s sort, leaving every other shelf's as it was.
  Future<void> setLibraryShelfSort(
      int? shelfId, String option, bool ascending) async {
    final sorts = {
      ...libraryShelfSortsNotifier.value,
      _shelfSortKey(shelfId): '$option|${ascending ? 'asc' : 'desc'}',
    };
    libraryShelfSortsNotifier.value = sorts;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('libraryShelfSorts',
        [for (final e in sorts.entries) '${e.key}=${e.value}']);
  }

  /// Every shelf's remembered sort. The single sort all shelves used to
  /// share ('librarySortOption') isn't carried over: each shelf starts from
  /// its own default instead.
  static Future<Map<String, String>> getLibraryShelfSorts() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return {
      for (final entry
          in prefs.getStringList('libraryShelfSorts') ?? const <String>[])
        if (entry.indexOf('=') case final split when split > 0)
          entry.substring(0, split): entry.substring(split + 1),
    };
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

  Future<void> setLibraryReviewed(bool isReviewed) async {
    libraryReviewedFilterNotifier.value = isReviewed;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool('libraryReviewed', isReviewed);
  }

  static Future<bool> getLibraryReviewed() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool('libraryReviewed') ?? false;
  }

  Future<void> setLibraryGroupSeries(bool group) async {
    libraryGroupSeriesNotifier.value = group;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool('libraryGroupSeries', group);
  }

  static Future<bool> getLibraryGroupSeries() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool('libraryGroupSeries') ?? true;
  }

  Future<void> setLibrarySeriesOnly(bool only) async {
    librarySeriesOnlyNotifier.value = only;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool('librarySeriesOnly', only);
  }

  static Future<bool> getLibrarySeriesOnly() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool('librarySeriesOnly') ?? false;
  }

  Future<void> setLibraryCoverFilter(String filter) async {
    libraryCoverFilterNotifier.value = filter;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('libraryCoverFilter', filter);
  }

  static Future<String> getLibraryCoverFilter() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('libraryCoverFilter') ?? 'all';
  }

  // A measure filter is stored as 'min|max|missing', an open end left
  // empty: '4||0' is four stars and up.
  static String _encodeMeasure(MeasureRange r) =>
      '${r.min ?? ''}|${r.max ?? ''}|${r.missing ? 1 : 0}';

  static MeasureRange _decodeMeasure(String? saved) {
    final parts = saved?.split('|');
    if (parts == null || parts.length != 3) return MeasureRange.any;
    return MeasureRange(
      min: num.tryParse(parts[0]),
      max: num.tryParse(parts[1]),
      missing: parts[2] == '1',
    );
  }

  Future<void> _saveMeasure(
      String key, ValueNotifier<MeasureRange> notifier, MeasureRange r) async {
    notifier.value = r;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, _encodeMeasure(r));
  }

  Future<void> setLibraryRatingFilter(MeasureRange r) =>
      _saveMeasure('libraryRatingFilter', libraryRatingFilterNotifier, r);

  Future<void> setLibraryPagesFilter(MeasureRange r) =>
      _saveMeasure('libraryPagesFilter', libraryPagesFilterNotifier, r);

  Future<void> setLibraryListeningFilter(MeasureRange r) =>
      _saveMeasure('libraryListeningFilter', libraryListeningFilterNotifier, r);

  /// The rating, page and listening filters, in that order.
  static Future<(MeasureRange, MeasureRange, MeasureRange)>
      getLibraryMeasureFilters() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return (
      _decodeMeasure(prefs.getString('libraryRatingFilter')),
      _decodeMeasure(prefs.getString('libraryPagesFilter')),
      _decodeMeasure(prefs.getString('libraryListeningFilter')),
    );
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

    if (typesString == null || typesString.isEmpty || typesString == 'All') {
      return []; // Empty list represents "All" types
    }
    return typesString.split(',');
  }

  // Load saved book format filter
  static Future<String> getLibraryBookView() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final view = prefs.getString('libraryBookView');
    // Only 'grid' survives; legacy 'row_expanded'/'row_compact', null, or
    // anything unexpected all collapse to the default 'rows'.
    return view == 'grid' ? 'grid' : 'rows';
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

  Future<void> setNavStyle(IconStyle style) async {
    navStyleNotifier.value = style;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('navStyle', _iconStyleToString(style));
  }

  static Future<IconStyle> getNavStyle() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return _iconStringToStyle(prefs.getString('navStyle') ?? 'default');
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

  // Save stats year filter (0 = All years)
  Future<void> setStatsYearFilter(int year) async {
    statsYearFilterNotifier.value = year;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('statsYearFilter', year);
  }

  // Load saved stats year filter
  static Future<int> getStatsYearFilter() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt('statsYearFilter') ?? 0;
  }

  // Save stats chart style ('bars' or 'cumulative')
  Future<void> setStatsChartStyle(String style) async {
    if (style != 'bars' && style != 'cumulative') style = 'bars';
    statsChartStyleNotifier.value = style;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('statsChartStyle', style);
  }

  // Load saved stats chart style (defaults to per-period bars)
  static Future<String> getStatsChartStyle() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final style = prefs.getString('statsChartStyle');
    return style == 'cumulative' ? 'cumulative' : 'bars';
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

  static String _iconStyleToString(IconStyle style) {
    switch (style) {
      case IconStyle.animated:
        return 'animated';
      case IconStyle.Default:
        return 'default';
      default:
        return 'simple';
    }
  }

  static IconStyle _iconStringToStyle(String style) {
    switch (style) {
      case 'animated':
        return IconStyle.animated;
      case 'default':
        return IconStyle.Default;
      default:
        return IconStyle.simple;
    }
  }

  Future<void> setLibraryTagFilterMode(String mode) async {
    if (!['any', 'all', 'exclude'].contains(mode)) {
      mode = 'any';
    }
    libraryTagFilterModeNotifier.value = mode;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('libraryTagFilterMode', mode);
  }

  static Future<String> getLibraryTagFilterMode() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('libraryTagFilterMode') ?? 'any';
  }

  // Save pinned book IDs
  Future<void> setPinnedBookIds(List<int> ids) async {
    pinnedBookIdsNotifier.value = ids;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (ids.isEmpty) {
      await prefs.setString('pinnedBookIds', '');
    } else {
      await prefs.setString('pinnedBookIds', ids.join(','));
    }
  }

  // Load pinned book IDs
  static Future<List<int>> getPinnedBookIds() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? idsString = prefs.getString('pinnedBookIds');
    if (idsString == null || idsString.isEmpty) {
      return [];
    }
    return idsString.split(',').map((id) => int.parse(id)).toList();
  }

  // Save selected shelf filter
  Future<void> setLibraryShelfFilter(int? shelfId) async {
    libraryShelfFilterNotifier.value = shelfId;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (shelfId == null) {
      await prefs.remove('libraryShelfFilter');
    } else {
      await prefs.setInt('libraryShelfFilter', shelfId);
    }
  }

  // Load saved shelf filter
  static Future<int?> getLibraryShelfFilter() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt('libraryShelfFilter');
  }

  static const String _onboardingVersion = '1.1';

  // Returns true if the user has seen the current onboarding version
  static Future<bool> getHasSeenOnboarding() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final seenVersion = prefs.getString('onboardingVersion');
    return seenVersion == _onboardingVersion;
  }

  // Mark current onboarding version as seen
  static Future<void> setHasSeenOnboarding() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('onboardingVersion', _onboardingVersion);
  }
}