import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'edit_session_page.dart';
import 'add_session_page.dart';
import '/viewmodels/SettingsViewModel.dart';
import '/data/repositories/session_repository.dart';

class SessionsPage extends StatefulWidget {
  final List<Map<String, dynamic>> books;
  final List<Map<String, dynamic>> sessions;
  final Function() refreshSessions;
  final SettingsViewModel settingsViewModel;
  final SessionRepository sessionRepository;

  const SessionsPage({
    super.key,
    required this.books,
    required this.sessions,
    required this.refreshSessions,
    required this.settingsViewModel,
    required this.sessionRepository,
  });

  @override
  State<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends State<SessionsPage> {
  late Map<int, Map<String, dynamic>> _bookMap;

  @override
  void initState() {
    super.initState();
    _initializeBookMap();
  }

  @override
  void didUpdateWidget(covariant SessionsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.books != widget.books) {
      _initializeBookMap();
      widget.refreshSessions();
    }
  }

  // Fetch book details and store in a map
  void _initializeBookMap() {
    setState(() {
      _bookMap = {for (var book in widget.books) book['id']: book};
    });
  }

  String _formatDuration(int minutes) {
    final int hours = minutes ~/ 60;
    final int remainingMinutes = minutes % 60;

    final String hourText = hours > 0 ? '${hours}h ' : '';
    final String minuteText = '${remainingMinutes}m';
    return '$hourText$minuteText'.trim(); // Trim to remove extra spaces
  }

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

      // Merge book data with session
      int bookId = session['book_id'];
      Map<String, dynamic>? book = _bookMap[bookId];

      var sessionWithBook = {...session, 'book': book};

      if (!groupedSessions.containsKey(monthYear)) {
        groupedSessions[monthYear] = [];
      }
      groupedSessions[monthYear]!.add(sessionWithBook);
    }

    return groupedSessions;
  }

  void _navigateToEditSessionsPage(Map<String, dynamic> session) async {
    int bookId = session['book_id'];
    Map<String, dynamic>? book = _bookMap[bookId];

    if (book != null) {
      await Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (context) => EditSessionPage(
            session: session,
            book: book,
            refreshSessions: widget.refreshSessions,
            settingsViewModel: widget.settingsViewModel,
            sessionRepository: widget.sessionRepository,
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
          settingsViewModel: widget.settingsViewModel,
          sessionRepository: widget.sessionRepository,
        ),
      ),
    );
  }

  String _getMessageToDisplay() {
    if (widget.books.isEmpty) {
      return 'Add a book to your library';
    } else if (widget.sessions.isEmpty) {
      return 'No sessions, time to get cozy and read a few pages';
    } else {
      return ''; // No message when there are books and sessions
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = CupertinoColors.systemBackground.resolveFrom(context);
    final textColor = CupertinoColors.label.resolveFrom(context);
    final groupedSessions = _groupSessionsByMonth();
    final accentColor = widget.settingsViewModel.accentColorNotifier.value;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Reading Sessions'),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            widget.sessions.isEmpty
                ? Center(
                    child: Text(
                      _getMessageToDisplay(),
                      style: TextStyle(color: textColor),
                      textAlign: TextAlign.center,
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
                            padding: const EdgeInsets.symmetric(vertical: 10.0),
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
                            final book = session['book'];
                            final bookTitle = book?['title'] ?? 'Unknown Book';
                            final bookAuthor =
                                book?['author'] ?? 'Unknown Author';
                            final pagesRead = session['pages_read'] ?? 0;
                            final minutes = session['duration_minutes'] ?? 0;
                            final date = session['date'] ?? '';

                            return GestureDetector(
                              onTap: () {
                                _navigateToEditSessionsPage(session);
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 10, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: CupertinoColors
                                      .secondarySystemBackground
                                      .resolveFrom(context),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // Left Column
                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(bookTitle,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                overflow: TextOverflow.ellipsis,
                                              )),
                                          Text(bookAuthor,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color:
                                                    CupertinoColors.systemGrey,
                                                overflow: TextOverflow.ellipsis,
                                              )),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 24),
                                    // Right Column
                                    Expanded(
                                      flex: 1,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('$pagesRead pages',
                                              style: const TextStyle(
                                                  color: CupertinoColors
                                                      .systemGrey,
                                                  fontSize: 14)),
                                          Text(_formatDuration(minutes),
                                              style: const TextStyle(
                                                  color: CupertinoColors
                                                      .systemGrey,
                                                  fontSize: 14)),
                                          Text(
                                            date.isNotEmpty
                                                ? _formatDate(date)
                                                : 'No date available',
                                            style: const TextStyle(
                                                color:
                                                    CupertinoColors.systemGrey,
                                                fontSize: 14),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Edit Icon (Trailing)
                                    const Icon(CupertinoIcons.chevron_right,
                                        color: CupertinoColors.systemGrey),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ],
                      );
                    },
                  ),
            if (widget.books.isNotEmpty)
              Positioned(
                bottom: 20,
                right: 20,
                child: CupertinoButton(
                  padding: const EdgeInsets.all(16),
                  borderRadius: BorderRadius.circular(16),
                  color: accentColor,
                  onPressed: _navigateToAddSessionPage,
                  child: const Icon(CupertinoIcons.add,
                      color: CupertinoColors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
