import 'package:flutter/material.dart';

/// How a book's `book_type_id` is shown to the reader — the ids are the ones
/// seeded into the `book_types` table, so they're stable.
///
/// It matters more than it looks: a reader can own the same title twice, a
/// paperback and an audiobook, and title and author alone can't tell the two
/// copies apart.
(IconData, String) bookTypeDetails(int? id) => switch (id) {
  1 => (Icons.book_outlined, 'Paperback'),
  2 => (Icons.book, 'Hardback'),
  3 => (Icons.computer, 'eBook'),
  4 => (Icons.headset, 'Audiobook'),
  _ => (Icons.book, 'Paperback'),
};

/// The book's format, as a small tinted chip.
///
/// Named rather than icon-only: at this size the paperback and hardback marks
/// are the same book glyph outlined and filled, which is not a difference a
/// reader should have to squint at.
class BookTypeBadge extends StatelessWidget {
  final int? bookTypeId;

  const BookTypeBadge({super.key, required this.bookTypeId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, label) = bookTypeDetails(bookTypeId);
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 2, 8, 2),
      decoration: BoxDecoration(
        // The highest neutral step, not `surfaceContainer`: these sit on cards,
        // which are already a container tone themselves. One step apart left
        // the chip all but invisible in dark, where the card and the old fill
        // were within a thousandth of each other in luminance.
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
