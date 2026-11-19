import 'package:intl/intl.dart';
import 'package:read_stats/data/models/book_type.dart';
import 'package:read_stats/data/models/shelf.dart';
import 'package:read_stats/data/utils/reading_clock.dart';
import 'package:read_stats/domain/reader_personality.dart';
import 'package:read_stats/domain/reading_stats.dart';

/// How a book was read. Paperback and hardback are one thing here — the
/// question Wrapped asks is "page, screen or voice", not which binding.
enum WrappedFormat { physical, ebook, audio }

/// Which unit a reader's year is best told in. Sessions carry minutes and pages
/// optionally, so a reader who only ever logs pages has no time to chart, and a
/// timer-only reader has no pages — the story follows what was recorded.
///
/// [books] is for a year logged only by finishing books, with no sessions.
enum WrappedMeasure { minutes, pages, sessions, books }

/// Why a book was named book of the year. Shown on the slide, so the choice is
/// never a mystery and never pretends to more than the data says.
enum BookOfYearReason { favorite, topRated, mostTime, onlyBook }

/// A book as Wrapped sees it: the row, plus what happened to it this year.
class WrappedBook {
  final int id;
  final String title;
  final String author;
  final String? narrator;

  /// 0 when unrated.
  final double rating;
  final bool isFavorite;
  final String? coverPath;
  final int? coverShape;

  /// 0 when the page count is unknown.
  final int pages;
  final WrappedFormat format;

  /// Null for a book read this year but not finished in it.
  final DateTime? finishedAt;
  final DateTime? startedAt;

  /// Session totals for this book inside the recapped year only.
  final int minutes;
  final int pagesRead;
  final int sessionCount;

  const WrappedBook({
    required this.id,
    required this.title,
    required this.author,
    required this.narrator,
    required this.rating,
    required this.isFavorite,
    required this.coverPath,
    required this.coverShape,
    required this.pages,
    required this.format,
    required this.finishedAt,
    required this.startedAt,
    required this.minutes,
    required this.pagesRead,
    required this.sessionCount,
  });

  bool get hasCover => coverPath != null && coverPath!.isNotEmpty;
  bool get isRated => rating > 0;

  /// Calendar days from start to finish, counting both ends — a book begun and
  /// finished on the same day took one day. Null when either date is missing
  /// or they are the wrong way round.
  int? get daysToFinish {
    final start = startedAt;
    final end = finishedAt;
    if (start == null || end == null) return null;
    final days = _epochDay(end) - _epochDay(start);
    if (days < 0) return null;
    return days + 1;
  }
}

/// A day-precise moment worth naming: when, how much, and in which book.
class WrappedMoment {
  final DateTime date;
  final int value;
  final WrappedBook? book;

  const WrappedMoment({required this.date, required this.value, this.book});
}

/// One calendar year of reading, worked out from the book and session maps the
/// app already keeps in memory — the same rows the monthly recap reads.
///
/// The rules for what belongs to the year:
///
/// * A book counts as finished in the year its finish date falls in, and only
///   if it isn't sitting on the Unfinished shelf — the book form lets a
///   did-not-finish keep a finish date, and that is not a completion.
/// * A session belongs to the year its start time falls in.
/// * Pages and minutes come from sessions. A book marked finished without any
///   sessions adds a book, not pages — see [displayPages] for the fallback.
///
/// Nothing is stored. Wrapped is recomputed from the rows each time it opens,
/// so an edit made in February to a December session is reflected.
class YearWrapped {
  final int year;

  /// True while [year] is the current year — the figures are a running total.
  final bool isInProgress;

  final int minutes;
  final int sessions;
  final int pages;

  /// Books finished in the year, oldest finish first.
  final List<WrappedBook> finished;

  /// Every book with a session in the year, finished or not.
  final List<WrappedBook> booksRead;

