import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BarChartWidget extends StatefulWidget {
  final Map<String, int> data;
  final int selectedYear;
  final Color barColor;
  final String? title;
  final String? subtitleValue;
  final String? averageValue;
  final String? averageLabel;
  final String Function(int)? tooltipFormatter;
  final String Function(int)? shortFormatter;

  /// When true, render a running-total line instead of per-period bars.
  final bool cumulative;

  /// Per-day totals (keyed by midnight DateTime) used to draw the cumulative
  /// line at daily resolution. Required when [cumulative] is true.
  final Map<DateTime, int>? dailyData;

  const BarChartWidget({
    super.key,
    required this.data,
    required this.selectedYear,
    required this.barColor,
    this.title,
    this.subtitleValue,
    this.averageValue,
    this.averageLabel,
    this.tooltipFormatter,
    this.shortFormatter,
    this.cumulative = false,
    this.dailyData,
  });

  @override
  State<BarChartWidget> createState() => _BarChartWidgetState();
}

class _BarChartWidgetState extends State<BarChartWidget> {
  int _touchedIndex = -1;
  int _pendingIndex = -1;

  // Cumulative line: which spot's tooltip is pinned (survives finger-up), and
  // the spot captured on touch-down that gets committed on release.
  int _touchedLineIndex = -1;
  int _pendingLineIndex = -1;

