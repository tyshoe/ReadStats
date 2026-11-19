import 'package:flutter/material.dart';

import 'package:read_stats/data/models/notification_pref.dart' show kAllWeekdays;
import 'package:read_stats/data/utils/reading_clock.dart';

/// When in the week and when in the day reading happens, in one picture: a
/// track per weekday running through the reading day, shaded where the
/// reading falls.
///
/// Sits above the weekday strip and the time-of-day strip, which give the
/// exact totals but can't show the combination — "weeknight evenings and weekend
/// afternoons" flattens to "evenings" and "Sunday" once either axis is summed
/// away.
///
/// The track starts at [kReadingDayStartHour] rather than midnight, so a late
/// sitting stays in one piece on the night it began.
class WhenYouReadChart extends StatelessWidget {
  /// Totals per weekday and hour slot — see [emptyClockGrid] for the shape.
  final List<List<int>> grid;

  /// Total per weekday, keyed by DateTime.monday..sunday. Includes sessions
  /// that carry no clock time, so a row's figure can exceed its shading.
  final Map<int, int> weekdayTotals;

  final Color color;

  /// Formats a weekday total for the end of its row.
  final String Function(int) valueFormatter;

  /// What the shading measures, shown beside the title: "reading time" or
  /// "sessions".
  final String measureLabel;

  const WhenYouReadChart({
    super.key,
    required this.grid,
    required this.weekdayTotals,
    required this.color,
    required this.valueFormatter,
    required this.measureLabel,
  });

  static const double _trackHeight = 14;
  static const double _labelWidth = 34;
  static const double _totalWidth = 38;
  // Matches the fl_chart charts above, so switching the year filter moves the
  // whole page at one speed.
  static const Duration _animationDuration = Duration(milliseconds: 400);
  static const Curve _animationCurve = Curves.easeOutCubic;

  /// Clock hours labelled under the tracks.
  static const Map<int, String> _axisLabels = {
    6: '6a',
    12: '12p',
    18: '6p',
    0: '12a',
  };

  static const List<String> _daypartPlurals = [
    'mornings',
    'afternoons',
    'evenings',
    'nights',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withAlpha(120);

    var maxCell = 0;
    for (final row in grid) {
      for (final value in row) {
        if (value > maxCell) maxCell = value;
      }
    }
    final peakDay = peakBucket(weekdayTotals, kAllWeekdays);
    final caption = _caption();

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    'When You Read',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  measureLabel,
                  style: theme.textTheme.labelSmall?.copyWith(color: muted),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (maxCell == 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: Text(
                    'No session start times yet',
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ),
              )
            else
              Semantics(
                label: caption,
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Sunday-first, matching the heatmap and the reminder
                      // settings.
                      for (final day in kAllWeekdays) ...[
                        _buildRow(theme, day, maxCell, isPeak: day == peakDay),
                        const SizedBox(height: 8),
                      ],
                      _buildAxis(theme),
                      if (caption != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          caption,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withAlpha(200),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(ThemeData theme, int day, int maxCell,
      {required bool isPeak}) {
    final muted = theme.colorScheme.onSurface.withAlpha(120);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: isPeak ? theme.colorScheme.onSurface : muted,
      fontWeight: isPeak ? FontWeight.bold : null,
    );
    final total = weekdayTotals[day] ?? 0;
    final row = grid[day - 1];

    return Row(
      children: [
        SizedBox(
          width: _labelWidth,
          child: Text(kWeekdayShort[day]!, style: labelStyle, maxLines: 1),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_trackHeight / 2),
            child: Container(
              height: _trackHeight,
              color: theme.colorScheme.surfaceContainerHighest,
              child: Row(
                children: [
                  for (final value in row)
                    Expanded(
                      child: AnimatedContainer(
                        duration: _animationDuration,
                        curve: _animationCurve,
                        color: color.withValues(
                            alpha: _shade(value, maxCell)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(
          width: _totalWidth,
          child: Text(
            total == 0 ? '' : valueFormatter(total),
            style: labelStyle,
            textAlign: TextAlign.right,
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  /// Opacity for a slot. Anything logged keeps a visible floor, or a single
  /// short session beside a favourite hour would round away to nothing.
  static double _shade(int value, int maxCell) {
    if (value <= 0 || maxCell <= 0) return 0;
    return 0.18 + 0.82 * (value / maxCell);
  }

  Widget _buildAxis(ThemeData theme) {
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurface.withAlpha(120),
      fontSize: 10,
    );
    return Padding(
      padding: const EdgeInsets.only(left: _labelWidth, right: _totalWidth),
      child: SizedBox(
        height: 12,
        child: Stack(
          children: [
            for (final entry in _axisLabels.entries)
              Align(
                // The slot's left edge as a fraction of the track.
                alignment: Alignment(
                  -1 +
                      2 *
                          ((entry.key - kReadingDayStartHour + 24) % 24) /
                          24,
                  0,
                ),
                child: Text(entry.value, style: style),
              ),
          ],
        ),
      ),
    );
  }

  /// One sentence naming the busiest weekday-and-daypart, or null when
  /// nothing carries a clock time.
  String? _caption() {
    int? bestDay;
    int? bestPart;
    var best = 0;
    for (final day in kAllWeekdays) {
      final parts = List<int>.filled(kDaypartLabels.length, 0);
      final row = grid[day - 1];
      for (var slot = 0; slot < row.length; slot++) {
        parts[daypartOf(clockHourOfSlot(slot))] += row[slot];
      }
      for (final part in kDaypartOrder) {
        if (parts[part] > best) {
          best = parts[part];
          bestDay = day;
          bestPart = part;
        }
      }
    }
    if (bestDay == null || bestPart == null) return null;
    return 'You read most on ${kWeekdayFull[bestDay]} '
        '${_daypartPlurals[bestPart]}.';
  }
}
