import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'edit_session_page.dart';
import 'add_session_page.dart';
import '../repositories/session_repository.dart';
import '../repositories/book_repository.dart';

class SessionsPage extends StatefulWidget {
  final List<Map<String, dynamic>> books;
  final List<Map<String, dynamic>> sessions;
  final Function() refreshSessions; // Function to refresh the list from parent

  const SessionsPage(
      {super.key,
        required this.books,
        required this.sessions,
        required this.refreshSessions});

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
          books: widget.books, // Passes the full book list
          refreshSessions: widget.refreshSessions,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = CupertinoColors.systemBackground.resolveFrom(context);
    final textColor = CupertinoColors.label.resolveFrom(context);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
          middle: Text('Reading Sessions'), backgroundColor: bgColor),
      child: SafeArea(
        child: Stack(
          children: [
            widget.sessions.isEmpty
                ? Center(
                child: Text(
                  'No sessions logged yet',
                  style: TextStyle(color: textColor),
                ))
                : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: widget.sessions.length,
              itemBuilder: (context, index) {
                final session = widget.sessions[index];
                final bookTitle = session['book_title'] ?? 'Unknown Book'; // Default if null
                final pagesRead = session['pages_read'] ?? 0;
                final hours = session['hours'] ?? 0;
                final minutes = session['minutes'] ?? 0;
                final date = session['date'] ?? ''; // Default if null

                return GestureDetector(
                  onTap: () {
                    _navigateToEditSessionsPage(session); // Navigate to the edit session page when tapped
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    decoration: BoxDecoration(
                      color: CupertinoColors.secondarySystemBackground
                          .resolveFrom(context),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: CupertinoListTile(
                      title: Text(bookTitle), // Use the fallback string if null
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
                child: const Icon(CupertinoIcons.add, color: CupertinoColors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
