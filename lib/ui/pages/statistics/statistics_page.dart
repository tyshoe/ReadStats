import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:read_stats/data/services/cover_service.dart';
import 'package:read_stats/ui/pages/statistics/widgets/activity_heatmap.dart';
import 'package:read_stats/ui/pages/statistics/widgets/bar_chart_single.dart';
import 'package:read_stats/ui/pages/statistics/widgets/pie_chart.dart';
import 'package:read_stats/ui/pages/statistics/widgets/stacked_bar_chart.dart';
import 'package:read_stats/ui/pages/statistics/widgets/top_authors_chart.dart';
import 'package:read_stats/ui/pages/statistics/widgets/rating_summary.dart';
import 'package:read_stats/ui/pages/statistics/widgets/stat_card.dart';
import '../../../data/models/book.dart';
import '/data/repositories/session_repository.dart';
import '/data/repositories/book_repository.dart';
import '/data/repositories/tag_repository.dart';
import '/data/models/session.dart';
import '/data/database/database_helper.dart';
import '/viewmodels/SettingsViewModel.dart';
import '/ui/pages/library/widgets/book_detail_sheet.dart';
import '/ui/pages/library/book_form_page.dart';
import '/ui/pages/sessions/session_form_page.dart';
import '/ui/pages/sessions/widgets/rate_book_dialog.dart';

/// Immutable snapshot of everything the Statistics page renders for one year
/// filter. Computed in a single pass ([_StatisticsPageState._compute]) so the
/// page reads from one source of truth instead of many inline FutureBuilders.
class StatsData {
  final int year;
  final Map<String, dynamic> stats;
  final List<Map<String, dynamic>> shelfData;
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

  const StatsData({
    required this.year,
    required this.stats,
    required this.shelfData,
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
  });
}

class StatisticsPage extends StatefulWidget {
  final BookRepository bookRepository;
  final SessionRepository sessionRepository;
  final SettingsViewModel settingsViewModel;

  const StatisticsPage({
    super.key,
    required this.bookRepository,
    required this.sessionRepository,
    required this.settingsViewModel,
  });

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();

  /// Warm the stats cache at app startup so the first Statistics visit paints
  /// complete instead of computing after navigation. [year] is the persisted
  /// year filter so the warmed payload matches what the page will show.
  static Future<void> preload({
    required BookRepository bookRepo,
    required SessionRepository sessionRepo,
    required int year,
  }) async {
    final years = await _StatisticsPageState._fetchYears(sessionRepo, bookRepo);
    _StatisticsPageState._cachedYears = years;
    final y = (year != 0 && !years.contains(year)) ? 0 : year;
    _StatisticsPageState._cachedData = await _StatisticsPageState._compute(
      year: y,
      bookRepo: bookRepo,
      sessionRepo: sessionRepo,
    );
  }
}

class _StatisticsPageState extends State<StatisticsPage> {
  int selectedYear = 0;
  String _chartStyle = 'bars';

  bool get _cumulative => _chartStyle == 'cumulative';

  // The Statistics tab is rebuilt on every nav switch and recomputes from the
  // DB. Cache the last-computed payload (and available years) across instances
  // so a revisit paints immediately and just refreshes in the background,
  // instead of every chart popping in after the page appears.
  static List<int>? _cachedYears;
  static StatsData? _cachedData;

  List<int>? _years = _cachedYears;
  StatsData? _data = _cachedData;

