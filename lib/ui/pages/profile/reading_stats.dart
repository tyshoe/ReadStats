import '/data/database/database_helper.dart';

/// Book type ids (match the Settings book-type map / seed order).
const int _ebookTypeId = 3;
const int _audiobookTypeId = 4;
const Set<int> _physicalTypeIds = {1, 2}; // Paperback, Hardback

/// Lifetime, identity-level reading metrics derived from the user's books and
/// sessions. This is deliberately the *cumulative* view (who you are as a
/// reader) — distinct from the Statistics page, which handles time-bounded
/// analytical breakdowns.
class ReadingStats {
  final int booksFinished;
  final int totalPagesRead;
  final int totalMinutes;
  final int totalSessions;
  final int currentWeekStreak;
  final int longestWeekStreak;
  final int booksThisYear;
  final int pagesThisYear;
  final int minutesThisYear;
  final int reviewsWritten;
  final int ratedCount;
  final double averageRating;
  final int audiobooksFinished;
  final int ebooksFinished;
  final int physicalFinished;
  final int maxBookPages;
  final int maxSessionPages;
  final int maxSessionMinutes;
  final int maxSessionPph; // best pages-per-hour in a single qualifying session
  final DateTime? readingSince;

  const ReadingStats({
    required this.booksFinished,
    required this.totalPagesRead,
    required this.totalMinutes,
    required this.totalSessions,
    required this.currentWeekStreak,
    required this.longestWeekStreak,
    required this.booksThisYear,
    required this.pagesThisYear,
    required this.minutesThisYear,
    required this.reviewsWritten,
    required this.ratedCount,
    required this.averageRating,
    required this.audiobooksFinished,
    required this.ebooksFinished,
    required this.physicalFinished,
    required this.maxBookPages,
    required this.maxSessionPages,
    required this.maxSessionMinutes,
    required this.maxSessionPph,
    required this.readingSince,
  });

  int get totalHours => totalMinutes ~/ 60;
  int get hoursThisYear => minutesThisYear ~/ 60;

  bool get isEmpty =>
      booksFinished == 0 && totalSessions == 0 && totalPagesRead == 0;

