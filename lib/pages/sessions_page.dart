import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'edit_session_page.dart';
import 'log_session_page.dart';
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

  // Delete a session from the database
  Future<void> _deleteSession(int sessionId) async {
    await _sessionRepo.deleteSession(sessionId);
    widget.refreshSessions();
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

  void _confirmDelete(int sessionId) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete Session'),
        content: const Text('Are you sure you want to delete this session?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            child: const Text('Delete'),
            isDestructiveAction: true,
            onPressed: () async {
              _deleteSession(sessionId);
              Navigator.pop(context); // Close the dialog
            },
          ),
        ],
      ),
    );
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
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Reading Sessions'),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            widget.sessions.isEmpty
                ? const Center(child: Text('No sessions logged yet'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: widget.sessions.length,
                    itemBuilder: (context, index) {
                      final session = widget.sessions[index];
                      final bookTitle = session['book_title'] ??
                          'Unknown Book'; // Default if null
                      final pagesRead = session['pages_read'] ?? 0;
                      final hours = session['hours'] ?? 0;
                      final minutes = session['minutes'] ?? 0;
                      final date = session['date'] ?? ''; // Default if null

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemGrey6,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: CupertinoListTile(
                          title: Text(
                              bookTitle), // Use the fallback string if null
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
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CupertinoButton(
                                padding: EdgeInsets.zero,
                                child: const Icon(CupertinoIcons.pencil),
                                onPressed: () {
                                  _navigateToEditSessionsPage(session);
                                },
                              ),
                              CupertinoButton(
                                padding: EdgeInsets.zero,
                                child: const Icon(CupertinoIcons.delete,
                                    color: CupertinoColors.destructiveRed),
                                onPressed: () {
                                  _confirmDelete(session['id']);
                                },
                              ),
                            ],
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
                color: CupertinoColors.activeBlue,
                child: const Icon(CupertinoIcons.add,
                    color: CupertinoColors.white),
                onPressed: _navigateToAddSessionPage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
