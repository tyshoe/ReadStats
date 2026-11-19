import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:read_stats/domain/year_wrapped.dart';
import 'package:read_stats/ui/pages/wrapped/slides/wrapped_slide_view.dart';
import 'package:read_stats/ui/pages/wrapped/wrapped_style.dart';

// ── Intro ────────────────────────────────────────────────────────────────────

class IntroSlide extends StatelessWidget {
  final SlideEnv env;
  final WrappedPalette palette;

  const IntroSlide({super.key, required this.env, required this.palette});

  @override
  Widget build(BuildContext context) {
    final w = env.w;
    final a = env.entrance;

    // Lead with books when there are any; a year of sessions without a finish
    // still has its hours, pages or sittings to open on.
    final (int value, String Function(int) format, String label) lead =
        w.booksFinished > 0
            ? (
                w.booksFinished,
                YearWrapped.formatNumber,
                w.booksFinished == 1 ? 'book finished' : 'books finished'
              )
            : w.minutes > 0
                ? (w.minutes, YearWrapped.formatMinutes, 'spent reading')
                : w.displayPages > 0
                    ? (w.displayPages, YearWrapped.formatNumber, 'pages read')
                    : (
                        w.sessions,
                        YearWrapped.formatNumber,
                        w.sessions == 1 ? 'reading session' : 'reading sessions'
                      );

    final opener = w.booksFinished == 0
        ? 'No finish line crossed yet — but the reading still counts.'
        : w.booksFinished == 1
            ? 'One book, start to finish. Let’s look back.'
            : 'Here’s how it all added up.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SlideEyebrow('ReadStats Wrapped', entrance: a),
        const Spacer(flex: 2),
        Reveal(
          animation: a,
          start: 0.05,
          end: 0.45,
          lift: 40,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: ShaderMask(
              shaderCallback: (rect) => LinearGradient(
                colors: [Colors.white, palette.accent],
              ).createShader(rect),
              child: Text('${w.year}',
                  style: WrappedType.hero(context, size: 132)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Reveal(
          animation: a,
          start: 0.15,
          end: 0.55,
          child: Text(
            w.isInProgress
                ? 'Your year in reading,\nso far.'
                : 'Your year\nin reading.',
            style: WrappedType.headline(context, size: 34),
          ),
        ),
        const Spacer(flex: 3),
        Reveal(
          animation: a,
          start: 0.35,
          end: 0.75,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: CountUp(
              animation: a,
              value: lead.$1,
              format: lead.$2,
              start: 0.4,
              end: 0.95,
              style: WrappedType.hero(context, size: 84, color: palette.accent),
            ),
          ),
        ),
        Reveal(
          animation: a,
          start: 0.42,
          end: 0.8,
          child: Text(lead.$3, style: WrappedType.title(context, size: 22)),
        ),
        const SizedBox(height: 14),
        Reveal(
          animation: a,
          start: 0.55,
          end: 0.95,
          child: Text(opener, style: WrappedType.body(context)),
        ),
        const Spacer(flex: 2),
        if (!env.shareMode)
          Reveal(
            animation: a,
            start: 0.75,
            end: 1,
            lift: 8,
            child: Row(
              children: [
                Icon(Icons.touch_app,
                    size: 18, color: Colors.white.withValues(alpha: 0.6)),
                const SizedBox(width: 8),
                Text('Tap to begin', style: WrappedType.caption(context)),
              ],
            ),
          ),
      ],
    );
  }
}

// ── The year in numbers ──────────────────────────────────────────────────────

class NumbersSlide extends StatelessWidget {
  final SlideEnv env;
  final WrappedPalette palette;

  const NumbersSlide({super.key, required this.env, required this.palette});

