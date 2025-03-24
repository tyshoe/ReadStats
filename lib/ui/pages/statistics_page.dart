import 'package:flutter/cupertino.dart';
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
    final bgColor = CupertinoColors.systemBackground.resolveFrom(context);
    final textColor = CupertinoColors.label.resolveFrom(context);
    final subtitleColor = CupertinoColors.secondaryLabel.resolveFrom(context);
    final cardColor = CupertinoColors.systemGrey6.resolveFrom(context);
    final accentColor = widget.settingsViewModel.accentColorNotifier.value;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('Statistics'),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Year selection row - Static at the top
            FutureBuilder<List<int>>(
              future: getCombinedYears(),
              builder: (context, yearSnapshot) {
                List<int> years = yearSnapshot.data!;
                return SizedBox(
                  height: 35,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: years.length + 1, // Add "All" option
                    itemBuilder: (context, index) {
                      int year = (index == 0) ? 0 : years[index - 1]; // "All" is represented by 0
                      bool isSelected = selectedYear == year;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedYear = year;
                            print('Selected year: $selectedYear');
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Container(
                            width: 60,  // Control the width of the underline here
                            decoration: BoxDecoration(
                              shape: BoxShape.rectangle,
                              border: isSelected
                                  ? Border(
                                bottom: BorderSide(
                                  color: accentColor,
                                  width: 2.0,
                                ),
                              )
                                  : null, // No border when not selected
                            ),
                            child: Align(
                              alignment: Alignment.center,  // Align the text horizontally
                              child: Text(
                                (year == 0) ? 'All' : year.toString(),
                                style: TextStyle(
                                  color: isSelected ? accentColor : textColor,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal ,
                                ),
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
            // Divider
            Container(
              height: 1.0, // Height of the divider
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey, // Color of the divider
                borderRadius: BorderRadius.circular(1.0), // Optional: Add rounded corners
              ),
            ),
            // Rest of the statistics content (scrollable)
            Expanded(
              child: FutureBuilder<Map<String, dynamic>>(
                future: calculateStats(selectedYear),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CupertinoActivityIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  final stats = snapshot.data ?? {};

                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          const Text(
                            'Overall',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          _statCard(
                              title: 'Total Sessions',
                              value: stats['totalSessions'].toString(),
                              bgColor: cardColor,
                              textColor: textColor,
                              subtitleColor: subtitleColor),
                          _statCard(
                              title: 'Books Finished',
                              value: stats['booksCompleted'].toString(),
                              bgColor: cardColor,
                              textColor: textColor,
                              subtitleColor: subtitleColor),
                          const SizedBox(height: 16),
                          const Text(
                            'Ratings',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          _statCard(
                              title: 'Highest Rating',
                              value: stats['highestRating'].toString(),
                              bgColor: cardColor,
                              textColor: textColor,
                              subtitleColor: subtitleColor),
                          _statCard(
                              title: 'Lowest Rating',
                              value: stats['lowestRating'].toString(),
                              bgColor: cardColor,
                              textColor: textColor,
                              subtitleColor: subtitleColor),
                          _statCard(
                              title: 'Average Rating',
                              value: stats['averageRating'].toStringAsPrecision(2),
                              bgColor: cardColor,
                              textColor: textColor,
                              subtitleColor: subtitleColor),
                          const SizedBox(height: 16),
                          const Text(
                            'Reading Time',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          _statCard(
                              title: 'Total Time Spent',
                              value: stats['totalTimeSpent'],
                              bgColor: cardColor,
                              textColor: textColor,
                              subtitleColor: subtitleColor),
                          _statCard(
                              title: 'Slowest Read',
                              value: stats['slowestReadTime'].toString(),
                              bgColor: cardColor,
                              textColor: textColor,
                              subtitleColor: subtitleColor),
                          _statCard(
                              title: 'Fastest Read',
                              value: stats['fastestReadTime'].toString(),
                              bgColor: cardColor,
                              textColor: textColor,
                              subtitleColor: subtitleColor),
                          const SizedBox(height: 16),
                          const Text(
                            'Pages',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          _statCard(
                              title: 'Total Pages Read',
                              value: stats['totalPagesRead'].toString(),
                              bgColor: cardColor,
                              textColor: textColor,
                              subtitleColor: subtitleColor),
                          _statCard(
                              title: 'Average Pages/Minute',
                              value: stats['avgPagesPerMinute'].toStringAsFixed(2),
                              bgColor: cardColor,
                              textColor: textColor,
                              subtitleColor: subtitleColor),
                          _statCard(
                              title: 'Average Pages',
                              value: stats['averagePages'].toStringAsFixed(2),
                              bgColor: cardColor,
                              textColor: textColor,
                              subtitleColor: subtitleColor),
                          _statCard(
                              title: 'Longest Book',
                              value: stats['highestPages'].toString(),
                              bgColor: cardColor,
                              textColor: textColor,
                              subtitleColor: subtitleColor),
                          _statCard(
                              title: 'Shortest Book',
                              value: stats['lowestPages'].toString(),
                              bgColor: cardColor,
                              textColor: textColor,
                              subtitleColor: subtitleColor),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required Color bgColor,
    required Color textColor,
    required Color subtitleColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: 16, color: subtitleColor)),
          Text(value,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
        ],
      ),
    );
  }

  Future<List<int>> getCombinedYears() async {
    // Fetch the valid session years and book years
    final sessionYears = await widget.sessionRepository.getSessionYears();
    final bookYears = await widget.bookRepository.getBookYears();

    print('SessionYears: $sessionYears, bookYears: $bookYears');

    // Combine both lists and remove duplicates
    final combinedYears = {...sessionYears, ...bookYears}.toList();

    // Sort the combined list in descending order
    combinedYears.sort((a, b) => b.compareTo(a));

    return combinedYears;
  }
}