  /// Index 0 is January. Sessions-derived except [booksByMonth].
  final List<int> minutesByMonth;
  final List<int> pagesByMonth;
  final List<int> sessionsByMonth;
  final List<int> booksByMonth;

  final int activeDays;

  /// Every day with a session, at midnight local time.
  final Set<DateTime> readingDays;
  final int longestStreak;
  final DateTime? longestStreakStart;

  /// Distinct Monday-aligned weeks with a session, and how many weeks there
  /// were to read in — from the first session of the year to its end (or to
  /// today, for a year still running).
  final int activeWeeks;
  final int weeksSpanned;

  final WrappedMoment? longestSession;

  /// The day with the most of [primaryMeasure] in it.
  final WrappedMoment? bestDay;

  /// Keyed DateTime.monday..sunday.
  final Map<int, int> weekdayMinutes;
  final Map<int, int> weekdaySessions;

  /// Keyed by daypart index (see reading_clock.dart). Only sessions that carry
  /// a real start time — a midnight stamp is an import with no clock.
  final Map<int, int> daypartMinutes;
  final Map<int, int> daypartSessions;
  final int clockedSessions;

  /// Sessions with a duration.
  final int timedSessions;

  /// Pages and minutes from sessions on non-audiobooks where both were logged,
  /// which is the only honest basis for a reading speed.
  final int speedPages;
  final int speedMinutes;

  const YearWrapped({
    required this.year,
    required this.isInProgress,
    required this.minutes,
    required this.sessions,
    required this.pages,
    required this.finished,
    required this.booksRead,
    required this.minutesByMonth,
    required this.pagesByMonth,
    required this.sessionsByMonth,
    required this.booksByMonth,
    required this.activeDays,
    required this.readingDays,
    required this.longestStreak,
    required this.longestStreakStart,
    required this.activeWeeks,
    required this.weeksSpanned,
    required this.longestSession,
    required this.bestDay,
    required this.weekdayMinutes,
    required this.weekdaySessions,
    required this.daypartMinutes,
    required this.daypartSessions,
    required this.clockedSessions,
    required this.timedSessions,
    required this.speedPages,
    required this.speedMinutes,
  });

  // ── availability ───────────────────────────────────────────────────────────

  /// The current year's Wrapped opens on December 1st; every earlier year is
  /// always there. Before December the newest available year is last year.
  static bool isYearUnlocked(int year, {DateTime? now}) {
    final today = now ?? DateTime.now();
    if (year < today.year) return true;
    return year == today.year && today.month == 12;
  }

  /// Years with any reading in them that are unlocked, newest first.
  static List<int> availableYears({
    required List<Map<String, dynamic>> books,
    required List<Map<String, dynamic>> sessions,
    DateTime? now,
  }) {
    final years = <int>{};
    for (final s in sessions) {
      final d = _asDate(s['date']);
      if (d != null) years.add(d.year);
    }
    for (final b in books) {
      if (_asInt(b['shelf_id']) == Shelf.unfinished) continue;
      final d = _asDate(b['date_finished']);
      if (d != null) years.add(d.year);
    }
    return years.where((y) => isYearUnlocked(y, now: now)).toList()
      ..sort((a, b) => b.compareTo(a));
  }

  /// The year Wrapped is "about" right now: this year in December, otherwise
  /// last year.
  static int featuredYear({DateTime? now}) {
    final today = now ?? DateTime.now();
    return today.month == 12 ? today.year : today.year - 1;
  }

  // ── derived ────────────────────────────────────────────────────────────────

  bool get isEmpty => sessions == 0 && finished.isEmpty;

  int get booksFinished => finished.length;

  /// Pages across the year's finished books, for the reader who logs books but
  /// not sessions. Never added to [pages] — they are different figures.
  int get finishedBookPages =>
      finished.fold(0, (sum, b) => sum + (b.pages > 0 ? b.pages : 0));

