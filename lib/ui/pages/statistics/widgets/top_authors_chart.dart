import 'package:flutter/material.dart';

/// Ranked list of the authors with the most finished books. Each entry must
/// have 'name' (String) and 'book_count' (int); data is expected pre-sorted
/// descending and already trimmed to the top N by the caller.
class TopAuthorsChart extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> data;

  const TopAuthorsChart({super.key, required this.title, required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.primaryColor;

    final maxCount = data.isEmpty
        ? 0
        : data
            .map((e) => e['book_count'] as int)
            .reduce((a, b) => a > b ? a : b);

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
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (data.isEmpty)
              Center(
                child: Text(
                  'No data available',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.hintColor),
                ),
              )
            else
              for (int i = 0; i < data.length; i++)
                Padding(
                  padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
                  child: _AuthorRow(
                    rank: i + 1,
                    name: data[i]['name'] as String,
                    count: data[i]['book_count'] as int,
                    maxCount: maxCount,
                    color: primary,
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _AuthorRow extends StatelessWidget {
  final int rank;
  final String name;
  final int count;
  final int maxCount;
  final Color color;

  const _AuthorRow({
    required this.rank,
    required this.name,
    required this.count,
    required this.maxCount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = maxCount == 0 ? 0.0 : count / maxCount;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 16,
          child: Text(
            '$rank',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(120),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$count',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                // Animate the fill from its previous value to the new one when
                // the year filter changes, matching the 400ms easeOutCubic
                // tween the fl_chart bar charts use.
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: fraction),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => LinearProgressIndicator(
                    value: value,
                    minHeight: 6,
                    backgroundColor: color.withAlpha(28),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
