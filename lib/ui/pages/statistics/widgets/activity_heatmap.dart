import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A year of reading at a glance: one square per day, darker the more sessions
/// were logged that day.
///
/// Laid out like a contribution graph — a column is a week, Sunday at the top
/// to match the sessions calendar — but split into two half-year strips stacked
/// on top of each other. A full year in one strip is either scrolled or shrunk
/// past the point of being readable; half a year at a time fits a phone with
/// squares big enough to see and to tap.
class ActivityHeatmap extends StatefulWidget {
  /// Sessions per day, keyed by local midnight — the same shape the cumulative
  /// charts are drawn from.
  final Map<DateTime, int> dailyCounts;

  /// The page's year filter: a calendar year, or 0 for the trailing year that
  /// ends today.
  final int selectedYear;
  final Color color;

  const ActivityHeatmap({
    super.key,
    required this.dailyCounts,
    required this.selectedYear,
    required this.color,
  });

  @override
  State<ActivityHeatmap> createState() => _ActivityHeatmapState();
}

/// The square size and spacing for one layout pass, derived from the available
/// width. Squares are square, so a column and a row are the same [step].
class _Metrics {
  final double cell;
  final double gap;

  const _Metrics(this.cell, this.gap);

  double get step => cell + gap;
}

/// Half a year of days, drawn as one strip of week columns.
class _Strip {
  final DateTime start;
  final DateTime end;

  const _Strip(this.start, this.end);

  /// The Sunday the strip's first column begins on.
  DateTime get gridStart => _ActivityHeatmapState._weekStart(start);

  int get weeks => (end.difference(gridStart).inDays / 7).floor() + 1;
}

class _ActivityHeatmapState extends State<ActivityHeatmap> {
  /// Half of the trailing-year view, in weeks — two of these make the year.
  static const int _halfWeeks = 26;

  /// Width set aside for the weekday markers down the left of each strip.
  static const double _labelWidth = 14;

  /// The day whose details replace the summary line, until it's tapped again.
  DateTime? _selectedDay;

