import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
  }

  Future<Map<String, dynamic>> calculateStats(int selectedYear) async {
    // Fetch session stats filtered by the selected year
    List<Session> sessions;

    sessions = await widget.sessionRepository.getSessions(yearFilter: selectedYear);

    int totalSessions = sessions.length;
    int totalPagesRead = 0;
    int totalMinutes = 0;

    for (var session in sessions) {
      totalPagesRead += session.pagesRead;
      totalMinutes += session.durationMinutes;
    }

    double avgPagesPerMinute =
    totalMinutes > 0 ? totalPagesRead / totalMinutes : 0;
    String totalTimeSpent = convertMinutesToTimeString(totalMinutes);

    // Fetch book stats filtered by the selected year
    Map<String, dynamic> bookStats = await widget.bookRepository.getAllBookStats(selectedYear);

    return {
      'totalSessions': totalSessions,
      'totalPagesRead': totalPagesRead,
      'totalTimeSpent': totalTimeSpent,
      'avgPagesPerMinute': avgPagesPerMinute,
      'highestRating': bookStats['highest_rating'] ?? 0,
      'lowestRating': bookStats['lowest_rating'] ?? 0,
      'averageRating': bookStats['average_rating'] ?? 0,
      'highestPages': bookStats['highest_pages'] ?? 0,
      'lowestPages': bookStats['lowest_pages'] ?? 0,
      'averagePages': bookStats['average_pages'] ?? 0,
      'slowestReadTime':
      convertMinutesToTimeString(bookStats['slowest_read_time'] ?? 0),
      'fastestReadTime':
      convertMinutesToTimeString(bookStats['fastest_read_time'] ?? 0),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Year selection row
          FutureBuilder<List<int>>(
            future: getCombinedYears(),
            builder: (context, yearSnapshot) {
              if (!yearSnapshot.hasData) return const SizedBox.shrink();

              final years = yearSnapshot.data!;
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
                        onPressed: () => setState(() => selectedYear = year),
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
            },
          ),
          const Divider(height: 1),
          // Statistics content
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: calculateStats(selectedYear),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final stats = snapshot.data ?? {};

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader('Overall'),
                      _buildStatCard('Total Sessions', stats['totalSessions'].toString()),
                      _buildStatCard('Books Finished', stats['booksCompleted'].toString()),

                      _buildSectionHeader('Ratings'),
                      _buildStatCard('Highest Rating', stats['highestRating'].toString()),
                      _buildStatCard('Lowest Rating', stats['lowestRating'].toString()),
                      _buildStatCard('Average Rating', stats['averageRating'].toStringAsFixed(2)),

                      _buildSectionHeader('Reading Time'),
                      _buildStatCard('Total Time Spent', stats['totalTimeSpent']),
                      _buildStatCard('Slowest Read', stats['slowestReadTime'].toString()),
                      _buildStatCard('Fastest Read', stats['fastestReadTime'].toString()),

                      _buildSectionHeader('Pages'),
                      _buildStatCard('Total Pages Read', stats['totalPagesRead'].toString()),
                      _buildStatCard('Avg Pages/Min', stats['avgPagesPerMinute'].toStringAsFixed(2)),
                      _buildStatCard('Average Pages', stats['averagePages'].toStringAsFixed(2)),
                      _buildStatCard('Longest Book', stats['highestPages'].toString()),
                      _buildStatCard('Shortest Book', stats['lowestPages'].toString()),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
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

  Future<List<int>> getCombinedYears() async {
    // Fetch the valid session years and book years
    final sessionYears = await widget.sessionRepository.getSessionYears();
    final bookYears = await widget.bookRepository.getBookYears();

    if (kDebugMode) {
      print('SessionYears: $sessionYears, bookYears: $bookYears');
    }

    // Combine both lists and remove duplicates
    final combinedYears = {...sessionYears, ...bookYears}.toList();

    // Sort the combined list in descending order
    combinedYears.sort((a, b) => b.compareTo(a));

    return combinedYears;
  }
}
