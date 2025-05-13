import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '/viewmodels/SettingsViewModel.dart';

class SortFilterOptions {
  final String sortOption;
  final bool isAscending;
  final List<String> bookTypes;
  final bool isFavorite;
  final List<String> finishedYears;
  final List<String> tags;

  SortFilterOptions({
    required this.sortOption,
    required this.isAscending,
    required this.bookTypes,
    required this.isFavorite,
    this.finishedYears = const [],
    this.tags = const [],
  });

  SortFilterOptions copyWith({
    String? sortOption,
    bool? isAscending,
    List<String>? bookTypes,
    bool? isFavorite,
    List<String>? finishedYears,
    List<String>? tags,
  }) {
    return SortFilterOptions(
      sortOption: sortOption ?? this.sortOption,
      isAscending: isAscending ?? this.isAscending,
      bookTypes: bookTypes ?? this.bookTypes,
      isFavorite: isFavorite ?? this.isFavorite,
      finishedYears: finishedYears ?? this.finishedYears,
      tags: tags ?? this.tags,
    );
  }
}

class SortFilterPopup {
  static void showSortFilterPopup({
    required BuildContext context,
    required SortFilterOptions currentOptions,
    required Function(SortFilterOptions) onOptionsChange,
    required List<String> availableYears,
    required List<String> availableTags,
    required SettingsViewModel settingsViewModel,
  }) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) {
        return _SortFilterPopup(
          currentOptions: currentOptions,
          onOptionsChange: onOptionsChange,
          availableYears: availableYears,
          availableTags: availableTags,
          settingsViewModel: settingsViewModel,
        );
      },
    );
  }
}

class _SortFilterPopup extends StatefulWidget {
  final SortFilterOptions currentOptions;
  final Function(SortFilterOptions) onOptionsChange;
  final List<String> availableYears;
  final List<String> availableTags;
  final SettingsViewModel settingsViewModel;

  const _SortFilterPopup({
    Key? key,
    required this.currentOptions,
    required this.onOptionsChange,
    required this.availableYears,
    required this.availableTags,
    required this.settingsViewModel,
  }) : super(key: key);

  @override
  _SortFilterPopupState createState() => _SortFilterPopupState();
}

class _SortFilterPopupState extends State<_SortFilterPopup> {
  late SortFilterOptions currentOptions;
  final List<String> bookTypes = ['Paperback', 'Hardback', 'eBook', 'Audiobook'];
  final List<String> sortOptions = [
    'Title',
    'Author',
    'Rating',
    'Pages',
    'Date started',
    'Date finished',
    'Date added'
  ];

