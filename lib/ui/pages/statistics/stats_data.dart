import 'package:intl/intl.dart';
import 'package:read_stats/data/models/book.dart';
import 'package:read_stats/data/models/session.dart';
import 'package:read_stats/data/repositories/book_repository.dart';
import 'package:read_stats/data/repositories/session_repository.dart';
import 'package:read_stats/data/services/cover_service.dart';
import 'package:read_stats/data/utils/reading_clock.dart';

/// Immutable snapshot of everything the Statistics page renders for one year
/// filter. Computed in a single pass ([compute]) so the page reads from one
/// source of truth instead of many inline FutureBuilders.
class StatsData {
  final int year;
  final Map<String, dynamic> stats;
  final List<Map<String, dynamic>> bookTypeData;
  final List<Map<String, dynamic>> topAuthors;
  final Map<String, int> booksDist;
  final Map<String, int> sessionsDist;
  final Map<String, int> readingTimeDist;
  final Map<String, int> pagesDist;
  final Map<double, int> ratingDist;
  // Daily totals (keyed by date at midnight) that back the cumulative line.
  // Finer-grained than the *Dist maps so an influx within a month is visible.
  final Map<DateTime, int> booksDaily;
  final Map<DateTime, int> sessionsDaily;
  final Map<DateTime, int> readingTimeDaily;
  final Map<DateTime, int> pagesDaily;
  // When reading happens. Weekday keys are DateTime.monday..sunday, by
  // reading day — see [readingWeekday]. The clock grids break each weekday
  // into hour slots — see [emptyClockGrid]. Counts are kept alongside minutes
  // for readers who log pages but no time — see
  // `_StatisticsPageState._habitsUseMinutes`.
  final Map<int, int> weekdayMinutes;
  final Map<int, int> weekdaySessions;
  final List<List<int>> clockMinutes;
  final List<List<int>> clockSessions;

  const StatsData({
    required this.year,
    required this.stats,
    required this.bookTypeData,
    required this.topAuthors,
    required this.booksDist,
    required this.sessionsDist,
    required this.readingTimeDist,
    required this.pagesDist,
    required this.ratingDist,
    required this.booksDaily,
    required this.sessionsDaily,
    required this.readingTimeDaily,
    required this.pagesDaily,
    required this.weekdayMinutes,
    required this.weekdaySessions,
    required this.clockMinutes,
    required this.clockSessions,
  });

  /// What the page shows before the first load finishes.
  static final Map<String, dynamic> emptyStats = {
    'totalSessions': 0,
    'booksCompleted': 0,
    'highestRating': '-',
    'highestRatingBookTitle': '',
    'highestRatingCoverPath': null,
    'highestRatingBookId': null,
    'lowestRating': '-',
    'lowestRatingBookTitle': '',
    'lowestRatingCoverPath': null,
    'lowestRatingBookId': null,
    'averageRating': 0.0,
    'totalTimeSpent': '0m',
    'slowestReadTime': '0m',
    'slowestReadBookTitle': '',
    'slowestReadCoverPath': null,
    'slowestReadBookId': null,
    'fastestReadTime': '0m',
    'fastestReadBookTitle': '',
    'fastestReadCoverPath': null,
    'fastestReadBookId': null,
    'totalPagesRead': 0,
    'avgPagesPerMinute': 0.0,
    'averagePages': 0.0,
    'highestPages': 0,
    'highestPagesBookTitle': '',
    'highestPagesCoverPath': null,
    'highestPagesBookId': null,
    'lowestPages': 0,
    'lowestPagesBookTitle': '',
    'lowestPagesCoverPath': null,
    'lowestPagesBookId': null,
  };

  static Future<List<int>> fetchYears(
    SessionRepository sessionRepo,
    BookRepository bookRepo,
  ) async {
    final sessionYears = await sessionRepo.getSessionYears();
    final bookYears = await bookRepo.getBookYears();
    final combined = {...sessionYears, ...bookYears}.toList()
      ..sort((a, b) => b.compareTo(a));
    return combined;
  }

