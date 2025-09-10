import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CombinedBarChartWidget extends StatelessWidget {
  final Map<String, Map<String, int>> data;
  final int selectedYear;

  const CombinedBarChartWidget({
    super.key,
    required this.data,
    required this.selectedYear,
  });

  @override
  Widget build(BuildContext context) {
    // Keep layout stable: even with no data, render an "empty" chart
    final keys = data.keys.toList();

    final valuesBooks = keys.map((k) => data[k]?['books'] ?? 0).toList();
    final valuesSessions = keys.map((k) => data[k]?['sessions'] ?? 0).toList();

    final maxBooks = valuesBooks.isEmpty ? 0 : valuesBooks.reduce(max);
    final maxSessions = valuesSessions.isEmpty ? 0 : valuesSessions.reduce(max);
    final maxValue = max(maxBooks, maxSessions);

    final screenWidth = MediaQuery.of(context).size.width;
    const horizontalPadding = 32.0;
    final minChartWidth = screenWidth - horizontalPadding;
    final chartWidth = max(minChartWidth, keys.length * 70).toDouble();

    return SizedBox(
      height: 320, // taller to fit legend
      child: Stack(
        children: [
          // Rounded background
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
            ),
          ),

          // Chart + Legend stacked on top
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: chartWidth,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: BarChart(
                        key: ValueKey('combined_chart_${selectedYear}_${keys.length}'),
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: maxValue == 0 ? 10 : (maxValue * 1.3).toDouble(),
                          barTouchData: BarTouchData(
                            enabled: true,
                            touchTooltipData: BarTouchTooltipData(
                              getTooltipColor: (_) => Colors.transparent,
                              tooltipPadding: EdgeInsets.zero,
                              tooltipMargin: 8,
                              getTooltipItem: (
                                BarChartGroupData group,
                                int groupIndex,
                                BarChartRodData rod,
                                int rodIndex,
                              ) {
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
                            final booksValue = data[key]?['books'] ?? 0;
                            final sessionsValue = data[key]?['sessions'] ?? 0;

                            return BarChartGroupData(
                              x: i,
                              barsSpace: 6,
                              barRods: [
                                BarChartRodData(
                                  toY: booksValue.toDouble(),
                                  color: Theme.of(context).primaryColor,
                                  width: 16,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(6),
                                    topRight: Radius.circular(6),
                                  ),
                                ),
                                BarChartRodData(
                                  toY: sessionsValue.toDouble(),
                                  color: Theme.of(context).primaryColor.withAlpha(100),
                                  width: 16,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(6),
                                    topRight: Radius.circular(6),
                                  ),
                                ),
                              ],
                              showingTooltipIndicators: [0, 1],
                            );
                          }),
                          titlesData: FlTitlesData(
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: 1,
                                getTitlesWidget: (value, meta) {
                                  if (value.toInt() < 0 || value.toInt() >= keys.length) {
                                    return const SizedBox.shrink();
                                  }
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
                            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles:
                                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          gridData: FlGridData(show: false),
                          borderData: FlBorderData(show: false),
                          groupsSpace: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Legend
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
        ],
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