  @override
  Widget build(BuildContext context) {
    final w = env.w;
    final a = env.entrance;

    final rows = <(int, String Function(int), String)>[
      if (w.minutes > 0)
        (w.minutes, YearWrapped.formatMinutes, 'spent reading'),
      if (w.displayPages > 0)
        (
          w.displayPages,
          YearWrapped.formatNumber,
          w.pagesAreFromBooks ? 'pages across your finished books' : 'pages turned'
        ),
      if (w.sessions > 0)
        (
          w.sessions,
          YearWrapped.formatNumber,
          w.sessions == 1 ? 'reading session' : 'reading sessions'
        ),
      if (w.booksFinished > 0)
        (
          w.booksFinished,
          YearWrapped.formatNumber,
          w.booksFinished == 1 ? 'book finished' : 'books finished'
        ),
    ];

    final rated = w.ratedBooks.length;
    String? footnote;
    if (w.minutes >= 1440) {
      footnote = 'That’s ${(w.minutes / 1440).toStringAsFixed(1)} days of '
          'reading, around the clock.';
    } else if (w.avgSessionMinutes > 0) {
      footnote = 'About ${YearWrapped.formatMinutes(w.avgSessionMinutes)} '
          'every time you sat down.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SlideEyebrow('${w.year} at a glance', entrance: a),
        const SizedBox(height: 14),
        Reveal(
          animation: a,
          start: 0.02,
          end: 0.4,
          child: Text(
              w.minutes > 0
                  ? 'You put in\nthe hours.'
                  : w.displayPages > 0
                      ? 'Page after\npage.'
                      : 'You kept\nshowing up.',
              style: WrappedType.headline(context)),
        ),
        const Spacer(),
        for (var i = 0; i < rows.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Reveal(
              animation: a,
              start: 0.15 + i * 0.1,
              end: 0.55 + i * 0.1,
              lift: 36,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: CountUp(
                      animation: a,
                      value: rows[i].$1,
                      format: rows[i].$2,
                      start: 0.18 + i * 0.1,
                      end: 0.75 + i * 0.05,
                      style: WrappedType.hero(
                        context,
                        size: i == 0 ? 64 : 48,
                        color: i == 0 ? palette.accent : Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(rows[i].$3, style: WrappedType.body(context)),
                ],
              ),
            ),
          ),
        if (rated >= 2)
          Reveal(
            animation: a,
            start: 0.6,
            end: 0.95,
            child: Row(
              children: [
                WrappedStars(rating: w.averageRating, size: 18),
                const SizedBox(width: 8),
                Text(
                  '${w.averageRating.toStringAsFixed(1)} average across '
                  '$rated rated books',
                  style: WrappedType.caption(context, alpha: 0.8),
                ),
              ],
            ),
          ),
        const Spacer(),
        if (footnote != null)
          Reveal(
            animation: a,
            start: 0.7,
            end: 1,
            child: Text(footnote, style: WrappedType.body(context, alpha: 0.9)),
          ),
      ],
    );
  }
}

// ── The year's shape ─────────────────────────────────────────────────────────

class ShapeSlide extends StatelessWidget {
  final SlideEnv env;
  final WrappedPalette palette;

  const ShapeSlide({super.key, required this.env, required this.palette});

  @override
  Widget build(BuildContext context) {
    final w = env.w;
    final a = env.entrance;
    final measure = w.primaryMeasure;
    final values = w.byMonth(measure);
    final peak = w.peakMonth!;
    final quiet = w.quietestMonth;
    final peakValue = values[peak - 1];
    final lastMonth = w.isInProgress ? DateTime.now().month : 12;

    final unit = switch (measure) {
      WrappedMeasure.minutes => 'Reading time',
      WrappedMeasure.pages => 'Pages read',
      WrappedMeasure.sessions => 'Sessions',
      WrappedMeasure.books => 'Books finished',
    };

    String? quietLine;
    if (quiet != null) {
      final q = values[quiet - 1];
      quietLine = q == 0
          ? 'And ${w.monthName(quiet)}? You took it off.'
          : '${w.monthName(quiet)} was the quietest, at '
              '${w.formatMeasure(measure, q)}.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SlideEyebrow('Your reading journey', entrance: a),
        const SizedBox(height: 14),
        Reveal(
          animation: a,
          start: 0.02,
          end: 0.4,
          child: Text('${w.monthName(peak)}\nwas your month.',
              style: WrappedType.headline(context, size: 36)),
        ),
        const SizedBox(height: 10),
        Reveal(
          animation: a,
          start: 0.1,
          end: 0.5,
          child: Text(
            '${w.formatMeasure(measure, peakValue)} — more than any other '
            'month of ${w.year}.',
            style: WrappedType.body(context),
          ),
        ),
        const Spacer(),
        Reveal(
          animation: a,
          start: 0.15,
          end: 0.4,
          lift: 8,
          child: Text(unit.toUpperCase(),
              style: WrappedType.eyebrow(context).copyWith(fontSize: 10)),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 200,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var m = 1; m <= 12; m++)
                Expanded(
                  child: _MonthBar(
                    animation: a,
                    index: m - 1,
                    fraction: peakValue == 0 ? 0 : values[m - 1] / peakValue,
                    isPeak: m == peak,
                    isQuiet: m == quiet,
                    isFuture: m > lastMonth,
                    label: DateFormat('MMMMM').format(DateTime(w.year, m)),
                    accent: palette.accent,
                  ),
                ),
            ],
          ),
        ),
        const Spacer(),
        if (quietLine != null)
          Reveal(
            animation: a,
            start: 0.65,
            end: 1,
            child: Text(quietLine, style: WrappedType.body(context, alpha: 0.9)),
          ),
      ],
    );
  }
}

class _MonthBar extends StatelessWidget {
  final Animation<double> animation;
  final int index;
  final double fraction;
  final bool isPeak;
  final bool isQuiet;
  final bool isFuture;
  final String label;
  final Color accent;

