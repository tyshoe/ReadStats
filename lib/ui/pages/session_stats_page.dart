import 'package:flutter/cupertino.dart';
import '/data/repositories/session_repository.dart';
import '/data/repositories/book_repository.dart';
import '/data/models/session.dart';

class SessionStatsPage extends StatefulWidget {
  final BookRepository bookRepository;
  const SessionStatsPage({
    super.key,
    required this.bookRepository,
  });

  @override
  State<SessionStatsPage> createState() => _SessionStatsPageState();
}

class _SessionStatsPageState extends State<SessionStatsPage> {
  final SessionRepository _sessionRepo = SessionRepository();

  Future<Map<String, dynamic>> calculateStats() async {
    // Fetch session stats
    List<Session> sessions = await _sessionRepo.getSessions();

    int totalSessions = sessions.length;
    int totalPagesRead = 0;
    int totalMinutes = 0;

    for (var session in sessions) {
      totalPagesRead += session.pagesRead;
      totalMinutes += (session.hours * 60) + session.minutes;
    }

    double avgPagesPerMinute =
        totalMinutes > 0 ? totalPagesRead / totalMinutes : 0;
    String formattedTime = convertMinutesToTimeString(totalMinutes);

    // Fetch book stats
    Map<String, dynamic> bookStats =
        await widget.bookRepository.getAllBookStats();

    return {
      'totalSessions': totalSessions,
      'totalPagesRead': totalPagesRead,
      'totalTimeSpent': formattedTime,
      'avgPagesPerMinute': avgPagesPerMinute,
      'highestRating': bookStats['highest_rating'] ?? 'N/A',
      'lowestRating': bookStats['lowest_rating'] ?? 'N/A',
      'averageRating': bookStats['average_rating'] ?? 'N/A',
      'slowestReadTime': convertMinutesToTimeString(bookStats['slowest_read_time']) ?? 'N/A',
      'fastestReadTime': convertMinutesToTimeString(bookStats['fastest_read_time']) ?? 'N/A',
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

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Statistics'),
      ),
      child: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: calculateStats(), // Call dynamically to refresh data
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CupertinoActivityIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            final stats = snapshot.data ?? {};

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                // Add this to make content scrollable
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Overall',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    _statCard(
                        title: 'Total Sessions',
                        value: stats['totalSessions'].toString(),
                        bgColor: cardColor,
                        textColor: textColor,
                        subtitleColor: subtitleColor),
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
                        title: 'Books Finished',
                        value: stats['booksCompleted'].toString(),
                        bgColor: cardColor,
                        textColor: textColor,
                        subtitleColor: subtitleColor),
                    const Text(
                      'Ratings',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                        value: stats['averageRating'].toStringAsFixed(2),
                        bgColor: cardColor,
                        textColor: textColor,
                        subtitleColor: subtitleColor),
                    const Text(
                      'Reading Time',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                  ],
                ),
              ),
            );
          },
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
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
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
}
