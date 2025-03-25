import 'package:flutter/cupertino.dart';

class SortFilterPopup {
  static void showSortFilterPopup(
    BuildContext context,
    Function(String) onSortChange,
    Function(bool) onOrderChange,
    String selectedSortOption,
    bool isAscending,
    Function(String) onFormatChange, // Added format change callback
    String selectedFormat, // Added selected format parameter
  ) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) {
        return _SortFilterPopup(
          selectedSortOption: selectedSortOption,
          isAscending: isAscending,
          onSortChange: onSortChange,
          onOrderChange: onOrderChange,
          onFormatChange: onFormatChange, // Pass to the popup
          selectedFormat: selectedFormat, // Pass to the popup
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
  final Function(String) onFormatChange; // Added for format change
  final String selectedFormat; // Added for selected format

  const _SortFilterPopup({
    Key? key,
    required this.selectedSortOption,
    required this.isAscending,
    required this.onSortChange,
    required this.onOrderChange,
    required this.onFormatChange, // Added to constructor
    required this.selectedFormat, // Added to constructor
  }) : super(key: key);

  @override
  _SortFilterPopupState createState() => _SortFilterPopupState();
}

class _SortFilterPopupState extends State<_SortFilterPopup> {
  late String currentSelectedSortOption;
  late bool currentIsAscending;
  late String currentSelectedFormat; // Track selected format

  // Book formats to be filtered
  final List<String> bookFormats = ['All', 'Paperback', 'Hardback', 'eBook', 'Audiobook'];

  @override
  void initState() {
    super.initState();
    currentSelectedSortOption = widget.selectedSortOption;
    currentIsAscending = widget.isAscending;
    currentSelectedFormat = widget.selectedFormat; // Initialize format
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
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                    color: CupertinoColors.systemGrey5,
                    borderRadius: BorderRadius.circular(8),
                    onPressed: () async {
                      final sortOption = await showCupertinoModalPopup<String>(
                        context: context,
                        builder: (context) {
                          return Container(
                            height: 200,
                            color: CupertinoColors.secondarySystemBackground
                                .resolveFrom(context),
                            child: CupertinoPicker(
                              itemExtent: 32,
                              scrollController: FixedExtentScrollController(
                                initialItem: _getSortOptionIndex(
                                    currentSelectedSortOption),
                              ),
                              onSelectedItemChanged: (index) {
                                final newSortOption =
                                    _getSortOptionByIndex(index);
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
                          currentSelectedSortOption,
                          style: TextStyle(
                              fontSize: 16,
                              color:
                                  CupertinoColors.label.resolveFrom(context)),
                        ),
                        Icon(CupertinoIcons.chevron_down,
                            color: CupertinoColors.systemGrey),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Sorting button (up/down icons)
                CupertinoButton(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  color: CupertinoColors.systemGrey5,
                  borderRadius: BorderRadius.circular(8),
                  onPressed: () {
                    setState(() {
                      currentIsAscending = !currentIsAscending;
                    });
                    widget.onOrderChange(currentIsAscending);
                    widget.onSortChange(currentSelectedSortOption);
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
            // Book Format Filter dropdown
            Row(
              children: [
                Expanded(
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                    color: CupertinoColors.systemGrey5,
                    borderRadius: BorderRadius.circular(8),
                    onPressed: () async {
                      final formatOption =
                          await showCupertinoModalPopup<String>(
                        context: context,
                        builder: (context) {
                          return Container(
                            height: 200,
                            color: CupertinoColors.secondarySystemBackground
                                .resolveFrom(context),
                            child: CupertinoPicker(
                              itemExtent: 32,
                              scrollController: FixedExtentScrollController(
                                initialItem:
                                    bookFormats.indexOf(currentSelectedFormat),
                              ),
                              onSelectedItemChanged: (index) {
                                setState(() {
                                  currentSelectedFormat = bookFormats[index];
                                });
                              },
                              children: bookFormats
                                  .map((format) => Text(format))
                                  .toList(),
                            ),
                          );
                        },
                      );
                      if (formatOption != null) {
                        setState(() {
                          currentSelectedFormat = formatOption;
                        });
                      }
                      widget.onFormatChange(
                          currentSelectedFormat); // Trigger format change callback
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          currentSelectedFormat,
                          style: TextStyle(
                              fontSize: 16,
                              color:
                                  CupertinoColors.label.resolveFrom(context)),
                        ),
                        Icon(CupertinoIcons.chevron_down,
                            color: CupertinoColors.systemGrey),
                      ],
                    ),
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
