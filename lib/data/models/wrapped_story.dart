import 'package:intl/intl.dart';

import '/data/utils/reading_clock.dart';
import 'year_wrapped.dart';

/// The slides Wrapped can tell, in the order they are told.
enum WrappedSlide {
  intro,
  numbers,
  shape,
  rhythm,
  bigBooks,
  bookOfYear,
  people,
  formats,
  personality,
  discoveries,
  finale;

  /// Whether the slide offers a share button. The rest are steps in the story
  /// rather than something a reader would post on its own.
  bool get isShareable => switch (this) {
        WrappedSlide.intro ||
        WrappedSlide.numbers ||
        WrappedSlide.bookOfYear ||
        WrappedSlide.personality ||
        WrappedSlide.discoveries ||
        WrappedSlide.finale =>
          true,
        _ => false,
      };

  /// Short name for the jump-to strip on the finale.
  String get label => switch (this) {
        WrappedSlide.intro => 'Intro',
        WrappedSlide.numbers => 'Numbers',
        WrappedSlide.shape => 'Your year',
        WrappedSlide.rhythm => 'Rhythm',
        WrappedSlide.bigBooks => 'Big books',
        WrappedSlide.bookOfYear => 'Top book',
        WrappedSlide.people => 'Authors',
        WrappedSlide.formats => 'Formats',
        WrappedSlide.personality => 'Personality',
        WrappedSlide.discoveries => 'Discoveries',
        WrappedSlide.finale => 'Summary',
      };
}

/// One "did you know" line on the discoveries slide.
class WrappedFact {
  /// The figure, set large: "3h 40m", "2 days", "+0.8★".
  final String value;

  /// What it is: "Your biggest day".
  final String label;

  /// What it refers to: "Saturday, March 14".
  final String detail;

  const WrappedFact({
    required this.value,
    required this.label,
    required this.detail,
  });
}

/// Decides which slides a year has earned, and gathers its discoveries.
///
/// Every condition lives here rather than in the widgets, so a slide is never
/// built only to discover it has nothing to say.
class WrappedStory {
  final YearWrapped wrapped;
  final List<WrappedSlide> slides;
  final List<WrappedFact> facts;

  const WrappedStory._(this.wrapped, this.slides, this.facts);

  factory WrappedStory.of(YearWrapped w) {
    final facts = _discoveries(w);
    final slides = <WrappedSlide>[
      WrappedSlide.intro,
      if (_nonZeroTotals(w) >= 2) WrappedSlide.numbers,
      // A year needs a few months in it before it has a shape to show.
      if (w.peakMonth != null && w.activeMonths >= 3) WrappedSlide.shape,
      if (w.activeDays >= 5) WrappedSlide.rhythm,
      if (w.shortestBook != null ||
          (w.mostTimeBook != null && w.booksRead.length >= 2))
        WrappedSlide.bigBooks,
      if (w.finished.isNotEmpty) WrappedSlide.bookOfYear,
      if (w.topAuthor != null || w.topNarrator != null) WrappedSlide.people,
      if (w.booksFinished >= 3 && w.formatCounts.length >= 2)
        WrappedSlide.formats,
      if (w.personality != null) WrappedSlide.personality,
      if (facts.isNotEmpty) WrappedSlide.discoveries,
      WrappedSlide.finale,
    ];
    return WrappedStory._(w, List.unmodifiable(slides), facts);
  }

  /// Minutes and pages are amounts worth comparing day to day or month to
  /// month; counts of sessions or books are too small to make a "3×" mean much.
  static bool _isAmount(WrappedMeasure m) =>
      m == WrappedMeasure.minutes || m == WrappedMeasure.pages;

  static int _nonZeroTotals(YearWrapped w) => [
        w.booksFinished,
        w.minutes,
        w.displayPages,
        w.sessions,
      ].where((v) => v > 0).length;

