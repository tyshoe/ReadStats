import 'package:flutter/material.dart';
import 'package:read_stats/data/models/shelf.dart';

/// The four shelves side by side, the chosen one filled: where the book goes
/// once the session is saved.
class SessionShelfPicker extends StatelessWidget {
  final int? selectedShelfId;
  final ValueChanged<int> onSelected;

  const SessionShelfPicker({
    super.key,
    required this.selectedShelfId,
    required this.onSelected,
  });

  static const _shelves = [
    (id: Shelf.wantToRead, label: 'To Read', icon: Icons.bookmark),
    (
      id: Shelf.currentlyReading,
      label: 'Reading',
      icon: Icons.menu_book_rounded,
    ),
    (id: Shelf.finished, label: 'Finished', icon: Icons.check),
    (id: Shelf.unfinished, label: 'Unfinished', icon: Icons.do_not_disturb_on),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (final shelf in _shelves)
            Expanded(
              child: GestureDetector(
                onTap: () => onSelected(shelf.id),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selectedShelfId == shelf.id
                        ? cs.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        shelf.icon,
                        size: 18,
                        color: selectedShelfId == shelf.id
                            ? cs.onPrimary
                            : cs.onSurfaceVariant,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        shelf.label,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: selectedShelfId == shelf.id
                              ? cs.onPrimary
                              : cs.onSurfaceVariant,
                          fontWeight: selectedShelfId == shelf.id
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
