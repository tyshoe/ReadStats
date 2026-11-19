import 'package:flutter/material.dart';
import 'package:read_stats/domain/monthly_recap.dart';

/// Which unit the daily chart is drawn in. The app records all three per
/// session, and readers don't all log the same one — a timer user's month is
/// empty in pages, and a page counter's is empty in minutes.
enum _DayMetric { time, pages, sessions }

/// The month's shape: one bar per day, scaled to the biggest day. Shows at a
/// glance whether the reading was steady or came in bursts — which the totals
/// above can't say on their own.
class MonthActivityStrip extends StatefulWidget {
  final MonthlyRecap recap;
  final Color color;

  const MonthActivityStrip({
    super.key,
    required this.recap,
    required this.color,
  });

  @override
  State<MonthActivityStrip> createState() => _MonthActivityStripState();
}

class _MonthActivityStripState extends State<MonthActivityStrip> {
  /// Tall enough for [TextTheme.labelSmall], which is all the axis holds.
  static const double _axisHeight = 14;

  /// The plot's height. Named because the average line is placed by measuring
  /// against it rather than by a fraction of its parent.
  static const double _chartHeight = 64;

  /// What the reader last picked, which is not necessarily what is drawn — see
  /// [_resolve]. Held so the choice survives flicking through the months.
  _DayMetric _preferred = _DayMetric.time;

  /// Only the units this month actually has. Offering "Pages" on a month that
  /// was timed instead would hand the reader a flat, empty chart.
  List<_DayMetric> get _available {
    final recap = widget.recap;
    return [
      if (recap.minutes > 0) _DayMetric.time,
      if (recap.pages > 0) _DayMetric.pages,
      if (recap.sessions > 0) _DayMetric.sessions,
    ];
  }

  /// The preference when the month can honour it, else whatever it does have.
  /// Falling back without writing the fallback down is what stops a month that
  /// only has sessions from quietly resetting a reader who prefers time.
  _DayMetric _resolve(List<_DayMetric> available) =>
      available.contains(_preferred) ? _preferred : available.first;

  Map<int, int> _byDay(_DayMetric metric) => switch (metric) {
    _DayMetric.time => widget.recap.minutesByDay,
    _DayMetric.pages => widget.recap.pagesByDay,
    _DayMetric.sessions => widget.recap.sessionsByDay,
  };

  static String _name(_DayMetric metric) => switch (metric) {
    _DayMetric.time => 'Time',
    _DayMetric.pages => 'Pages',
    _DayMetric.sessions => 'Sessions',
  };

