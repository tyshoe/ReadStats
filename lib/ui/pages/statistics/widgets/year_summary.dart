import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// The headline numbers for the year the Stats page is showing — books,
/// time, pages and sessions — each with how it compares to the year before.
///
/// The current year is measured against the same stretch of last year, up to
/// today's date, so a year in progress isn't made to look behind a finished
/// one. A past year is measured whole against the one before it. "All" has
/// nothing to compare with and shows totals alone.
class YearSummary extends StatelessWidget {
  final List<Map<String, dynamic>> books;
  final List<Map<String, dynamic>> sessions;

  /// The selected year, or 0 for all time.
  final int year;

  const YearSummary({
    super.key,
    required this.books,
    required this.sessions,
    required this.year,
  });

  static const _up = Color(0xFF4CAF50);
  static const _down = Color(0xFFE57373);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withAlpha(153);
    final now = DateTime.now();
    final inProgress = year == now.year;

    final current = _Totals.of(books, sessions,
        from: year == 0 ? null : DateTime(year),
        until: year == 0 ? null : DateTime(year + 1));

    // Last year, cut off at this point in it when the year is still running.
    // Day + 1 so that today itself is inside the window.
    final previous = year == 0
        ? null
        : _Totals.of(books, sessions,
            from: DateTime(year - 1),
            until: inProgress
                ? DateTime(year - 1, now.month, now.day + 1)
                : DateTime(year));
    final compare = previous != null && !previous.isEmpty;

    final caption = year == 0
        ? 'All time'
        : [
            inProgress ? '$year so far' : '$year',
            if (compare)
              inProgress
                  ? 'vs this point in ${year - 1}'
                  : 'vs ${year - 1}',
          ].join(' · ');

    Widget cell(String label, String value, String? change, int direction) =>
        Expanded(
          child: Column(
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 2),
              Text(label,
                  style: theme.textTheme.bodySmall?.copyWith(color: muted)),
              if (compare) ...[
                const SizedBox(height: 4),
                Text(
                  change ?? '—',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: direction > 0
                        ? _up
                        : (direction < 0 ? _down : muted),
                  ),
                ),
              ],
            ],
          ),
        );

    // Books move in ones and twos, where a percentage says little: "+3".
    // The rest are large enough for one: "+18%".
    Widget count(String label, int now, int? before) {
      final diff = before == null ? 0 : now - before;
      return cell(
        label,
        NumberFormat.decimalPattern().format(now),
        before == null || diff == 0
            ? null
            : '${diff > 0 ? '+' : '−'}${diff.abs()}',
        diff.sign,
      );
    }

    Widget share(String label, String value, int now, int? before) {
      if (before == null || before == 0) return cell(label, value, null, 0);
      final percent = ((now - before) / before * 100).round();
      return cell(
        label,
        value,
        percent == 0 ? null : '${percent > 0 ? '+' : '−'}${percent.abs()}%',
        percent.sign,
      );
    }

    final hours = current.minutes ~/ 60;
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(caption,
                style: theme.textTheme.bodySmall?.copyWith(color: muted)),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                count('Books', current.books, compare ? previous.books : null),
                share(
                  'Time',
                  hours > 0
                      ? '${NumberFormat.decimalPattern().format(hours)}h'
                      : '${current.minutes}m',
                  current.minutes,
                  compare ? previous.minutes : null,
                ),
                share(
                  'Pages',
                  NumberFormat.compact().format(current.pages),
                  current.pages,
                  compare ? previous.pages : null,
                ),
                share(
                  'Sessions',
                  NumberFormat.decimalPattern().format(current.sessions),
                  current.sessions,
                  compare ? previous.sessions : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// What was read between two moments: books by their finish date, the rest
/// by the sessions logged.
class _Totals {
  final int books;
  final int minutes;
  final int pages;
  final int sessions;

  const _Totals(this.books, this.minutes, this.pages, this.sessions);

  bool get isEmpty => books == 0 && sessions == 0;

  /// From [from] up to but not including [until]; null leaves that end open.
  factory _Totals.of(
    List<Map<String, dynamic>> books,
    List<Map<String, dynamic>> sessions, {
    DateTime? from,
    DateTime? until,
  }) {
    bool within(Object? value) {
      final date = value is String ? DateTime.tryParse(value) : null;
      if (date == null) return false;
      if (from != null && date.isBefore(from)) return false;
      return until == null || date.isBefore(until);
    }

    var finished = 0;
    for (final b in books) {
      if (within(b['date_finished'])) finished++;
    }
    var minutes = 0, pages = 0, count = 0;
    for (final s in sessions) {
      if (!within(s['date'])) continue;
      count++;
      minutes += (s['duration_minutes'] as num?)?.toInt() ?? 0;
      pages += (s['pages_read'] as num?)?.toInt() ?? 0;
    }
    return _Totals(finished, minutes, pages, count);
  }
}
