import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:read_stats/data/services/cover_service.dart';
import 'package:read_stats/ui/pages/statistics/widgets/bar_chart_double.dart';
import 'package:read_stats/ui/pages/statistics/widgets/bar_chart_single.dart';
import 'package:read_stats/ui/pages/statistics/widgets/pie_chart.dart';
import 'package:read_stats/ui/pages/statistics/widgets/stacked_bar_chart.dart';
import 'package:read_stats/ui/pages/statistics/widgets/rating_summary.dart';
import 'package:read_stats/ui/pages/statistics/widgets/stat_card.dart';
import 'package:read_stats/ui/pages/statistics/widgets/year_filter.dart';
import '../../../data/models/book.dart';
import '/data/repositories/session_repository.dart';
import '/data/repositories/book_repository.dart';
import '/data/models/session.dart';
import '/viewmodels/SettingsViewModel.dart';

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

  Map<String, dynamic> _stats = {
    'totalSessions': 0,
    'booksCompleted': 0,
    'highestRating': '-',
    'highestRatingBookTitle': '',
    'highestRatingCoverPath': null,
    'lowestRating': '-',
    'lowestRatingBookTitle': '',
    'lowestRatingCoverPath': null,
    'averageRating': 0.0,
    'totalTimeSpent': '0m',
    'slowestReadTime': '0m',
    'slowestReadBookTitle': '',
    'slowestReadCoverPath': null,
    'fastestReadTime': '0m',
    'fastestReadBookTitle': '',
    'fastestReadCoverPath': null,
    'totalPagesRead': 0,
    'avgPagesPerMinute': 0.0,
    'averagePages': 0.0,
    'highestPages': 0,
    'highestPagesBookTitle': '',
    'highestPagesCoverPath': null,
    'lowestPages': 0,
    'lowestPagesBookTitle': '',
    'lowestPagesCoverPath': null,
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
      'lowestRating': bookStats['lowest_rating'] ?? 0,
      'lowestRatingBookTitle': bookStats['lowest_rating_book_title'],
      'lowestRatingCoverPath': await resolveCover(bookStats['lowest_rating_cover_path']),
      'averageRating': bookStats['average_rating'] ?? 0,
      'highestPages': bookStats['highest_pages'] ?? 0,
      'highestPagesBookTitle': bookStats['highest_pages_book_title'],
      'highestPagesCoverPath': await resolveCover(bookStats['highest_pages_cover_path']),
      'lowestPages': bookStats['lowest_pages'] ?? 0,
      'lowestPagesBookTitle': bookStats['lowest_pages_book_title'],
      'lowestPagesCoverPath': await resolveCover(bookStats['lowest_pages_cover_path']),
      'averagePages': bookStats['average_pages'] ?? 0,
      'slowestReadTime': _formatMinutes(bookStats['slowest_read_time'] ?? 0),
      'slowestReadBookTitle': bookStats['slowest_read_book_title'],
      'slowestReadCoverPath': await resolveCover(bookStats['slowest_read_cover_path']),
      'fastestReadTime': _formatMinutes(bookStats['fastest_read_time'] ?? 0),
      'fastestReadBookTitle': bookStats['fastest_read_book_title'],
      'fastestReadCoverPath': await resolveCover(bookStats['fastest_read_cover_path']),
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
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }

  List<Widget> _spaced(List<Widget> children, {double gap = 8, double sectionGap = 24}) {
    final result = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      result.add(children[i]);
      if (i < children.length - 1) {
        final nextIsSectionHeader = children[i + 1] is! StatCard &&
            i + 1 < children.length &&
            children[i + 1].runtimeType.toString().contains('Padding') == false;
        // Use larger gap before section headers
        final isNextSection = _isSectionHeader(children[i + 1]);
        result.add(SizedBox(height: isNextSection ? sectionGap : gap));
      }
    }
    return result;
  }

  bool _isSectionHeader(Widget w) {
    // Section headers are plain Text widgets from _buildSectionHeader
    return w is Text;
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

  Widget _buildReadingTimeChart() {
    return FutureBuilder<Map<String, int>>(
      future: _getReadingTimeDistribution(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        return BarChartWidget(
          data: snapshot.data!,
          selectedYear: selectedYear,
          barColor: Theme.of(context).primaryColor,
          tooltipFormatter: (value) => _formatMinutes(value), // custom formatting for reading time
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
        return BarChartWidget(
          data: snapshot.data!,
          selectedYear: selectedYear,
          barColor: Theme.of(context).primaryColor,
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

  Future<Map<String, Map<String, int>>> _getCombinedDistribution() async {
    // Get both datasets
    final booksData = await _getBooksDistribution();
    final sessionsData = await _getSessionsDistribution();

    // Get all unique keys from both datasets
    final allKeys = {...booksData.keys, ...sessionsData.keys}.toList();

    // Sort keys if monthly view
    if (selectedYear != 0) {
      const monthOrder = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      final monthIndexMap = {for (var i = 0; i < monthOrder.length; i++) monthOrder[i]: i};

      allKeys.sort((a, b) {
        final indexA = monthIndexMap[a] ?? 99;
        final indexB = monthIndexMap[b] ?? 99;
        return indexA.compareTo(indexB);
      });
    } else {
      // Yearly view - sort descending
      allKeys.sort((a, b) {
        try {
          final yearA = int.tryParse(a) ?? 0;
          final yearB = int.tryParse(b) ?? 0;
          return yearB.compareTo(yearA);
        } catch (e) {
          return b.compareTo(a);
        }
      });
    }

    // Create combined data structure
    final combinedData = <String, Map<String, int>>{};
    for (final key in allKeys) {
      combinedData[key] = {
        'books': booksData[key] ?? 0,
        'sessions': sessionsData[key] ?? 0,
      };
    }

    return combinedData;
  }

  Widget _buildCombinedChart() {
    return FutureBuilder<Map<String, Map<String, int>>>(
      future: _getCombinedDistribution(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Show an "empty" chart while loading
          return const CombinedBarChartWidget(
            data: {},
            selectedYear: 0,
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          // Still show an empty chart instead of shrinking
          return const CombinedBarChartWidget(
            data: {},
            selectedYear: 0,
          );
        }

        return CombinedBarChartWidget(
          data: snapshot.data!,
          selectedYear: selectedYear,
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

  Widget _buildTypeBreakdown() {
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

  Widget _buildShelfBreakdown() {
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
          title: 'Library Breakdown',
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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return RatingSummaryWidget(ratingData: {}, selectedYear: selectedYear);
        }

        if (!snapshot.hasData) {
          return RatingSummaryWidget(ratingData: {}, selectedYear: selectedYear);
        }

        return RatingSummaryWidget(
          ratingData: snapshot.data!,
          selectedYear: selectedYear,
        );
      },
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
                  _buildShelfBreakdown(),
                  _buildTypeBreakdown(),
                  _buildCombinedChart(),
                  StatCard(
                    title: 'Books Finished',
                    value: _stats['booksCompleted'].toString(),
                  ),
                  StatCard(
                    title: 'Total Sessions',
                    value: _stats['totalSessions'].toString(),
                  ),

                  _buildSectionHeader('Ratings'),
                  _buildRatingSummary(),
                  _buildPair(
                    StatCard(
                      title: 'Lowest Rating',
                      value: _stats['lowestRating'].toString(),
                      bookTitle: _stats['lowestRatingBookTitle'],
                      coverPath: _stats['lowestRatingCoverPath'],
                    ),
                    StatCard(
                      title: 'Highest Rating',
                      value: _stats['highestRating'].toString(),
                      bookTitle: _stats['highestRatingBookTitle'],
                      coverPath: _stats['highestRatingCoverPath'],
                    ),
                  ),

                  _buildSectionHeader('Reading Time'),
                  _buildReadingTimeChart(),
                  StatCard(
                    title: 'Reading Time',
                    value: _stats['totalTimeSpent'],
                  ),
                  _buildPair(
                    StatCard(
                      title: 'Fastest Read',
                      value: _stats['fastestReadTime'].toString(),
                      bookTitle: _stats['fastestReadBookTitle'],
                      coverPath: _stats['fastestReadCoverPath'],
                    ),
                    StatCard(
                      title: 'Slowest Read',
                      value: _stats['slowestReadTime'].toString(),
                      bookTitle: _stats['slowestReadBookTitle'],
                      coverPath: _stats['slowestReadCoverPath'],
                    ),
                  ),

                  _buildSectionHeader('Pages'),
                  _buildPagesChart(),
                  StatCard(
                    title: 'Total Pages Read',
                    value: _stats['totalPagesRead'].toString(),
                  ),
                  StatCard(
                    title: 'Avg Pages/Min',
                    value: _stats['avgPagesPerMinute'].toStringAsFixed(2),
                  ),
                  StatCard(
                    title: 'Average Pages',
                    value: _stats['averagePages'].toStringAsFixed(2),
                  ),
                  _buildPair(
                    StatCard(
                      title: 'Shortest Book',
                      value: _stats['lowestPages'].toString(),
                      bookTitle: _stats['lowestPagesBookTitle'],
                      coverPath: _stats['lowestPagesCoverPath'],
                    ),
                    StatCard(
                      title: 'Longest Book',
                      value: _stats['highestPages'].toString(),
                      bookTitle: _stats['highestPagesBookTitle'],
                      coverPath: _stats['highestPagesCoverPath'],
                    ),
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
