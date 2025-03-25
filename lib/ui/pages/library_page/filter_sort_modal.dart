import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class SortFilterPopup {
  static void showSortFilterPopup(
      BuildContext context,
      Function(String) onSortChange,
      Function(bool) onOrderChange,
      String selectedSortOption,
      bool isAscending,
      ) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) {
        return _SortFilterPopup(
          selectedSortOption: selectedSortOption,
          isAscending: isAscending,
          onSortChange: onSortChange,
          onOrderChange: onOrderChange,
        );
      },
    );
  }
}

class _SortFilterPopup extends StatefulWidget {
  final String selectedSortOption;
  final bool isAscending;
  final Function(String) onSortChange;
  final Function(bool) onOrderChange;

  const _SortFilterPopup({
    Key? key,
    required this.selectedSortOption,
    required this.isAscending,
    required this.onSortChange,
    required this.onOrderChange,
  }) : super(key: key);

  @override
  _SortFilterPopupState createState() => _SortFilterPopupState();
}

class _SortFilterPopupState extends State<_SortFilterPopup> {
  late String currentSelectedSortOption;
  late bool currentIsAscending;

  @override
  void initState() {
    super.initState();
    currentSelectedSortOption = widget.selectedSortOption;
    currentIsAscending = widget.isAscending;
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
            Text(
              'Sort and Filter',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            // Sort and Order buttons in the same row
            Row(
              children: [
                // Sort dropdown
                Expanded(
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    color: CupertinoColors.systemGrey5,
                    borderRadius: BorderRadius.circular(8),
                    onPressed: () async {
                      // Show modal to select sort option
                      final sortOption = await showCupertinoModalPopup<String>(
                        context: context,
                        builder: (context) {
                          return Container(
                            height: 200,
                            color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
                            child: CupertinoPicker(
                              itemExtent: 32,
                              scrollController: FixedExtentScrollController(
                                initialItem: _getSortOptionIndex(currentSelectedSortOption),
                              ),
                              onSelectedItemChanged: (index) {
                                // Update the selected sort option when the user interacts with the picker
                                final newSortOption = _getSortOptionByIndex(index);
                                setState(() {
                                  currentSelectedSortOption = newSortOption;
                                });
                              },
                              children: const [
                                Text('Title'),
                                Text('Author'),
                                Text('Rating'),
                                Text('Pages'),
                                Text('Date started'),
                                Text('Date finished'),
                                Text('Date added'),
                              ],
                            ),
                          );
                        },
                      );
                      // Only update the state when the modal is dismissed
                      if (sortOption != null) {
                        setState(() {
                          currentSelectedSortOption = sortOption;
                        });
                      }
                      widget.onSortChange(currentSelectedSortOption);
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          currentSelectedSortOption ?? 'Select a Sort Option',
                          style: TextStyle(fontSize: 16, color: CupertinoColors.label.resolveFrom(context)),
                        ),
                        Icon(CupertinoIcons.chevron_down, color: CupertinoColors.systemGrey),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Sorting button (up/down icons) with background
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  color: CupertinoColors.systemGrey5,
                  borderRadius: BorderRadius.circular(8),
                  onPressed: () {
                    setState(() {
                      currentIsAscending = !currentIsAscending;
                    });
                    widget.onOrderChange(currentIsAscending);
                    widget.onSortChange(currentSelectedSortOption);  // Call when the order changes
                  },
                  child: Icon(
                    currentIsAscending
                        ? CupertinoIcons.sort_up
                        : CupertinoIcons.sort_down,
                    size: 24,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // Helper method to get the index of the selected sort option
  int _getSortOptionIndex(String sortOption) {
    switch (sortOption) {
      case 'Author':
        return 1;
      case 'Rating':
        return 2;
      case 'Pages':
        return 3;
      case 'Date started':
        return 4;
      case 'Date finished':
        return 5;
      case 'Date added':
        return 6;
      case 'Title':
      default:
        return 0;
    }
  }

  // Helper method to get the sort option by index
  String _getSortOptionByIndex(int index) {
    switch (index) {
      case 1:
        return 'Author';
      case 2:
        return 'Rating';
      case 3:
        return 'Pages';
      case 4:
        return 'Date started';
      case 5:
        return 'Date finished';
      case 6:
        return 'Date added';
      case 0:
      default:
        return 'Title';
    }
  }
}
