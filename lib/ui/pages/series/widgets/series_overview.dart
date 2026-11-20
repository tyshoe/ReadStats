import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:read_stats/data/models/book_type.dart';
import 'package:read_stats/data/models/shelf.dart';
import 'package:read_stats/domain/series_progress.dart';
import 'package:read_stats/ui/pages/series/widgets/series_strip.dart';
import 'package:read_stats/ui/widgets/book_cover.dart';

// The top of the series page: who and what it is, how far along the reader
// is, what's next and the series' numbers. The book list follows.

/// The covers fanned out beside "SERIES", the name and the author.
class SeriesHeader extends StatelessWidget {
  final SeriesProgress progress;

  const SeriesHeader({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = progress;
    final muted = theme.colorScheme.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (p.books.isNotEmpty) ...[
          SeriesCoverStack(books: p.books, coverWidth: 76),
          const SizedBox(width: 16),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SERIES',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: muted,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                p.name,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (p.author != null) ...[
                const SizedBox(height: 4),
                Text(
                  p.author!,
                  style: theme.textTheme.bodyLarge?.copyWith(color: muted),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// "2 of 4 read" over the strip of little books.
class SeriesProgressSection extends StatelessWidget {
  final SeriesProgress progress;

  /// The number of the book the page was opened from, outlined in the strip.
  final double? highlight;
  final ValueChanged<SeriesSlot> onSlotTap;

  const SeriesProgressSection({
    super.key,
    required this.progress,
    required this.highlight,
    required this.onSlotTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = progress;
    final muted = theme.colorScheme.onSurfaceVariant;
    final percent = p.total == 0 ? 0 : (p.read * 100 / p.total).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            if (p.isComplete) ...[
              Icon(
                Icons.check_circle,
                size: 18,
                color: seriesFinishedColor(theme.colorScheme),
              ),
              const SizedBox(width: 6),
              Text(
                'Series complete',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ] else
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${p.read}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(
                      text: ' of ${p.total} read',
                      style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
            const Spacer(),
            Text(
              '$percent%',
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SeriesStrip(progress: p, highlight: highlight, onTap: onSlotTap),
      ],
    );
  }
}

/// The book to pick up next, with the one action that fits it: find a
/// missing one, open the one being read, or plan the next.
class SeriesUpNextCard extends StatelessWidget {
  final SeriesSlot next;

  /// The next book is already in the Planner.
  final bool inPlanner;

  /// Opens the add panel for a number not in the library.
  final VoidCallback onAdd;
  final VoidCallback onFind;
  final ValueChanged<Map<String, dynamic>> onOpenBook;
  final ValueChanged<Map<String, dynamic>> onPlan;

  const SeriesUpNextCard({
    super.key,
    required this.next,
    required this.inPlanner,
    required this.onAdd,
    required this.onFind,
    required this.onOpenBook,
    required this.onPlan,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final reading = next.state == SeriesSlotState.reading;
    final book = next.book;
    final cover = book?['cover_path'] as String?;

    final Widget action;
    if (next.isMissing) {
      action = FilledButton.tonalIcon(
        onPressed: onFind,
        icon: const Icon(Icons.search, size: 18),
        label: const Text('Find'),
      );
    } else if (reading) {
      action = FilledButton.tonal(
        onPressed: () => onOpenBook(book!),
        child: const Text('Open'),
      );
    } else if (inPlanner) {
      action = FilledButton.tonalIcon(
        onPressed: null,
        icon: const Icon(Icons.check, size: 18),
        label: const Text('Planned'),
      );
    } else {
      action = FilledButton.tonalIcon(
        onPressed: () => onPlan(book!),
        icon: const Icon(Icons.playlist_add, size: 18),
        label: const Text('Plan'),
      );
    }

    final String title;
    if (book != null) {
      title = book['title'] as String? ?? '';
    } else if (next.plannedTitle != null) {
      title = next.plannedTitle!;
    } else {
      title = next.isPlanned ? 'Not out yet' : 'Not in your library yet';
    }

    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: book == null ? onAdd : () => onOpenBook(book),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (next.isMissing)
                MissingCover(
                  width: 44,
                  icon: next.isPlanned ? Icons.schedule : Icons.search,
                )
              else if (cover != null && cover.isNotEmpty)
                BookCover(
                  path: cover,
                  shape: book!['cover_shape'] as int?,
                  width: 44,
                  borderRadius: 4,
                )
              else
                const MissingCover(width: 44, icon: Icons.menu_book_rounded),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${reading ? 'READING NOW' : 'UP NEXT'} · '
                      '${SeriesProgress.label(next.position).toUpperCase()}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: book == null && next.plannedTitle == null
                            ? muted
                            : null,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              action,
            ],
          ),
        ),
      ),
    );
  }
}

/// How much of the series is read and when it was started and last
/// finished — numbers only the books' own lengths and dates are needed for.
///
/// A series can be read in any mix of formats, so how much is counted both
/// ways: the pages of the finished print and ebooks, and the length of the
/// finished audiobooks. Each shows when it has something to count; a series
/// with nothing finished shows the one its books are.
class SeriesStatsRow extends StatelessWidget {
  final SeriesProgress progress;

  const SeriesStatsRow({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = progress;
    bool isAudio(Map<String, dynamic> b) =>
        b['book_type_id'] == BookType.audiobook;
    final finished = p.books
        .where((b) => b['shelf_id'] == Shelf.finished)
        .toList();
    final pages = finished
        .where((b) => !isAudio(b))
        .fold<int>(
          0,
          (sum, b) => sum + ((b['page_count'] as num?)?.toInt() ?? 0),
        );
    final minutes = finished
        .where(isAudio)
        .fold<int>(
          0,
          (sum, b) => sum + ((b['duration_minutes'] as num?)?.toInt() ?? 0),
        );
    final showListened =
        minutes > 0 ||
        (pages == 0 && p.books.isNotEmpty && p.books.every(isAudio));
    final showPages = pages > 0 || !showListened;
    final hours = minutes ~/ 60, mins = minutes % 60;
    final listened = hours == 0
        ? '${mins}m'
        : mins == 0
        ? '${NumberFormat.decimalPattern().format(hours)}h'
        : '${NumberFormat.decimalPattern().format(hours)}h ${mins}m';
    DateTime? parse(Object? v) => v is String ? DateTime.tryParse(v) : null;
    final starts = p.books.map((b) => parse(b['date_started'])).nonNulls;
    final ends = finished.map((b) => parse(b['date_finished'])).nonNulls;
    final started = starts.isEmpty
        ? null
        : starts.reduce((a, b) => a.isBefore(b) ? a : b);
    final last = ends.isEmpty
        ? null
        : ends.reduce((a, b) => a.isAfter(b) ? a : b);
    final fmt = DateFormat('MMM y');

    final tiles = [
      if (showPages)
        (NumberFormat.decimalPattern().format(pages), 'pages read'),
      if (showListened) (listened, 'listened'),
      (started == null ? '–' : fmt.format(started), 'started'),
      (last == null ? '–' : fmt.format(last), 'last finished'),
    ];
    Widget row(List<(String, String)> tiles) => Row(
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tiles[i].$1,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    tiles[i].$2,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
    // Four don't fit across a phone, so both counts get a row of their own.
    if (tiles.length < 4) return row(tiles);
    return Column(
      children: [
        row(tiles.sublist(0, 2)),
        const SizedBox(height: 8),
        row(tiles.sublist(2)),
      ],
    );
  }
}