  static final Map<String, dynamic> _defaultStats = {
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

  Map<String, dynamic> get _stats => _data?.stats ?? _defaultStats;

  @override
  void initState() {
    super.initState();
    selectedYear = widget.settingsViewModel.statsYearFilterNotifier.value;
    _chartStyle = widget.settingsViewModel.statsChartStyleNotifier.value;
    WidgetsBinding.instance.addPostFrameCallback((_) => loadStats());
  }

  /// Single entry point for (re)loading the page: refresh the available years,
  /// validate the selected year, then recompute the full payload in one pass.
  /// Previously loaded data stays on screen while the new data loads (no flash).
  Future<void> loadStats() async {
    final years =
        await _fetchYears(widget.sessionRepository, widget.bookRepository);
    _cachedYears = years;
    if (mounted) setState(() => _years = years);

    // Safeguard: if the saved year no longer has any data, fall back to All.
    if (selectedYear != 0 && !years.contains(selectedYear)) {
      selectedYear = 0;
      widget.settingsViewModel.setStatsYearFilter(0);
    }

    final data = await _compute(
      year: selectedYear,
      bookRepo: widget.bookRepository,
      sessionRepo: widget.sessionRepository,
    );
    _cachedData = data;
    if (!mounted) return;
    setState(() => _data = data);
  }

  static Future<List<int>> _fetchYears(
      SessionRepository sessionRepo, BookRepository bookRepo) async {
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
  static Future<StatsData> _compute({
    required int year,
    required BookRepository bookRepo,
    required SessionRepository sessionRepo,
  }) async {
    final results = await Future.wait([
      sessionRepo.getSessions(yearFilter: year),
      bookRepo.getBooks(yearFilter: year),
      bookRepo.getAllBookStats(year),
      bookRepo.getBookCountsPerShelf(),
      bookRepo.getBookCountsPerType(),
      bookRepo.getRatingDistribution(selectedYear: year),
    ]);
    final sessions = results[0] as List<Session>;
    final books = results[1] as List<Book>;
    final bookStats = results[2] as Map<String, dynamic>;
    final shelfData = results[3] as List<Map<String, dynamic>>;
    final bookTypeData = results[4] as List<Map<String, dynamic>>;
    final ratingDist = results[5] as Map<double, int>;

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
      'totalTimeSpent': _formatMinutes(totalMinutes),
      'avgPagesPerMinute': totalMinutes > 0 ? totalPagesRead / totalMinutes : 0.0,
      'highestRating': bookStats['highest_rating'] ?? 0,
      'highestRatingBookTitle': bookStats['highest_rating_book_title'],
      'highestRatingCoverPath': covers[0],
      'highestRatingBookId': bookStats['highest_rating_book_id'],
      'lowestRating': bookStats['lowest_rating'] ?? 0,
      'lowestRatingBookTitle': bookStats['lowest_rating_book_title'],
      'lowestRatingCoverPath': covers[1],
      'lowestRatingBookId': bookStats['lowest_rating_book_id'],
      'averageRating': bookStats['average_rating'] ?? 0,
      'highestPages': bookStats['highest_pages'] ?? 0,
      'highestPagesBookTitle': bookStats['highest_pages_book_title'],
      'highestPagesCoverPath': covers[2],
      'highestPagesBookId': bookStats['highest_pages_book_id'],
      'lowestPages': bookStats['lowest_pages'] ?? 0,
      'lowestPagesBookTitle': bookStats['lowest_pages_book_title'],
      'lowestPagesCoverPath': covers[3],
      'lowestPagesBookId': bookStats['lowest_pages_book_id'],
      'averagePages': bookStats['average_pages'] ?? 0,
      'slowestReadTime': _formatMinutes(bookStats['slowest_read_time'] ?? 0),
      'slowestReadBookTitle': bookStats['slowest_read_book_title'],
      'slowestReadCoverPath': covers[4],
      'slowestReadBookId': bookStats['slowest_read_book_id'],
      'fastestReadTime': _formatMinutes(bookStats['fastest_read_time'] ?? 0),
      'fastestReadBookTitle': bookStats['fastest_read_book_title'],
      'fastestReadCoverPath': covers[5],
      'fastestReadBookId': bookStats['fastest_read_book_id'],
      'booksCompleted': bookStats['books_completed'] ?? 0,
    };

    return StatsData(
      year: year,
      stats: stats,
      shelfData: shelfData,
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
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withAlpha(120),
              letterSpacing: 1.2,
            ),
      ),
    );
  }

  List<Widget> _spaced(List<Widget> children, {double gap = 8, double sectionGap = 20}) {
    final result = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      result.add(children[i]);
      if (i < children.length - 1) {
        final isNextSection = children[i + 1] is Padding;
        result.add(SizedBox(height: isNextSection ? sectionGap : gap));
      }
    }
    return result;
  }

  Widget _buildPair(Widget left, Widget right) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: left),
          const SizedBox(width: 8),
          Expanded(child: right),
        ],
      ),
    );
  }

  static String _formatMinutes(int minutes) {
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

  String _shortFormatMinutes(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    return '${hours}h';
  }

  Widget _buildReadingTimeChart() {
    final data = _data!.readingTimeDist;
    final activeMinutes = data.values.where((v) => v > 0).toList();
    final avgMinutes = activeMinutes.isEmpty
        ? '0'
        : _shortFormatMinutes(
            (activeMinutes.reduce((a, b) => a + b) / activeMinutes.length)
                .round());
    return BarChartWidget(
      data: data,
      selectedYear: selectedYear,
      barColor: Theme.of(context).primaryColor,
      title: 'Reading Time',
      subtitleValue: _stats['totalTimeSpent'],
      averageValue: avgMinutes,
      averageLabel: selectedYear == 0 ? 'Avg/year' : 'Avg/month',
      shortFormatter: _shortFormatMinutes,
      tooltipFormatter: _formatMinutes,
      cumulative: _cumulative,
      dailyData: _data!.readingTimeDaily,
    );
  }

  Widget _buildPagesChart() {
    final data = _data!.pagesDist;
    final activePages = data.values.where((v) => v > 0).toList();
    final avgPages = activePages.isEmpty
        ? '0'
        : NumberFormat('#,###').format(
            (activePages.reduce((a, b) => a + b) / activePages.length).round());
    return BarChartWidget(
      data: data,
      selectedYear: selectedYear,
      barColor: Theme.of(context).primaryColor,
      title: 'Pages Read',
      subtitleValue: NumberFormat('#,###').format(_stats['totalPagesRead']),
      averageValue: avgPages,
      averageLabel: selectedYear == 0 ? 'Avg/year' : 'Avg/month',
      cumulative: _cumulative,
      dailyData: _data!.pagesDaily,
    );
  }

  String _formatAverage(Map<String, int> data) {
    final active = data.values.where((v) => v > 0).toList();
    if (active.isEmpty) return '0';
    return (active.reduce((a, b) => a + b) / active.length).round().toString();
  }

  Widget _buildBooksChart() {
    final data = _data!.booksDist;
    return BarChartWidget(
      data: data,
      selectedYear: selectedYear,
      barColor: Theme.of(context).primaryColor,
      title: 'Books Finished',
      subtitleValue: _stats['booksCompleted'].toString(),
      averageValue: _formatAverage(data),
      averageLabel: selectedYear == 0 ? 'Avg/year' : 'Avg/month',
      cumulative: _cumulative,
      dailyData: _data!.booksDaily,
    );
  }

  Widget _buildActivityHeatmap() {
    return ActivityHeatmap(
      dailyCounts: _data!.sessionsDaily,
      selectedYear: selectedYear,
      color: Theme.of(context).primaryColor,
    );
  }

  Widget _buildSessionsChart() {
    final data = _data!.sessionsDist;
    return BarChartWidget(
      data: data,
      selectedYear: selectedYear,
      barColor: Theme.of(context).primaryColor,
      title: 'Sessions',
      subtitleValue: _stats['totalSessions'].toString(),
      averageValue: _formatAverage(data),
      averageLabel: selectedYear == 0 ? 'Avg/year' : 'Avg/month',
      cumulative: _cumulative,
      dailyData: _data!.sessionsDaily,
    );
  }

  /// Returns [candidate] unchanged unless its hue is within [threshold]
  /// degrees of [primary], in which case it rotates the hue 120° away.
  Color _safeColor(Color candidate, Color primary, {double threshold = 30.0}) {
    final primaryHue = HSLColor.fromColor(primary).hue;
    final candidateHSL = HSLColor.fromColor(candidate);
    final diff = (primaryHue - candidateHSL.hue).abs();
    final distance = diff > 180 ? 360 - diff : diff;
    if (distance < threshold) {
      final newHue = (candidateHSL.hue + 120) % 360;
      return candidateHSL.withHue(newHue).toColor();
    }
    return candidate;
  }

  static const _typeIcons = {
    'Paperback': Icons.menu_book,
    'Hardback':  Icons.auto_stories,
    'EBook':     Icons.tablet_android,
    'Audiobook': Icons.headphones,
  };

  Widget _buildBookTypeChart() {
    return PieChartWidget(
      title: 'Book Formats',
      data: _data!.bookTypeData,
      icons: _typeIcons,
      sortByCount: true,
      colors: {
        'Paperback':  Theme.of(context).primaryColor,
        'Hardback':   _safeColor(const Color(0xFF9575CD), Theme.of(context).primaryColor),
        'EBook':      _safeColor(const Color(0xFF4CAF50), Theme.of(context).primaryColor),
        'Audiobook':  _safeColor(const Color(0xFFFF9800), Theme.of(context).primaryColor),
      },
    );
  }

  Widget _buildShelfChart() {
    final primary = Theme.of(context).primaryColor;
    const shelfOrder = ['Want to Read', 'Currently Reading', 'Finished', 'Unfinished'];
    final sorted = [..._data!.shelfData]..sort((a, b) {
        final ai = shelfOrder.indexOf(a['name'] as String);
        final bi = shelfOrder.indexOf(b['name'] as String);
        return (ai == -1 ? 999 : ai).compareTo(bi == -1 ? 999 : bi);
      });
    return StackedBarChartWidget(
      title: 'Library Shelves',
      data: sorted,
      colors: {
        'Currently Reading': primary,
        'Want to Read':      _safeColor(const Color(0xFF9575CD), primary),
        'Finished':          _safeColor(const Color(0xFF4CAF50), primary),
        'Unfinished':        _safeColor(const Color(0xFFFF9800), primary),
      },
    );
  }

  /// Compact segmented control (bars / cumulative line) that flips how every
  /// time-series chart on the page is drawn. Persisted like the year filter.
  Widget _buildChartStyleToggle() {
    final theme = Theme.of(context);

    Widget segment(IconData icon, String style, String tooltip) {
      final selected = _chartStyle == style;
      return Tooltip(
        message: tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (_chartStyle == style) return;
            setState(() => _chartStyle = style);
            widget.settingsViewModel.setStatsChartStyle(style);
          },
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: selected
                  ? theme.colorScheme.primaryContainer
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              size: 16,
              color: selected
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.onSurface.withAlpha(140),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          segment(Icons.bar_chart, 'bars', 'Per-period bars'),
          segment(Icons.show_chart, 'cumulative', 'Cumulative total'),
        ],
      ),
    );
  }

  Widget _buildTopAuthorsChart() {
    return TopAuthorsChart(
      title: 'Top Authors',
      data: _data!.topAuthors,
    );
  }

  Widget _buildRatingSummary() {
    return RatingSummaryWidget(
      ratingData: _data!.ratingDist,
      selectedYear: selectedYear,
      title: 'My Ratings',
    );
  }

  void _onStatCardTap(int? bookId) async {
    if (bookId == null) return;
    final book = await widget.bookRepository.getBookById(bookId);
    if (book == null || !mounted) return;

    final mutableBook = Map<String, dynamic>.from(book);
    final rawCover = mutableBook['cover_path'];
    if (rawCover != null && (rawCover as String).isNotEmpty) {
      mutableBook['cover_path'] = await CoverService.resolveFullPath(rawCover);
    }

    BookPopup.showBookPopup(
      context,
      mutableBook,
      widget.settingsViewModel.defaultRatingStyleNotifier.value,
      widget.settingsViewModel.defaultDateFormatNotifier.value,
      _navigateToEditBookPage,
      _navigateToAddSessionPage,
      _confirmDelete,
      TagRepository(DatabaseHelper()),
      BookRepository(DatabaseHelper()),
      widget.settingsViewModel,
      refreshCallback: loadStats,
      isPinned: false,
      onTogglePin: (_) {},
    );
  }

  void _navigateToEditBookPage(Map<String, dynamic>? book) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookFormPage(
          onSave: (_) async => loadStats(),
          settingsViewModel: widget.settingsViewModel,
          book: book,
        ),
      ),
    );
  }

  void _navigateToAddSessionPage(Map<String, dynamic> book) async {
    final books = await widget.bookRepository.getBooks();
    if (!mounted) return;
    final finishedBook = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => SessionFormPage(
          availableBooks: books.map((b) => b.toMap()).toList(),
          book: book,
          onSave: loadStats,
          settingsViewModel: widget.settingsViewModel,
          sessionRepository: widget.sessionRepository,
          bookRepository: widget.bookRepository,
        ),
      ),
    );

    if (finishedBook != null && mounted) {
      await showRatingDialogForBook(
        context: context,
        book: finishedBook,
        bookRepository: widget.bookRepository,
        settingsViewModel: widget.settingsViewModel,
      );
      if (mounted) loadStats();
    }
  }

  void _confirmDelete(int bookId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Book'),
        content: const Text('Are you sure you want to delete this book and all its sessions?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              // Repository delete also removes the stored cover image file.
              await widget.bookRepository.deleteBook(bookId);
              if (mounted) Navigator.pop(context);
              loadStats();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  double _statsDividerOpacity = 0;

  // Fade a hairline in under the pinned year-filter row once the stats content
  // scrolls beneath it, matching the bottom nav line. Keeps the app bar flush.
  bool _onStatsScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;
    final raw = (n.metrics.pixels / 12).clamp(0.0, 1.0);
    final stepped = (raw * 8).round() / 8;
    if (stepped != _statsDividerOpacity) {
      setState(() => _statsDividerOpacity = stepped);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 40,
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: _onStatsScroll,
        child: Column(
        children: [
          // Year selection row
          if (_years != null)
            Builder(builder: (context) {
              final allYears = [0, ..._years!];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 32,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          itemCount: allYears.length,
                          itemBuilder: (context, index) {
                            final year = allYears[index];
                            final isSelected = selectedYear == year;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: FilterChip(
                                label: Text(year == 0 ? 'All' : year.toString()),
                                selected: isSelected,
                                onSelected: (_) {
                                  setState(() => selectedYear = year);
                                  widget.settingsViewModel.setStatsYearFilter(year);
                                  loadStats();
                                },
                                showCheckmark: false,
                                labelStyle: theme.textTheme.bodySmall,
                                labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                selectedColor: theme.colorScheme.primaryContainer,
                                elevation: 0,
                                pressElevation: 0,
                                side: BorderSide.none,
                                shape: const StadiumBorder(),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildChartStyleToggle(),
                    const SizedBox(width: 8),
                  ],
                ),
              );
            }),

          Divider(
            height: .5,
            thickness: .25,
            color: theme.dividerColor
                .withAlpha((128 * _statsDividerOpacity).round()),
          ),
          // Statistics content
          Expanded(
            child: _data == null
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _spaced([
                  _buildSectionHeader('Overview'),
                  _buildShelfChart(),
                  _buildBookTypeChart(),
                  _buildBooksChart(),
                  _buildSessionsChart(),
                  _buildActivityHeatmap(),
                  _buildTopAuthorsChart(),
                  _buildSectionHeader('Ratings'),
                  _buildRatingSummary(),
                  _buildPair(
                    StatCard(
                      title: 'Lowest Rating',
                      value: _stats['lowestRating'].toString(),
                      bookTitle: _stats['lowestRatingBookTitle'],
                      coverPath: _stats['lowestRatingCoverPath'],
                      onTap: () => _onStatCardTap(_stats['lowestRatingBookId']),
                    ),
                    StatCard(
                      title: 'Highest Rating',
                      value: _stats['highestRating'].toString(),
                      bookTitle: _stats['highestRatingBookTitle'],
                      coverPath: _stats['highestRatingCoverPath'],
                      onTap: () => _onStatCardTap(_stats['highestRatingBookId']),
                    ),
                  ),
                  _buildSectionHeader('Reading Time'),
                  _buildReadingTimeChart(),
                  _buildPair(
                    StatCard(
                      title: 'Fastest Read',
                      value: _stats['fastestReadTime'].toString(),
                      bookTitle: _stats['fastestReadBookTitle'],
                      coverPath: _stats['fastestReadCoverPath'],
                      onTap: () => _onStatCardTap(_stats['fastestReadBookId']),
                    ),
                    StatCard(
                      title: 'Slowest Read',
                      value: _stats['slowestReadTime'].toString(),
                      bookTitle: _stats['slowestReadBookTitle'],
                      coverPath: _stats['slowestReadCoverPath'],
                      onTap: () => _onStatCardTap(_stats['slowestReadBookId']),
                    ),
                  ),
                  _buildSectionHeader('Pages'),
                  _buildPagesChart(),
                  _buildPair(
                    StatCard(
                      title: 'Shortest Book',
                      value: _stats['lowestPages'].toString(),
                      bookTitle: _stats['lowestPagesBookTitle'],
                      coverPath: _stats['lowestPagesCoverPath'],
                      onTap: () => _onStatCardTap(_stats['lowestPagesBookId']),
                    ),
                    StatCard(
                      title: 'Longest Book',
                      value: _stats['highestPages'].toString(),
                      bookTitle: _stats['highestPagesBookTitle'],
                      coverPath: _stats['highestPagesCoverPath'],
                      onTap: () => _onStatCardTap(_stats['highestPagesBookId']),
                    ),
                  ),
                  StatCard(
                    title: 'Avg Pages/Min',
                    value: _stats['avgPagesPerMinute'].toStringAsFixed(2),
                  ),
                ]),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}
