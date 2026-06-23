import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'reading_stats.dart';

/// Visual rank of a milestone. Drives the medal color; purely cosmetic.
enum BadgeTier { bronze, silver, gold, platinum }

/// One milestone within a goal: reach [threshold] to earn it.
class GoalTier {
  final num threshold;
  final String title;
  final BadgeTier tier;

  const GoalTier(this.threshold, this.title, this.tier);
}

/// A single, ever-progressing achievement (e.g. "Books"). A goal holds an
/// ascending ladder of [tiers]; the medal shows the highest tier reached and
/// the ring shows progress toward the next one. One medal per goal — no
/// duplicate medals for the same metric.
class ReadingGoal {
  final String id;
  final String label; // short, for the grid ("Books")
  final String title; // full, for the detail sheet ("Books finished")
  final IconData icon;
  final num Function(ReadingStats) measure;
  final List<GoalTier> tiers;
  final String Function(num)? _format;
  final String Function(num)? _formatShort;

  const ReadingGoal({
    required this.id,
    required this.label,
    required this.title,
    required this.icon,
    required this.measure,
    required this.tiers,
    String Function(num)? format,
    String Function(num)? formatShort,
  })  : _format = format,
        _formatShort = formatShort;

  /// Full value with unit ("8,000 pages", "40 hours") — for the one headline
  /// sentence users read to see what's left to the next tier.
  String formatValue(num v) =>
      _format?.call(v) ?? NumberFormat.decimalPattern().format(v);

  /// Bare number, scaled to the display unit ("8,000", "40"). Used where the
  /// unit is already implied — ladder rows and bar anchors — so the word isn't
  /// repeated into clutter on every line.
  String formatShortValue(num v) =>
      _formatShort?.call(v) ?? NumberFormat.decimalPattern().format(v);

  /// Index of the highest tier reached, or -1 if none yet.
  int achievedIndex(ReadingStats s) {
    final v = measure(s);
    var idx = -1;
    for (var i = 0; i < tiers.length; i++) {
      if (v >= tiers[i].threshold) {
        idx = i;
      } else {
        break;
      }
    }
    return idx;
  }

  GoalTier? highestTier(ReadingStats s) {
    final i = achievedIndex(s);
    return i >= 0 ? tiers[i] : null;
  }

  GoalTier? nextTier(ReadingStats s) {
    final n = achievedIndex(s) + 1;
    return n < tiers.length ? tiers[n] : null;
  }

  /// How much more of the metric is needed to reach the next tier, or null if
  /// every tier is already earned. Clamped at 0 so it never reads negative.
  num? remainingToNext(ReadingStats s) {
    final next = nextTier(s);
    if (next == null) return null;
    final r = next.threshold - measure(s);
    return r < 0 ? 0 : r;
  }

  bool isComplete(ReadingStats s) => achievedIndex(s) == tiers.length - 1;

  /// Progress (0–1) from the current tier's floor to the next tier.
  double progress(ReadingStats s) {
    final next = nextTier(s);
    if (next == null) return 1;
    final i = achievedIndex(s);
    final floor = i >= 0 ? tiers[i].threshold : 0;
    final span = next.threshold - floor;
    if (span <= 0) return 1;
    return ((measure(s) - floor) / span).clamp(0, 1).toDouble();
  }
}

/// Tier color, tuned for contrast on both light and dark surfaces.
Color badgeTierColor(BadgeTier tier) {
  switch (tier) {
    case BadgeTier.bronze:
      return const Color(0xFFC17C3A);
    case BadgeTier.silver:
      return const Color(0xFF7E8B9E); // steel silver — reads distinctly metallic
    case BadgeTier.gold:
      return const Color(0xFFD9A520);
    case BadgeTier.platinum:
      return const Color(0xFF3FB8C9);
  }
}

String badgeTierLabel(BadgeTier tier) {
  switch (tier) {
    case BadgeTier.bronze:
      return 'Bronze';
    case BadgeTier.silver:
      return 'Silver';
    case BadgeTier.gold:
      return 'Gold';
    case BadgeTier.platinum:
      return 'Platinum';
  }
}

// Metric accessors (top-level so they can be used in the const goal list).
num _books(ReadingStats s) => s.booksFinished;
num _pages(ReadingStats s) => s.totalPagesRead;
num _minutes(ReadingStats s) => s.totalMinutes;
num _streak(ReadingStats s) => s.longestWeekStreak;
num _sessions(ReadingStats s) => s.totalSessions;
num _reviews(ReadingStats s) => s.reviewsWritten;
num _rated(ReadingStats s) => s.ratedCount;
num _audiobooks(ReadingStats s) => s.audiobooksFinished;
num _ebooks(ReadingStats s) => s.ebooksFinished;
num _physical(ReadingStats s) => s.physicalFinished;
num _maxBook(ReadingStats s) => s.maxBookPages;
num _maxSession(ReadingStats s) => s.maxSessionPages;
num _maxSessionMinutes(ReadingStats s) => s.maxSessionMinutes;
num _maxPph(ReadingStats s) => s.maxSessionPph;

