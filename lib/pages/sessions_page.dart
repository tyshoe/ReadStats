import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'edit_session_page.dart';
import 'add_session_page.dart';
import '../repositories/session_repository.dart';
import '../repositories/book_repository.dart';

class SessionsPage extends StatefulWidget {
  final List<Map<String, dynamic>> books;
  final List<Map<String, dynamic>> sessions;
  final Function() refreshSessions;

  const SessionsPage({
    super.key,
    required this.books,
    required this.sessions,
    required this.refreshSessions,
  });

  @override
  State<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends State<SessionsPage> {
  final SessionRepository _sessionRepo = SessionRepository();
  final BookRepository _bookRepo = BookRepository();

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

  // Group sessions by month and year
  Map<String, List<Map<String, dynamic>>> _groupSessionsByMonth() {
    Map<String, List<Map<String, dynamic>>> groupedSessions = {};

    for (var session in widget.sessions) {
      String date = session['date'] ?? '';
      if (date.isEmpty) continue;

      DateTime sessionDate = DateTime.parse(date);
      String monthYear = DateFormat('MMMM yyyy').format(sessionDate);

      if (!groupedSessions.containsKey(monthYear)) {
        groupedSessions[monthYear] = [];
      }
      groupedSessions[monthYear]!.add(session);
    }

    return groupedSessions;
  }

  Future<Map<String, dynamic>?> _fetchBookById(int bookId) async {
    return await _bookRepo.getBookById(bookId);
  }

  void _navigateToEditSessionsPage(Map<String, dynamic> session) async {
    int bookId = session['book_id'];
    Map<String, dynamic>? book = await _fetchBookById(bookId);

    if (book != null) {
      await Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (context) => EditSessionPage(
            session: session,
            book: book,
            refreshSessions: widget.refreshSessions,
          ),
        ),
      );
    } else {
      showCupertinoDialog(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text("Error"),
          content: const Text("Book details not found."),
          actions: [
            CupertinoDialogAction(
              child: const Text("OK"),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    }
  }

  void _navigateToAddSessionPage() async {
    await Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => LogSessionPage(
          books: widget.books,
          refreshSessions: widget.refreshSessions,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = CupertinoColors.systemBackground.resolveFrom(context);
    final textColor = CupertinoColors.label.resolveFrom(context);
    final groupedSessions = _groupSessionsByMonth();

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Reading Sessions'),
        backgroundColor: bgColor,
      ),
      child: SafeArea(
        child: Stack(
          children: [
            widget.sessions.isEmpty
                ? Center(
              child: Text(
                'No sessions logged yet',
                style: TextStyle(color: textColor),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: groupedSessions.length,
              itemBuilder: (context, index) {
                String monthYear = groupedSessions.keys.elementAt(index);
                List<Map<String, dynamic>> sessions =
                groupedSessions[monthYear]!;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding:
                      const EdgeInsets.symmetric(vertical: 10.0),
                      child: Text(
                        monthYear,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                    ...sessions.map((session) {
                      final bookTitle =
                          session['book_title'] ?? 'Unknown Book';
                      final pagesRead = session['pages_read'] ?? 0;
                      final hours = session['hours'] ?? 0;
                      final minutes = session['minutes'] ?? 0;
                      final date = session['date'] ?? '';

                      return GestureDetector(
                        onTap: () {
                          _navigateToEditSessionsPage(session);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding:
                          const EdgeInsets.symmetric(vertical: 5),
                          decoration: BoxDecoration(
                            color: CupertinoColors
                                .secondarySystemBackground
                                .resolveFrom(context),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: CupertinoListTile(
                            title: Text(bookTitle),
                            subtitle: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
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
                                  date.isNotEmpty
                                      ? '📅 ${_formatDate(date)}'
                                      : '📅 No date available',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                            trailing: Icon(CupertinoIcons.chevron_right,
                                color: textColor),
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                );
              },
            ),
            Positioned(
              bottom: 20,
              right: 20,
              child: CupertinoButton(
                padding: const EdgeInsets.all(16),
                borderRadius: BorderRadius.circular(30),
                color: CupertinoColors.systemPurple,
                onPressed: _navigateToAddSessionPage,
                child:
                const Icon(CupertinoIcons.add, color: CupertinoColors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
