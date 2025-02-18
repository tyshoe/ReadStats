import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import '../database_helper.dart';

class SessionsPage extends StatefulWidget {
  final List<Map<String, dynamic>> sessions;
  final Function() refreshSessions; // Function to refresh the list from parent

  const SessionsPage({super.key, required this.sessions, required this.refreshSessions});

  @override
  State<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends State<SessionsPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Fetch sessions from the database and update the state


  // Format duration (hours and minutes)
  String _formatDuration(int hours, int minutes) {
    final hourText = hours > 0 ? '${hours}h ' : '';
    return '$hourText${minutes}m';
  }

  // Format date
  String _formatDate(String isoDate) {
    final date = DateTime.parse(isoDate);
    return DateFormat('MMM dd, yyyy').format(date);
  }


  // Delete a session from the database
  Future<void> _deleteSession(int sessionId) async {
    await _dbHelper.deleteSession(sessionId);
    widget.refreshSessions();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Reading Sessions'),
      ),
      child: SafeArea(
        child: widget.sessions.isEmpty
            ? const Center(child: Text('No sessions logged yet'))
            : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: widget.sessions.length,
          itemBuilder: (context, index) {
            final session = widget.sessions[index];
            final bookTitle = session['book_title'] ?? 'Unknown Book';  // Default if null
            final pagesRead = session['pages_read'] ?? 0;
            final hours = session['hours'] ?? 0;
            final minutes = session['minutes'] ?? 0;
            final date = session['date'] ?? '';  // Default if null

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6,
                borderRadius: BorderRadius.circular(8),
              ),
              child: CupertinoListTile(
                title: Text(bookTitle),  // Use the fallback string if null
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📖 $pagesRead pages',
                      style: const TextStyle(fontSize: 14),
                    ),
                    Text(
                      '⏱️ ${_formatDuration(hours, minutes)}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    Text(
                      date.isNotEmpty ? '📅 ${_formatDate(date)}' : '📅 No date available',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: const Icon(CupertinoIcons.pencil),
                      onPressed: () {
                        // Navigate to the Edit Session Page (we'll set up navigation later)
                      },
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: const Icon(CupertinoIcons.delete, color: CupertinoColors.destructiveRed),
                      onPressed: () {
                        _deleteSession(session['id']);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}