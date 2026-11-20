import 'package:flutter/material.dart';

/// One chip per shelf, in a horizontal strip. Tapping the selected shelf
/// clears the filter (null).
class ShelfChips extends StatelessWidget {
  final List<Map<String, dynamic>> shelves;
  final int? selectedShelfId;

  /// Put on the selected chip, so the page can scroll it into view.
  final GlobalKey selectedKey;
  final ValueChanged<int?> onSelected;

  const ShelfChips({
    super.key,
    required this.shelves,
    required this.selectedShelfId,
    required this.selectedKey,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 32,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [for (final shelf in shelves) _chip(theme, shelf)],
      ),
    );
  }

  Widget _chip(ThemeData theme, Map<String, dynamic> shelf) {
    final id = shelf['id'] as int;
    final isSelected = selectedShelfId == id;
    return Padding(
      key: isSelected ? selectedKey : null,
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(shelf['name'] as String),
        selected: isSelected,
        onSelected: (_) => onSelected(isSelected ? null : id),
        showCheckmark: false,
        labelStyle: theme.textTheme.bodySmall,
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        selectedColor: theme.colorScheme.primaryContainer,
        elevation: 0,
        pressElevation: 0,
        side: BorderSide.none,
        shape: const StadiumBorder(),
      ),
    );
  }
}