  @override
  void didUpdateWidget(covariant ActivityHeatmap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedYear != widget.selectedYear) _selectedDay = null;
  }

  static DateTime _dayOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// The Sunday on or before [date]. Built by calendar arithmetic rather than
  /// [Duration], which is an hour short or long across a DST boundary.
  static DateTime _weekStart(DateTime date) =>
      DateTime(date.year, date.month, date.day - (date.weekday % 7));

  /// The two strips to draw, oldest first. A half-year that hasn't started yet
  /// is left out entirely rather than drawn as an empty block.
  List<_Strip> get _strips {
    final today = _dayOnly(DateTime.now());

    if (widget.selectedYear == 0) {
      final gridStart = DateTime(
        _weekStart(today).year,
        _weekStart(today).month,
        _weekStart(today).day - (_halfWeeks * 2 - 1) * 7,
      );
      final split = DateTime(
        gridStart.year,
        gridStart.month,
        gridStart.day + _halfWeeks * 7,
      );
      return [
        _Strip(gridStart, DateTime(split.year, split.month, split.day - 1)),
        _Strip(split, today),
      ];
    }

    final year = widget.selectedYear;
    final halves = [
      _Strip(DateTime(year, 1, 1), DateTime(year, 6, 30)),
      _Strip(DateTime(year, 7, 1), DateTime(year, 12, 31)),
    ];
    return [
      for (final half in halves)
        if (!half.start.isAfter(today))
          // The current half stops at today: a run of squares for days that
          // haven't happened says nothing.
          half.end.isAfter(today) ? _Strip(half.start, today) : half,
    ];
  }

  /// Days with at least one session across everything drawn, and the longest
  /// run of them back to back.
  (int daysRead, int longestStreak) _summary(List<_Strip> strips) {
    if (strips.isEmpty) return (0, 0);
    final start = strips.first.start;
    final end = strips.last.end;
    final days =
        widget.dailyCounts.entries
            .where((e) => e.value > 0)
            .map((e) => e.key)
            .where((d) => !d.isBefore(start) && !d.isAfter(end))
            .toList()
          ..sort();
    if (days.isEmpty) return (0, 0);

    var longest = 1;
    var run = 1;
    for (var i = 1; i < days.length; i++) {
      final previous = days[i - 1];
      final nextDay = DateTime(previous.year, previous.month, previous.day + 1);
      run = days[i] == nextDay ? run + 1 : 1;
      if (run > longest) longest = run;
    }
    return (days.length, longest);
  }

  /// Four steps, so a day with a single session still registers and a heavy day
  /// still stands out. Counts this high are rare enough that quartiles of the
  /// maximum would flatten every ordinary day into one shade.
  Color _cellColor(ThemeData theme, int count) {
    if (count <= 0) return theme.colorScheme.onSurface.withValues(alpha: 0.07);
    final alpha = switch (count) {
      1 => 0.3,
      2 => 0.5,
      3 => 0.75,
      _ => 1.0,
    };
    return widget.color.withValues(alpha: alpha);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strips = _strips;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Text(
              'Reading Activity',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
            child: _buildHeader(theme, strips),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Both strips are sized off the longer one, so their columns
                // line up underneath each other.
                final weeks = strips
                    .map((s) => s.weeks)
                    .fold(1, (a, b) => a > b ? a : b);
                final step = (constraints.maxWidth - _labelWidth) / weeks;
                final gap = (step * 0.18).clamp(1.0, 3.0);
                final metrics = _Metrics(step - gap, gap);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final strip in strips) ...[
                      if (strip != strips.first) const SizedBox(height: 10),
                      _buildStrip(theme, strip, metrics),
                    ],
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: _buildLegend(theme),
          ),
        ],
      ),
    );
  }

  /// The summary line, or the tapped day's own numbers — a square is too small
  /// to label, and a tooltip is a poor fit for a grid this dense.
  Widget _buildHeader(ThemeData theme, List<_Strip> strips) {
    final selected = _selectedDay;
    final count = selected == null ? 0 : widget.dailyCounts[selected] ?? 0;
    // Only a day that still has sessions takes over the line — a reload can
    // empty the selected day out from under it.
    if (selected != null && count > 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('EEEE, MMM d, y').format(selected),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(120),
            ),
          ),
          Text(
            '$count ${count == 1 ? 'session' : 'sessions'}',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w300,
            ),
          ),
        ],
      );
    }

    final (daysRead, longestStreak) = _summary(strips);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _summaryValue(theme, 'Days Read', daysRead.toString()),
        const SizedBox(width: 20),
        _summaryValue(theme, 'Longest Streak', '$longestStreak d'),
      ],
    );
  }

  Widget _summaryValue(ThemeData theme, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withAlpha(120),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }

  Widget _buildStrip(ThemeData theme, _Strip strip, _Metrics metrics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: _labelWidth),
          child: _buildMonthLabels(theme, strip, metrics),
        ),
        const SizedBox(height: 3),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWeekdayLabels(theme, metrics),
            _buildGrid(theme, strip, metrics),
          ],
        ),
      ],
    );
  }

  Widget _buildWeekdayLabels(ThemeData theme, _Metrics metrics) {
    // Mon/Wed/Fri only — every row labelled is unreadable at this size, and
    // three markers are enough to count from.
    const labels = {1: 'M', 3: 'W', 5: 'F'};
    final style = theme.textTheme.labelSmall?.copyWith(
      fontSize: 8,
      height: 1,
      color: theme.colorScheme.onSurface.withAlpha(120),
    );
    return SizedBox(
      width: _labelWidth,
      child: Column(
        children: [
          for (var row = 0; row < 7; row++)
            SizedBox(
              height: metrics.step,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(labels[row] ?? '', style: style),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMonthLabels(ThemeData theme, _Strip strip, _Metrics metrics) {
    final style = theme.textTheme.labelSmall?.copyWith(
      fontSize: 9,
      color: theme.colorScheme.onSurface.withAlpha(120),
    );

    final labels = <Widget>[];
    var lastLabelX = double.negativeInfinity;
    for (var week = 0; week < strip.weeks; week++) {
      final weekStart = DateTime(
        strip.gridStart.year,
        strip.gridStart.month,
        strip.gridStart.day + week * 7,
      );
      final weekEnd = DateTime(
        weekStart.year,
        weekStart.month,
        weekStart.day + 6,
      );
      // A column is labelled with the month that *begins* inside it, not the
      // month its Sunday falls in: the week holding January 1st usually starts
      // in December, and labelling that column Dec would date the whole strip
      // wrong.
      final DateTime? monthStart = weekStart.day == 1
          ? weekStart
          : weekEnd.month != weekStart.month
          ? DateTime(weekEnd.year, weekEnd.month, 1)
          : null;
      if (monthStart == null) continue;
      // The end columns overhang into the next half-year — the week holding
      // June 30th usually runs into July — but those days are drawn in the
      // other strip. Labelling their month here would put a stray Jul at the
      // end of the first half and a Jan at the end of the second.
      if (monthStart.isBefore(strip.start) || monthStart.isAfter(strip.end)) {
        continue;
      }

      // Only where the label before it has room to be read.
      final x = week * metrics.step;
      if (x - lastLabelX < 26) continue;
      labels.add(
        Positioned(
          left: x,
          child: Text(DateFormat('MMM').format(monthStart), style: style),
        ),
      );
      lastLabelX = x;
    }

    return SizedBox(
      width: strip.weeks * metrics.step,
      height: 11,
      child: Stack(clipBehavior: Clip.none, children: labels),
    );
  }

  /// One gesture for the whole strip rather than one per square: at this size a
  /// square is smaller than a fingertip, so the tap is resolved by which cell
  /// the finger landed in.
  Widget _buildGrid(ThemeData theme, _Strip strip, _Metrics metrics) {
    return GestureDetector(
      onTapUp: (details) =>
          _selectDayAt(details.localPosition, strip, metrics),
      child: SizedBox(
        width: strip.weeks * metrics.step,
        height: 7 * metrics.step,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var week = 0; week < strip.weeks; week++)
              _buildWeek(theme, strip, week, metrics),
          ],
        ),
      ),
    );
  }

  void _selectDayAt(Offset position, _Strip strip, _Metrics metrics) {
    final week = (position.dx / metrics.step).floor();
    final row = (position.dy / metrics.step).floor();
    if (row < 0 || row > 6) return;

    final day = DateTime(
      strip.gridStart.year,
      strip.gridStart.month,
      strip.gridStart.day + week * 7 + row,
    );
    if (day.isBefore(strip.start) || day.isAfter(strip.end)) return;
    // A day with no sessions has nothing to say, so it doesn't answer a tap.
    if ((widget.dailyCounts[day] ?? 0) == 0) return;

    setState(() => _selectedDay = _selectedDay == day ? null : day);
  }

  Widget _buildWeek(
    ThemeData theme,
    _Strip strip,
    int week,
    _Metrics metrics,
  ) {
    return Padding(
      padding: EdgeInsets.only(right: metrics.gap),
      child: Column(
        children: [
          for (var row = 0; row < 7; row++)
            _buildDay(
              theme,
              strip,
              DateTime(
                strip.gridStart.year,
                strip.gridStart.month,
                strip.gridStart.day + week * 7 + row,
              ),
              metrics,
            ),
        ],
      ),
    );
  }

  Widget _buildDay(
    ThemeData theme,
    _Strip strip,
    DateTime day,
    _Metrics metrics,
  ) {
    // The end columns overhang the half-year; those days are drawn in the other
    // strip, so here they're left as empty space.
    final outside = day.isBefore(strip.start) || day.isAfter(strip.end);

    return Padding(
      padding: EdgeInsets.only(bottom: metrics.gap),
      child: SizedBox(
        width: metrics.cell,
        height: metrics.cell,
        child: outside
            ? null
            : DecoratedBox(
                decoration: BoxDecoration(
                  color: _cellColor(theme, widget.dailyCounts[day] ?? 0),
                  borderRadius: BorderRadius.circular(
                    (metrics.cell / 4).clamp(1.0, 3.0),
                  ),
                  border: _selectedDay == day
                      ? Border.all(color: theme.colorScheme.onSurface, width: 1)
                      : null,
                ),
              ),
      ),
    );
  }

  Widget _buildLegend(ThemeData theme) {
    final style = theme.textTheme.labelSmall?.copyWith(
      fontSize: 9,
      color: theme.colorScheme.onSurface.withAlpha(120),
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text('Less', style: style),
        const SizedBox(width: 4),
        for (final count in [0, 1, 2, 3, 4])
          Padding(
            padding: const EdgeInsets.only(right: 3),
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: _cellColor(theme, count),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        const SizedBox(width: 1),
        Text('More', style: style),
      ],
    );
  }
}
