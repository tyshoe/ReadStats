import 'package:intl/intl.dart';

/// A book finished inside the recap's month.
class RecapBook {
  final int id;
  final String title;
  final String author;

  /// 0 when the book is unrated.
  final double rating;
  final String? coverPath;
  final int? coverShape;
  final int pages;

  const RecapBook({
    required this.id,
    required this.title,
    required this.author,
    required this.rating,
    required this.coverPath,
    required this.coverShape,
    required this.pages,
  });

  RecapBook withCoverPath(String? path) => RecapBook(
        id: id,
        title: title,
        author: author,
        rating: rating,
        coverPath: path,
        coverShape: coverShape,
        pages: pages,
      );
}

/// One calendar month of reading, worked out from the book and session maps the
/// app already keeps in memory.
///
/// Distinct from both of the existing summaries: `ReadingStats` is the lifetime
/// identity view, and the Statistics page is a year-filtered analytical
/// breakdown. This is a single month, closed and comparable to the one before
/// it — which is what makes it worth announcing and worth sharing.
///
/// Nothing is stored: a month is recomputed from the same rows every time, so a
/// session edited long after the fact is reflected in that month's recap rather
/// than being frozen at whatever the numbers were on the 1st.
class MonthlyRecap {
  final int year;
  final int month;

  final int minutes;
  final int sessions;
  final int pages;

  /// Distinct days with at least one session.
  final int activeDays;

  /// Longest run of consecutive active days *within* the month.
  final int longestDayStreak;

  final int longestSessionMinutes;

  /// The day the most time was logged on, and how much.
  final DateTime? bestDay;
  final int bestDayMinutes;

  /// The book the most time went into this month.
  final String? topBookTitle;
  final String? topBookCoverPath;
  final int? topBookCoverShape;
  final int topBookMinutes;

  /// Books whose finish date falls in this month, newest first.
  final List<RecapBook> booksFinished;

  /// Average rating across the finished books that carry one.
  final double averageRating;

  /// Per day of the month, keyed by day number (1–31). Only days with reading
  /// are present, so a day missing from all three simply wasn't read on.
  ///
  /// Three of them because the daily chart can be read in any of the units the
  /// app records — a reader who logs pages and not time has nothing to see in
  /// [minutesByDay], and one who runs a timer without counting pages has
  /// nothing in [pagesByDay].
  final Map<int, int> minutesByDay;
  final Map<int, int> pagesByDay;
  final Map<int, int> sessionsByDay;

  // The month before, for the comparison lines. Zero when there was none.
  final int previousMinutes;
  final int previousSessions;
  final int previousPages;
  final int previousBooksFinished;

  const MonthlyRecap({
    required this.year,
    required this.month,
    required this.minutes,
    required this.sessions,
    required this.pages,
    required this.activeDays,
    required this.longestDayStreak,
    required this.longestSessionMinutes,
    required this.bestDay,
    required this.bestDayMinutes,
    required this.topBookTitle,
    required this.topBookCoverPath,
    required this.topBookCoverShape,
    required this.topBookMinutes,
    required this.booksFinished,
    required this.averageRating,
    required this.minutesByDay,
    required this.pagesByDay,
    required this.sessionsByDay,
    required this.previousMinutes,
    required this.previousSessions,
    required this.previousPages,
    required this.previousBooksFinished,
  });

  /// Day 0 of the next month is the last day of this one.
  int get daysInMonth => DateTime(year, month + 1, 0).day;

  int get booksFinishedCount => booksFinished.length;

  bool get isEmpty => sessions == 0 && booksFinished.isEmpty;

  /// A month still being written. Its numbers are a running total, so the page
  /// labels it rather than presenting it as a finished recap.
  bool get isInProgress {
    final now = DateTime.now();
    return now.year == year && now.month == month;
  }

  int get avgSessionMinutes => sessions == 0 ? 0 : (minutes / sessions).round();

