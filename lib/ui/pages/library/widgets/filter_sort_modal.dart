import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '/viewmodels/SettingsViewModel.dart';

class SortFilterOptions {
  final String sortOption;
  final bool isAscending;
  final String bookType;
  final bool isFavorite;
  final List<String> finishedYears;

  SortFilterOptions({
    required this.sortOption,
    required this.isAscending,
    required this.bookType,
    required this.isFavorite,
    this.finishedYears = const [],
  });

  SortFilterOptions copyWith({
    String? sortOption,
    bool? isAscending,
    String? bookType,
    bool? isFavorite,
    List<String>? finishedYears,
  }) {
    return SortFilterOptions(
      sortOption: sortOption ?? this.sortOption,
      isAscending: isAscending ?? this.isAscending,
      bookType: bookType ?? this.bookType,
      isFavorite: isFavorite ?? this.isFavorite,
      finishedYears: finishedYears ?? this.finishedYears,
    );
  }
}

class SortFilterPopup {
  static void showSortFilterPopup({
    required BuildContext context,
    required SortFilterOptions currentOptions,
    required Function(SortFilterOptions) onOptionsChange,
    required List<String> availableYears,
    required SettingsViewModel settingsViewModel,  // Added parameter
  }) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) {
        return _SortFilterPopup(
          currentOptions: currentOptions,
          onOptionsChange: onOptionsChange,
          availableYears: availableYears,
          settingsViewModel: settingsViewModel,  // Pass it through
        );
      },
    );
  }
}

class _SortFilterPopup extends StatefulWidget {
  final SortFilterOptions currentOptions;
  final Function(SortFilterOptions) onOptionsChange;
  final List<String> availableYears;
  final SettingsViewModel settingsViewModel;  // Added field

  const _SortFilterPopup({
    Key? key,
    required this.currentOptions,
    required this.onOptionsChange,
    required this.availableYears,
    required this.settingsViewModel,  // Added parameter
  }) : super(key: key);

  @override
  _SortFilterPopupState createState() => _SortFilterPopupState();
}

class _SortFilterPopupState extends State<_SortFilterPopup> {
  late SortFilterOptions currentOptions;
  final List<String> bookTypes = ['All', 'Paperback', 'Hardback', 'eBook', 'Audiobook'];
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
              const Text(
                'Filter By',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              _buildBookTypeFilter(),
              const SizedBox(height: 16),
              _buildFavoriteFilter(),
              const SizedBox(height: 16),
              _buildYearFilter(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookTypeFilter() {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: CupertinoColors.systemGrey5,
      borderRadius: BorderRadius.circular(8),
      onPressed: () => _showBookTypePicker(context),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            currentOptions.bookType,
            style: TextStyle(
              fontSize: 16,
              color: CupertinoColors.label.resolveFrom(context),
            ),
          ),
          const Icon(CupertinoIcons.chevron_down, color: CupertinoColors.systemGrey),
        ],
      ),
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
                      if (currentOptions.finishedYears.isEmpty)
                        Icon(
                          CupertinoIcons.checkmark,
                          size: 18,
                          color: _getIconColorBasedOnAccentColor(accentColor.withOpacity(0.2)),
                        ),
                      const SizedBox(width: 6),
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

  void _showBookTypePicker(BuildContext context) async {
    final index = bookTypes.indexOf(currentOptions.bookType);
    String? selectedBookType;

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
                    scrollController: FixedExtentScrollController(initialItem: index),
                    onSelectedItemChanged: (index) => selectedBookType = bookTypes[index],
                    children: bookTypes.map((bookType) => Text(bookType)).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selectedBookType != null) {
      setState(() {
        currentOptions = currentOptions.copyWith(bookType: selectedBookType!);
      });
      widget.onOptionsChange(currentOptions);
    }
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