  /// Up to three facts, in order of how surprising they tend to be. Each one
  /// has its own bar to clear; one that doesn't is simply not offered.
  static List<WrappedFact> _discoveries(YearWrapped w) {
    final facts = <WrappedFact>[];
    final measure = w.primaryMeasure;

    final best = w.bestDay;
    if (best != null && w.activeDays >= 5 && _isAmount(measure)) {
      facts.add(WrappedFact(
        value: w.formatMeasure(measure, best.value),
        label: 'Your biggest day',
        detail: DateFormat('EEEE, MMMM d').format(best.date),
      ));
    }

    final longest = w.longestSession;
    if (longest != null && w.timedSessions >= 3 && longest.value >= 30) {
      final title = longest.book?.title;
      facts.add(WrappedFact(
        value: YearWrapped.formatMinutes(longest.value),
        label: 'Your longest sitting',
        detail: title == null || title.isEmpty
            ? DateFormat('MMMM d').format(longest.date)
            : 'with $title',
      ));
    }

    final fastest = w.fastestFinish;
    if (fastest != null) {
      final days = fastest.daysToFinish!;
      facts.add(WrappedFact(
        value: days == 1 ? '1 day' : '$days days',
        label: 'Your fastest finish',
        detail: fastest.title,
      ));
    }

    final halves = w.ratingHalves;
    if (halves != null) {
      final diff = halves.$2 - halves.$1;
      if (diff.abs() >= 0.5) {
        facts.add(WrappedFact(
          value: '${diff > 0 ? '+' : '−'}${diff.abs().toStringAsFixed(1)}★',
          label: diff > 0
              ? 'Your ratings rose after June'
              : 'You got tougher after June',
          detail: 'Average ${halves.$1.toStringAsFixed(1)}★ → '
              '${halves.$2.toStringAsFixed(1)}★',
        ));
      }
    }

    // A weekday that took a clear lion's share: a seventh of the week is 14%.
    if (w.sessions >= 10) {
      final source = w.minutes > 0 ? w.weekdayMinutes : w.weekdaySessions;
      final total = source.values.fold(0, (a, b) => a + b);
      final peak = peakBucket(source, kAllWeekdaysMondayFirst);
      if (peak != null && total > 0) {
        final share = (source[peak] ?? 0) / total;
        if (share >= 0.22) {
          facts.add(WrappedFact(
            value: '${(share * 100).round()}%',
            label: '${kWeekdayFull[peak]}s were your day',
            detail: w.minutes > 0
                ? 'of all your reading time'
                : 'of all your sessions',
          ));
        }
      }
    }

    final peak = w.peakMonth;
    final quiet = w.quietestMonth;
    if (peak != null && quiet != null && _isAmount(measure)) {
      final values = w.byMonth(measure);
      final high = values[peak - 1];
      final low = values[quiet - 1];
      if (low > 0 && high / low >= 2) {
        facts.add(WrappedFact(
          value: '${(high / low).round()}×',
          label: '${w.monthName(peak)} out-read ${w.monthName(quiet)}',
          detail: '${w.formatMeasure(measure, high)} against '
              '${w.formatMeasure(measure, low)}',
        ));
      }
    }

    final lengths = w.booksByLength;
    if (lengths.length >= 3) {
      final avg =
          (lengths.fold(0, (s, b) => s + b.pages) / lengths.length).round();
      facts.add(WrappedFact(
        value: YearWrapped.formatNumber(avg),
        label: 'Pages in your average book',
        detail: 'across ${lengths.length} books with a page count',
      ));
    }

    return facts.take(3).toList(growable: false);
  }
}

/// Monday-first, so a tie between days goes to the earlier one in the week.
const List<int> kAllWeekdaysMondayFirst = [
  DateTime.monday,
  DateTime.tuesday,
  DateTime.wednesday,
  DateTime.thursday,
  DateTime.friday,
  DateTime.saturday,
  DateTime.sunday,
];
