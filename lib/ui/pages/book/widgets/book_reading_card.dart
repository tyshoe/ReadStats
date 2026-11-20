import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:read_stats/data/models/book_type.dart';
import 'package:read_stats/data/models/shelf.dart';
import 'package:read_stats/ui/pages/book/widgets/detail_section.dart';

/// One card for the read itself: progress while reading (or when it was
/// read, once done), then every number that has a value, three to a row.
/// Check [isEmpty] before showing it.
class BookReadingCard extends StatelessWidget {
  final Map<String, dynamic> book;
  final Map<String, dynamic> stats;

  /// The page the last session ended on, or 0.
  final int currentPage;
  final DateFormat dateFormat;

  const BookReadingCard({
    super.key,
    required this.book,
    required this.stats,
    required this.currentPage,
    required this.dateFormat,
  });

  bool get _isAudio => book['book_type_id'] == BookType.audiobook;
  bool get _reading => book['shelf_id'] == Shelf.currentlyReading;
  int get _total => _isAudio
      ? (book['duration_minutes'] as int?) ?? 0
      : (book['page_count'] as int?) ?? 0;

  /// Nothing to say: no sessions, and no progress or dates to show.
  bool get isEmpty {
    final hasTop = _reading
        ? _total > 0
        : DetailFormat.parse(book['date_started']) != null ||
              DetailFormat.parse(book['date_finished']) != null;
    return !hasTop && _statCells().isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: cs.onSurfaceVariant,
    );

    final top = _reading ? _progress(theme) : _dates(theme);
    final cells = _statCells();

    return DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ?top,
          if (top != null && cells.isNotEmpty)
            Divider(
              height: 24,
              color: cs.outlineVariant.withValues(alpha: 0.5),
            ),
          for (var r = 0; r < cells.length; r += 3) ...[
            if (r > 0) const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = r; i < r + 3; i++)
                  Expanded(
                    child: i < cells.length
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cells[i].$1,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(cells[i].$2, style: muted),
                            ],
                          )
                        : const SizedBox(),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Big percentage, the bar, and where they are in it.
  Widget? _progress(ThemeData theme) {
    final cs = theme.colorScheme;
    final total = _total;
    if (total <= 0) return null;
    final done = _isAudio
        ? (stats['total_time'] as num?)?.toInt() ?? 0
        : (stats['total_pages'] as num?)?.toInt() ?? 0;
    final fraction = (done / total).clamp(0.0, 1.0);

    String? left;
    if (_isAudio) {
      if (done < total) left = '${DetailFormat.time(total - done)} left';
    } else {
      final ppm = (stats['pages_per_minute'] as num?)?.toDouble() ?? 0;
      if (ppm > 0 && done < total) {
        left = '${DetailFormat.time(((total - done) / ppm).round())} left';
      }
    }

    final where = _isAudio
        ? '${DetailFormat.time(done)} of ${DetailFormat.time(total)}'
        : currentPage > 0
        ? 'Page ${DetailFormat.number(currentPage)} of ${DetailFormat.number(total)}'
        : '${DetailFormat.number(done)} of ${DetailFormat.number(total)} pages';
    final start = DetailFormat.parse(book['date_started']);
    final since = start == null
        ? null
        : 'Day ${DetailFormat.daysBetween(start, DateTime.now()) + 1} · since ${DateFormat.MMMd().format(start)}';
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: cs.onSurfaceVariant,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '${(fraction * 100).round()}%',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: cs.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                where,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
            if (left != null)
              Text(
                left,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 8,
            backgroundColor: cs.surfaceContainerHighest,
          ),
        ),
        if (since != null) ...[
          const SizedBox(height: 6),
          Text(since, style: muted),
        ],
      ],
    );
  }

  /// "Oct 27 – Nov 5, 2026" with "9 days" at the end.
  Widget? _dates(ThemeData theme) {
    final cs = theme.colorScheme;
    final start = DetailFormat.parse(book['date_started']);
    final finish = DetailFormat.parse(book['date_finished']);
    final f = dateFormat;
    final String text;
    String? span;
    if (start != null && finish != null) {
      text = '${f.format(start)} – ${f.format(finish)}';
      final d = DetailFormat.daysBetween(start, finish).clamp(1, 1 << 31);
      span = '$d ${d == 1 ? 'day' : 'days'}';
    } else if (start != null) {
      text = 'Started ${f.format(start)}';
    } else if (finish != null) {
      text = 'Finished ${f.format(finish)}';
    } else {
      return null;
    }
    return Row(
      children: [
        Icon(Icons.event, size: 18, color: cs.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (span != null)
          Text(
            span,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
      ],
    );
  }

  /// Every reading number that has a value.
  List<(String, String)> _statCells() {
    final sessions = (stats['session_count'] as int?) ?? 0;
    if (sessions == 0) return const [];
    final minutes = (stats['total_time'] as num?)?.toInt() ?? 0;
    final pages = (stats['total_pages'] as num?)?.toInt() ?? 0;
    final ppm = (stats['pages_per_minute'] as num?)?.toDouble() ?? 0;
    final wpm = (stats['words_per_minute'] as num?)?.toDouble() ?? 0;
    return [
      if (minutes > 0)
        (DetailFormat.time(minutes), _isAudio ? 'listened' : 'read time'),
      ('$sessions', sessions == 1 ? 'session' : 'sessions'),
      if (minutes > 0)
        (DetailFormat.time((minutes / sessions).round()), 'avg session'),
      // Progress already says how many pages while reading.
      if (!_isAudio && pages > 0 && !_reading)
        (DetailFormat.number(pages), 'pages read'),
      if (!_isAudio && ppm > 0) ('${(ppm * 60).round()}', 'pages/hr'),
      if (wpm > 0) ('${wpm.round()}', 'words/min'),
    ];
  }
}