  /// Session pages when there are any, else the finished books' page counts.
  /// [pagesAreFromBooks] says which, so the label can be honest about it.
  int get displayPages => pages > 0 ? pages : finishedBookPages;
  bool get pagesAreFromBooks => pages == 0 && finishedBookPages > 0;

  WrappedMeasure get primaryMeasure {
    if (minutes > 0) return WrappedMeasure.minutes;
    if (pages > 0) return WrappedMeasure.pages;
    if (sessions > 0) return WrappedMeasure.sessions;
    return WrappedMeasure.books;
  }

  List<int> byMonth(WrappedMeasure measure) => switch (measure) {
        WrappedMeasure.minutes => minutesByMonth,
        WrappedMeasure.pages => pagesByMonth,
        WrappedMeasure.sessions => sessionsByMonth,
        WrappedMeasure.books => booksByMonth,
      };

  /// Days the year has had so far — all of it, once it is over.
  int get daysElapsed {
    final start = DateTime.utc(year, 1, 1);
    final end = isInProgress
        ? DateTime.now()
        : DateTime(year, 12, 31);
    return _epochDay(end) - _epochDay(start) + 1;
  }

  /// The last month whose numbers are final. A month still being read can't be
  /// anyone's quietest.
  int get lastCompleteMonth => isInProgress ? DateTime.now().month - 1 : 12;

  /// The month reading started in this year, 1-based. Null for an empty year.
  int? get firstActiveMonth {
    for (var m = 0; m < 12; m++) {
      if (sessionsByMonth[m] > 0 || booksByMonth[m] > 0) return m + 1;
    }
    return null;
  }

  /// The month with the most of [primaryMeasure], 1-based. Ties go to the
  /// earlier month, so the answer is stable.
  int? get peakMonth {
    final values = byMonth(primaryMeasure);
    int? best;
    for (var m = 0; m < 12; m++) {
      if (values[m] > 0 && (best == null || values[m] > values[best - 1])) {
        best = m + 1;
      }
    }
    return best;
  }

  /// The month with the least reading, among the finished months since this
  /// year's reading began — someone who started in June didn't have a quiet
  /// February, they weren't here yet. Needs three months to compare.
  int? get quietestMonth {
    final first = firstActiveMonth;
    final last = lastCompleteMonth;
    final peak = peakMonth;
    if (first == null || peak == null || last - first + 1 < 3) return null;
    final values = byMonth(primaryMeasure);
    int? quiet;
    for (var m = first; m <= last; m++) {
      if (quiet == null || values[m - 1] < values[quiet - 1]) quiet = m;
    }
    return quiet == peak ? null : quiet;
  }

  int get activeMonths =>
      List.generate(12, (m) => sessionsByMonth[m] > 0 || booksByMonth[m] > 0)
          .where((v) => v)
          .length;

  int get avgSessionMinutes {
    if (timedSessions == 0) return 0;
    return (minutes / timedSessions).round();
  }

  /// Pages per hour across sessions where both were logged on a printed or
  /// ebook — audiobooks have no pages to turn.
  int get pagesPerHour =>
      speedMinutes == 0 ? 0 : (speedPages * 60 / speedMinutes).round();

  Map<WrappedFormat, int> get formatCounts {
    final counts = <WrappedFormat, int>{};
    for (final b in finished) {
      counts[b.format] = (counts[b.format] ?? 0) + 1;
    }
    return counts;
  }

  List<WrappedBook> get ratedBooks =>
      finished.where((b) => b.isRated).toList(growable: false);

  double get averageRating {
    final rated = ratedBooks;
    if (rated.isEmpty) return 0;
    return rated.fold<double>(0, (s, b) => s + b.rating) / rated.length;
  }

  /// Share of rated books at four stars or more, 0–1. Null under three rated
  /// books, where a percentage would be a grand word for one or two opinions.
  double? get highRatedShare {
    final rated = ratedBooks;
    if (rated.length < 3) return null;
    return rated.where((b) => b.rating >= 4).length / rated.length;
  }

