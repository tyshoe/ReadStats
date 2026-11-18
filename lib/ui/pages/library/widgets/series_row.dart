import 'package:flutter/material.dart';

import '/data/database/database_helper.dart';
import '/data/utils/series_progress.dart';
import '/ui/widgets/book_cover.dart';
import 'series_strip.dart';

/// A series in the Library list: its covers stacked, its strip, and how far
/// along the reader is. Expands to the books that passed the Library's
/// filters, each a compact row.
class SeriesRow extends StatelessWidget {
  /// The whole series, for the strip and the counts.
  final SeriesProgress progress;

  /// The books the Library is showing right now — the shelf and filters
  /// narrow these, the series doesn't.
  final List<Map<String, dynamic>> books;

  final bool expanded;
  final VoidCallback onToggle;

  /// Opens the Series page.
  final VoidCallback onOpen;
  final VoidCallback? onLongPress;
  final void Function(Map<String, dynamic> book) onBookTap;
  final void Function(Map<String, dynamic> book)? onBookLongPress;

  final bool Function(int bookId) isSelected;
  final Color selectionColor;
  final bool showStars;

  const SeriesRow({
    super.key,
    required this.progress,
    required this.books,
    required this.expanded,
    required this.onToggle,
    required this.onOpen,
    required this.onBookTap,
    required this.isSelected,
    required this.selectionColor,
    required this.showStars,
    this.onLongPress,
    this.onBookLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6);
    final allSelected =
        books.isNotEmpty && books.every((b) => isSelected(b['id'] as int));
    final author = progress.author;
    final hidden = progress.books.length - books.length;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      color: allSelected
          ? selectionColor.withValues(alpha: 0.45)
          : theme.cardTheme.color,
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onOpen,
            onLongPress: onLongPress,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SeriesCoverStack(books: progress.books, coverWidth: 56),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.collections_bookmark,
                                size: 16, color: muted),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                progress.name,
                                style: theme.textTheme.bodyLarge
                                    ?.copyWith(fontWeight: FontWeight.w600),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            ?author,
                            '${progress.total} '
                                '${progress.total == 1 ? 'book' : 'books'}',
                          ].join(' · '),
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: muted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                        SeriesStrip(progress: progress, compact: true),
                        const SizedBox(height: 8),
                        Text(
                          _summary(),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: muted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onToggle,
                    tooltip: expanded ? 'Hide books' : 'Show books',
                    icon: AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(Icons.expand_more),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: !expanded
                ? const SizedBox(width: double.infinity)
                : Column(
                    children: [
                      Divider(
                        height: 1,
                        indent: 12,
                        endIndent: 12,
                        color: theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.5),
                      ),
                      for (final b in books) _child(theme, b),
                      if (hidden > 0)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '$hidden more on other shelves',
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: muted),
                            ),
                          ),
                        )
                      else
                        const SizedBox(height: 6),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// "2 of 4 read · Up next: Anne of the Island"
  String _summary() {
    final read = progress.isComplete
        ? 'All ${progress.total} read'
        : '${progress.read} of ${progress.total} read';
    final next = progress.nextUp;
    if (next == null || progress.isComplete) return read;
    final what = next.isMissing
        ? '${SeriesProgress.label(next.position)} not in library'
        : next.state == SeriesSlotState.reading
            ? 'Reading ${next.book!['title']}'
            : 'Next: ${next.book!['title']}';
    return '$read · $what';
  }

  Widget _child(ThemeData theme, Map<String, dynamic> book) {
    final muted = theme.colorScheme.onSurfaceVariant;
    final position = (book['series_position'] as num?)?.toDouble();
    final cover = book['cover_path'] as String?;
    final rating = (book['rating'] as num?)?.toDouble();
    final selected = isSelected(book['id'] as int);

    return Material(
      color: selected
          ? selectionColor.withValues(alpha: 0.35)
          : Colors.transparent,
      child: InkWell(
        onTap: () => onBookTap(book),
        onLongPress:
            onBookLongPress == null ? null : () => onBookLongPress!(book),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: Text(
                  position == null
                      ? '–'
                      : '#${SeriesProgress.formatNumber(position)}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(
                width: 30,
                child: cover != null && cover.isNotEmpty
                    ? BookCover(
                        path: cover,
                        shape: book['cover_shape'] as int?,
                        width: 30,
                        borderRadius: 3,
                      )
                    : Icon(Icons.menu_book_rounded, size: 20, color: muted),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book['title'] as String? ?? '',
                      style: theme.textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      shelfLabel(book['shelf_id'] as int?),
                      style:
                          theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
              if (rating != null && rating > 0) ...[
                const SizedBox(width: 8),
                const Icon(Icons.star_rounded,
                    size: 16, color: Color(0xFFFBCB04)),
                const SizedBox(width: 2),
                Text(
                  rating.toStringAsFixed(rating % 1 == 0 ? 0 : 1),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String shelfLabel(int? shelfId) => switch (shelfId) {
        DatabaseHelper.shelfFinished => 'Finished',
        DatabaseHelper.shelfCurrentlyReading => 'Reading',
        DatabaseHelper.shelfUnfinished => 'Unfinished',
        _ => 'Want to read',
      };
}

/// A series in the Library grid: its covers fanned in one cell, with a count.
/// Tapping opens the Series page — expanding inside a grid would shove every
/// cell after it around.
class SeriesGridTile extends StatelessWidget {
  final SeriesProgress progress;

  /// The books the Library is showing, for the count and selection.
  final List<Map<String, dynamic>> books;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool selected;
  final Color selectionColor;

  const SeriesGridTile({
    super.key,
    required this.progress,
    required this.books,
    required this.onTap,
    this.onLongPress,
    this.selected = false,
    this.selectionColor = Colors.blue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      color: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: selected
            ? BorderSide(color: selectionColor, width: 3)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: LayoutBuilder(builder: (context, c) {
          final coverWidth = c.maxWidth * 0.52;
          const spread = 0.7;
          return Stack(
            children: [
              Positioned(
                top: 8,
                left: (c.maxWidth -
                        SeriesCoverStack.widthFor(coverWidth, spread: spread)) /
                    2,
                child: SeriesCoverStack(
                  books: progress.books,
                  coverWidth: coverWidth,
                  spread: spread,
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${books.length}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      progress.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    SeriesProgressBar(progress: progress, height: 4),
                    const SizedBox(height: 4),
                    Text(
                      '${progress.read} of ${progress.total} read',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Positioned.fill(
                  child: Center(
                    child: Icon(Icons.check_circle,
                        color: Colors.white, size: 32),
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }
}
