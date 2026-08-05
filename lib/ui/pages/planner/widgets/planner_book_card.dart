import 'package:flutter/material.dart';
import '/data/models/planner_book.dart';
import '/ui/widgets/book_cover.dart';

class PlannerBookCard extends StatelessWidget {
  final PlannerBook book;
  final int index;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback onLongPress;

  const PlannerBookCard({
    super.key,
    required this.book,
    required this.index,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  static const int _audiobookTypeId = 4;
  static const double _coverWidth = 40;

  String? _metadata() {
    if (book.bookTypeId == _audiobookTypeId && book.durationMinutes > 0) {
      final h = book.durationMinutes ~/ 60;
      final m = book.durationMinutes % 60;
      if (h > 0 && m > 0) return '${h}h ${m}m';
      if (h > 0) return '${h}h';
      return '${m}m';
    }
    if (book.pageCount > 0) return '${book.pageCount} pages';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meta = _metadata();

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        elevation: 0,
        color: isSelected
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
            : theme.cardTheme.color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              ReorderableDragStartListener(
                index: index - 1,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.drag_handle,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.4),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$index',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Cover only when one exists — no placeholder otherwise.
              if (book.coverPath != null) ...[
                _buildCover(book.coverPath!),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      book.bookTitle,
                      style: theme.textTheme.bodyLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      meta != null
                          ? '${book.bookAuthor} · $meta'
                          : book.bookAuthor,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCover(String path) {
    return BookCover(
      path: path,
      shape: book.coverShape,
      width: _coverWidth,
      borderRadius: 4,
    );
  }
}
