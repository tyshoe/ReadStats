import 'package:flutter/cupertino.dart';
import '../repositories/session_repository.dart';
import '../models/session.dart';

class SessionStatsPage extends StatefulWidget {
  @override
  _SessionStatsPageState createState() => _SessionStatsPageState();
}

class _SessionStatsPageState extends State<SessionStatsPage> {
  final SessionRepository _sessionRepo = SessionRepository(); // Use the session repository
  late Future<List<Session>> _allSessions;

  @override
  void initState() {
    super.initState();
    _allSessions = _sessionRepo.getSessions(); // Fetch all sessions using the session repository
  }

  Future<Map<String, dynamic>> calculateStats() async {
    List<Session> sessions = await _allSessions;

    int totalSessions = sessions.length;
    int totalPagesRead = 0;
    int totalMinutes = 0;

    for (var session in sessions) {
      totalPagesRead += session.pagesRead;
      totalMinutes += (session.hours * 60) + session.minutes; // Convert hours to minutes and add minutes
    }

    // Calculate the average pages per minute if there was time spent
    double avgPagesPerMinute = totalMinutes > 0 ? totalPagesRead / totalMinutes : 0;

    // Format total time spent using the formatTime function
    String formattedTime = formatTime(totalMinutes);

    return {
      'totalSessions': totalSessions,
      'totalPagesRead': totalPagesRead,
      'totalTimeSpent': formattedTime,
      'avgPagesPerMinute': avgPagesPerMinute,
    };
  }

  // Function to format total time in a readable way
  String formatTime(int totalTimeInMinutes) {
    int days = totalTimeInMinutes ~/ (24 * 60); // Divide by the number of minutes in a day
    int hours = (totalTimeInMinutes % (24 * 60)) ~/ 60; // Remainder after days, then divide by 60 to get hours
    int minutes = totalTimeInMinutes % 60; // Remainder after hours, gives minutes

    // Build the formatted string
    String formattedTime = '';

    if (days > 0) {
      formattedTime += '${days}d ';
    }
    if (hours > 0 || days > 0) {
      formattedTime += '${hours}h ';
    }
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
          future: calculateStats(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CupertinoActivityIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            final stats = snapshot.data;

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _statCard(title: 'Total Sessions', value: stats?['totalSessions'].toString() ?? '0', bgColor: cardColor, textColor: textColor, subtitleColor: subtitleColor),
                  _statCard(title: 'Total Pages Read', value: stats?['totalPagesRead'].toString() ?? '0', bgColor: cardColor, textColor: textColor, subtitleColor: subtitleColor),
                  _statCard(title: 'Total Time Spent', value: stats?['totalTimeSpent'] ?? '0', bgColor: cardColor, textColor: textColor, subtitleColor: subtitleColor),
                  _statCard(title: 'Average Pages/Minute', value: stats?['avgPagesPerMinute'].toStringAsFixed(2) ?? '0', bgColor: cardColor, textColor: textColor, subtitleColor: subtitleColor),
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
          Text(title, style: TextStyle(fontSize: 16, color: subtitleColor)), // Use dynamic subtitle color
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)), // Use dynamic text color
        ],
      ),
    );
  }
}
