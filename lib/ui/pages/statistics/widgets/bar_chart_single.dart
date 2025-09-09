import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BarChartWidget extends StatelessWidget {
  final Map<String, int> data;
  final int selectedYear;
  final Color barColor;
  final String Function(int)? tooltipFormatter; // optional custom formatting

  const BarChartWidget({
    super.key,
    required this.data,
    required this.selectedYear,
    required this.barColor,
    this.tooltipFormatter,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    List<String> keys = data.keys.toList();

    // Month ordering if yearly view
    if (selectedYear != 0) {
      const monthOrder = [
        'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'
      ];
      final monthIndexMap = {for (var i=0; i<monthOrder.length; i++) monthOrder[i]: i};
      keys.sort((a, b) {
        final indexA = monthIndexMap[a] ?? 99;
        final indexB = monthIndexMap[b] ?? 99;
        return indexA.compareTo(indexB);
      });
    }

    final values = keys.map((k) => data[k] ?? 0).toList();
    final maxValue = values.isEmpty ? 0 : values.reduce(max);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SizedBox(
        height: 280,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: max(400, keys.length * 70).toDouble(),
            child: BarChart(
              key: ValueKey('chart_${selectedYear}_${keys.length}'),
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: (maxValue * 1.3).toDouble(),
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => Colors.transparent,
                    tooltipPadding: EdgeInsets.zero,
                    tooltipMargin: 8,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final formatted = tooltipFormatter != null
                          ? tooltipFormatter!(rod.toY.toInt())
                          : NumberFormat('#,###').format(rod.toY.toInt());
                      return BarTooltipItem(
                        formatted,
                        TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ),
                barGroups: List.generate(keys.length, (i) {
                  final rods = [
                    BarChartRodData(
                      toY: values[i].toDouble(),
                      color: barColor,
                      width: 36,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(6),
                        topRight: Radius.circular(6),
                      ),
                    ),
                  ];
                  return BarChartGroupData(
                    x: i,
                    barRods: rods,
                    showingTooltipIndicators: rods.isNotEmpty ? [0] : [],
                  );
                }),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() < 0 || value.toInt() >= keys.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            keys[value.toInt()],
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(show: false),
                borderData: FlBorderData(show: false),
                backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
