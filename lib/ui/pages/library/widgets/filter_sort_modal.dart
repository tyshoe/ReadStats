import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class SortFilterOptions {
  final String sortOption;
  final bool isAscending;
  final String bookType;
  final bool isFavorite;  // Added field for is_favorite

  SortFilterOptions({
    required this.sortOption,
    required this.isAscending,
    required this.bookType,
    required this.isFavorite,  // Initialize isFavorite
  });

  SortFilterOptions copyWith({
    String? sortOption,
    bool? isAscending,
    String? bookType,
    bool? isFavorite,  // Add isFavorite to copyWith
  }) {
    return SortFilterOptions(
      sortOption: sortOption ?? this.sortOption,
      isAscending: isAscending ?? this.isAscending,
      bookType: bookType ?? this.bookType,
      isFavorite: isFavorite ?? this.isFavorite,  // Update isFavorite
    );
  }
}

class SortFilterPopup {
  static void showSortFilterPopup(
      BuildContext context,
      SortFilterOptions currentOptions,
      Function(SortFilterOptions) onOptionsChange,
      ) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) {
        return _SortFilterPopup(
          currentOptions: currentOptions,
          onOptionsChange: onOptionsChange,
        );
      },
    );
  }
}

class _SortFilterPopup extends StatefulWidget {
  final SortFilterOptions currentOptions;
  final Function(SortFilterOptions) onOptionsChange;

  const _SortFilterPopup({
    Key? key,
    required this.currentOptions,
    required this.onOptionsChange,
  }) : super(key: key);

  @override
  _SortFilterPopupState createState() => _SortFilterPopupState();
}

class _SortFilterPopupState extends State<_SortFilterPopup> {
  late SortFilterOptions currentOptions;
  final List<String> bookTypes = [
    'All',
    'Paperback',
    'Hardback',
    'eBook',
    'Audiobook'
  ];
  final List<String> sortOptions = [
    'Title',
    'Author',
    'Rating',
    'Pages',
    'Date started',
    'Date finished',
    'Date added'
  ];
  final List<String> favoriteOptions = ['All', 'Favorites Only']; // Added filter options for favorites

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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sort By',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            // Sort and Order row
            Row(
              children: [
                // Sort dropdown
                Expanded(
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                    color: CupertinoColors.systemGrey5,
                    borderRadius: BorderRadius.circular(8),
                    onPressed: () async {
                      final sortIndex =
                      sortOptions.indexOf(currentOptions.sortOption);
                      String? selectedOption;

                      await showCupertinoModalPopup<void>(
                        context: context,
                        builder: (context) {
                          return GestureDetector(
                            onTap: () => Navigator.pop(context),
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              height: 200,
                              color: CupertinoColors.secondarySystemBackground
                                  .resolveFrom(context),
                              child: Column(
                                children: [
                                  Expanded(
                                    child: CupertinoPicker(
                                      itemExtent: 32,
                                      scrollController:
                                      FixedExtentScrollController(
                                          initialItem: sortIndex),
                                      onSelectedItemChanged: (index) {
                                        selectedOption = sortOptions[index];
                                      },
                                      children: sortOptions
                                          .map((option) => Text(option))
                                          .toList(),
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
                          currentOptions = currentOptions.copyWith(
                              sortOption: selectedOption!);
                        });
                        widget.onOptionsChange(currentOptions);
                      }
                    },
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
                  padding:
                  const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  color: CupertinoColors.systemGrey5,
                  borderRadius: BorderRadius.circular(8),
                  onPressed: () {
                    setState(() {
                      currentOptions = currentOptions.copyWith(
                          isAscending: !currentOptions.isAscending);
                    });
                    widget.onOptionsChange(currentOptions);
                  },
                  child: Icon(
                    currentOptions.isAscending
                        ? CupertinoIcons.sort_up
                        : CupertinoIcons.sort_down,
                    size: 24,
                  ),
                ),
              ],
            ),
            // Divider line
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Divider(
                height: 1,
                color: CupertinoColors.systemGrey4.resolveFrom(context),
              ),
            ),
            const Text(
              'Filter By',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            // Format filter
            CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              color: CupertinoColors.systemGrey5,
              borderRadius: BorderRadius.circular(8),
              onPressed: () async {
                final index = bookTypes.indexOf(currentOptions.bookType);
                String? selectedFormat;

                await showCupertinoModalPopup<void>(  // Modal for book type
                  context: context,
                  builder: (context) {
                    return GestureDetector(
                      onTap: () => Navigator.pop(context),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        height: 200,
                        color: CupertinoColors.secondarySystemBackground
                            .resolveFrom(context),
                        child: Column(
                          children: [
                            Expanded(
                              child: CupertinoPicker(
                                itemExtent: 32,
                                scrollController: FixedExtentScrollController(
                                    initialItem: index),
                                onSelectedItemChanged: (index) {
                                  selectedFormat = bookTypes[index];
                                },
                                children: bookTypes
                                    .map((format) => Text(format))
                                    .toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );

                if (selectedFormat != null) {
                  setState(() {
                    currentOptions =
                        currentOptions.copyWith(bookType: selectedFormat!);
                  });
                  widget.onOptionsChange(currentOptions);
                }
              },
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
                  const Icon(CupertinoIcons.chevron_down,
                      color: CupertinoColors.systemGrey),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Favorite filter (newly added)
            CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              color: currentOptions.isFavorite
                  ? CupertinoColors.systemRed.withOpacity(0.2)
                  : CupertinoColors.systemGrey5,
              borderRadius: BorderRadius.circular(8),
              onPressed: () {
                setState(() {
                  currentOptions = currentOptions.copyWith(
                      isFavorite: !currentOptions.isFavorite
                  );
                });
                widget.onOptionsChange(currentOptions);
              },
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
            ),
          ],
        ),
      ),
    );
  }
}
