import 'package:flutter/cupertino.dart';
import '/data/repositories/session_repository.dart';
import '/data/models/session.dart';

class SessionStatsPage extends StatefulWidget {
  const SessionStatsPage({
    super.key,
  });

  @override
  State<SessionStatsPage> createState() => _SessionStatsPageState();
}

class _SessionStatsPageState extends State<SessionStatsPage> {
  final SessionRepository _sessionRepo = SessionRepository();

  Future<Map<String, dynamic>> calculateStats() async {
    List<Session> sessions =
        await _sessionRepo.getSessions(); // Fetch sessions dynamically

    int totalSessions = sessions.length;
    int totalPagesRead = 0;
    int totalMinutes = 0;

    for (var session in sessions) {
      totalPagesRead += session.pagesRead;
      totalMinutes += (session.hours * 60) + session.minutes;
    }

    double avgPagesPerMinute =
        totalMinutes > 0 ? totalPagesRead / totalMinutes : 0;
    String formattedTime = formatTime(totalMinutes);

    return {
      'totalSessions': totalSessions,
      'totalPagesRead': totalPagesRead,
      'totalTimeSpent': formattedTime,
      'avgPagesPerMinute': avgPagesPerMinute,
    };
  }

  String formatTime(int totalTimeInMinutes) {
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
        middle: Text('Total Session Stats'),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                      title: 'Total Time Spent',
                      value: stats['totalTimeSpent'],
                      bgColor: cardColor,
                      textColor: textColor,
                      subtitleColor: subtitleColor),
                  _statCard(
                      title: 'Average Pages/Minute',
                      value: stats['avgPagesPerMinute'].toStringAsFixed(2),
                      bgColor: cardColor,
                      textColor: textColor,
                      subtitleColor: subtitleColor),
                ],
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