  @override
  Widget build(BuildContext context) {
    const monthOrder = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    Map<String, int> displayData = Map.from(widget.data);
    List<String> keys;

    if (widget.selectedYear != 0) {
      for (final month in monthOrder) {
        displayData.putIfAbsent(month, () => 0);
      }
      final monthIndexMap = {for (var i = 0; i < monthOrder.length; i++) monthOrder[i]: i};
      keys = displayData.keys.toList()
        ..sort((a, b) {
          final indexA = monthIndexMap[a] ?? 99;
          final indexB = monthIndexMap[b] ?? 99;
          return indexA.compareTo(indexB);
        });
    } else {
      keys = displayData.keys.toList();
    }

    final maxVal = displayData.isEmpty ? 0 : displayData.values.reduce(max);

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Text(
                widget.title!,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          if (widget.subtitleValue != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withAlpha(120),
                            ),
                      ),
                      Text(
                        widget.subtitleValue!,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w300,
                            ),
                      ),
                    ],
                  ),
                  if (widget.averageValue != null) ...[
                    const SizedBox(width: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.averageLabel ?? 'Avg',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withAlpha(120),
                              ),
                        ),
                        Text(
                          widget.averageValue!,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w300,
                              ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          SizedBox(
            height: 200,
            child: (widget.cumulative
                    ? (widget.dailyData?.isEmpty ?? true)
                    : keys.isEmpty)
                ? Center(
                    child: Text(
                      'No data available',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).hintColor,
                          ),
                    ),
                  )
                : widget.cumulative
                    ? _buildLine(context)
                    : _buildBars(context, keys, displayData, maxVal),
          ),
        ],
      ),
    );
  }

  Widget _buildBars(
    BuildContext context,
    List<String> keys,
    Map<String, int> displayData,
    int maxVal,
  ) {
    return LayoutBuilder(
                    builder: (context, constraints) {
                      final chartWidth = max(constraints.maxWidth, keys.length * 28.0);
                      final barWidth = (chartWidth / keys.length * 0.80).clamp(12.0, 36.0);
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: chartWidth,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: BarChart(
                              key: ValueKey('chart_${widget.selectedYear}_${keys.length}'),
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeOutCubic,
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                maxY: (maxVal * 1.4).toDouble(),
                                barTouchData: BarTouchData(
                                  enabled: true,
                                  touchCallback: (event, response) {
                                    if (event is FlTapDownEvent || event is FlLongPressStart) {
                                      _pendingIndex = response?.spot?.touchedBarGroupIndex ?? -1;
                                    } else if (event is FlTapUpEvent || event is FlLongPressEnd) {
                                      setState(() {
                                        if (_pendingIndex == -1) {
                                          _touchedIndex = -1;
                                        } else {
                                          _touchedIndex = (_pendingIndex == _touchedIndex)
                                              ? -1
                                              : _pendingIndex;
                                        }
                                        _pendingIndex = -1;
                                      });
                                    }
                                  },
                                  touchTooltipData: BarTouchTooltipData(
                                    getTooltipColor: (_) => Colors.transparent,
                                    tooltipPadding: EdgeInsets.zero,
                                    tooltipMargin: 4,
                                    fitInsideHorizontally: true,
                                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                      final value = rod.toY.toInt();
                                      if (value == 0) return null;
                                      final isTouched = group.x == _touchedIndex;
                                      final formatter = isTouched
                                          ? (widget.tooltipFormatter ?? widget.shortFormatter)
                                          : widget.shortFormatter ?? widget.tooltipFormatter;
                                      final formatted = formatter != null
                                          ? formatter(value)
                                          : NumberFormat('#,###').format(value);
                                      return BarTooltipItem(
                                        formatted,
                                        TextStyle(
                                          color: Theme.of(context).colorScheme.onSurface.withAlpha(
                                                isTouched ? 255 : 160,
                                              ),
                                          fontWeight: isTouched ? FontWeight.bold : FontWeight.normal,
                                          fontSize: isTouched ? 12 : 10,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                barGroups: List.generate(keys.length, (i) {
                                  final key = keys[i];
                                  final value = displayData[key] ?? 0;
                                  final isTouched = i == _touchedIndex;
                                  return BarChartGroupData(
                                    x: i,
                                    showingTooltipIndicators: [0],
                                    barRods: [
                                      BarChartRodData(
                                        toY: value.toDouble(),
                                        color: isTouched
                                            ? widget.barColor
                                            : widget.barColor.withAlpha(180),
                                        width: barWidth,
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(6),
                                          topRight: Radius.circular(6),
                                        ),
                                      ),
                                    ],
                                  );
                                }),
                                titlesData: FlTitlesData(
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      interval: 1,
                                      getTitlesWidget: (value, meta) {
                                        final i = value.toInt();
                                        if (i < 0 || i >= keys.length) {
                                          return const SizedBox.shrink();
                                        }
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Text(
                                            keys[i],
                                            style: Theme.of(context).textTheme.bodySmall,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                ),
                                gridData: FlGridData(show: false),
                                borderData: FlBorderData(show: false),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
  }

  Widget _buildLine(BuildContext context) {
    final theme = Theme.of(context);

    // Daily totals sorted chronologically. Plotting by real date offset (not
    // index) is what makes a burst of activity read as a steep climb.
    final entries = widget.dailyData!.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    // Domain: a selected year spans Jan 1 → its end so clusters show against the
    // whole year; "All" spans the first → last day with activity. For the
    // current year the right edge is today, not a future Dec 31.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final DateTime start = widget.selectedYear != 0
        ? DateTime(widget.selectedYear, 1, 1)
        : entries.first.key;
    final DateTime end = widget.selectedYear != 0
        ? (widget.selectedYear == now.year
            ? today
            : DateTime(widget.selectedYear, 12, 31))
        : entries.last.key;
    double offsetOf(DateTime d) => d.difference(start).inDays.toDouble();
    final maxOffset = max(offsetOf(end), 1.0);

    // Step curve: hold flat until an active day, then jump. Anchored at both
    // ends so the line spans the full domain.
    final spots = <FlSpot>[const FlSpot(0, 0)];
    double running = 0;
    for (final e in entries) {
      final x = offsetOf(e.key).clamp(0.0, maxOffset);
      spots.add(FlSpot(x, running));
      running += e.value;
      spots.add(FlSpot(x, running));
    }
    spots.add(FlSpot(maxOffset, running));
    final maxCum = running;

    String formatValue(int v) {
      final formatter = widget.tooltipFormatter ?? widget.shortFormatter;
      return formatter != null ? formatter(v) : NumberFormat('#,###').format(v);
    }

    // A few rough reference ticks rather than every date: ~6 across a year
    // (labelled by month). Across the "All" range, one tick per year — but with
    // many years those labels collide, so widen the step to every Nth year
    // (~6 labels max) so they don't pack together.
    final double bottomInterval;
    if (widget.selectedYear != 0) {
      bottomInterval = (maxOffset / 6).clamp(1.0, double.infinity);
    } else if (maxOffset >= 366) {
      // Step by the average calendar-year length so each tick lands at the same
      // point in its year (a whole 365-day step drifts backward and bunches the
      // last labels, e.g. a 2026 tick landing on 2025-12-29).
      const yearDays = 365.25;
      final years = maxOffset / yearDays;
      final yearStep = (years / 6).ceil().clamp(1, years.ceil());
      bottomInterval = yearDays * yearStep;
    } else {
      bottomInterval = (maxOffset / 4).clamp(1.0, double.infinity);
    }

    // Keep the pinned spot in range if the data changed under it (e.g. the year
    // toggle rebuilt the line with fewer spots).
    final pinnedIndex =
        (_touchedLineIndex >= 0 && _touchedLineIndex < spots.length)
            ? _touchedLineIndex
            : -1;

    final lineBar = LineChartBarData(
      spots: spots,
      isCurved: false,
      color: widget.barColor,
      barWidth: 2.5,
      dotData: const FlDotData(show: false),
      // Mark the pinned spot so its dot/indicator stays drawn after release.
      showingIndicators: pinnedIndex >= 0 ? [pinnedIndex] : const [],
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            widget.barColor.withAlpha(64),
            widget.barColor.withAlpha(0),
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 12, 6),
      child: LineChart(
        key: ValueKey('line_${widget.selectedYear}_${spots.length}'),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        LineChartData(
          minX: 0,
          maxX: maxOffset,
          minY: 0,
          maxY: (maxCum * 1.15).clamp(1.0, double.infinity),
          // Pin the touched spot's tooltip so it stays after the finger lifts,
          // matching the bar chart's tap-to-keep behavior.
          showingTooltipIndicators: pinnedIndex >= 0
              ? [
                  ShowingTooltipIndicators([
                    LineBarSpot(lineBar, 0, spots[pinnedIndex]),
                  ]),
                ]
              : const [],
          lineTouchData: LineTouchData(
            // Manage the tooltip ourselves via showingTooltipIndicators; with
            // built-in touches on, fl_chart overwrites that list and clears it
            // on release, so the pinned tooltip would never survive finger-up.
            handleBuiltInTouches: false,
            // Large threshold so a tap anywhere — including a long flat gap
            // between two sparse data points — still resolves to the nearest
            // spot and shows its running total.
            touchSpotThreshold: double.infinity,
            touchCallback: (event, response) {
              final index = response?.lineBarSpots?.first.spotIndex ?? -1;
              if (event is FlTapDownEvent || event is FlLongPressStart) {
                _pendingLineIndex = index;
              } else if (event is FlTapUpEvent || event is FlLongPressEnd) {
                setState(() {
                  if (_pendingLineIndex == -1) {
                    _touchedLineIndex = -1;
                  } else {
                    _touchedLineIndex = (_pendingLineIndex == _touchedLineIndex)
                        ? -1
                        : _pendingLineIndex;
                  }
                  _pendingLineIndex = -1;
                });
              }
            },
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => theme.colorScheme.inverseSurface,
              getTooltipItems: (spots) => spots.map((s) {
                final date = start.add(Duration(days: s.x.round()));
                return LineTooltipItem(
                  '${formatValue(s.y.toInt())}\n',
                  TextStyle(
                    color: theme.colorScheme.onInverseSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  children: [
                    TextSpan(
                      text: DateFormat('MMM d, y').format(date),
                      style: TextStyle(
                        color: theme.colorScheme.onInverseSurface.withAlpha(180),
                        fontWeight: FontWeight.normal,
                        fontSize: 10,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          lineBarsData: [lineBar],
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: bottomInterval,
                // fl_chart otherwise forces an extra tick at the domain's min
                // and max edges, which collides with the last evenly-spaced
                // interval tick (e.g. 2025 and 2026 drawn on top of each other).
                minIncluded: false,
                maxIncluded: false,
                getTitlesWidget: (value, meta) {
                  String labelFor(DateTime d) => widget.selectedYear != 0
                      ? DateFormat('MMM').format(d)
                      : DateFormat('y').format(d);
                  final label =
                      labelFor(start.add(Duration(days: value.round())));

                  // Drop a tick that repeats the previous tick's label so short
                  // ranges don't read "Jan Jan Jan".
                  if (value - bottomInterval >= meta.min - 0.5) {
                    final prev = start
                        .add(Duration(days: (value - bottomInterval).round()));
                    if (labelFor(prev) == label) return const SizedBox.shrink();
                  }

                  // Keep the first/last labels inside the plot: anchor the edge
                  // label's inner edge to the tick instead of centering on it.
                  final range = meta.max - meta.min;
                  final dx = (value - meta.min) < range * 0.1
                      ? 0.5
                      : (meta.max - value) < range * 0.1
                          ? -0.5
                          : 0.0;

                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: FractionalTranslation(
                      translation: Offset(dx, 0),
                      child: Text(
                        label,
                        maxLines: 1,
                        softWrap: false,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(show: false),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }
}
