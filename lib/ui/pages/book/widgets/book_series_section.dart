import 'package:flutter/material.dart';
import 'package:read_stats/data/utils/series_title.dart';
import 'package:read_stats/domain/series_progress.dart';
import 'package:read_stats/ui/pages/book/widgets/detail_section.dart';
import 'package:read_stats/ui/pages/series/widgets/series_strip.dart';
import 'package:read_stats/ui/widgets/book_cover.dart';

/// The series [book] belongs to: how far through it the reader is, every
/// number as a cover (tap one to open it), and what's up next.
class BookSeriesSection extends StatelessWidget {
  final Map<String, dynamic> book;
  final SeriesProgress series;
  final VoidCallback onOpenSeries;

  /// Opens another book's page over [from].
  final void Function(BuildContext from, Map<String, dynamic> book) onOpenBook;

  const BookSeriesSection({
    super.key,
    required this.book,
    required this.series,
    required this.onOpenSeries,
    required this.onOpenBook,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final name = book['series_name'] as String? ?? '';
    final position = (book['series_position'] as num?)?.toDouble();
    final total = series.total;
    final done = series.isComplete;
    final finishedColor = seriesFinishedColor(cs);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: cs.onSurfaceVariant,
    );

    // Up next, unless it's this book.
    final next = series.nextUp;
    final showNext =
        next != null && !(next.book != null && next.book!['id'] == book['id']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DetailHeading('Series', trailing: 'View', onTrailing: onOpenSeries),
        DetailCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    done ? 'Complete' : '${series.read} of $total read',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: done ? finishedColor : cs.onSurfaceVariant,
                      fontWeight: done ? FontWeight.w700 : null,
                    ),
                  ),
                ],
              ),
              if (position != null)
                Text(
                  'This is book ${SeriesTitle.formatPosition(position)}',
                  style: muted,
                ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : series.read / total,
                  minHeight: 4,
                  color: finishedColor,
                  backgroundColor: cs.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 14),
              SeriesStrip(
                progress: series,
                highlight: position,
                onTap: (slot) => slot.book == null
                    ? onOpenSeries()
                    : onOpenBook(context, slot.book!),
              ),
              if (showNext) ...[
                Divider(
                  height: 24,
                  color: cs.outlineVariant.withValues(alpha: 0.5),
                ),
                _upNextRow(context, theme, next),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// "Up next · Book 3 — Title", opening that book; a number missing from
  /// the library opens the series, where it can be found.
  Widget _upNextRow(BuildContext context, ThemeData theme, SeriesSlot next) {
    final cs = theme.colorScheme;
    final book = next.book;
    final cover = book?['cover_path'] as String?;
    final reading = next.state == SeriesSlotState.reading;
    final title =
        book?['title'] as String? ?? next.plannedTitle ?? 'Not in your library';
    final label = reading
        ? 'Reading now'
        : book == null
        ? 'Missing'
        : 'Up next';

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => book == null ? onOpenSeries() : onOpenBook(context, book),
      child: Row(
        children: [
          if (cover != null && cover.isNotEmpty)
            BookCover(
              path: cover,
              shape: book?['cover_shape'] as int?,
              width: 36,
              borderRadius: 4,
            )
          else
            Container(
              width: 36,
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Icon(
                book == null ? Icons.search : Icons.menu_book,
                size: 16,
                color: cs.onSurfaceVariant,
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$label · ${SeriesProgress.label(next.position)}'
                      .toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: book == null ? cs.onSurfaceVariant : null,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
        ],
      ),
    );
  }
}
