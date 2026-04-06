import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class PieBreakdownWidget extends StatelessWidget {
  /// Each entry must have 'name' (String) and 'book_count' (int).
  final List<Map<String, dynamic>> data;

  final String title;

  /// Optional icons shown in the legend, keyed by the entry's name.
  final Map<String, IconData>? icons;

  /// Optional color overrides keyed by entry name. Falls back to palette.
  final Map<String, Color>? colors;

  /// When true, data is sorted by count descending for the legend.
  final bool sortByCount;

  const PieBreakdownWidget({super.key, required this.title, required this.data, this.icons, this.colors, this.sortByCount = false});

  static List<Color> _palette(Color primary) => [
    primary,
    primary.withAlpha(200),
    primary.withAlpha(160),
    primary.withAlpha(120),
    primary.withAlpha(80),
    primary.withAlpha(40),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final displayData = sortByCount
        ? ([...data]..sort((a, b) =>
            (b['book_count'] as int).compareTo(a['book_count'] as int)))
        : data;

    final total = displayData.fold<int>(0, (sum, e) => sum + (e['book_count'] as int));

    final palette = _palette(theme.primaryColor);
    Color colorFor(int dataIndex) {
      final name = displayData[dataIndex]['name'] as String;
      return colors?[name] ?? palette[dataIndex % palette.length];
    }

    // Pie slices sorted ascending (smallest right, largest left).
    final sectionIndices = <int>[];
    for (int i = 0; i < displayData.length; i++) {
      if ((displayData[i]['book_count'] as int) > 0) sectionIndices.add(i);
    }
    sectionIndices.sort((a, b) =>
        (displayData[a]['book_count'] as int)
            .compareTo(displayData[b]['book_count'] as int));

    return Container(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: total == 0
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'No data available',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                  ),
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      for (int i = 0; i < displayData.length; i++)
                        Padding(
                          padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: colorFor(i),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (icons != null &&
                                  icons!.containsKey(displayData[i]['name'])) ...[
                                Icon(
                                  icons![displayData[i]['name']],
                                  size: 14,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                              ],
                              Expanded(
                                child: Text(
                                  displayData[i]['name'] as String,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                              Text(
                                '${displayData[i]['book_count']} (${((displayData[i]['book_count'] as int) * 100 / total).round()}%)',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                SizedBox(
                  width: 120,
                  height: 120,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 0,
                      startDegreeOffset: -90,
                      pieTouchData: PieTouchData(enabled: false),
                      sections: [
                        for (int i = 0; i < sectionIndices.length; i++)
                          PieChartSectionData(
                            value: (displayData[sectionIndices[i]]['book_count'] as int).toDouble(),
                            color: colorFor(sectionIndices[i]),
                            radius: 60,
                            titlePositionPercentageOffset: 0.75,
                            showTitle: (displayData[sectionIndices[i]]['book_count'] as int) * 100 / total >= 10,
                            title: '${((displayData[sectionIndices[i]]['book_count'] as int) * 100 / total).round()}%',
                            titleStyle: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