  @override
  void initState() {
    super.initState();
    currentOptions = widget.currentOptions;
    // Initialize bookTypes as empty if it contains "All" or is empty
    if (currentOptions.bookTypes.isEmpty || currentOptions.bookTypes.contains('All')) {
      currentOptions = currentOptions.copyWith(bookTypes: []);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPopupSurface(
      isSurfacePainted: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        width: double.infinity,
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground.resolveFrom(context),
          borderRadius: BorderRadius.circular(12),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filter & Sort',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              const Text(
                'Sort By',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      color: CupertinoColors.systemGrey5,
                      borderRadius: BorderRadius.circular(8),
                      onPressed: () => _showSortPicker(context),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            currentOptions.sortOption,
                            style: TextStyle(
                              fontSize: 16,
                              color: CupertinoColors.label.resolveFrom(context),
                            ),
                          ),
                          const Icon(CupertinoIcons.chevron_down,
                              color: CupertinoColors.systemGrey),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    color: CupertinoColors.systemGrey5,
                    borderRadius: BorderRadius.circular(8),
                    onPressed: _toggleSortOrder,
                    child: Icon(
                      currentOptions.isAscending ? CupertinoIcons.sort_up : CupertinoIcons.sort_down,
                      size: 24,
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1),
              ),
              _buildBookTypeFilter(),
              const SizedBox(height: 24),
              _buildFavoriteFilter(),
              const SizedBox(height: 24),
              _buildYearFilter(),
              const SizedBox(height: 24),
              _buildTagFilter(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookTypeFilter() {
    final accentColor = widget.settingsViewModel.accentColorNotifier.value;
    final bool showAll = currentOptions.bookTypes.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Book Type',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              // "All" chip
              GestureDetector(
                onTap: _clearBookTypeFilters,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: showAll
                        ? accentColor.withOpacity(0.3)
                        : CupertinoColors.secondarySystemBackground.resolveFrom(context),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showAll) ...[
                        Icon(
                          CupertinoIcons.checkmark,
                          size: 18,
                          color: _getIconColorBasedOnAccentColor(accentColor.withOpacity(0.2)),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        'All',
                        style: TextStyle(
                          fontSize: 16,
                          color: showAll
                              ? _getIconColorBasedOnAccentColor(accentColor.withOpacity(0.2))
                              : CupertinoColors.label.resolveFrom(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Book type chips
              ...bookTypes.map((type) {
                final isSelected = currentOptions.bookTypes.contains(type);
                return GestureDetector(
                  onTap: () => _toggleBookTypeFilter(type),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? accentColor.withOpacity(0.3)
                          : CupertinoColors.secondarySystemBackground.resolveFrom(context),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSelected)
                          Icon(
                            CupertinoIcons.checkmark,
                            size: 18,
                            color: _getIconColorBasedOnAccentColor(accentColor.withOpacity(0.2)),
                          ),
                        if (isSelected) const SizedBox(width: 6),
                        Text(
                          type,
                          style: TextStyle(
                            fontSize: 16,
                            color: isSelected
                                ? _getIconColorBasedOnAccentColor(accentColor.withOpacity(0.2))
                                : CupertinoColors.label.resolveFrom(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFavoriteFilter() {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: currentOptions.isFavorite
          ? CupertinoColors.systemRed.withOpacity(0.2)
          : CupertinoColors.systemGrey5,
      borderRadius: BorderRadius.circular(8),
      onPressed: _toggleFavoriteFilter,
      child: Row(
        children: [
          Icon(
            CupertinoIcons.heart_fill,
            color: currentOptions.isFavorite
                ? CupertinoColors.systemRed
                : CupertinoColors.systemGrey,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            currentOptions.isFavorite ? 'Favorites Only' : 'All Books',
            style: TextStyle(
              fontSize: 16,
              color: CupertinoColors.label.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYearFilter() {
    final accentColor = widget.settingsViewModel.accentColorNotifier.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Finished Year',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              // "All" chip
              GestureDetector(
                onTap: _clearYearFilters,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: currentOptions.finishedYears.isEmpty
                        ? accentColor.withOpacity(0.3)
                        : CupertinoColors.secondarySystemBackground.resolveFrom(context),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (currentOptions.finishedYears.isEmpty) ...[
                        Icon(
                          CupertinoIcons.checkmark,
                          size: 18,
                          color: _getIconColorBasedOnAccentColor(accentColor.withOpacity(0.2)),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        'All',
                        style: TextStyle(
                          fontSize: 16,
                          color: currentOptions.finishedYears.isEmpty
                              ? _getIconColorBasedOnAccentColor(accentColor.withOpacity(0.2))
                              : CupertinoColors.label.resolveFrom(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Year chips
              ...widget.availableYears.map((year) {
                final isSelected = currentOptions.finishedYears.contains(year);
                return GestureDetector(
                  onTap: () => _toggleYearFilter(year),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? accentColor.withOpacity(0.3)
                          : CupertinoColors.secondarySystemBackground.resolveFrom(context),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSelected)
                          Icon(
                            CupertinoIcons.checkmark,
                            size: 18,
                            color: _getIconColorBasedOnAccentColor(accentColor.withOpacity(0.2)),
                          ),
                        if (isSelected) const SizedBox(width: 6),
                        Text(
                          year,
                          style: TextStyle(
                            fontSize: 16,
                            color: isSelected
                                ? _getIconColorBasedOnAccentColor(accentColor.withOpacity(0.2))
                                : CupertinoColors.label.resolveFrom(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTagFilter() {
    final accentColor = widget.settingsViewModel.accentColorNotifier.value;
    final bool showAll = currentOptions.tags.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tags',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              // "All" chip
              GestureDetector(
                onTap: _clearTagFilters,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: showAll
                        ? accentColor.withOpacity(0.3)
                        : CupertinoColors.secondarySystemBackground.resolveFrom(context),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showAll) ...[
                        Icon(
                          CupertinoIcons.checkmark,
                          size: 18,
                          color: _getIconColorBasedOnAccentColor(accentColor.withOpacity(0.2)),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        'All',
                        style: TextStyle(
                          fontSize: 16,
                          color: showAll
                              ? _getIconColorBasedOnAccentColor(accentColor.withOpacity(0.2))
                              : CupertinoColors.label.resolveFrom(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Tag chips
              ...widget.availableTags.map((tag) {
                final isSelected = currentOptions.tags.contains(tag);
                return GestureDetector(
                  onTap: () => _toggleTagFilter(tag),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? accentColor.withOpacity(0.3)
                          : CupertinoColors.secondarySystemBackground.resolveFrom(context),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSelected)
                          Icon(
                            CupertinoIcons.checkmark,
                            size: 18,
                            color: _getIconColorBasedOnAccentColor(accentColor.withOpacity(0.2)),
                          ),
                        if (isSelected) const SizedBox(width: 6),
                        Text(
                          tag,
                          style: TextStyle(
                            fontSize: 16,
                            color: isSelected
                                ? _getIconColorBasedOnAccentColor(accentColor.withOpacity(0.2))
                                : CupertinoColors.label.resolveFrom(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  void _toggleTagFilter(String tag) {
    setState(() {
      final updatedTags = List<String>.from(currentOptions.tags);
      if (updatedTags.contains(tag)) {
        updatedTags.remove(tag);
      } else {
        updatedTags.add(tag);
      }
      currentOptions = currentOptions.copyWith(tags: updatedTags);
    });
    widget.onOptionsChange(currentOptions);
  }

  void _clearTagFilters() {
    setState(() {
      currentOptions = currentOptions.copyWith(tags: []);
    });
    widget.onOptionsChange(currentOptions);
  }

  void _showSortPicker(BuildContext context) async {
    final sortIndex = sortOptions.indexOf(currentOptions.sortOption);
    String? selectedOption;

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (context) {
        return GestureDetector(
          onTap: () => Navigator.pop(context),
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 200,
            color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
            child: Column(
              children: [
                Expanded(
                  child: CupertinoPicker(
                    itemExtent: 32,
                    scrollController: FixedExtentScrollController(initialItem: sortIndex),
                    onSelectedItemChanged: (index) => selectedOption = sortOptions[index],
                    children: sortOptions.map((option) => Text(option)).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selectedOption != null) {
      setState(() {
        currentOptions = currentOptions.copyWith(sortOption: selectedOption!);
      });
      widget.onOptionsChange(currentOptions);
    }
  }

  void _toggleBookTypeFilter(String type) {
    final updatedTypes = List<String>.from(currentOptions.bookTypes);
    if (updatedTypes.contains(type)) {
      updatedTypes.remove(type);
    } else {
      updatedTypes.add(type);
    }
    setState(() {
      currentOptions = currentOptions.copyWith(bookTypes: updatedTypes);
    });
    widget.onOptionsChange(currentOptions);
  }

  void _clearBookTypeFilters() {
    setState(() {
      currentOptions = currentOptions.copyWith(bookTypes: []);
    });
    widget.onOptionsChange(currentOptions);
  }


  void _toggleSortOrder() {
    setState(() {
      currentOptions = currentOptions.copyWith(isAscending: !currentOptions.isAscending);
    });
    widget.onOptionsChange(currentOptions);
  }

  void _toggleFavoriteFilter() {
    setState(() {
      currentOptions = currentOptions.copyWith(isFavorite: !currentOptions.isFavorite);
    });
    widget.onOptionsChange(currentOptions);
  }

  void _toggleYearFilter(String year) {
    setState(() {
      final newYears = List<String>.from(currentOptions.finishedYears);
      if (newYears.contains(year)) {
        newYears.remove(year);
      } else {
        newYears.add(year);
      }
      currentOptions = currentOptions.copyWith(finishedYears: newYears);
    });
    widget.onOptionsChange(currentOptions);
  }

  void _clearYearFilters() {
    setState(() {
      currentOptions = currentOptions.copyWith(finishedYears: []);
    });
    widget.onOptionsChange(currentOptions);
  }

  Color _getIconColorBasedOnAccentColor(Color color) {
    HSLColor hslColor = HSLColor.fromColor(color);
    double lightness = hslColor.lightness;
    return lightness < 0.5 ? CupertinoColors.white : CupertinoColors.black;
  }
}