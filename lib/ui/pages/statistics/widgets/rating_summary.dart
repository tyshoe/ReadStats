import 'dart:math';
import 'package:flutter/material.dart';

class RatingSummaryWidget extends StatelessWidget {
  final Map<double, int> ratingData;
  final int selectedYear;

  const RatingSummaryWidget({
    super.key,
    required this.ratingData,
    required this.selectedYear,
  });

  @override
  Widget build(BuildContext context) {
    // Round ratings into histogram 1–5
    Map<int, int> histogram = {for (int i = 1; i <= 5; i++) i: 0};
    ratingData.forEach((rating, count) {
      int star = rating.round().clamp(1, 5);
      histogram[star] = (histogram[star] ?? 0) + count;
    });

    final totalRatings = histogram.values.fold(0, (a, b) => a + b);
    final maxCount = histogram.values.isEmpty ? 0 : histogram.values.reduce(max);

    // Average rating calculation
    final avgRating = totalRatings > 0
        ? (ratingData.entries.map((e) => e.key * e.value).reduce((a, b) => a + b) / totalRatings)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overall summary
          Row(
            children: [
              Text(
                avgRating.toStringAsFixed(1),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(width: 8),
              Text(
                '($totalRatings ratings)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withAlpha(179),
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Bars (always render, even if empty)
          Column(
            children: List.generate(5, (i) {
              int star = 5 - i; // render 5 → 1
              int count = histogram[star] ?? 0;
              double percent = maxCount > 0 ? count / maxCount : 0;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    // Star label
                    SizedBox(
                      width: 24,
                      child: Text(
                        '$star',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ),

                    // Progress bar
                    Expanded(
                      child: Stack(
                        children: [
                          Container(
                            height: 12,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.inverseSurface.withAlpha(51),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: percent,
                            alignment: Alignment.centerLeft,
                            child: Container(
                              height: 12,
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Count + %
                    SizedBox(
                      width: 60,
                      child: Text(
                        '$count (${totalRatings > 0 ? (count / totalRatings * 100).round() : 0}%)',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withAlpha(204),
                            ),
                        textAlign: TextAlign.left,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
