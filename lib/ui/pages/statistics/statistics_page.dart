import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:read_stats/data/services/cover_service.dart';
import 'package:read_stats/ui/pages/statistics/widgets/bar_chart_single.dart';
import 'package:read_stats/ui/pages/statistics/widgets/pie_chart.dart';
import 'package:read_stats/ui/pages/statistics/widgets/stacked_bar_chart.dart';
import 'package:read_stats/ui/pages/statistics/widgets/rating_summary.dart';
import 'package:read_stats/ui/pages/statistics/widgets/stat_card.dart';
import 'package:read_stats/ui/pages/statistics/widgets/year_filter.dart';
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
}

class _StatisticsPageState extends State<StatisticsPage> {
  int selectedYear = 0;
  Map<double, int> _cachedRatingData = {};

  Map<String, dynamic> _stats = {
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => loadStats());
  }

  void loadStats() async {
    final newStats = await calculateStats(selectedYear);
    setState(() {
      _stats = newStats;
    });
  }

  Future<Map<String, dynamic>> calculateStats(int selectedYear) async {
    // Fetch session stats filtered by the selected year
    List<Session> sessions = await widget.sessionRepository.getSessions(yearFilter: selectedYear);

    int totalSessions = sessions.length;
    int totalPagesRead = 0;
    int totalMinutes = 0;

    for (var session in sessions) {
      totalPagesRead += session.pagesRead ?? 0;
      totalMinutes += session.durationMinutes ?? 0;
    }

    double avgPagesPerMinute = totalMinutes > 0 ? totalPagesRead / totalMinutes : 0;
    String totalTimeSpent = _formatMinutes(totalMinutes);

    // Fetch book stats filtered by the selected year
    Map<String, dynamic> bookStats = await widget.bookRepository.getAllBookStats(selectedYear);

    Future<String?> resolveCover(dynamic raw) async {
      if (raw == null) return null;
      final path = raw as String;
      if (path.isEmpty) return null;
      return await CoverService.resolveFullPath(path);
    }

    return {
      'totalSessions': totalSessions,
      'totalPagesRead': totalPagesRead,
      'totalTimeSpent': totalTimeSpent,
      'avgPagesPerMinute': avgPagesPerMinute,
      'highestRating': bookStats['highest_rating'] ?? 0,
      'highestRatingBookTitle': bookStats['highest_rating_book_title'],
      'highestRatingCoverPath': await resolveCover(bookStats['highest_rating_cover_path']),
      'highestRatingBookId': bookStats['highest_rating_book_id'],
      'lowestRating': bookStats['lowest_rating'] ?? 0,
      'lowestRatingBookTitle': bookStats['lowest_rating_book_title'],
      'lowestRatingCoverPath': await resolveCover(bookStats['lowest_rating_cover_path']),
      'lowestRatingBookId': bookStats['lowest_rating_book_id'],
      'averageRating': bookStats['average_rating'] ?? 0,
      'highestPages': bookStats['highest_pages'] ?? 0,
      'highestPagesBookTitle': bookStats['highest_pages_book_title'],
      'highestPagesCoverPath': await resolveCover(bookStats['highest_pages_cover_path']),
      'highestPagesBookId': bookStats['highest_pages_book_id'],
      'lowestPages': bookStats['lowest_pages'] ?? 0,
      'lowestPagesBookTitle': bookStats['lowest_pages_book_title'],
      'lowestPagesCoverPath': await resolveCover(bookStats['lowest_pages_cover_path']),
      'lowestPagesBookId': bookStats['lowest_pages_book_id'],
      'averagePages': bookStats['average_pages'] ?? 0,
      'slowestReadTime': _formatMinutes(bookStats['slowest_read_time'] ?? 0),
      'slowestReadBookTitle': bookStats['slowest_read_book_title'],
      'slowestReadCoverPath': await resolveCover(bookStats['slowest_read_cover_path']),
      'slowestReadBookId': bookStats['slowest_read_book_id'],
      'fastestReadTime': _formatMinutes(bookStats['fastest_read_time'] ?? 0),
      'fastestReadBookTitle': bookStats['fastest_read_book_title'],
      'fastestReadCoverPath': await resolveCover(bookStats['fastest_read_cover_path']),
      'fastestReadBookId': bookStats['fastest_read_book_id'],
      'booksCompleted': bookStats['books_completed'] ?? 0,
    };
  }

  Future<List<int>> getCombinedYears() async {
    final sessionYears = await widget.sessionRepository.getSessionYears();
    final bookYears = await widget.bookRepository.getBookYears();

    if (kDebugMode) {
      print('SessionYears: $sessionYears, bookYears: $bookYears');
    }

    final combinedYears = {...sessionYears, ...bookYears}.toList();
    combinedYears.sort((a, b) => b.compareTo(a));
    return combinedYears;
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

  String _formatMinutes(int minutes) {
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

  Future<Map<String, int>> _getReadingTimeDistribution() async {
    List<Session> sessions = await widget.sessionRepository.getSessions(
      yearFilter: selectedYear,
    );

    Map<String, int> groupedMinutes = {};

    for (var s in sessions) {
      final date = DateTime.parse(s.date);
      final key = selectedYear == 0
          ? date.year.toString() // group by year
          : DateFormat('MMM').format(date); // group by month

      groupedMinutes[key] = (groupedMinutes[key] ?? 0) + (s.durationMinutes ?? 0);
    }

    return groupedMinutes;
  }

  String _shortFormatMinutes(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    return '${hours}h';
  }

  Widget _buildReadingTimeChart() {
    return FutureBuilder<Map<String, int>>(
      future: _getReadingTimeDistribution(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final data = snapshot.data!;
        final activeMinutes = data.values.where((v) => v > 0).toList();
        final avgMinutes = activeMinutes.isEmpty
            ? '0'
            : _shortFormatMinutes((activeMinutes.reduce((a, b) => a + b) / activeMinutes.length).round());
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
        );
      },
    );
  }

  Future<Map<String, int>> _getPagesDistribution() async {
    List<Session> sessions = await widget.sessionRepository.getSessions(
      yearFilter: selectedYear,
    );

    Map<String, int> groupedPages = {};

    for (var s in sessions) {
      final date = DateTime.parse(s.date);
      final key = selectedYear == 0
          ? date.year.toString() // group by year
          : DateFormat('MMM').format(date); // group by month

      groupedPages[key] = (groupedPages[key] ?? 0) + (s.pagesRead ?? 0);
    }

    return groupedPages;
  }

  Widget _buildPagesChart() {
    return FutureBuilder<Map<String, int>>(
      future: _getPagesDistribution(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final data = snapshot.data!;
        final activePages = data.values.where((v) => v > 0).toList();
        final avgPages = activePages.isEmpty
            ? '0'
            : NumberFormat('#,###').format((activePages.reduce((a, b) => a + b) / activePages.length).round());
        return BarChartWidget(
          data: data,
          selectedYear: selectedYear,
          barColor: Theme.of(context).primaryColor,
          title: 'Pages Read',
          subtitleValue: NumberFormat('#,###').format(_stats['totalPagesRead']),
          averageValue: avgPages,
          averageLabel: selectedYear == 0 ? 'Avg/year' : 'Avg/month',
        );
      },
    );
  }

  Future<Map<String, int>> _getBooksDistribution() async {
    List<Book> books = await widget.bookRepository.getBooks(
      yearFilter: selectedYear,
    );

    Map<String, int> grouped = {};
    for (var book in books) {
      // Use date_finished for books (assuming books have a date_finished field)
      if (book.dateFinished != null) {
        final date = DateTime.parse(book.dateFinished!);
        final key =
            selectedYear == 0 ? date.year.toString() : DateFormat('MMM').format(date); // month name

        grouped[key] = (grouped[key] ?? 0) + 1; // count per book
      }
    }
    return grouped;
  }

  Future<Map<String, int>> _getSessionsDistribution() async {
    List<Session> sessions = await widget.sessionRepository.getSessions(
      yearFilter: selectedYear,
    );

    Map<String, int> grouped = {};
    for (var s in sessions) {
      final date = DateTime.parse(s.date);
      final key =
          selectedYear == 0 ? date.year.toString() : DateFormat('MMM').format(date); // month name

      grouped[key] = (grouped[key] ?? 0) + 1; // count per session
    }
    return grouped;
  }


  String _formatAverage(Map<String, int> data) {
    final active = data.values.where((v) => v > 0).toList();
    if (active.isEmpty) return '0';
    return (active.reduce((a, b) => a + b) / active.length).round().toString();
  }

  Widget _buildBooksChart() {
    return FutureBuilder<Map<String, int>>(
      future: _getBooksDistribution(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        return BarChartWidget(
          data: snapshot.data!,
          selectedYear: selectedYear,
          barColor: Theme.of(context).primaryColor,
          title: 'Books Finished',
          subtitleValue: _stats['booksCompleted'].toString(),
          averageValue: _formatAverage(snapshot.data!),
          averageLabel: selectedYear == 0 ? 'Avg/year' : 'Avg/month',
        );
      },
    );
  }

  Widget _buildSessionsChart() {
    return FutureBuilder<Map<String, int>>(
      future: _getSessionsDistribution(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        return BarChartWidget(
          data: snapshot.data!,
          selectedYear: selectedYear,
          barColor: Theme.of(context).primaryColor,
          title: 'Sessions',
          subtitleValue: _stats['totalSessions'].toString(),
          averageValue: _formatAverage(snapshot.data!),
          averageLabel: selectedYear == 0 ? 'Avg/year' : 'Avg/month',
        );
      },
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
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: widget.bookRepository.getBookCountsPerType(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        return PieChartWidget(
          title: 'Book Formats',
          data: snapshot.data!,
          icons: _typeIcons,
          sortByCount: true,
          colors: {
            'Paperback':  Theme.of(context).primaryColor,
            'Hardback':   _safeColor(const Color(0xFF9575CD), Theme.of(context).primaryColor),
            'EBook':      _safeColor(const Color(0xFF4CAF50), Theme.of(context).primaryColor),
            'Audiobook':  _safeColor(const Color(0xFFFF9800), Theme.of(context).primaryColor),
          },
        );
      },
    );
  }

  Widget _buildShelfChart() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: widget.bookRepository.getBookCountsPerShelf(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final primary = Theme.of(context).primaryColor;
        const shelfOrder = ['Want to Read', 'Currently Reading', 'Finished', 'Unfinished'];
        final sorted = [...snapshot.data!]..sort((a, b) {
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
      },
    );
  }

  Widget _buildRatingSummary() {
    return FutureBuilder<Map<double, int>>(
      future: widget.bookRepository.getRatingDistribution(selectedYear: selectedYear),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          _cachedRatingData = snapshot.data!;
        }

        return RatingSummaryWidget(
          ratingData: _cachedRatingData,
          selectedYear: selectedYear,
          title: 'My Ratings',
        );
      },
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
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SessionFormPage(
          availableBooks: books
              .where((b) => b.isCompleted == false)
              .map((b) => b.toMap())
              .toList(),
          book: book,
          onSave: loadStats,
          settingsViewModel: widget.settingsViewModel,
          sessionRepository: widget.sessionRepository,
          bookRepository: widget.bookRepository,
        ),
      ),
    );
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
              await DatabaseHelper().deleteBook(bookId);
              if (mounted) Navigator.pop(context);
              loadStats();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: false,
      ),
      body: Column(
        children: [
          // Year selection row
          FutureBuilder<List<int>>(
            future: getCombinedYears(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              final years = snapshot.data!;
              return YearFilterWidget(
                years: years,
                selectedYear: selectedYear,
                onYearSelected: (year) {
                  setState(() {
                    selectedYear = year;
                  });
                  loadStats();
                },
              );
            },
          ),

          const Divider(height: 1),
          // Statistics content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _spaced([
                  _buildSectionHeader('Overview'),
                  _buildShelfChart(),
                  _buildBookTypeChart(),
                  _buildBooksChart(),
                  _buildSessionsChart(),
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
    );
  }
}