  const _MonthBar({
    required this.animation,
    required this.index,
    required this.fraction,
    required this.isPeak,
    required this.isQuiet,
    required this.isFuture,
    required this.label,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final grow = CurvedAnimation(
      parent: animation,
      curve: Interval(0.2 + index * 0.025, 0.6 + index * 0.025,
          curve: Curves.easeOutBack),
    );
    final color = isPeak
        ? accent
        : isFuture
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: isQuiet ? 0.22 : 0.42);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: AnimatedBuilder(
              animation: grow,
              builder: (context, _) => Align(
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  heightFactor:
                      (math.max(fraction, 0.025) * grow.value).clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: isPeak
                          ? [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.5),
                                blurRadius: 18,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: WrappedType.caption(context, alpha: isPeak ? 1 : 0.55)
                .copyWith(
                    fontWeight: isPeak ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ── Rhythm ───────────────────────────────────────────────────────────────────

class RhythmSlide extends StatelessWidget {
  final SlideEnv env;
  final WrappedPalette palette;

  const RhythmSlide({super.key, required this.env, required this.palette});

  @override
  Widget build(BuildContext context) {
    final w = env.w;
    final a = env.entrance;
    // Measured from the first day read when that came after January: someone
    // who started in September didn't skip the spring, they weren't here yet.
    final first = w.readingDays.isEmpty
        ? null
        : w.readingDays.reduce((a, b) => a.isBefore(b) ? a : b);
    final lateStart = first != null && first.month > 1;
    final span = lateStart
        ? w.daysElapsed - first.difference(DateTime(w.year)).inDays
        : w.daysElapsed;
    final share = span <= 0 ? 0 : w.activeDays / span;
    final shareLine = lateStart
        ? '${(share * 100).round()}% of the days since your first session '
            'on ${DateFormat('MMMM d').format(first)}.'
        : '${(share * 100).round()}% of ${w.year}'
            '${w.isInProgress ? ' so far' : ''}.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SlideEyebrow('Your rhythm', entrance: a),
        const SizedBox(height: 14),
        Reveal(
          animation: a,
          start: 0.02,
          end: 0.4,
          child: Text('You read on', style: WrappedType.headline(context)),
        ),
        Reveal(
          animation: a,
          start: 0.08,
          end: 0.5,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              CountUp(
                animation: a,
                value: w.activeDays,
                start: 0.1,
                end: 0.7,
                style:
                    WrappedType.hero(context, size: 80, color: palette.accent),
              ),
              const SizedBox(width: 10),
              Text('days', style: WrappedType.headline(context)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Reveal(
          animation: a,
          start: 0.15,
          end: 0.55,
          child: Text(shareLine, style: WrappedType.body(context)),
        ),
        const Spacer(),
        _YearDots(env: env, accent: palette.accent),
        const Spacer(),
        Reveal(
          animation: a,
          start: 0.65,
          end: 1,
          child: Row(
            children: [
              if (w.longestStreak >= 2)
                Expanded(
                  child: _MiniStat(
                    value: '${w.longestStreak} days',
                    label: w.longestStreakStart == null
                        ? 'longest streak'
                        : 'longest streak, from '
                            '${DateFormat('MMM d').format(w.longestStreakStart!)}',
                  ),
                ),
              if (w.weeksSpanned >= 4)
                Expanded(
                  child: _MiniStat(
                    value: '${w.activeWeeks} of ${w.weeksSpanned}',
                    label: 'weeks with reading',
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String value;
  final String label;

  const _MiniStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: WrappedType.title(context, size: 24)),
          const SizedBox(height: 2),
          Text(label, style: WrappedType.caption(context)),
        ],
      ),
    );
  }
}

/// The whole year as a field of dots, one row per month, lit where a session
/// was logged. Reads at a glance as "steady" or "in bursts".
class _YearDots extends StatelessWidget {
  final SlideEnv env;
  final Color accent;

  const _YearDots({required this.env, required this.accent});

  @override
  Widget build(BuildContext context) {
    final w = env.w;
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);
    final labelStyle = WrappedType.caption(context, alpha: 0.5)
        .copyWith(fontSize: 10, fontWeight: FontWeight.w700);

    return LayoutBuilder(builder: (context, constraints) {
      const labelWidth = 16.0;
      final cell = (constraints.maxWidth - labelWidth) / 31;
      final dot = cell * 0.62;

      return Column(
        children: [
          for (var m = 1; m <= 12; m++)
            Reveal(
              animation: env.entrance,
              start: 0.2 + m * 0.025,
              end: 0.5 + m * 0.025,
              lift: 6,
              child: SizedBox(
                height: cell,
                child: Row(
                  children: [
                    SizedBox(
                      width: labelWidth,
                      child: Text(
                          DateFormat('MMMMM').format(DateTime(w.year, m)),
                          style: labelStyle),
                    ),
                    for (var d = 1; d <= 31; d++)
                      SizedBox(
                        width: cell,
                        child: Center(
                          child: _dot(w, m, d, dot, todayKey),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      );
    });
  }

  Widget _dot(YearWrapped w, int month, int day, double size, DateTime today) {
    final date = DateTime(w.year, month, day);
    // DateTime rolls Feb 30 into March; such days don't exist here.
    if (date.month != month) return const SizedBox.shrink();
    final lit = w.readingDays.contains(date);
    final future = date.isAfter(today);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: lit
            ? accent
            : Colors.white.withValues(alpha: future ? 0.05 : 0.14),
      ),
    );
  }
}