  /// Average rating of books finished January–June against July–December.
  /// Null unless both halves have at least two rated books.
  (double, double)? get ratingHalves {
    final first = <double>[];
    final second = <double>[];
    for (final b in ratedBooks) {
      (b.finishedAt!.month <= 6 ? first : second).add(b.rating);
    }
    if (first.length < 2 || second.length < 2) return null;
    double avg(List<double> v) => v.reduce((a, b) => a + b) / v.length;
    return (avg(first), avg(second));
  }

  /// The one book the year is remembered by, and why it was picked.
  ///
  /// In order: a book marked favourite (highest rated among them), the highest
  /// rated book, the one the most time went into, and finally a lone finished
  /// book. With several finished books and no rating, favourite or timed
  /// session to tell them apart there is no honest pick, so there is none.
  (WrappedBook, BookOfYearReason)? get bookOfTheYear {
    if (finished.isEmpty) return null;

    int byRatingThenTime(WrappedBook a, WrappedBook b) {
      final r = b.rating.compareTo(a.rating);
      if (r != 0) return r;
      final t = b.minutes.compareTo(a.minutes);
      if (t != 0) return t;
      return b.finishedAt!.compareTo(a.finishedAt!);
    }

    final favorites = finished.where((b) => b.isFavorite).toList()
      ..sort(byRatingThenTime);
    if (favorites.isNotEmpty) {
      return (favorites.first, BookOfYearReason.favorite);
    }
    final rated = ratedBooks.toList()..sort(byRatingThenTime);
    if (rated.isNotEmpty) return (rated.first, BookOfYearReason.topRated);

    final timed = finished.where((b) => b.minutes > 0).toList()
      ..sort((a, b) => b.minutes.compareTo(a.minutes));
    if (timed.isNotEmpty) return (timed.first, BookOfYearReason.mostTime);

    if (finished.length == 1) {
      return (finished.first, BookOfYearReason.onlyBook);
    }
    return null;
  }

  /// Other books rated four stars or more, best first, book of the year left
  /// out. The supporting cast on the book-of-the-year slide.
  List<WrappedBook> get alsoLoved {
    final top = bookOfTheYear?.$1;
    final list = ratedBooks
        .where((b) => b.rating >= 4 && b.id != top?.id)
        .toList()
      ..sort((a, b) => b.rating.compareTo(a.rating));
    return list.take(3).toList(growable: false);
  }

  /// Finished books with a known page count, longest first.
  List<WrappedBook> get booksByLength {
    final list = finished.where((b) => b.pages > 0).toList()
      ..sort((a, b) => b.pages.compareTo(a.pages));
    return list;
  }

  WrappedBook? get longestBook {
    final list = booksByLength;
    return list.isEmpty ? null : list.first;
  }

  /// Only offered alongside the longest, so it needs a second book.
  WrappedBook? get shortestBook {
    final list = booksByLength;
    return list.length < 2 ? null : list.last;
  }

  /// The book the most reading time went into this year, finished or not.
  /// Needs a full hour to be worth naming.
  WrappedBook? get mostTimeBook {
    WrappedBook? best;
    for (final b in booksRead) {
      if (b.minutes > (best?.minutes ?? 0)) best = b;
    }
    return (best == null || best.minutes < 60) ? null : best;
  }

  /// The quickest start-to-finish among books with at least two sessions. The
  /// sessions are the evidence the dates are real: marking a book finished
  /// fills in a missing start date with the same day, which would otherwise
  /// make every book logged after the fact a one-day read.
  WrappedBook? get fastestFinish {
    final candidates = finished
        .where((b) => b.sessionCount >= 2 && b.daysToFinish != null)
        .toList();
    if (candidates.length < 2) return null;
    candidates.sort((a, b) => a.daysToFinish!.compareTo(b.daysToFinish!));
    return candidates.first;
  }

