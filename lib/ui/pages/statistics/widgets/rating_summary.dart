import 'dart:math';

import 'package:flutter/material.dart';

class RatingSummary extends StatelessWidget {
  final Future<Map<double, int>> ratingDataFuture;
  final int selectedYear;

  const RatingSummary({
    super.key,
    required this.ratingDataFuture,
    required this.selectedYear,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<double, int>>(
      future: ratingDataFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final ratingData = snapshot.data!;

        // Round ratings to nearest whole number 1-5
        Map<int, int> histogram = {for (int i = 1; i <= 5; i++) i: 0};
        ratingData.forEach((rating, count) {
          int star = rating.round().clamp(1, 5);
          histogram[star] = (histogram[star] ?? 0) + count;
        });

        final totalRatings = histogram.values.reduce((a, b) => a + b);
        final maxCount = histogram.values.reduce(max);

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Overall rating summary
              if (totalRatings > 0) ...[
                Row(
                  children: [
                    Text(
                      (ratingData.entries.map((e) => e.key * e.value).reduce((a, b) => a + b) / totalRatings).toStringAsFixed(1),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '($totalRatings ratings)',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              // Rating bars (5 → 1)
              Column(
                children: List.generate(5, (i) {
                  int star = 5 - i; // Top → bottom
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
                              // Background bar
                              Container(
                                height: 12,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceVariant,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              // Filled bar
                              Container(
                                height: 12,
                                width: MediaQuery.of(context).size.width * 0.6 * percent,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Count and percentage
                        SizedBox(
                          width: 60,
                          child: Text(
                            '$count (${totalRatings > 0 ? (count / totalRatings * 100).round() : 0}%)',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
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
      },
    );
  }
}