  static String _amount(_DayMetric metric, int value) => switch (metric) {
    _DayMetric.time => MonthlyRecap.formatMinutes(value),
    _DayMetric.pages => '$value ${value == 1 ? 'page' : 'pages'}',
    _DayMetric.sessions => '$value ${value == 1 ? 'session' : 'sessions'}',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final available = _available;
    if (available.isEmpty) return const SizedBox.shrink();

    final metric = _resolve(available);
    final byDay = _byDay(metric);
    final daysInMonth = widget.recap.daysInMonth;
    final peak = byDay.values.fold<int>(0, (a, b) => a > b ? a : b);
    if (peak == 0) return const SizedBox.shrink();

    // Averaged over the days that were read, not over the month: the question
    // a reader asks of a bar is "was that a good day for me", and days off
    // aren't part of that comparison. Under three days there is no typical day
    // to speak of, so the line is left off rather than drawn through everything.
    final read = byDay.values.where((v) => v > 0).toList(growable: false);
    final average = read.length < 3
        ? 0
        : (read.reduce((a, b) => a + b) / read.length).round();

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The tallest bar is the only thing the chart is scaled to, so
            // saying what it was worth is what turns the shape into figures.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Daily reading',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(153),
                  ),
                ),
                Text(
                  average > 0
                      ? 'Avg ${_amount(metric, average)} · '
                            'Peak ${_amount(metric, peak)}'
                      : 'Peak ${_amount(metric, peak)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            // No row of chips for a month that only ever had one unit to be
            // read in — the choice would be a control that does nothing.
            if (available.length > 1) ...[
              const SizedBox(height: 10),
              _buildMetricPicker(theme, available, metric),
            ],
            const SizedBox(height: 12),
            SizedBox(
              height: _chartHeight,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var day = 1; day <= daysInMonth; day++)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 0.8,
                              ),
                              child: _bar(byDay[day] ?? 0, peak, theme),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Drawn through the same transform the bars are, so a bar
                  // standing above the line really was an above-average day.
                  // Sizing it off the raw fraction would put it wrong, because
                  // the bars are floored to stay visible rather than scaled
                  // straight from zero.
                  if (average > 0)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: _heightFactor(average, peak) * _chartHeight,
                      child: _dashedLine(theme),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            _buildAxis(theme, daysInMonth),
          ],
        ),
      ),
    );
  }

  /// The same chips the month picker at the top of the page uses, so the two
  /// rows of choices on this screen read as the same control.
  Widget _buildMetricPicker(
    ThemeData theme,
    List<_DayMetric> available,
    _DayMetric selected,
  ) {
    return Row(
      children: [
        for (final metric in available)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              label: Text(_name(metric)),
              selected: metric == selected,
              onSelected: (_) => setState(() => _preferred = metric),
              showCheckmark: false,
              labelStyle: theme.textTheme.labelSmall,
              labelPadding: const EdgeInsets.symmetric(horizontal: 6),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              selectedColor: theme.colorScheme.primaryContainer,
              elevation: 0,
              pressElevation: 0,
              side: BorderSide.none,
              shape: const StadiumBorder(),
            ),
          ),
      ],
    );
  }

  /// Week markers under the bars — the 1st, 8th, 15th and so on.
  ///
  /// Built from the same run of [Expanded] cells the bars are, so each number
  /// sits under the day it names; two labels pushed to the ends would only line
  /// up by accident. The numbers are wider than the ~9pt cell they belong to,
  /// so each is allowed to spill evenly either side of its own column rather
  /// than being squeezed or clipped.
  ///
  /// The row is given a height because [OverflowBox] takes its parent's
  /// constraints for its own size, and a bare row inside a column offers it an
  /// unbounded one.
  Widget _buildAxis(ThemeData theme, int daysInMonth) {
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurface.withAlpha(120),
    );
    return SizedBox(
      height: _axisHeight,
      child: Row(
        children: [
          for (var day = 1; day <= daysInMonth; day++)
            Expanded(
              child: day % 7 == 1
                  ? Center(
                      child: OverflowBox(
                        maxWidth: 40,
                        maxHeight: _axisHeight,
                        child: Text('$day', style: style, maxLines: 1),
                      ),
                    )
                  : const SizedBox(),
            ),
        ],
      ),
    );
  }

  /// How tall a bar of [value] stands, as a fraction of the plot.
  ///
  /// Not a straight proportion: a day worth two minutes would otherwise be a
  /// bar too short to see, so anything read at all starts at 12% and the rest
  /// of the plot is shared out above that. A day with nothing keeps a hairline
  /// so the month reads as a continuous strip rather than as gaps between bars.
  ///
  /// Shared with the average line, which has to sit where a bar of that value
  /// would stand or it isn't telling the truth.
  static double _heightFactor(int value, int peak) =>
      value == 0 ? 0.04 : 0.12 + (value / peak) * 0.88;

  Widget _bar(int value, int peak, ThemeData theme) {
    return FractionallySizedBox(
      alignment: Alignment.bottomCenter,
      heightFactor: _heightFactor(value, peak),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: value == 0
              ? theme.colorScheme.onSurface.withAlpha(30)
              : widget.color.withValues(alpha: 0.35 + (value / peak) * 0.65),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  /// The average, as a dashed rule across the plot. Dashed so it reads as an
  /// annotation over the month rather than as another day in it.
  Widget _dashedLine(ThemeData theme) {
    const dash = 3.0;
    const gap = 3.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = (constraints.maxWidth / (dash + gap)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < count; i++)
              SizedBox(
                width: dash,
                height: 1,
                child: ColoredBox(
                  color: theme.colorScheme.onSurface.withAlpha(90),
                ),
              ),
          ],
        );
      },
    );
  }
}