  /// The author with the most finished books, when that is at least two.
  (String, List<WrappedBook>)? get topAuthor =>
      _topBy(finished, (b) => b.author);

  /// The same for audiobook narrators.
  (String, List<WrappedBook>)? get topNarrator => _topBy(
      finished.where((b) => b.format == WrappedFormat.audio),
      (b) => b.narrator ?? '');

  static (String, List<WrappedBook>)? _topBy(
    Iterable<WrappedBook> books,
    String Function(WrappedBook) key,
  ) {
    final groups = <String, List<WrappedBook>>{};
    for (final b in books) {
      final k = key(b).trim();
      if (k.isEmpty) continue;
      groups.putIfAbsent(k, () => []).add(b);
    }
    final entries = groups.entries.where((e) => e.value.length >= 2).toList()
      ..sort((a, b) {
        final byCount = b.value.length.compareTo(a.value.length);
        if (byCount != 0) return byCount;
        int time(List<WrappedBook> l) => l.fold(0, (s, x) => s + x.minutes);
        final byTime = time(b.value).compareTo(time(a.value));
        return byTime != 0 ? byTime : a.key.compareTo(b.key);
      });
    if (entries.isEmpty) return null;
    return (entries.first.key, entries.first.value);
  }

  ReaderPersonality? get personality => ReaderPersonality.of(this);

  String monthName(int month) =>
      DateFormat('MMMM').format(DateTime(year, month));

  // ── formatting ─────────────────────────────────────────────────────────────

