import 'package:flutter/material.dart';
import '/data/models/planner_book.dart';

class PlannerBookCard extends StatelessWidget {
  final PlannerBook book;
  final int index;
  final VoidCallback onDelete;

  const PlannerBookCard({
    super.key,
    required this.book,
    required this.index,
    required this.onDelete,
  });

  String? _metadata() {
    const audiobookTypeId = 4;
    if (book.bookTypeId == audiobookTypeId && book.durationMinutes > 0) {
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

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      color: theme.cardTheme.color,
      child: ReorderableDragStartListener(
        index: index - 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: Text(
                  '$index',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 12),
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
                      meta != null ? '${book.bookAuthor} · $meta' : book.bookAuthor,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.drag_indicator,
                size: 20,
                color: theme.iconTheme.color?.withAlpha(80),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
