import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'session_form_page.dart';
import '/viewmodels/SettingsViewModel.dart';
import '/data/repositories/session_repository.dart';
import '/data/repositories/book_repository.dart';
import 'widgets/session_calendar.dart';

class SessionsPage extends StatefulWidget {
  final List<Map<String, dynamic>> books;
  final List<Map<String, dynamic>> sessions;
  final Function() refreshSessions;
  final SettingsViewModel settingsViewModel;
  final SessionRepository sessionRepository;
  final BookRepository bookRepository;

  const SessionsPage({
    super.key,
    required this.books,
    required this.sessions,
    required this.refreshSessions,
    required this.settingsViewModel,
    required this.sessionRepository,
    required this.bookRepository,
  });

  @override
  State<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends State<SessionsPage> {
  late Map<int, Map<String, dynamic>> _bookMap;
  late String _dateFormatString;
  late final VoidCallback _formatListener;

  @override
  void initState() {
    super.initState();
    _initializeBookMap();
    _dateFormatString = widget.settingsViewModel.defaultDateFormatNotifier.value;

    // Add listener for date format changes
    _formatListener = () {
      if (mounted) {
        setState(() {
          _dateFormatString = widget.settingsViewModel.defaultDateFormatNotifier.value;
        });
      }
    };
    widget.settingsViewModel.defaultDateFormatNotifier.addListener(_formatListener);
  }

  @override
  void didUpdateWidget(covariant SessionsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.books != widget.books) {
      _initializeBookMap();
      widget.refreshSessions();
    }
  }

  @override
  void dispose() {
    widget.settingsViewModel.defaultDateFormatNotifier.removeListener(_formatListener);
    super.dispose();
  }

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
    return '$hourText$minuteText'.trim();
  }

  String _formatDate(String isoDate) {
    final date = DateTime.parse(isoDate);
    return DateFormat(_dateFormatString).format(date);
  }

  Map<String, List<Map<String, dynamic>>> _groupSessionsByMonth() {
    Map<String, List<Map<String, dynamic>>> groupedSessions = {};

    for (var session in widget.sessions) {
      String date = session['date'] ?? '';
      if (date.isEmpty) continue;

      DateTime sessionDate = DateTime.parse(date);
      String monthYear = DateFormat('MMMM yyyy').format(sessionDate);

      int bookId = session['book_id'];
      Map<String, dynamic>? book = _bookMap[bookId];
      var sessionWithBook = {...session, 'book': book};

      groupedSessions.putIfAbsent(monthYear, () => []).add(sessionWithBook);
    }

    return groupedSessions;
  }

  void _navigateToEditSessionsPage(Map<String, dynamic> session) async {
    int bookId = session['book_id'];
    Map<String, dynamic>? book = _bookMap[bookId];

    if (book != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SessionFormPage(
            session: session,
            book: book,
            availableBooks: [],
            // Not used in edit mode
            refreshSessions: () {
              widget.refreshSessions();
            },
            settingsViewModel: widget.settingsViewModel,
            sessionRepository: widget.sessionRepository,
            bookRepository: widget.bookRepository,
          ),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Error"),
          content: const Text("Book details not found."),
          actions: [
            TextButton(
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
      MaterialPageRoute(
        builder: (context) => SessionFormPage(
          availableBooks: widget.books.where((book) => book['is_completed'] == 0).toList(),
          refreshSessions: widget.refreshSessions,
          settingsViewModel: widget.settingsViewModel,
          sessionRepository: widget.sessionRepository,
          bookRepository: widget.bookRepository,
        ),
      ),
    );
  }


  String _getMessageToDisplay() {
    if (widget.books.isEmpty) {
      return 'Add a book to your library';
    } else if (widget.sessions.isEmpty) {
      return 'No sessions, time to get cozy and read a few pages';
    }
    return '';
  }

  Widget _buildStats(DateTime start, DateTime end) {
    final sessionsInRange = widget.sessions.where((s) {
      final date = DateTime.parse(s['date']);
      return !date.isBefore(start) && !date.isAfter(end);
    }).toList();

    final totalSessions = sessionsInRange.length;
    final totalMinutes = sessionsInRange.fold<int>(0, (sum, s) {
      final minutes = int.tryParse(s['duration_minutes']?.toString() ?? '0') ?? 0;
      return sum + minutes;
    });

    final totalPages = sessionsInRange.fold<int>(0, (sum, s) {
      final pages = int.tryParse(s['pages_read']?.toString() ?? '0') ?? 0;
      return sum + pages;
    });

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatCard("Sessions", "$totalSessions"),
          _buildStatCard("Time", _formatDuration(totalMinutes)),
          _buildStatCard("Pages", "$totalPages"),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _buildSessionCard(Map<String, dynamic> session) {
    final theme = Theme.of(context); // use context from StatefulWidget
    final book = session['book'];
    final bookTitle = book?['title'] ?? 'Unknown Book';
    final bookAuthor = book?['author'] ?? 'Unknown Author';
    final pagesRead = session['pages_read'] ?? 0;
    final minutes = session['duration_minutes'] ?? 0;
    final date = session['date'] ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 1,
      child: InkWell(
        onTap: () => _navigateToEditSessionsPage(session),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bookTitle,
                      style: theme.textTheme.bodyLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      bookAuthor,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$pagesRead pages',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  Text(
                    _formatDuration(minutes),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  Text(
                    date.isNotEmpty ? _formatDate(date) : 'No date',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groupedSessions = _groupSessionsByMonth();
    final accentColor = widget.settingsViewModel.accentColorNotifier.value;

    final now = DateTime.now();
    final end = now.subtract(Duration(days: now.weekday % 7 - 6));
    final start = end.subtract(const Duration(days: 34));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reading Sessions'),
        backgroundColor: theme.scaffoldBackgroundColor,
        centerTitle: false,
        elevation: 0,
      ),
      body: widget.sessions.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  _getMessageToDisplay(),
                  style: theme.textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(8),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(
                    'Monthly Review',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SessionsCalendar(
                  start: start,
                  end: end,
                  sessions: widget.sessions,
                ),
                const SizedBox(height: 8),
                _buildStats(start, end),
                Divider(
                  color: Colors.grey[600],
                  height: 1,
                ),
                ...groupedSessions.entries.map((entry) {
                  final monthYear = entry.key;
                  final sessions = entry.value;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16),
                        child: Text(
                          monthYear,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ...sessions.map(_buildSessionCard),
                    ],
                  );
                }),
              ],
            ),
      floatingActionButton: widget.books.isNotEmpty
          ? FloatingActionButton(
              backgroundColor: accentColor,
              onPressed: _navigateToAddSessionPage,
              child: Icon(Icons.add, color: Theme.of(context).colorScheme.onPrimary),
            )
          : null,
    );
  }
}