  /// "142h", "12h 30m", "45m" — hours carry the weight once there are many.
  static String formatMinutes(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours == 0) return '${mins}m';
    if (hours >= 100 || mins == 0) return '${hours}h';
    return '${hours}h ${mins}m';
  }

  static String formatNumber(int n) => NumberFormat('#,###').format(n);

  static String plural(int n, String one, [String? many]) =>
      '${formatNumber(n)} ${n == 1 ? one : (many ?? '${one}s')}';

  String formatMeasure(WrappedMeasure measure, int value) => switch (measure) {
        WrappedMeasure.minutes => formatMinutes(value),
        WrappedMeasure.pages => plural(value, 'page'),
        WrappedMeasure.sessions => plural(value, 'session'),
        WrappedMeasure.books => plural(value, 'book'),
      };

  // ── computation ────────────────────────────────────────────────────────────

  factory YearWrapped.forYear({
    required List<Map<String, dynamic>> books,
    required List<Map<String, dynamic>> sessions,
    required int year,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();

    final bookRows = <int, Map<String, dynamic>>{};
    for (final b in books) {
      bookRows[_asInt(b['id'])] = b;
    }

    WrappedFormat formatOfRow(Map<String, dynamic>? row) =>
        switch (_asInt(row?['book_type_id'])) {
          BookType.audiobook => WrappedFormat.audio,
          BookType.ebook => WrappedFormat.ebook,
          _ => WrappedFormat.physical,
        };

    final minutesByMonth = List.filled(12, 0);
    final pagesByMonth = List.filled(12, 0);
    final sessionsByMonth = List.filled(12, 0);
    final booksByMonth = List.filled(12, 0);

    final minutesByBook = <int, int>{};
    final pagesByBook = <int, int>{};
    final sessionsByBook = <int, int>{};

    final minutesByDay = <int, int>{}; // epoch day → minutes
    final pagesByDay = <int, int>{};
    final sessionsByDay = <int, int>{};
    final weeks = <int>{};

    final weekdayMinutes = <int, int>{};
    final weekdaySessions = <int, int>{};
    final daypartMinutes = <int, int>{};
    final daypartSessions = <int, int>{};

    var totalMinutes = 0;
    var totalPages = 0;
    var totalSessions = 0;
    var clocked = 0;
    var timed = 0;
    var speedPages = 0;
    var speedMinutes = 0;
    DateTime? firstSession;
    WrappedMoment? longest;
    int? longestBookId;

    for (final s in sessions) {
      final at = _asDate(s['date']);
      if (at == null || at.year != year) continue;

      final minutes = _asInt(s['duration_minutes']).clamp(0, 1 << 30);
      final pages = _asInt(s['pages_read']).clamp(0, 1 << 30);
      final bookId = _asInt(s['book_id']);
      final month = at.month - 1;
      final day = _epochDay(at);

      totalSessions++;
      totalMinutes += minutes;
      totalPages += pages;
      if (minutes > 0) timed++;

      minutesByMonth[month] += minutes;
      pagesByMonth[month] += pages;
      sessionsByMonth[month] += 1;

      minutesByBook[bookId] = (minutesByBook[bookId] ?? 0) + minutes;
      pagesByBook[bookId] = (pagesByBook[bookId] ?? 0) + pages;
      sessionsByBook[bookId] = (sessionsByBook[bookId] ?? 0) + 1;

      minutesByDay[day] = (minutesByDay[day] ?? 0) + minutes;
      pagesByDay[day] = (pagesByDay[day] ?? 0) + pages;
      sessionsByDay[day] = (sessionsByDay[day] ?? 0) + 1;
      weeks.add(ReadingStats.weekOrdinal(at));

      weekdayMinutes[at.weekday] = (weekdayMinutes[at.weekday] ?? 0) + minutes;
      weekdaySessions[at.weekday] = (weekdaySessions[at.weekday] ?? 0) + 1;
      if (hasRealClockTime(at)) {
        clocked++;
        final part = daypartOf(at.hour);
        daypartMinutes[part] = (daypartMinutes[part] ?? 0) + minutes;
        daypartSessions[part] = (daypartSessions[part] ?? 0) + 1;
      }

      if (formatOfRow(bookRows[bookId]) != WrappedFormat.audio &&
          minutes > 0 &&
          pages > 0) {
        speedPages += pages;
        speedMinutes += minutes;
      }

      if (minutes > (longest?.value ?? 0)) {
        longest = WrappedMoment(date: at, value: minutes);
        longestBookId = bookId;
      }
      if (firstSession == null || at.isBefore(firstSession)) {
        firstSession = at;
      }
    }

    WrappedBook buildBook(int id, Map<String, dynamic> row, DateTime? done) =>
        WrappedBook(
          id: id,
          title: row['title']?.toString() ?? '',
          author: row['author']?.toString() ?? '',
          narrator: row['narrator']?.toString(),
          rating: _asDouble(row['rating']),
          isFavorite: _asInt(row['is_favorite']) == 1,
          coverPath: row['cover_path'] as String?,
          coverShape: _asIntOrNull(row['cover_shape']),
          pages: _asInt(row['page_count']).clamp(0, 1 << 30),
          format: formatOfRow(row),
          finishedAt: done,
          startedAt: _asDate(row['date_started']),
          minutes: minutesByBook[id] ?? 0,
          pagesRead: pagesByBook[id] ?? 0,
          sessionCount: sessionsByBook[id] ?? 0,
        );

    final finished = <WrappedBook>[];
    final finishedIds = <int>{};
    for (final row in books) {
      final done = _asDate(row['date_finished']);
      if (done == null || done.year != year) continue;
      if (_asInt(row['shelf_id']) == Shelf.unfinished) continue;
      final id = _asInt(row['id']);
      finished.add(buildBook(id, row, done));
      finishedIds.add(id);
      booksByMonth[done.month - 1] += 1;
    }
    finished.sort((a, b) => a.finishedAt!.compareTo(b.finishedAt!));

    final booksRead = <WrappedBook>[
      ...finished.where((b) => b.sessionCount > 0),
      for (final id in sessionsByBook.keys)
        if (!finishedIds.contains(id) && bookRows[id] != null)
          buildBook(id, bookRows[id]!, null),
    ];

    if (longest != null) {
      WrappedBook? book;
      for (final b in booksRead) {
        if (b.id == longestBookId) book = b;
      }
      longest = WrappedMoment(
          date: longest.date, value: longest.value, book: book);
    }

    // Longest run of consecutive days, within the year.
    final days = sessionsByDay.keys.toList()..sort();
    var streak = days.isEmpty ? 0 : 1;
    var streakStart = days.isEmpty ? null : days.first;
    var run = 1;
    var runStart = days.isEmpty ? 0 : days.first;
    for (var i = 1; i < days.length; i++) {
      if (days[i] - days[i - 1] == 1) {
        run++;
      } else {
        run = 1;
        runStart = days[i];
      }
      if (run > streak) {
        streak = run;
        streakStart = runStart;
      }
    }

    // Best day, in whichever unit the year is told in.
    final dayValues = totalMinutes > 0
        ? minutesByDay
        : totalPages > 0
            ? pagesByDay
            : sessionsByDay;
    WrappedMoment? bestDay;
    for (final day in days) {
      final value = dayValues[day] ?? 0;
      if (value > (bestDay?.value ?? 0)) {
        bestDay = WrappedMoment(date: _fromEpochDay(day), value: value);
      }
    }

    var weeksSpanned = 0;
    if (firstSession != null) {
      final isCurrent = year == today.year;
      final end = isCurrent ? today : DateTime(year, 12, 31);
      weeksSpanned = ReadingStats.weekOrdinal(end) -
          ReadingStats.weekOrdinal(firstSession) +
          1;
    }

    return YearWrapped(
      year: year,
      isInProgress: year == today.year,
      minutes: totalMinutes,
      sessions: totalSessions,
      pages: totalPages,
      finished: List.unmodifiable(finished),
      booksRead: List.unmodifiable(booksRead),
      minutesByMonth: List.unmodifiable(minutesByMonth),
      pagesByMonth: List.unmodifiable(pagesByMonth),
      sessionsByMonth: List.unmodifiable(sessionsByMonth),
      booksByMonth: List.unmodifiable(booksByMonth),
      activeDays: days.length,
      readingDays: Set.unmodifiable(days.map(_fromEpochDay)),
      longestStreak: streak,
      longestStreakStart:
          streakStart == null ? null : _fromEpochDay(streakStart),
      activeWeeks: weeks.length,
      weeksSpanned: weeksSpanned,
      longestSession: longest,
      bestDay: bestDay,
      weekdayMinutes: weekdayMinutes,
      weekdaySessions: weekdaySessions,
      daypartMinutes: daypartMinutes,
      daypartSessions: daypartSessions,
      clockedSessions: clocked,
      timedSessions: timed,
      speedPages: speedPages,
      speedMinutes: speedMinutes,
    );
  }

  // ── parsing ────────────────────────────────────────────────────────────────
  //
  // Rows arrive as ints or strings depending on the column and the writer, the
  // same way MonthlyRecap and ReadingStats treat these maps.

  static int _asInt(dynamic v) =>
      v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;

  static int? _asIntOrNull(dynamic v) =>
      v is int ? v : int.tryParse(v?.toString() ?? '');

  static double _asDouble(dynamic v) => v is num
      ? v.toDouble()
      : double.tryParse(v?.toString() ?? '') ?? 0.0;

  static DateTime? _asDate(dynamic v) {
    final s = v?.toString();
    if (s == null || s.isEmpty) return null;
    return DateTime.tryParse(s);
  }
}

/// Whole days since the epoch, in UTC so a DST change can't move a date.
int _epochDay(DateTime d) =>
    DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;

DateTime _fromEpochDay(int day) {
  final utc = DateTime.fromMillisecondsSinceEpoch(day * 86400000, isUtc: true);
  return DateTime(utc.year, utc.month, utc.day);
}