  /// Per cent change in reading time against the previous month, or null when
  /// there is nothing to compare against — a first month can't be up or down.
  int? get minutesChangePercent {
    if (previousMinutes == 0) return null;
    return ((minutes - previousMinutes) / previousMinutes * 100).round();
  }

  int get booksChange => booksFinishedCount - previousBooksFinished;

  String get monthLabel => DateFormat('MMMM yyyy').format(DateTime(year, month));

  String get monthNameOnly => DateFormat('MMMM').format(DateTime(year, month));

  String get shortMonthLabel =>
      DateFormat('MMM yyyy').format(DateTime(year, month));

  /// Sortable identity for a month, used as the key for "already seen".
  int get key => monthKey(year, month);

  static int monthKey(int year, int month) => year * 100 + month;

  /// "12h 30m", or "45m" under an hour.
  static String formatMinutes(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours == 0) return '${mins}m';
    return mins == 0 ? '${hours}h' : '${hours}h ${mins}m';
  }

  // ── computation ────────────────────────────────────────────────────────────

  factory MonthlyRecap.forMonth({
    required List<Map<String, dynamic>> books,
    required List<Map<String, dynamic>> sessions,
    required int year,
    required int month,
  }) {
    final previous = DateTime(year, month - 1);
    final current = _MonthTotals.from(
        books: books, sessions: sessions, year: year, month: month);
    final before = _MonthTotals.from(
        books: books,
        sessions: sessions,
        year: previous.year,
        month: previous.month);

    // Longest run of consecutive days read, bounded by the month.
    final days = current.activeDays.toList()..sort();
    var longestRun = days.isEmpty ? 0 : 1;
    var run = 1;
    for (var i = 1; i < days.length; i++) {
      run = days[i] - days[i - 1] == 1 ? run + 1 : 1;
      if (run > longestRun) longestRun = run;
    }

    int? bestDayNumber;
    var bestDayMinutes = 0;
    current.minutesByDay.forEach((day, minutes) {
      if (minutes > bestDayMinutes) {
        bestDayMinutes = minutes;
        bestDayNumber = day;
      }
    });

    // The book the most minutes went into. Sessions without a duration still
    // can't win, so a month of untimed sessions simply has no top book.
    int? topBookId;
    var topBookMinutes = 0;
    current.minutesByBook.forEach((bookId, minutes) {
      if (minutes > topBookMinutes) {
        topBookMinutes = minutes;
        topBookId = bookId;
      }
    });
    Map<String, dynamic>? topBook;
    if (topBookId != null) {
      for (final book in books) {
        if (_asInt(book['id']) == topBookId) {
          topBook = book;
          break;
        }
      }
    }

    final rated =
        current.booksFinished.where((b) => b.rating > 0).toList(growable: false);

    return MonthlyRecap(
      year: year,
      month: month,
      minutes: current.minutes,
      sessions: current.sessions,
      pages: current.pages,
      activeDays: current.activeDays.length,
      longestDayStreak: longestRun,
      longestSessionMinutes: current.longestSessionMinutes,
      bestDay:
          bestDayNumber == null ? null : DateTime(year, month, bestDayNumber!),
      bestDayMinutes: bestDayMinutes,
      topBookTitle: topBook?['title']?.toString(),
      topBookCoverPath: topBook?['cover_path'] as String?,
      topBookCoverShape:
          topBook == null ? null : _asIntOrNull(topBook['cover_shape']),
      topBookMinutes: topBookMinutes,
      booksFinished: current.booksFinished,
      averageRating: rated.isEmpty
          ? 0
          : rated.map((b) => b.rating).reduce((a, b) => a + b) / rated.length,
      minutesByDay: current.minutesByDay,
      pagesByDay: current.pagesByDay,
      sessionsByDay: current.sessionsByDay,
      previousMinutes: before.minutes,
      previousSessions: before.sessions,
      previousPages: before.pages,
      previousBooksFinished: before.booksFinished.length,
    );
  }

  /// Every month that has something in it, newest first, with the current month
  /// always present so the page is never empty for someone reading right now.
  static List<DateTime> availableMonths({
    required List<Map<String, dynamic>> books,
    required List<Map<String, dynamic>> sessions,
  }) {
    final now = DateTime.now();
    final months = <int, DateTime>{
      monthKey(now.year, now.month): DateTime(now.year, now.month),
    };

    void add(DateTime? date) {
      if (date == null) return;
      months[monthKey(date.year, date.month)] = DateTime(date.year, date.month);
    }

    for (final session in sessions) {
      add(_asDate(session['date']));
    }
    for (final book in books) {
      add(_asDate(book['date_finished']));
    }

    final sorted = months.values.toList()
      ..sort((a, b) => b.compareTo(a));
    return sorted;
  }

  /// The month before [from] — the one a recap covers when it is announced on
  /// the 1st.
  static DateTime previousMonthOf(DateTime from) =>
      DateTime(from.year, from.month - 1);

  // ── parsing ────────────────────────────────────────────────────────────────
  //
  // Rows arrive as ints or strings depending on the column and the writer, the
  // same way ReadingStats treats these very maps.

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

