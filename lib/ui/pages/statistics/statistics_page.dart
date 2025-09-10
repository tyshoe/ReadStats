import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:read_stats/ui/pages/statistics/widgets/bar_chart_double.dart';
import 'package:read_stats/ui/pages/statistics/widgets/bar_chart_single.dart';
import 'package:read_stats/ui/pages/statistics/widgets/rating_summary.dart';
import 'package:read_stats/ui/pages/statistics/widgets/stat_card.dart';
import 'package:read_stats/ui/pages/statistics/widgets/year_filter.dart';
import 'dart:math';
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
    'lowestRating': '-',
    'lowestRatingBookTitle': '',
    'averageRating': 0.0,
    'totalTimeSpent': '0m',
    'slowestReadTime': '0m',
    'slowestReadBookTitle': '',
    'fastestReadTime': '0m',
    'fastestReadBookTitle': '',
    'totalPagesRead': 0,
    'avgPagesPerMinute': 0.0,
    'averagePages': 0.0,
    'highestPages': 0,
    'highestPagesBookTitle': '',
    'lowestPages': 0,
    'lowestPagesBookTitle': '',
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
      totalPagesRead += session.pagesRead;
      totalMinutes += session.durationMinutes;
    }

    double avgPagesPerMinute = totalMinutes > 0 ? totalPagesRead / totalMinutes : 0;
    String totalTimeSpent = convertMinutesToTimeString(totalMinutes);

    // Fetch book stats filtered by the selected year
    Map<String, dynamic> bookStats = await widget.bookRepository.getAllBookStats(selectedYear);

    return {
      'totalSessions': totalSessions,
      'totalPagesRead': totalPagesRead,
      'totalTimeSpent': totalTimeSpent,
      'avgPagesPerMinute': avgPagesPerMinute,
      'highestRating': bookStats['highest_rating'] ?? 0,
      'highestRatingBookTitle': bookStats['highest_rating_book_title'],
      'lowestRating': bookStats['lowest_rating'] ?? 0,
      'lowestRatingBookTitle': bookStats['lowest_rating_book_title'],
      'averageRating': bookStats['average_rating'] ?? 0,
      'highestPages': bookStats['highest_pages'] ?? 0,
      'highestPagesBookTitle': bookStats['highest_pages_book_title'],
      'lowestPages': bookStats['lowest_pages'] ?? 0,
      'lowestPagesBookTitle': bookStats['lowest_pages_book_title'],
      'averagePages': bookStats['average_pages'] ?? 0,
      'slowestReadTime': convertMinutesToTimeString(bookStats['slowest_read_time'] ?? 0),
      'slowestReadBookTitle': bookStats['slowest_read_book_title'],
      'fastestReadTime': convertMinutesToTimeString(bookStats['fastest_read_time'] ?? 0),
      'fastestReadBookTitle': bookStats['fastest_read_book_title'],
      'booksCompleted': bookStats['books_completed'] ?? 0,
    };
  }

  String convertMinutesToTimeString(int totalTimeInMinutes) {
    int days = totalTimeInMinutes ~/ (24 * 60);
    int hours = (totalTimeInMinutes % (24 * 60)) ~/ 60;
    int minutes = totalTimeInMinutes % 60;

    String formattedTime = '';
    if (days > 0) formattedTime += '${days}d ';
    if (hours > 0 || days > 0) formattedTime += '${hours}h ';
    formattedTime += '${minutes}m';

    return formattedTime;
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

  Widget _buildSectionHeader(String title, double topPad) {
    return Padding(
      padding: EdgeInsets.only(top: topPad),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
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

      groupedMinutes[key] = (groupedMinutes[key] ?? 0) + s.durationMinutes;
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

  // Add this method to get pages distribution data
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

      groupedPages[key] = (groupedPages[key] ?? 0) + s.pagesRead;
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

  Widget _buildBooksChart() {
    return FutureBuilder<Map<String, int>>(
      future: _getBooksDistribution(),
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

  Widget _buildSessionsChart() {
    return FutureBuilder<Map<String, int>>(
      future: _getSessionsDistribution(),
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
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('Overall', 0),
                  _buildCombinedChart(),
                  // _buildBooksChart(),
                  StatCard(
                    title: 'Books Finished',
                    value: _stats['booksCompleted'].toString(),
                  ),
                  // _buildSessionsChart(),
                  StatCard(
                    title: 'Total Sessions',
                    value: _stats['totalSessions'].toString(),
                  ),

                  _buildSectionHeader('Ratings', 16),
                  _buildRatingSummary(),
                  StatCard(
                    title: 'Highest Rating',
                    value: _stats['highestRating'].toString(),
                    bookTitle: _stats['highestRatingBookTitle'],
                  ),
                  StatCard(
                    title: 'Lowest Rating',
                    value: _stats['lowestRating'].toString(),
                    bookTitle: _stats['lowestRatingBookTitle'],
                  ),
                  StatCard(
                    title: 'Average Rating',
                    value: _stats['averageRating'].toStringAsFixed(2),
                  ),

                  _buildSectionHeader('Reading Time', 16),
                  _buildReadingTimeChart(),
                  StatCard(
                    title: 'Total Time Spent',
                    value: _stats['totalTimeSpent'],
                  ),
                  StatCard(
                    title: 'Slowest Read',
                    value: _stats['slowestReadTime'].toString(),
                    bookTitle: _stats['slowestReadBookTitle'],
                  ),
                  StatCard(
                    title: 'Fastest Read',
                    value: _stats['fastestReadTime'].toString(),
                    bookTitle: _stats['fastestReadBookTitle'],
                  ),

                  _buildSectionHeader('Pages', 16),
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
                  StatCard(
                    title: 'Longest Book',
                    value: _stats['highestPages'].toString(),
                    bookTitle: _stats['highestPagesBookTitle'],
                  ),
                  StatCard(
                    title: 'Shortest Book',
                    value: _stats['lowestPages'].toString(),
                    bookTitle: _stats['lowestPagesBookTitle'],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
