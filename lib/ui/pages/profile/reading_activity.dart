import 'package:intl/intl.dart';

import '/data/database/database_helper.dart';
import '/data/models/goal.dart';
import '/data/repositories/goal_repository.dart';
import 'badges.dart';
import 'reading_stats.dart';

/// What happened, in the order entries outrank one another when they share a
/// moment: a badge earned by finishing a book reads above the finish itself.
enum ActivityKind { addedBooks, added, started, setAside, finished, goalMet, badge }

/// One line of the reader's activity feed.
class ActivityEntry {
  final ActivityKind kind;
  final DateTime date;

  /// The book, for the book kinds.
  final Map<String, dynamic>? book;

  /// How many books, for [ActivityKind.addedBooks].
  final int count;

  /// The goal and the target that period had, for [ActivityKind.goalMet].
  final Goal? goal;
  final int target;

  /// The medal and the rung reached, for [ActivityKind.badge].
  final ReadingGoal? badge;
  final GoalTier? tier;

  const ActivityEntry({
    required this.kind,
    required this.date,
    this.book,
    this.count = 0,
    this.goal,
    this.target = 0,
    this.badge,
    this.tier,
  });
}

/// The reader's history as a feed, newest first.
///
/// Rebuilt from books, sessions and goals rather than logged as things happen,
/// so it covers everything from before the feed existed and follows any edit —
/// change a finish date and the entry moves, delete a book and its entries go.
class ReadingActivity {
  ReadingActivity._();

  /// More books than this added on one day collapse to a single entry — an
  /// import, or a first evening spent entering a shelf.
  static const _bulkAddThreshold = 5;

