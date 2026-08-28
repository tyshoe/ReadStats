import 'package:flutter/material.dart';

/// One bucket of the strip: what it's called and the total behind it.
class HabitBar {
  final String label;
  final int value;

  const HabitBar(this.label, this.value);
}

/// A short strip of bars for the "when do you read" charts.
///
/// Not [BarChartWidget]: that one is built around periods — it injects the
/// twelve months whenever a year is selected, and carries a cumulative line
/// that means nothing across a fixed handful of buckets. Here the buckets are
/// the days of the week, or the parts of a day, in a fixed order.
///
/// The largest bar is drawn in full colour and the rest are muted, so the
/// answer to "when do I read most" survives a glance at a phone-width chart.
class HabitBarChart extends StatelessWidget {
  final String title;
  final List<HabitBar> bars;
  final Color color;

  /// Formats a bar's total for the small label above it. Kept short — a
  /// weekday column is about forty pixels wide.
  final String Function(int) valueFormatter;

  /// Shown in place of the bars when every bucket is empty.
  final String emptyMessage;

  const HabitBarChart({
    super.key,
    required this.title,
    required this.bars,
    required this.color,
    required this.valueFormatter,
    required this.emptyMessage,
  });

  static const double _maxBarHeight = 90;
  // Matches the fl_chart charts above, so switching the year filter moves the
  // whole page at one speed.
  static const Duration _animationDuration = Duration(milliseconds: 400);
  static const Curve _animationCurve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxValue = bars.fold<int>(0, (m, b) => b.value > m ? b.value : m);

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (maxValue == 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: Text(
                    emptyMessage,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(120),
                    ),
                  ),
                ),
              )
            else
              Row(
                // Bottom-aligned so the bars share a baseline and the labels
                // under them line up whatever height the bars come out at.
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final bar in bars)
                    Expanded(child: _buildBar(theme, bar, maxValue)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBar(ThemeData theme, HabitBar bar, int maxValue) {
    final isPeak = bar.value == maxValue;
    final muted = theme.colorScheme.onSurface.withAlpha(120);
    // An empty bucket keeps a sliver of track so the row still reads as seven
    // days; anything logged gets at least 4px, or a ten-minute Tuesday beside
    // a six-hour Sunday would round away to nothing.
    final height = bar.value == 0
        ? 3.0
        : (_maxBarHeight * bar.value / maxValue).clamp(4.0, _maxBarHeight);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Fixed height, and scaled down rather than wrapped: the totals read
          // as one row across the top of the chart, and — with the fixed track
          // below — nothing in the column changes height while the bars are
          // animating, so the card can't breathe as the year filter swaps.
          SizedBox(
            height: 16,
            child: bar.value == 0
                ? const SizedBox.shrink()
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      valueFormatter(bar.value),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isPeak ? theme.colorScheme.onSurface : muted,
                        fontWeight: isPeak ? FontWeight.bold : null,
                      ),
                      maxLines: 1,
                    ),
                  ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: _maxBarHeight,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedContainer(
                duration: _animationDuration,
                curve: _animationCurve,
                height: height,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: bar.value == 0
                      ? theme.colorScheme.surfaceContainerHighest
                      : (isPeak ? color : color.withValues(alpha: 0.35)),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            bar.label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: isPeak ? theme.colorScheme.onSurface : muted,
              fontWeight: isPeak ? FontWeight.bold : null,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
