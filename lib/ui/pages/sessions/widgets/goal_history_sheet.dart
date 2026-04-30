import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '/data/models/goal.dart';

class GoalHistoryChart extends StatefulWidget {
  final List<PeriodProgress> periods;
  final Color accentColor;
  final GoalPeriod goalPeriod;
  final GoalMetric goalMetric;

  const GoalHistoryChart({
    super.key,
    required this.periods,
    required this.accentColor,
    required this.goalPeriod,
    required this.goalMetric,
  });

  static const double chartHeight = 130.0;
  static const double dotRadius = 5.0;
  static const double vPad = dotRadius + 4;

  @override
  State<GoalHistoryChart> createState() => _GoalHistoryChartState();
}

class _GoalHistoryChartState extends State<GoalHistoryChart> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex =
        widget.periods.isNotEmpty ? widget.periods.length - 1 : 0;
  }

  int get _maxVal {
    int max = 1;
    for (final p in widget.periods) {
      if (p.hasGoal && p.target > max) max = p.target;
      if (p.actual > max) max = p.actual;
    }
    return max;
  }

  double _yFor(int value, int maxVal) {
    const usable = GoalHistoryChart.chartHeight - GoalHistoryChart.vPad * 2;
    return GoalHistoryChart.vPad +
        (1.0 - value.clamp(0, maxVal) / maxVal) * usable;
  }

  String _shortLabel(PeriodProgress p) => switch (widget.goalPeriod) {
        GoalPeriod.weekly =>
          '${p.periodStart.day}\n${DateFormat('MMM').format(p.periodStart)}',
        GoalPeriod.monthly => DateFormat('MMM').format(p.periodStart),
        GoalPeriod.yearly => p.periodStart.year.toString(),
      };

  String _fullLabel(PeriodProgress p) => switch (widget.goalPeriod) {
        GoalPeriod.weekly =>
          '${DateFormat('MMM d').format(p.periodStart)} – ${DateFormat('MMM d').format(p.periodEnd)}',
        GoalPeriod.monthly => DateFormat('MMMM yyyy').format(p.periodStart),
        GoalPeriod.yearly => p.periodStart.year.toString(),
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxVal = _maxVal;
    final periods = widget.periods;
    final accent = widget.accentColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDetail(theme),
        const SizedBox(height: 8),
        Container(
          height: GoalHistoryChart.chartHeight,
          decoration: BoxDecoration(
            border: Border.all(
              color: theme.colorScheme.onSurface.withOpacity(0.08),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int i = 0; i < periods.length; i++)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedIndex = i),
                      behavior: HitTestBehavior.opaque,
                      child: _Column(
                        progress: periods[i],
                        maxVal: maxVal,
                        accentColor: accent,
                        isCurrent: i == periods.length - 1,
                        isSelected: _selectedIndex == i,
                        yFor: _yFor,
                        theme: theme,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (int i = 0; i < periods.length; i++)
              Expanded(
                child: Text(
                  _shortLabel(periods[i]),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 9,
                    height: 1.3,
                    fontWeight: i == _selectedIndex
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: i == _selectedIndex
                        ? accent.withOpacity(0.85)
                        : i == periods.length - 1
                            ? theme.colorScheme.onSurface.withOpacity(0.8)
                            : theme.colorScheme.onSurface.withOpacity(0.45),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _LegendDot(filled: true, color: accent.withOpacity(0.75)),
            const SizedBox(width: 4),
            Text('Actual',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                )),
            const SizedBox(width: 10),
            _LegendDot(
                filled: true,
                color: theme.colorScheme.onSurface.withOpacity(0.3)),
            const SizedBox(width: 4),
            Text('Target',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                )),
          ],
        ),
      ],
    );
  }

  Widget _buildDetail(ThemeData theme) {
    final p = widget.periods[_selectedIndex];
    final accent = widget.accentColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                widget.goalMetric.cardDisplay(p.actual),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              if (p.hasGoal) ...[
                const SizedBox(width: 4),
                Text(
                  '/ ${widget.goalMetric.cardDisplay(p.target)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.45),
                  ),
                ),
              ],
            ],
          ),
          Text(
            _fullLabel(p),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final bool filled;
  final Color color;

  const _LegendDot({required this.filled, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? color : Colors.transparent,
        border: filled ? null : Border.all(color: color, width: 1.5),
      ),
    );
  }
}

class _Column extends StatelessWidget {
  final PeriodProgress progress;
  final int maxVal;
  final Color accentColor;
  final bool isCurrent;
  final bool isSelected;
  final double Function(int value, int maxVal) yFor;
  final ThemeData theme;

  const _Column({
    required this.progress,
    required this.maxVal,
    required this.accentColor,
    required this.isCurrent,
    required this.isSelected,
    required this.yFor,
    required this.theme,
  });

  static const double _r = GoalHistoryChart.dotRadius;

  @override
  Widget build(BuildContext context) {
    final targetY = yFor(progress.target, maxVal);
    final actualY = yFor(progress.actual, maxVal);
    final met = progress.met;

    final dotSize = isSelected ? _r * 2 + 2 : _r * 2;
    final actualColor =
        met ? accentColor.withOpacity(0.75) : accentColor.withOpacity(0.4);
    final targetColor = theme.colorScheme.onSurface.withOpacity(0.3);
    final lineColor = theme.colorScheme.onSurface.withOpacity(0.15);

    final topY = math.min(targetY, actualY);
    final lineHeight = math.max((targetY - actualY).abs() - _r * 2, 0.0);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (isSelected)
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        if (progress.hasGoal && lineHeight > 0)
          Positioned(
            left: 0,
            right: 0,
            top: topY + _r,
            height: lineHeight,
            child: Center(
              child: Container(width: 1.5, color: lineColor),
            ),
          ),
        if (progress.hasGoal)
          Positioned(
            left: 0,
            right: 0,
            top: targetY - dotSize / 2,
            child: Center(
              child: Container(
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: targetColor,
                ),
              ),
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          top: actualY - dotSize / 2,
          child: Center(
            child: Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: actualColor,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