  static List<ActivityEntry> build({
    required List<Map<String, dynamic>> books,
    required List<Map<String, dynamic>> sessions,
    List<(Goal, List<GoalTargetChange>)> goals = const [],
  }) {
    final entries = <ActivityEntry>[
      ..._bookEntries(books, sessions),
      ..._goalEntries(books, sessions, goals),
      ..._badgeEntries(books, sessions),
    ];
    entries.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      if (byDate != 0) return byDate;
      return b.kind.index.compareTo(a.kind.index);
    });
    return entries;
  }

  // ── Books ──────────────────────────────────────────────────────────────────

  static List<ActivityEntry> _bookEntries(
    List<Map<String, dynamic>> books,
    List<Map<String, dynamic>> sessions,
  ) {
    // A book set aside has no date of its own; its last session is when the
    // reader stopped.
    final lastSession = <int, DateTime>{};
    for (final s in sessions) {
      final date = _date(s['date']);
      if (date == null) continue;
      final id = _int(s['book_id']);
      final current = lastSession[id];
      if (current == null || date.isAfter(current)) lastSession[id] = date;
    }

    final result = <ActivityEntry>[];
    final addsByDay = <DateTime, List<ActivityEntry>>{};

    for (final book in books) {
      final shelf = _int(book['shelf_id']);
      final steps = <(ActivityKind, DateTime)>[
        if (_date(book['date_added']) case final d?) (ActivityKind.added, d),
        if (_date(book['date_started']) case final d?)
          (ActivityKind.started, d),
        if (shelf == DatabaseHelper.shelfFinished)
          if (_date(book['date_finished']) case final d?)
            (ActivityKind.finished, d),
        if (shelf == DatabaseHelper.shelfUnfinished)
          if (lastSession[_int(book['id'])] ?? _date(book['date_finished'])
              case final d?)
            (ActivityKind.setAside, d),
      ];

      // One entry per book per day — the furthest it got. Added and started
      // the same evening is just "started"; older data has finish dates copied
      // from the add date, which would otherwise double every such book.
      final byDay = <DateTime, (ActivityKind, DateTime)>{};
      for (final step in steps) {
        final day = _day(step.$2);
        final kept = byDay[day];
        if (kept == null || step.$1.index > kept.$1.index) byDay[day] = step;
      }

      for (final MapEntry(key: day, value: step) in byDay.entries) {
        final entry = ActivityEntry(kind: step.$1, date: step.$2, book: book);
        if (step.$1 == ActivityKind.added) {
          addsByDay.putIfAbsent(day, () => []).add(entry);
        } else {
          result.add(entry);
        }
      }
    }

    for (final adds in addsByDay.values) {
      if (adds.length <= _bulkAddThreshold) {
        result.addAll(adds);
        continue;
      }
      final latest = adds.map((e) => e.date).reduce((a, b) => a.isAfter(b) ? a : b);
      result.add(ActivityEntry(
        kind: ActivityKind.addedBooks,
        date: latest,
        count: adds.length,
      ));
    }
    return result;
  }

  // ── Goals ──────────────────────────────────────────────────────────────────

  /// Each period a goal was met, dated by the session or finish that met it.
  /// Periods from before the goal was set don't count — there was nothing to
  /// meet yet.
  static List<ActivityEntry> _goalEntries(
    List<Map<String, dynamic>> books,
    List<Map<String, dynamic>> sessions,
    List<(Goal, List<GoalTargetChange>)> goals,
  ) {
    final result = <ActivityEntry>[];

    for (final (goal, changes) in goals) {
      // Same measures as DatabaseHelper.getProgressForPeriod.
      final items = <(DateTime, int)>[
        if (goal.metric == GoalMetric.booksFinished)
          for (final b in books)
            if (_date(b['date_finished']) case final d?) (d, 1)
        else
          for (final s in sessions)
            if (_date(s['date']) case final d?)
              (
                d,
                switch (goal.metric) {
                  GoalMetric.pagesRead => _int(s['pages_read']),
                  GoalMetric.timeReading => _int(s['duration_minutes']),
                  _ => 1,
                }
              ),
      ]..sort((a, b) => a.$1.compareTo(b.$1));

      final firstPeriod = GoalRepository.periodStartOf(
          goal.period, DateTime.parse(goal.createdAt));
      DateTime? period;
      var sum = 0;
      var met = false;

      for (final (date, amount) in items) {
        final start = GoalRepository.periodStartOf(goal.period, date);
        if (start.isBefore(firstPeriod)) continue;
        if (start != period) {
          period = start;
          sum = 0;
          met = false;
        }
        if (met) continue;
        sum += amount;
        final target = _targetFor(changes, start) ?? goal.target;
        if (target > 0 && sum >= target) {
          met = true;
          result.add(ActivityEntry(
            kind: ActivityKind.goalMet,
            date: date,
            goal: goal,
            target: target,
          ));
        }
      }
    }
    return result;
  }

  /// The target in force for the period starting [start], as
  /// DatabaseHelper.getTargetForPeriod resolves it.
  static int? _targetFor(List<GoalTargetChange> changes, DateTime start) {
    int? target;
    for (final c in changes) {
      if (c.effectiveFrom.isAfter(start)) break;
      target = c.target;
    }
    return target;
  }

  // ── Badges ─────────────────────────────────────────────────────────────────

  /// When each badge tier was earned, found by replaying the reader's history
  /// in order through the same [kGoals] ladders the Achievements grid uses.
  ///
  /// Ratings and reviews carry no date of their own, so they count from the
  /// book's finish (or, unfinished, its add date) — when they're usually given.
  /// Finished books without a finish date can't be placed and are left out.
  static List<ActivityEntry> _badgeEntries(
    List<Map<String, dynamic>> books,
    List<Map<String, dynamic>> sessions,
  ) {
    final audiobookIds = <int>{};
    final steps = <(DateTime, void Function(_Tally))>[];

    for (final book in books) {
      final typeId = _int(book['book_type_id']);
      if (typeId == _audiobookTypeId) audiobookIds.add(_int(book['id']));

      final finished = _int(book['shelf_id']) == DatabaseHelper.shelfFinished
          ? _date(book['date_finished'])
          : null;
      final judged = finished ?? _date(book['date_added']);

      if (finished != null) {
        final pages = _int(book['page_count']);
        steps.add((finished, (t) => t.finish(typeId, pages)));
      }
      if (judged != null) {
        final rating = _double(book['rating']);
        if (rating != null && rating > 0) {
          steps.add((judged, (t) => t.rated++));
        }
        if ((book['user_review']?.toString().trim() ?? '').isNotEmpty) {
          steps.add((judged, (t) => t.reviews++));
        }
      }
    }

    for (final s in sessions) {
      final date = _date(s['date']);
      if (date == null) continue;
      final pages = _int(s['pages_read']);
      final minutes = _int(s['duration_minutes']);
      final isAudio = audiobookIds.contains(_int(s['book_id']));
      steps.add((date, (t) => t.session(date, pages, minutes, isAudio)));
    }

    steps.sort((a, b) => a.$1.compareTo(b.$1));

    final tally = _Tally();
    final reached = List.filled(kGoals.length, -1);
    final result = <ActivityEntry>[];

    for (final (date, apply) in steps) {
      apply(tally);
      final stats = tally.snapshot();
      for (var i = 0; i < kGoals.length; i++) {
        final idx = kGoals[i].achievedIndex(stats);
        if (idx <= reached[i]) continue;
        reached[i] = idx;
        // Several rungs at once (a first 1,200-page book) show as the top one.
        result.add(ActivityEntry(
          kind: ActivityKind.badge,
          date: date,
          badge: kGoals[i],
          tier: kGoals[i].tiers[idx],
        ));
      }
    }
    return result;
  }

  // ── Display ────────────────────────────────────────────────────────────────

  /// "Today", "Yesterday", "3d ago", then the date.
  static String dateLabel(DateTime date, [DateTime? now]) {
    now ??= DateTime.now();
    final days = _day(now).difference(_day(date)).inDays;
    if (days <= 0) return 'Today';
    if (days == 1) return 'Yesterday';
    if (days < 7) return '${days}d ago';
    if (date.year == now.year) return DateFormat('MMM d').format(date);
    return DateFormat('MMM d, y').format(date);
  }

  // ── Parsing ────────────────────────────────────────────────────────────────

  static const _audiobookTypeId = 4;

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  static int _int(dynamic v) =>
      v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;

  static double? _double(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '');

  static DateTime? _date(dynamic v) {
    final s = v?.toString();
    if (s == null || s.isEmpty) return null;
    return DateTime.tryParse(s);
  }
}

