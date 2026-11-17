import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '/data/database/database_helper.dart';
import 'badges.dart';
import 'reading_stats.dart';

/// A quarter of the year that seasonal achievements are counted over: winter
/// is December to February, spring March to May, summer June to August, fall
/// September to November.
///
/// Named as the northern hemisphere has them. A winter spans two calendar
/// years and takes both in its name — "Winter 2025–26".
class Season {
  /// First day of the season.
  final DateTime start;

  const Season._(this.start);

  /// The season [date] falls in.
  factory Season.of(DateTime date) {
    // December belongs to the winter that starts in it; January and February
    // to the one that started the December before.
    final month = date.month;
    final startMonth = month == 12 ? 12 : ((month ~/ 3) * 3);
    return startMonth == 0
        ? Season._(DateTime(date.year - 1, 12))
        : Season._(DateTime(date.year, startMonth));
  }

  /// The season with this [id], or null if it isn't one.
  static Season? parse(String id) {
    final parts = id.split('-');
    if (parts.length != 2) return null;
    final year = int.tryParse(parts[0]), month = int.tryParse(parts[1]);
    if (year == null || month == null || month % 3 != 0) return null;
    return Season._(DateTime(year, month));
  }

  /// First day of the season after — where this one stops.
  DateTime get end => DateTime(start.year, start.month + 3);

  Season get previous => Season._(DateTime(start.year, start.month - 3));

  /// Stable key for the season: its first month, "2026-9".
  String get id => '${start.year}-${start.month}';

  bool contains(DateTime date) => !date.isBefore(start) && date.isBefore(end);

  int get _quarter => start.month == 12 ? 0 : start.month ~/ 3;

  /// "Fall 2026", "Winter 2025–26".
  String get name {
    final season = const ['Winter', 'Spring', 'Summer', 'Fall'][_quarter];
    if (_quarter != 0) return '$season ${start.year}';
    return '$season ${start.year}–${(start.year + 1) % 100}';
  }

  IconData get icon => const [
        Icons.ac_unit_rounded,
        Icons.local_florist_rounded,
        Icons.wb_sunny_rounded,
        Icons.eco_rounded,
      ][_quarter];

  /// The colour of the time of year: blue for winter, green for spring,
  /// yellow for summer, orange for fall. Tints the season's icon in its
  /// heading; the medals keep the colour of their tier.
  Color get color => const [
        Color(0xFF42A5F5),
        Color(0xFF66BB6A),
        Color(0xFFFFC107),
        Color(0xFFFB8C00),
      ][_quarter];

  /// "Sep – Nov"
  String get months {
    final last = DateTime(start.year, start.month + 2);
    final fmt = DateFormat('MMM');
    return '${fmt.format(start)} – ${fmt.format(last)}';
  }

  /// Whole days left in the season counting [now]'s, or 0 once it is over.
  int daysLeft(DateTime now) {
    // Counted on UTC dates so a clock change can't shave a day off.
    final left = DateTime.utc(end.year, end.month, end.day)
        .difference(DateTime.utc(now.year, now.month, now.day))
        .inDays;
    return left < 0 ? 0 : left;
  }

  @override
  bool operator ==(Object other) => other is Season && other.start == start;

  @override
  int get hashCode => start.hashCode;
}

/// What was read within one season — [ReadingStats] over only the sessions
/// logged in it and the books finished in it — for measuring [kSeasonGoals].
///
/// A finished book with no finish date can't be placed in a season and is
/// left out, as it is from the activity feed.
ReadingStats seasonStats(
  Season season,
  List<Map<String, dynamic>> books,
  List<Map<String, dynamic>> sessions,
) {
  DateTime? date(Object? v) => v is String ? DateTime.tryParse(v) : null;
  bool within(Object? v) {
    final d = date(v);
    return d != null && season.contains(d);
  }

  return ReadingStats.from(
    books: [
      for (final b in books)
        if (b['shelf_id'] == DatabaseHelper.shelfFinished &&
            within(b['date_finished']))
          b,
    ],
    sessions: [
      for (final s in sessions)
        if (within(s['date'])) s,
    ],
  );
}

/// Every season the reader has something in — a session logged or a book
/// finished — newest first, up to and including [now]'s, which is always
/// there even when empty.
List<Season> seasonsWithReading(
  List<Map<String, dynamic>> books,
  List<Map<String, dynamic>> sessions, [
  DateTime? now,
]) {
  final current = Season.of(now ?? DateTime.now());
  final seen = <Season>{current};
  void add(Object? v) {
    final d = v is String ? DateTime.tryParse(v) : null;
    if (d != null && d.isBefore(current.end)) seen.add(Season.of(d));
  }

  for (final s in sessions) {
    add(s['date']);
  }
  for (final b in books) {
    if (b['shelf_id'] == DatabaseHelper.shelfFinished) add(b['date_finished']);
  }
  return seen.toList()..sort((a, b) => b.start.compareTo(a.start));
}

num _books(ReadingStats s) => s.booksFinished;
num _pages(ReadingStats s) => s.totalPagesRead;
num _minutes(ReadingStats s) => s.totalMinutes;
num _sessions(ReadingStats s) => s.totalSessions;
num _streak(ReadingStats s) => s.longestWeekStreak;
num _maxBook(ReadingStats s) => s.maxBookPages;
num _maxSession(ReadingStats s) => s.maxSessionPages;
num _maxSessionMinutes(ReadingStats s) => s.maxSessionMinutes;

