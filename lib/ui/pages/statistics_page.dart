import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math';
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
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
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!;
        List<String> keys = data.keys.toList();

        // Sort keys depending on grouping
        if (selectedYear != 0) {
          // Monthly view → enforce Jan → Dec order
          const monthOrder = [
            'Jan','Feb','Mar','Apr','May','Jun',
            'Jul','Aug','Sep','Oct','Nov','Dec'
          ];

          // Use a map for faster lookup and handle missing months
          final monthIndexMap = {
            for (var i = 0; i < monthOrder.length; i++) monthOrder[i]: i
          };

          keys.sort((a, b) {
            final indexA = monthIndexMap[a] ?? 99; // Put unknown months at the end
            final indexB = monthIndexMap[b] ?? 99; // Put unknown months at the end
            return indexA.compareTo(indexB);
          });
        }

        final values = keys.map((k) => data[k] ?? 0).toList();
        final maxValue = values.isEmpty ? 0 : values.reduce(max);

        return SizedBox(
          height: 280,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: max(400, keys.length * 70).toDouble(),
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: (maxValue * 1.3).toDouble(),
                  // Add BarTouchData for tooltips
                  barTouchData: BarTouchData(
                    enabled: true, // Enable touch interaction
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (group) => Colors.transparent,
                      tooltipPadding: EdgeInsets.zero,
                      tooltipMargin: 8,
                      getTooltipItem: (
                          BarChartGroupData group,
                          int groupIndex,
                          BarChartRodData rod,
                          int rodIndex,
                          ) {
                        return BarTooltipItem(
                          _formatMinutes(rod.toY.toInt()), // Format the minutes
                          TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  barGroups: List.generate(keys.length, (i) {
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: values[i].toDouble(),
                          color: Theme.of(context).primaryColor,
                          width: 36,
                          borderRadius: BorderRadius.only(topLeft:Radius.circular(6), topRight:Radius.circular(6)),
                        ),
                      ],
                      showingTooltipIndicators: [0], // Always show tooltip for first rod
                    );
                  }),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() < 0 || value.toInt() >= keys.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              keys[value.toInt()],
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                ),
              ),
            ),
          ),
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



// Build the pages chart widget
  Widget _buildPagesChart() {
    return FutureBuilder<Map<String, int>>(
      future: _getPagesDistribution(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!;
        List<String> keys = data.keys.toList();

        // Sort keys depending on grouping
        if (selectedYear != 0) {
          // Monthly view → enforce Jan → Dec order
          const monthOrder = [
            'Jan','Feb','Mar','Apr','May','Jun',
            'Jul','Aug','Sep','Oct','Nov','Dec'
          ];

          // Use a map for faster lookup and handle missing months
          final monthIndexMap = {
            for (var i = 0; i < monthOrder.length; i++) monthOrder[i]: i
          };

          keys.sort((a, b) {
            final indexA = monthIndexMap[a] ?? 99; // Put unknown months at the end
            final indexB = monthIndexMap[b] ?? 99; // Put unknown months at the end
            return indexA.compareTo(indexB);
          });
        }

        final values = keys.map((k) => data[k] ?? 0).toList();
        final maxValue = values.isEmpty ? 0 : values.reduce(max);

        return SizedBox(
          height: 280,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: max(400, keys.length * 70).toDouble(),
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: (maxValue * 1.3).toDouble(),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (group) => Colors.transparent,
                      tooltipPadding: EdgeInsets.zero,
                      tooltipMargin: 8,
                      getTooltipItem: (
                          BarChartGroupData group,
                          int groupIndex,
                          BarChartRodData rod,
                          int rodIndex,
                          ) {
                        return BarTooltipItem(
                          NumberFormat('#,###').format(rod.toY.toInt()), // Format the pages
                          TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  barGroups: List.generate(keys.length, (i) {
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: values[i].toDouble(),
                          color: Theme.of(context).primaryColor,
                          width: 36,
                          borderRadius: BorderRadius.only(topLeft:Radius.circular(6), topRight:Radius.circular(6)),
                        ),
                      ],
                      showingTooltipIndicators: [0],
                    );
                  }),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() < 0 || value.toInt() >= keys.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              keys[value.toInt()],
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value) {
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: Theme.of(context).textTheme.bodyMedium),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCardWithBook(String title, String value, String? bookTitle) {
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    value,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  if (bookTitle != null && bookTitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      bookTitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withAlpha(179),
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYearFilter(List<int> years) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: years.length + 1,
        itemBuilder: (context, index) {
          final year = index == 0 ? 0 : years[index - 1];
          final isSelected = selectedYear == year;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: isSelected ? colors.primary : colors.onSurface,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
              ),
              onPressed: () {
                setState(() {
                  selectedYear = year;
                });
                loadStats();
              },
              child: Container(
                decoration: BoxDecoration(
                  border: isSelected
                      ? Border(
                          bottom: BorderSide(
                            color: colors.primary,
                            width: 2,
                          ),
                        )
                      : null,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  year == 0 ? 'All' : year.toString(),
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        },
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
            builder: (context, yearSnapshot) {
              if (!yearSnapshot.hasData) return const SizedBox.shrink();

              final years = yearSnapshot.data!;
              return _buildYearFilter(years);
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
                  _buildSectionHeader('Overall'),
                  _buildStatCard('Total Sessions', _stats['totalSessions'].toString()),
                  _buildStatCard('Books Finished', _stats['booksCompleted'].toString()),
                  _buildSectionHeader('Ratings'),
                  _buildStatCardWithBook(
                    'Highest Rating',
                    _stats['highestRating'].toString(),
                    _stats['highestRatingBookTitle'],
                  ),
                  _buildStatCardWithBook(
                    'Lowest Rating',
                    _stats['lowestRating'].toString(),
                    _stats['lowestRatingBookTitle'],
                  ),
                  _buildStatCard('Average Rating', _stats['averageRating'].toStringAsFixed(2)),
                  _buildSectionHeader('Reading Time'),
                  _buildReadingTimeChart(),
                  _buildStatCard('Total Time Spent', _stats['totalTimeSpent']),
                  _buildStatCardWithBook(
                    'Slowest Read',
                    _stats['slowestReadTime'].toString(),
                    _stats['slowestReadBookTitle'],
                  ),
                  _buildStatCardWithBook(
                    'Fastest Read',
                    _stats['fastestReadTime'].toString(),
                    _stats['fastestReadBookTitle'],
                  ),
                  _buildSectionHeader('Pages'),
                  _buildPagesChart(),
                  _buildStatCard('Total Pages Read', _stats['totalPagesRead'].toString()),
                  _buildStatCard('Avg Pages/Min', _stats['avgPagesPerMinute'].toStringAsFixed(2)),
                  _buildStatCard('Average Pages', _stats['averagePages'].toStringAsFixed(2)),
                  _buildStatCardWithBook(
                    'Longest Book',
                    _stats['highestPages'].toString(),
                    _stats['highestPagesBookTitle'],
                  ),
                  _buildStatCardWithBook(
                    'Shortest Book',
                    _stats['lowestPages'].toString(),
                    _stats['lowestPagesBookTitle'],
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
