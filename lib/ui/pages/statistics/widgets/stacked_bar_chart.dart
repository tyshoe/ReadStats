import 'package:flutter/material.dart';

class StackedBarChartWidget extends StatelessWidget {
  /// Each entry must have 'name' (String) and 'book_count' (int).
  final List<Map<String, dynamic>> data;
  final String title;
  final Map<String, Color>? colors;

  const StackedBarChartWidget({
    super.key,
    required this.title,
    required this.data,
    this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.primaryColor;
    final palette = [
      primary,
      primary.withAlpha(200),
      primary.withAlpha(160),
      primary.withAlpha(120),
      primary.withAlpha(80),
      primary.withAlpha(40),
    ];
    Color colorFor(int index, String name) =>
        colors?[name] ?? palette[index % palette.length];
    final total = data.fold<int>(0, (sum, e) => sum + (e['book_count'] as int));

    final segments = [
      for (int i = 0; i < data.length; i++)
        if ((data[i]['book_count'] as int) > 0) i,
    ];

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (total == 0)
            Center(
              child: Text(
                'No data available',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
              ),
            )
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 28,
                child: Row(
                  children: [
                    for (final i in segments)
                      Flexible(
                        flex: data[i]['book_count'] as int,
                        child: Container(
                          color: colorFor(i, data[i]['name'] as String),
                          child: Center(
                            child: (data[i]['book_count'] as int) * 100 / total >= 10
                                ? Text(
                                    '${((data[i]['book_count'] as int) * 100 / total).round()}%',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (final col in [0, 1])
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (int i = col; i < data.length; i += 2)
                          Padding(
                            padding: EdgeInsets.only(top: i <= 1 ? 0 : 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: colorFor(i, data[i]['name'] as String),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '${data[i]['name']}  ${data[i]['book_count']} (${((data[i]['book_count'] as int) * 100 / total).round()}%)',
                                    style: theme.textTheme.bodySmall,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
      ),
    );
  }
}
