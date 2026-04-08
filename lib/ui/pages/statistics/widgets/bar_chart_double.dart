import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CombinedBarChartWidget extends StatefulWidget {
  final Map<String, Map<String, int>> data;
  final int selectedYear;

  const CombinedBarChartWidget({
    super.key,
    required this.data,
    required this.selectedYear,
  });

  @override
  State<CombinedBarChartWidget> createState() => _CombinedBarChartWidgetState();
}

class _CombinedBarChartWidgetState extends State<CombinedBarChartWidget> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    const monthOrder = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    Map<String, Map<String, int>> displayData = Map.from(widget.data);
    List<String> keys;

    if (widget.selectedYear != 0) {
      for (final month in monthOrder) {
        displayData.putIfAbsent(month, () => {'books': 0, 'sessions': 0});
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

    final valuesBooks = keys.map((k) => displayData[k]?['books'] ?? 0).toList();
    final valuesSessions = keys.map((k) => displayData[k]?['sessions'] ?? 0).toList();

    final maxBooks = valuesBooks.isEmpty ? 0 : valuesBooks.reduce(max);
    final maxSessions = valuesSessions.isEmpty ? 0 : valuesSessions.reduce(max);
    final maxValue = max(maxBooks, maxSessions);

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 220,
        child: keys.isEmpty
            ? Center(
                child: Text(
                  'No data available',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).hintColor,
                      ),
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final chartWidth = max(constraints.maxWidth, keys.length * 28.0);
                        final barWidth = (chartWidth / keys.length * 0.28).clamp(6.0, 16.0);
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: chartWidth,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: BarChart(
                                key: ValueKey('combined_chart_${widget.selectedYear}_${keys.length}'),
                                BarChartData(
                                  alignment: BarChartAlignment.spaceAround,
                                  maxY: maxValue == 0 ? 10 : (maxValue * 1.3).toDouble(),
                                  barTouchData: BarTouchData(
                                    enabled: true,
                                    touchCallback: (event, response) {
                                      setState(() {
                                        if (event is FlTapUpEvent || event is FlLongPressEnd) {
                                          _touchedIndex = -1;
                                        } else {
                                          _touchedIndex = response?.spot?.touchedBarGroupIndex ?? -1;
                                        }
                                      });
                                    },
                                    touchTooltipData: BarTouchTooltipData(
                                      getTooltipColor: (_) => Colors.transparent,
                                      tooltipPadding: EdgeInsets.zero,
                                      tooltipMargin: 8,
                                      fitInsideHorizontally: true,
                                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                        if (group.x != _touchedIndex) return null;
                                        return BarTooltipItem(
                                          NumberFormat('#,###').format(rod.toY.toInt()),
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
                                    final key = keys[i];
                                    final booksValue = displayData[key]?['books'] ?? 0;
                                    final sessionsValue = displayData[key]?['sessions'] ?? 0;
                                    return BarChartGroupData(
                                      x: i,
                                      barsSpace: 4,
                                      barRods: [
                                        BarChartRodData(
                                          toY: booksValue.toDouble(),
                                          color: Theme.of(context).primaryColor,
                                          width: barWidth,
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(4),
                                            topRight: Radius.circular(4),
                                          ),
                                        ),
                                        BarChartRodData(
                                          toY: sessionsValue.toDouble(),
                                          color: Theme.of(context).primaryColor.withAlpha(100),
                                          width: barWidth,
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(4),
                                            topRight: Radius.circular(4),
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
                                          final label = i == _touchedIndex
                                              ? keys[i]
                                              : keys[i][0];
                                          return Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: Text(
                                              label,
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
                                  groupsSpace: 12,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildLegendItem(
                          context: context,
                          color: Theme.of(context).primaryColor,
                          label: 'Books',
                        ),
                        const SizedBox(width: 16),
                        _buildLegendItem(
                          context: context,
                          color: Theme.of(context).primaryColor.withAlpha(100),
                          label: 'Sessions',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildLegendItem({
    required BuildContext context,
    required Color color,
    required String label,
  }) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
