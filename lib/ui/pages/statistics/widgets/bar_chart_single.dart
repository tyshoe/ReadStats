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
  });

  @override
  State<BarChartWidget> createState() => _BarChartWidgetState();
}

class _BarChartWidgetState extends State<BarChartWidget> {
  int _touchedIndex = -1;
  int _pendingIndex = -1;

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
            child: keys.isEmpty
                ? Center(
                    child: Text(
                      'No data available',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).hintColor,
                          ),
                    ),
                  )
                : LayoutBuilder(
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
                  ),
          ),
        ],
      ),
    );
  }
}