  /// Compute the stats from the in-memory book and session maps that the app
  /// already passes between pages. Parsing is defensive because values may
  /// arrive as ints or strings depending on the source.
  factory ReadingStats.from({
    required List<Map<String, dynamic>> books,
    required List<Map<String, dynamic>> sessions,
  }) {
    final now = DateTime.now();

    var booksFinished = 0;
    var booksThisYear = 0;
    var reviewsWritten = 0;
    var ratedCount = 0;
    var ratingSum = 0.0;
    var audiobooksFinished = 0;
    var ebooksFinished = 0;
    var physicalFinished = 0;
    var maxBookPages = 0;
    DateTime? readingSince;
    // Audiobook sessions have no meaningful page count, so they're excluded
    // from the reading-speed badge below.
    final audiobookIds = <int>{};

    for (final book in books) {
      final typeId = _asInt(book['book_type_id']);
      final isAudiobook = typeId == _audiobookTypeId;
      if (isAudiobook) audiobookIds.add(_asInt(book['id']));

      final isFinished =
          _asInt(book['shelf_id']) == DatabaseHelper.shelfFinished;
      if (isFinished) {
        booksFinished++;
        if (isAudiobook) {
          audiobooksFinished++;
        } else if (typeId == _ebookTypeId) {
          ebooksFinished++;
        } else if (_physicalTypeIds.contains(typeId)) {
          physicalFinished++;
        }
        final pages = _asInt(book['page_count']);
        if (pages > maxBookPages) maxBookPages = pages;
        final finished = _asDate(book['date_finished']);
        if (finished != null && finished.year == now.year) booksThisYear++;
      }

      // "Reading since" anchors to the earliest sign of activity on any book,
      // not just finished ones. date_added is set on every insert, so this
      // stays stable instead of jumping when a book gains/loses a finish date.
      for (final key in const ['date_added', 'date_started', 'date_finished']) {
        final d = _asDate(book[key]);
        if (d != null) readingSince = _earliest(readingSince, d);
      }

      final rating = _asDouble(book['rating']);
      if (rating != null && rating > 0) {
        ratedCount++;
        ratingSum += rating;
      }

      final review = book['user_review']?.toString().trim() ?? '';
      if (review.isNotEmpty) reviewsWritten++;
    }

    var totalPages = 0;
    var totalMinutes = 0;
    var pagesThisYear = 0;
    var minutesThisYear = 0;
    var maxSessionPages = 0;
    var maxSessionMinutes = 0;
    var maxSessionPph = 0;
    final weeks = <int>{};

    for (final session in sessions) {
      final pages = _asInt(session['pages_read']);
      final minutes = _asInt(session['duration_minutes']);
      totalPages += pages;
      totalMinutes += minutes;
      if (pages > maxSessionPages) maxSessionPages = pages;
      if (minutes > maxSessionMinutes) maxSessionMinutes = minutes;

      // Reading speed (pages/hour): only count substantial, page-based sessions
      // so a tiny sliver (e.g. 1 page in 1 min) can't inflate the badge. Pages
      // are first-party data the reader can verify, unlike estimated word counts.
      final bookId = _asInt(session['book_id']);
      final isAudiobook = audiobookIds.contains(bookId);
      if (!isAudiobook && minutes >= 10 && pages >= 10) {
        final pph = (pages * 60 / minutes).round();
        if (pph > maxSessionPph) maxSessionPph = pph;
      }

      final date = _asDate(session['date']);
      if (date != null) {
        weeks.add(_weekOrdinal(date));
        if (date.year == now.year) {
          pagesThisYear += pages;
          minutesThisYear += minutes;
        }
        readingSince = _earliest(readingSince, date);
      }
    }

    return ReadingStats(
      booksFinished: booksFinished,
      totalPagesRead: totalPages,
      totalMinutes: totalMinutes,
      totalSessions: sessions.length,
      currentWeekStreak: _currentWeekStreak(weeks, now),
      longestWeekStreak: _longestWeekStreak(weeks),
      booksThisYear: booksThisYear,
      pagesThisYear: pagesThisYear,
      minutesThisYear: minutesThisYear,
      reviewsWritten: reviewsWritten,
      ratedCount: ratedCount,
      averageRating: ratedCount > 0 ? ratingSum / ratedCount : 0,
      audiobooksFinished: audiobooksFinished,
      ebooksFinished: ebooksFinished,
      physicalFinished: physicalFinished,
      maxBookPages: maxBookPages,
      maxSessionPages: maxSessionPages,
      maxSessionMinutes: maxSessionMinutes,
      maxSessionPph: maxSessionPph,
      readingSince: readingSince,
    );
  }

  // ── streak math (weeks) ────────────────────────────────────────────────────
  // Weeks suit book reading better than days: a session keeps the week alive,
  // so the streak rewards sustained habit without punishing a skipped day.

  /// Consecutive weeks read up to now. This week or last week keeps it alive.
  static int _currentWeekStreak(Set<int> weeks, DateTime now) {
    if (weeks.isEmpty) return 0;
    var w = _weekOrdinal(now);
    if (!weeks.contains(w)) w -= 1;
    var streak = 0;
    while (weeks.contains(w)) {
      streak++;
      w -= 1;
    }
    return streak;
  }

  /// Longest run of consecutive weeks ever achieved.
  static int _longestWeekStreak(Set<int> weeks) {
    if (weeks.isEmpty) return 0;
    final sorted = weeks.toList()..sort();
    var longest = 1;
    var run = 1;
    for (var i = 1; i < sorted.length; i++) {
      if (sorted[i] - sorted[i - 1] == 1) {
        run++;
      } else {
        run = 1;
      }
      if (run > longest) longest = run;
    }
    return longest;
  }

  // ── parsing helpers ────────────────────────────────────────────────────────

  static int _asInt(dynamic v) =>
      v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;

  static double? _asDouble(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '');

  static DateTime? _asDate(dynamic v) {
    final s = v?.toString();
    if (s == null || s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  static DateTime _earliest(DateTime? current, DateTime candidate) =>
      (current == null || candidate.isBefore(current)) ? candidate : current;

  /// Whole days since the Unix epoch, computed in UTC so daylight-saving
  /// transitions never shift a date across a boundary.
  static int _epochDay(DateTime d) =>
      DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;

  /// Monday-aligned week number (1970-01-05 was a Monday).
  static int _weekOrdinal(DateTime d) => (_epochDay(d) - 4) ~/ 7;
}
