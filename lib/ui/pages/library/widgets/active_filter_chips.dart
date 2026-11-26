import 'package:flutter/material.dart';

/// One filter that is narrowing the Library, as a chip that removes it.
class ActiveFilter {
  final String label;
  final VoidCallback onRemove;

  const ActiveFilter(this.label, {required this.onRemove});
}

/// The filters in force, in a horizontal strip under the shelves. Filters
/// are remembered between launches, so without this a shorter list has only
/// a dot on the filter button to explain it.
///
/// Named and ordered as the filter sheet lists them, and filled the way a
/// chosen chip is there, so each one reads as that choice carried out here.
class ActiveFilterChips extends StatelessWidget {
  final List<ActiveFilter> filters;

  /// Shown as a last chip once more than one filter is on.
  final VoidCallback onClearAll;

  const ActiveFilterChips({
    super.key,
    required this.filters,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    Widget chip(ActiveFilter f) => Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InputChip(
        label: Text(f.label),
        onDeleted: f.onRemove,
        onPressed: f.onRemove,
        deleteIcon: const Icon(Icons.close, size: 16),
        deleteIconColor: colors.onPrimaryContainer,
        labelStyle: theme.textTheme.bodySmall?.copyWith(
          color: colors.onPrimaryContainer,
        ),
        labelPadding: const EdgeInsets.only(left: 4, right: 2),
        backgroundColor: colors.primaryContainer,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );

    return SizedBox(
      height: 32,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final f in filters) chip(f),
          if (filters.length > 1)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ActionChip(
                label: const Text('Clear all'),
                onPressed: onClearAll,
                labelStyle: theme.textTheme.bodySmall?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w600,
                ),
                backgroundColor: Colors.transparent,
                side: BorderSide.none,
                shape: const StadiumBorder(),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
        ],
      ),
    );
  }
}