/// Running totals for the badge replay — the [ReadingStats] fields the badges
/// measure, built up one dated step at a time.
class _Tally {
  int books = 0;
  int audiobooks = 0;
  int ebooks = 0;
  int physical = 0;
  int maxBookPages = 0;
  int rated = 0;
  int reviews = 0;
  int sessions = 0;
  int pages = 0;
  int minutes = 0;
  int maxSessionPages = 0;
  int maxSessionMinutes = 0;
  int maxPph = 0;

  // Steps arrive in date order, so the week streak runs forward.
  int? _lastWeek;
  int _run = 0;
  int longestStreak = 0;

  static const _ebookTypeId = 3;
  static const _physicalTypeIds = {1, 2};

  void finish(int typeId, int bookPages) {
    books++;
    if (typeId == ReadingActivity._audiobookTypeId) {
      audiobooks++;
    } else if (typeId == _ebookTypeId) {
      ebooks++;
    } else if (_physicalTypeIds.contains(typeId)) {
      physical++;
    }
    if (bookPages > maxBookPages) maxBookPages = bookPages;
  }

  void session(DateTime date, int sessionPages, int sessionMinutes, bool isAudio) {
    sessions++;
    pages += sessionPages;
    minutes += sessionMinutes;
    if (sessionPages > maxSessionPages) maxSessionPages = sessionPages;
    if (sessionMinutes > maxSessionMinutes) maxSessionMinutes = sessionMinutes;
    // Same qualifying rule as ReadingStats.maxSessionPph.
    if (!isAudio && sessionMinutes >= 10 && sessionPages >= 10) {
      final pph = (sessionPages * 60 / sessionMinutes).round();
      if (pph > maxPph) maxPph = pph;
    }

    final week = ReadingStats.weekOrdinal(date);
    final last = _lastWeek;
    if (last == null || week > last + 1) {
      _run = 1;
    } else if (week == last + 1) {
      _run++;
    }
    _lastWeek = week;
    if (_run > longestStreak) longestStreak = _run;
  }

  ReadingStats snapshot() => ReadingStats(
        booksFinished: books,
        totalPagesRead: pages,
        totalMinutes: minutes,
        totalSessions: sessions,
        currentWeekStreak: 0,
        longestWeekStreak: longestStreak,
        booksThisYear: 0,
        pagesThisYear: 0,
        minutesThisYear: 0,
        reviewsWritten: reviews,
        ratedCount: rated,
        averageRating: 0,
        audiobooksFinished: audiobooks,
        ebooksFinished: ebooks,
        physicalFinished: physical,
        maxBookPages: maxBookPages,
        maxSessionPages: maxSessionPages,
        maxSessionMinutes: maxSessionMinutes,
        maxSessionPph: maxPph,
        readingSince: null,
      );
}