String _asHours(num minutes) {
  final h = (minutes / 60).round();
  return '$h hour${h == 1 ? '' : 's'}';
}

String _asWeeks(num n) => '${n.toInt()} week${n == 1 ? '' : 's'}';
String _asPages(num n) =>
    '${NumberFormat.decimalPattern().format(n)} pages';
String _asMinutes(num n) => '${n.toInt()} minute${n == 1 ? '' : 's'}';
String _asPph(num n) => '${n.toInt()} pages/hr';

/// Whole hours as a bare number (no unit) — minutes scaled to hours.
String _hoursShort(num minutes) =>
    NumberFormat.decimalPattern().format((minutes / 60).round());

/// Formatter for count-based goals: "1 book", "25 books" — keeps the unit on
/// the value so the badge copy reads as a complete thought everywhere.
String Function(num) _count(String noun) => (n) =>
    '${NumberFormat.decimalPattern().format(n)} $noun${n == 1 ? '' : 's'}';

/// The catalogue of goals — one medal each.
final List<ReadingGoal> kGoals = [
  ReadingGoal(
    id: 'books',
    label: 'Books',
    title: 'Books finished',
    icon: Icons.local_library_rounded,
    measure: _books,
    format: _count('book'),
    tiers: const [
      GoalTier(5, 'First Finish', BadgeTier.bronze),
      GoalTier(25, 'Bookworm', BadgeTier.silver),
      GoalTier(75, 'Bibliophile', BadgeTier.gold),
      GoalTier(200, 'Library Legend', BadgeTier.platinum),
    ],
  ),
  ReadingGoal(
    id: 'physical',
    label: 'Physical',
    title: 'Physical books finished',
    icon: Icons.auto_stories_rounded,
    measure: _physical,
    format: _count('book'),
    tiers: const [
      GoalTier(3, 'Page Holder', BadgeTier.bronze),
      GoalTier(10, 'Shelf Builder', BadgeTier.silver),
      GoalTier(25, 'Paper Purist', BadgeTier.gold),
      GoalTier(50, 'Library Keeper', BadgeTier.platinum),
    ],
  ),
  ReadingGoal(
    id: 'ebooks',
    label: 'EBook',
    title: 'Ebooks finished',
    icon: Icons.tablet_android_rounded,
    measure: _ebooks,
    format: _count('ebook'),
    tiers: const [
      GoalTier(3, 'Going Digital', BadgeTier.bronze),
      GoalTier(10, 'Screen Reader', BadgeTier.silver),
      GoalTier(25, 'Pixel Bookworm', BadgeTier.gold),
      GoalTier(50, 'Digital Devourer', BadgeTier.platinum),
    ],
  ),
  ReadingGoal(
    id: 'audiobooks',
    label: 'Audio',
    title: 'Audiobooks finished',
    icon: Icons.headphones_rounded,
    measure: _audiobooks,
    format: _count('audiobook'),
    tiers: const [
      GoalTier(3, 'Listener', BadgeTier.bronze),
      GoalTier(10, 'Audiophile', BadgeTier.silver),
      GoalTier(25, 'Devoted Listener', BadgeTier.gold),
      GoalTier(50, 'Audio Scholar', BadgeTier.platinum),
    ],
  ),
  ReadingGoal(
    id: 'time',
    label: 'Time',
    title: 'Time spent reading',
    icon: Icons.schedule_rounded,
    measure: _minutes,
    format: _asHours,
    formatShort: _hoursShort,
    tiers: const [
      GoalTier(600, 'Settling In', BadgeTier.bronze),
      GoalTier(3000, 'Dedicated', BadgeTier.silver),
      GoalTier(9000, 'Time Well Spent', BadgeTier.gold),
      GoalTier(30000, 'Eternal Reader', BadgeTier.platinum),
    ],
  ),
  ReadingGoal(
    id: 'sessions',
    label: 'Sessions',
    title: 'Sessions logged',
    icon: Icons.event_repeat_rounded,
    measure: _sessions,
    format: _count('session'),
    tiers: const [
      GoalTier(10, 'Routine', BadgeTier.bronze),
      GoalTier(100, 'Consistent', BadgeTier.silver),
      GoalTier(500, 'Devoted', BadgeTier.gold),
      GoalTier(1500, 'Unstoppable', BadgeTier.platinum),
    ],
  ),
  ReadingGoal(
    id: 'pages',
    label: 'Pages',
    title: 'Pages read',
    icon: Icons.menu_book_rounded,
    measure: _pages,
    format: _asPages,
    tiers: const [
      GoalTier(1000, 'Page Turner', BadgeTier.bronze),
      GoalTier(10000, 'Marathon Reader', BadgeTier.silver),
      GoalTier(50000, 'Page Master', BadgeTier.gold),
      GoalTier(100000, 'Ink Ocean', BadgeTier.platinum),
    ],
  ),
  ReadingGoal(
    id: 'streak',
    label: 'Streak',
    title: 'Longest weekly streak',
    icon: Icons.local_fire_department_rounded,
    measure: _streak,
    format: _asWeeks,
    tiers: const [
      GoalTier(2, 'Fortnight', BadgeTier.bronze),
      GoalTier(4, 'Monthly Habit', BadgeTier.silver),
      GoalTier(12, 'Quarter Master', BadgeTier.gold),
      GoalTier(52, 'Year-Round Reader', BadgeTier.platinum),
    ],
  ),
  ReadingGoal(
    id: 'ratings',
    label: 'Ratings',
    title: 'Books rated',
    icon: Icons.star_rounded,
    measure: _rated,
    format: _count('rating'),
    tiers: const [
      GoalTier(10, 'Taste Maker', BadgeTier.bronze),
      GoalTier(50, 'The Judge', BadgeTier.silver),
      GoalTier(100, 'Connoisseur', BadgeTier.gold),
      GoalTier(200, 'Curator', BadgeTier.platinum),
    ],
  ),
  ReadingGoal(
    id: 'reviews',
    label: 'Reviews',
    title: 'Reviews written',
    icon: Icons.rate_review_rounded,
    measure: _reviews,
    format: _count('review'),
    tiers: const [
      GoalTier(1, 'Critic', BadgeTier.bronze),
      GoalTier(10, 'Reviewer', BadgeTier.silver),
      GoalTier(25, 'Wordsmith', BadgeTier.gold),
      GoalTier(50, 'Literary Voice', BadgeTier.platinum),
    ],
  ),
  ReadingGoal(
    id: 'big_book',
    label: 'Big Book',
    title: 'Longest book finished',
    icon: Icons.menu_book_outlined,
    measure: _maxBook,
    format: _asPages,
    tiers: const [
      GoalTier(400, 'Chunky Read', BadgeTier.bronze),
      GoalTier(600, 'Doorstopper', BadgeTier.silver),
      GoalTier(900, 'Epic', BadgeTier.gold),
      GoalTier(1200, 'Tome Conqueror', BadgeTier.platinum),
    ],
  ),
  ReadingGoal(
    id: 'power_session',
    label: 'Session',
    title: 'Most pages in one session',
    icon: Icons.bolt_rounded,
    measure: _maxSession,
    format: _asPages,
    tiers: const [
      GoalTier(50, 'In the Zone', BadgeTier.bronze),
      GoalTier(100, 'Power Reader', BadgeTier.silver),
      GoalTier(200, 'Marathon Session', BadgeTier.gold),
      GoalTier(300, 'Page Devourer', BadgeTier.platinum),
    ],
  ),
  ReadingGoal(
    id: 'long_session',
    label: 'Sitting',
    title: 'Longest single session',
    icon: Icons.timer_rounded,
    measure: _maxSessionMinutes,
    format: _asMinutes,
    tiers: const [
      GoalTier(30, 'Settled In', BadgeTier.bronze),
      GoalTier(60, 'Deep Focus', BadgeTier.silver),
      GoalTier(120, 'Marathon Sitting', BadgeTier.gold),
      GoalTier(240, 'Iron Reader', BadgeTier.platinum),
    ],
  ),
  ReadingGoal(
    id: 'speed',
    label: 'Speed',
    title: 'Fastest reading pace',
    icon: Icons.speed_rounded,
    measure: _maxPph,
    format: _asPph,
    tiers: const [
      GoalTier(30, 'Steady', BadgeTier.bronze),
      GoalTier(50, 'Brisk', BadgeTier.silver),
      GoalTier(70, 'Swift', BadgeTier.gold),
      GoalTier(100, 'Speed Reader', BadgeTier.platinum),
    ],
  ),
];

/// Total milestones across every goal — the denominator for the header.
int get totalMilestones =>
    kGoals.fold(0, (sum, g) => sum + g.tiers.length);

/// Milestones earned so far across every goal.
int earnedMilestones(ReadingStats s) =>
    kGoals.fold(0, (sum, g) => sum + (g.achievedIndex(s) + 1));