/// One pass over the rows for a single month. Kept separate so the recap and
/// the month before it are gathered by exactly the same code.
class _MonthTotals {
  int minutes = 0;
  int sessions = 0;
  int pages = 0;
  int longestSessionMinutes = 0;
  final Set<int> activeDays = {};
  final Map<int, int> minutesByDay = {};
  final Map<int, int> pagesByDay = {};
  final Map<int, int> sessionsByDay = {};
  final Map<int, int> minutesByBook = {};
  final List<RecapBook> booksFinished = [];

  static _MonthTotals from({
    required List<Map<String, dynamic>> books,
    required List<Map<String, dynamic>> sessions,
    required int year,
    required int month,
  }) {
    final totals = _MonthTotals();

    for (final session in sessions) {
      final date = MonthlyRecap._asDate(session['date']);
      if (date == null || date.year != year || date.month != month) continue;

      final minutes = MonthlyRecap._asInt(session['duration_minutes']);
      final pages = MonthlyRecap._asInt(session['pages_read']);
      totals.sessions++;
      totals.minutes += minutes;
      totals.pages += pages;
      if (minutes > totals.longestSessionMinutes) {
        totals.longestSessionMinutes = minutes;
      }
      totals.activeDays.add(date.day);
      totals.minutesByDay[date.day] =
          (totals.minutesByDay[date.day] ?? 0) + minutes;
      totals.pagesByDay[date.day] =
          (totals.pagesByDay[date.day] ?? 0) + pages;
      totals.sessionsByDay[date.day] =
          (totals.sessionsByDay[date.day] ?? 0) + 1;
      final bookId = MonthlyRecap._asInt(session['book_id']);
      totals.minutesByBook[bookId] =
          (totals.minutesByBook[bookId] ?? 0) + minutes;
    }

    // Finished by date, not by shelf: a book can sit on any shelf, but the
    // finish date is what places it in a month. Matches how the Statistics page
    // counts finished books.
    final finished = <(DateTime, RecapBook)>[];
    for (final book in books) {
      final date = MonthlyRecap._asDate(book['date_finished']);
      if (date == null || date.year != year || date.month != month) continue;
      finished.add((
        date,
        RecapBook(
          id: MonthlyRecap._asInt(book['id']),
          title: book['title']?.toString() ?? '',
          author: book['author']?.toString() ?? '',
          rating: MonthlyRecap._asDouble(book['rating']),
          coverPath: book['cover_path'] as String?,
          coverShape: MonthlyRecap._asIntOrNull(book['cover_shape']),
          pages: MonthlyRecap._asInt(book['page_count']),
        )
      ));
    }
    finished.sort((a, b) => b.$1.compareTo(a.$1));
    totals.booksFinished.addAll(finished.map((e) => e.$2));

    return totals;
  }
}
