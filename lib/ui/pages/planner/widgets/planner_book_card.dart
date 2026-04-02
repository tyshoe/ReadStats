import 'package:flutter/material.dart';
import '/data/models/planner_book.dart';

class PlannerBookCard extends StatefulWidget {
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

  @override
  State<PlannerBookCard> createState() => _PlannerBookCardState();
}

class _PlannerBookCardState extends State<PlannerBookCard> {
  bool _isSwiping = false;

  String? _metadata() {
    const audiobookTypeId = 4;
    if (widget.book.bookTypeId == audiobookTypeId &&
        widget.book.durationMinutes > 0) {
      final h = widget.book.durationMinutes ~/ 60;
      final m = widget.book.durationMinutes % 60;
      if (h > 0 && m > 0) return '${h}h ${m}m';
      if (h > 0) return '${h}h';
      return '${m}m';
    }
    if (widget.book.pageCount > 0) return '${widget.book.pageCount} pages';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meta = _metadata();

    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: Listener(
        onPointerMove: (event) {
          if (event.delta.dx < -1 && !_isSwiping) {
            setState(() => _isSwiping = true);
          }
        },
        onPointerUp: (_) {
          if (_isSwiping) setState(() => _isSwiping = false);
        },
        onPointerCancel: (_) {
          if (_isSwiping) setState(() => _isSwiping = false);
        },
        child: Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          elevation: 0,
          color: widget.isSelected
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
              : theme.cardTheme.color,
          shape: RoundedRectangleBorder(
            borderRadius: _isSwiping
                ? const BorderRadius.horizontal(left: Radius.circular(12))
                : BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                ReorderableDragStartListener(
                  index: widget.index - 1,
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
                        '${widget.index}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.book.bookTitle,
                        style: theme.textTheme.bodyLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        meta != null
                            ? '${widget.book.bookAuthor} · $meta'
                            : widget.book.bookAuthor,
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
      ),
    );
  }
}
