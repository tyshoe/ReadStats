import 'dart:math';
import 'package:flutter/material.dart';

class RatingSummaryWidget extends StatelessWidget {
  final Map<double, int> ratingData;
  final int selectedYear;
  final String? title;

  const RatingSummaryWidget({
    super.key,
    required this.ratingData,
    required this.selectedYear,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    Map<int, int> histogram = {for (int i = 1; i <= 5; i++) i: 0};
    ratingData.forEach((rating, count) {
      int star = rating.round().clamp(1, 5);
      histogram[star] = (histogram[star] ?? 0) + count;
    });

    final totalRatings = histogram.values.fold(0, (a, b) => a + b);
    final maxCount = histogram.values.isEmpty ? 0 : histogram.values.reduce(max);

    final avgRating = totalRatings > 0
        ? (ratingData.entries.map((e) => e.key * e.value).reduce((a, b) => a + b) / totalRatings)
        : 0.0;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null) ...[
              Text(
                title!,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left: overall summary
                SizedBox(
                  width: 70,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        avgRating.toStringAsFixed(1),
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const Icon(Icons.star_rounded, size: 24, color: Color(0xFFFBCB04)),
                      const SizedBox(height: 4),
                      Text(
                        '$totalRatings ${totalRatings == 1 ? 'rating' : 'ratings'}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                // Right: distribution bars
                Expanded(
                  child: Column(
                    children: List.generate(5, (i) {
                      final star = 5 - i;
                      final count = histogram[star] ?? 0;
                      final percent = maxCount > 0 ? count / maxCount : 0.0;
                      final pct = totalRatings > 0 ? (count / totalRatings * 100).round() : 0;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 16,
                              child: Text(
                                '$star',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Stack(
                                children: [
                                  Container(
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.inverseSurface.withAlpha(51),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0, end: percent),
                                    duration: const Duration(milliseconds: 400),
                                    curve: Curves.easeOutCubic,
                                    builder: (context, value, _) => FractionallySizedBox(
                                      widthFactor: value,
                                      alignment: Alignment.centerLeft,
                                      child: Container(
                                        height: 16,
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).primaryColor,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 52,
                              child: Text(
                                '$count ($pct%)',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
                                    ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