  /// Compute the entire page payload for [year] in a single pass: the six
  /// distinct queries run in parallel once, and all per-period distributions
  /// are derived in memory from the same session/book lists (instead of each
  /// chart re-querying the DB).
  static Future<StatsData> compute({
    required int year,
    required BookRepository bookRepo,
    required SessionRepository sessionRepo,
  }) async {
    final results = await Future.wait([
      sessionRepo.getSessions(yearFilter: year),
      bookRepo.getBooks(yearFilter: year),
      bookRepo.getAllBookStats(year),
      bookRepo.getBookCountsPerType(),
      bookRepo.getRatingDistribution(selectedYear: year),
    ]);
    final sessions = results[0] as List<Session>;
    final books = results[1] as List<Book>;
    final bookStats = results[2] as Map<String, dynamic>;
    final bookTypeData = results[3] as List<Map<String, dynamic>>;
    final ratingDist = results[4] as Map<double, int>;

    String periodKey(String date) {
      final d = DateTime.parse(date);
      return year == 0 ? d.year.toString() : DateFormat('MMM').format(d);
    }

    DateTime dayOf(String date) {
      final d = DateTime.parse(date);
      return DateTime(d.year, d.month, d.day);
    }

    int totalPagesRead = 0;
    int totalMinutes = 0;
    final sessionsDist = <String, int>{};
    final pagesDist = <String, int>{};
    final readingTimeDist = <String, int>{};
    final sessionsDaily = <DateTime, int>{};
    final pagesDaily = <DateTime, int>{};
    final readingTimeDaily = <DateTime, int>{};
    final weekdayMinutes = <int, int>{};
    final weekdaySessions = <int, int>{};
    final clockMinutes = emptyClockGrid();
    final clockSessions = emptyClockGrid();
    for (final s in sessions) {
      final pages = s.pagesRead ?? 0;
      final minutes = s.durationMinutes ?? 0;
      totalPagesRead += pages;
      totalMinutes += minutes;
      final key = periodKey(s.date);
      sessionsDist[key] = (sessionsDist[key] ?? 0) + 1;
      pagesDist[key] = (pagesDist[key] ?? 0) + pages;
      readingTimeDist[key] = (readingTimeDist[key] ?? 0) + minutes;
      final day = dayOf(s.date);
      sessionsDaily[day] = (sessionsDaily[day] ?? 0) + 1;
      pagesDaily[day] = (pagesDaily[day] ?? 0) + pages;
      readingTimeDaily[day] = (readingTimeDaily[day] ?? 0) + minutes;

      // A session's timestamp is when reading *started*. The small hours
      // count toward the night before, so a sitting begun at 11pm on Saturday
      // is all Saturday's.
      final at = DateTime.parse(s.date);
      final weekday = readingWeekday(at);
      weekdayMinutes[weekday] = (weekdayMinutes[weekday] ?? 0) + minutes;
      weekdaySessions[weekday] = (weekdaySessions[weekday] ?? 0) + 1;
      // A session timed at exactly midnight arrived without a time, and would
      // pile a spike onto Night that nobody actually read. The day is still
      // real, so only the clock grid skips them.
      if (hasRealClockTime(at)) {
        addToClockGrids(
          at,
          minutes,
          minuteGrid: clockMinutes,
          sessionGrid: clockSessions,
        );
      }
    }

    final booksDist = <String, int>{};
    final booksDaily = <DateTime, int>{};
    final authorCounts = <String, int>{};
    for (final b in books) {
      if (b.dateFinished != null) {
        final key = periodKey(b.dateFinished!);
        booksDist[key] = (booksDist[key] ?? 0) + 1;
        final day = dayOf(b.dateFinished!);
        booksDaily[day] = (booksDaily[day] ?? 0) + 1;

        final author = b.author.trim();
        if (author.isNotEmpty) {
          authorCounts[author] = (authorCounts[author] ?? 0) + 1;
        }
      }
    }

    // Top 5 authors by finished-book count (ties broken alphabetically so the
    // order is stable across recomputes).
    final topAuthors = authorCounts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });
    final topAuthorsData = topAuthors
        .take(5)
        .map((e) => {'name': e.key, 'book_count': e.value})
        .toList();

    Future<String?> resolveCover(dynamic raw) async {
      if (raw == null) return null;
      final path = raw as String;
      if (path.isEmpty) return null;
      return CoverService.resolveFullPath(path);
    }

    final covers = await Future.wait([
      resolveCover(bookStats['highest_rating_cover_path']),
      resolveCover(bookStats['lowest_rating_cover_path']),
      resolveCover(bookStats['highest_pages_cover_path']),
      resolveCover(bookStats['lowest_pages_cover_path']),
      resolveCover(bookStats['slowest_read_cover_path']),
      resolveCover(bookStats['fastest_read_cover_path']),
    ]);

    final stats = <String, dynamic>{
      'totalSessions': sessions.length,
      'totalPagesRead': totalPagesRead,
      'totalTimeSpent': formatMinutes(totalMinutes),
      'avgPagesPerMinute': totalMinutes > 0
          ? totalPagesRead / totalMinutes
          : 0.0,
      'highestRating': bookStats['highest_rating'] ?? 0,
      'highestRatingBookTitle': bookStats['highest_rating_book_title'],
      'highestRatingCoverPath': covers[0],
      'highestRatingCoverShape': bookStats['highest_rating_cover_shape'],
      'highestRatingBookId': bookStats['highest_rating_book_id'],
      'lowestRating': bookStats['lowest_rating'] ?? 0,
      'lowestRatingBookTitle': bookStats['lowest_rating_book_title'],
      'lowestRatingCoverPath': covers[1],
      'lowestRatingCoverShape': bookStats['lowest_rating_cover_shape'],
      'lowestRatingBookId': bookStats['lowest_rating_book_id'],
      'averageRating': bookStats['average_rating'] ?? 0,
      'highestPages': bookStats['highest_pages'] ?? 0,
      'highestPagesBookTitle': bookStats['highest_pages_book_title'],
      'highestPagesCoverPath': covers[2],
      'highestPagesCoverShape': bookStats['highest_pages_cover_shape'],
      'highestPagesBookId': bookStats['highest_pages_book_id'],
      'lowestPages': bookStats['lowest_pages'] ?? 0,
      'lowestPagesBookTitle': bookStats['lowest_pages_book_title'],
      'lowestPagesCoverPath': covers[3],
      'lowestPagesCoverShape': bookStats['lowest_pages_cover_shape'],
      'lowestPagesBookId': bookStats['lowest_pages_book_id'],
      'averagePages': bookStats['average_pages'] ?? 0,
      'slowestReadTime': formatMinutes(bookStats['slowest_read_time'] ?? 0),
      'slowestReadBookTitle': bookStats['slowest_read_book_title'],
      'slowestReadCoverPath': covers[4],
      'slowestReadCoverShape': bookStats['slowest_read_cover_shape'],
      'slowestReadBookId': bookStats['slowest_read_book_id'],
      'fastestReadTime': formatMinutes(bookStats['fastest_read_time'] ?? 0),
      'fastestReadBookTitle': bookStats['fastest_read_book_title'],
      'fastestReadCoverPath': covers[5],
      'fastestReadCoverShape': bookStats['fastest_read_cover_shape'],
      'fastestReadBookId': bookStats['fastest_read_book_id'],
      'booksCompleted': bookStats['books_completed'] ?? 0,
    };

    return StatsData(
      year: year,
      stats: stats,
      bookTypeData: bookTypeData,
      topAuthors: topAuthorsData,
      booksDist: booksDist,
      sessionsDist: sessionsDist,
      readingTimeDist: readingTimeDist,
      pagesDist: pagesDist,
      ratingDist: ratingDist,
      booksDaily: booksDaily,
      sessionsDaily: sessionsDaily,
      readingTimeDaily: readingTimeDaily,
      pagesDaily: pagesDaily,
      weekdayMinutes: weekdayMinutes,
      weekdaySessions: weekdaySessions,
      clockMinutes: clockMinutes,
      clockSessions: clockSessions,
    );
  }

  static String formatMinutes(int minutes) {
    if (minutes < 60) return "${minutes}m";

    final hours = minutes ~/ 60;
    final mins = minutes % 60;

    if (hours < 24) {
      return mins == 0 ? "${hours}h" : "${hours}h ${mins}m";
    }

    // Handle days
    final days = hours ~/ 24;
    final remainingHours = hours % 24;

    String result = "${days}d";
    if (remainingHours > 0) result += " ${remainingHours}h";
    if (mins > 0) result += " ${mins}m";

    return result;
  }
}