String _n(num n) => NumberFormat.decimalPattern().format(n);
String _asBooks(num n) => '${_n(n)} book${n == 1 ? '' : 's'}';
String _asSessions(num n) => '${_n(n)} session${n == 1 ? '' : 's'}';
String _asPages(num n) => '${_n(n)} pages';
String _asWeeks(num n) => '${n.toInt()} week${n == 1 ? '' : 's'}';
String _asMinutes(num n) => '${n.toInt()} minute${n == 1 ? '' : 's'}';
String _asHours(num minutes) {
  final h = (minutes / 60).round();
  return '$h hour${h == 1 ? '' : 's'}';
}

String _hoursShort(num minutes) => _n((minutes / 60).round());

/// The seasonal medals: the lifetime ladders that make sense over three
/// months, with rungs sized for one season and measured against
/// [seasonStats]. They start again from nothing each season, so there is
/// always something to earn once the lifetime ones are done.
///
/// Ids are prefixed `season_` so they never collide with [kGoals] in a
/// stored snapshot.
final List<ReadingGoal> kSeasonGoals = [
  ReadingGoal(
    id: 'season_books',
    label: 'Books',
    title: 'Books finished this season',
    icon: Icons.local_library_rounded,
    measure: _books,
    format: _asBooks,
    tiers: const [
      GoalTier(1, 'Season Opener', BadgeTier.bronze),
      GoalTier(3, 'Hat Trick', BadgeTier.silver),
      GoalTier(6, 'Half Dozen', BadgeTier.gold),
      GoalTier(10, 'Ten in a Season', BadgeTier.platinum),
    ],
  ),
  ReadingGoal(
    id: 'season_time',
    label: 'Time',
    title: 'Time spent reading this season',
    icon: Icons.schedule_rounded,
    measure: _minutes,
    format: _asHours,
    formatShort: _hoursShort,
    tiers: const [
      GoalTier(300, 'Warming Up', BadgeTier.bronze),
      GoalTier(900, 'Regular Hours', BadgeTier.silver),
      GoalTier(2400, 'Deep In', BadgeTier.gold),
      GoalTier(4800, 'Season of Reading', BadgeTier.platinum),
    ],
  ),
  ReadingGoal(
    id: 'season_sessions',
    label: 'Sessions',
    title: 'Sessions logged this season',
    icon: Icons.event_repeat_rounded,
    measure: _sessions,
    format: _asSessions,
    tiers: const [
      GoalTier(5, 'Showing Up', BadgeTier.bronze),
      GoalTier(15, 'In the Habit', BadgeTier.silver),
      GoalTier(40, 'Most Days', BadgeTier.gold),
      GoalTier(80, 'Nearly Daily', BadgeTier.platinum),
    ],
  ),
  ReadingGoal(
    id: 'season_streak',
    label: 'Streak',
    title: 'Longest weekly streak this season',
    icon: Icons.local_fire_department_rounded,
    measure: _streak,
    format: _asWeeks,
    tiers: const [
      GoalTier(2, 'Back to Back', BadgeTier.bronze),
      GoalTier(4, 'A Solid Month', BadgeTier.silver),
      GoalTier(8, 'Two Months Straight', BadgeTier.gold),
      GoalTier(12, 'Every Week', BadgeTier.platinum),
    ],
  ),
  ReadingGoal(
    id: 'season_pages',
    label: 'Pages',
    title: 'Pages read this season',
    icon: Icons.menu_book_rounded,
    measure: _pages,
    format: _asPages,
    tiers: const [
      GoalTier(300, 'First Chapters', BadgeTier.bronze),
      GoalTier(1000, 'Thousand Pages', BadgeTier.silver),
      GoalTier(2500, 'Page Stacker', BadgeTier.gold),
      GoalTier(5000, 'Five Thousand', BadgeTier.platinum),
    ],
  ),
  ReadingGoal(
    id: 'season_big_book',
    label: 'Big Book',
    title: 'Longest book finished this season',
    icon: Icons.menu_book_outlined,
    measure: _maxBook,
    format: _asPages,
    tiers: const [
      GoalTier(300, 'Full Length', BadgeTier.bronze),
      GoalTier(500, 'Hefty', BadgeTier.silver),
      GoalTier(700, 'Brick', BadgeTier.gold),
      GoalTier(900, 'Season Epic', BadgeTier.platinum),
    ],
  ),
  ReadingGoal(
    id: 'season_power_session',
    label: 'Session',
    title: 'Most pages in one session this season',
    icon: Icons.bolt_rounded,
    measure: _maxSession,
    format: _asPages,
    tiers: const [
      GoalTier(40, 'Good Stretch', BadgeTier.bronze),
      GoalTier(80, 'On a Roll', BadgeTier.silver),
      GoalTier(150, "Couldn't Stop", BadgeTier.gold),
      GoalTier(250, 'One Sitting Wonder', BadgeTier.platinum),
    ],
  ),
  ReadingGoal(
    id: 'season_long_session',
    label: 'Sitting',
    title: 'Longest single session this season',
    icon: Icons.timer_rounded,
    measure: _maxSessionMinutes,
    format: _asMinutes,
    tiers: const [
      GoalTier(30, 'Half Hour', BadgeTier.bronze),
      GoalTier(60, 'Full Hour', BadgeTier.silver),
      GoalTier(120, 'Long Afternoon', BadgeTier.gold),
      GoalTier(180, 'Lost Track of Time', BadgeTier.platinum),
    ],
  ),
];

/// Seasonal medals there are to earn in one season.
int get totalSeasonMilestones =>
    kSeasonGoals.fold(0, (sum, g) => sum + g.tiers.length);

/// Seasonal medals earned with [stats], a season's [seasonStats].
int earnedSeasonMilestones(ReadingStats stats) =>
    kSeasonGoals.fold(0, (sum, g) => sum + (g.achievedIndex(stats) + 1));
