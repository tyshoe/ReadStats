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
  final Function() refreshBooks;
  final SettingsViewModel settingsViewModel;
  final SessionRepository sessionRepository;
  final BookRepository bookRepository;

  const SessionsPage({
    super.key,
    required this.books,
    required this.sessions,
    required this.refreshSessions,
    required this.refreshBooks,
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
  late DateTime _selectedMonth;
  int _monthStepDirection = 1;

  @override
  void initState() {
    super.initState();
    _initializeBookMap();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
    _dateFormatString = widget.settingsViewModel.defaultDateFormatNotifier.value;

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
    if (minutes < 60) {
      return '$minutes\u00A0min';
    }

    final int hours = minutes ~/ 60;
    final int remainingMinutes = minutes % 60;

    if (remainingMinutes == 0) {
      return '${hours}h';
    }

    return '${hours}h\u00A0${remainingMinutes}m';
  }


  String _formatDate(String isoDate) {
    final date = DateTime.parse(isoDate);
    return DateFormat(_dateFormatString).format(date);
  }

  Map<String, List<Map<String, dynamic>>> _groupSessionsByMonthAll() {
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
            onSave: () {
              widget.refreshSessions();
              widget.refreshBooks();
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
          onSave: () {
            widget.refreshSessions();
            widget.refreshBooks();
          },
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

  DateTime? get _firstSessionMonth {
    if (widget.sessions.isEmpty) return null;
    final earliest = widget.sessions
        .map((s) => DateTime.parse(s['date']))
        .reduce((a, b) => a.isBefore(b) ? a : b);
    return DateTime(earliest.year, earliest.month);
  }

  void _stepMonth(int delta) {
    setState(() {
      _monthStepDirection = delta;
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + delta);
    });
  }

  Widget _buildMonthNavigator() {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    final firstMonth = _firstSessionMonth;

    final canGoBack = firstMonth != null && _selectedMonth.isAfter(firstMonth);
    final canGoForward = _selectedMonth.isBefore(currentMonth);

    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: canGoBack ? () => _stepMonth(-1) : null,
          color: theme.colorScheme.onSurface,
          disabledColor: theme.colorScheme.onSurface.withAlpha(40),
        ),
        Expanded(
          child: Text(
            DateFormat('MMMM yyyy').format(_selectedMonth),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: canGoForward ? () => _stepMonth(1) : null,
          color: theme.colorScheme.onSurface,
          disabledColor: theme.colorScheme.onSurface.withAlpha(40),
        ),
      ],
    );
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
    final theme = Theme.of(context);
    final book = session['book'];

    final bookTitle = book?['title'] ?? 'Unknown Book';
    final bookAuthor = book?['author'] ?? 'Unknown Author';

    final int pagesRead = int.tryParse(session['pages_read']?.toString() ?? '0') ?? 0;
    final int minutes = int.tryParse(session['duration_minutes']?.toString() ?? '0') ?? 0;
    final String date = session['date'] ?? '';

    final double pagesPerMinute = (pagesRead > 0 && minutes > 0) ? pagesRead / minutes : 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Dismissible(
      key: ValueKey(session['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.error,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 28),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Session'),
            content: const Text('Are you sure you want to delete this session?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (_) async {
        await widget.sessionRepository.deleteSession(session['id']);
        widget.refreshSessions();
        widget.refreshBooks();
      },
      child: Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      shape: const RoundedRectangleBorder(),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _navigateToEditSessionsPage(session),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bookTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      bookAuthor,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(160),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      date.isNotEmpty ? _formatDate(date) : 'No date',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(120),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatDuration(minutes),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (pagesRead > 0)
                    Text(
                      '$pagesRead pages',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (pagesRead > 0 && minutes > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.speed,
                          size: 12,
                          color: theme.colorScheme.onSurface.withAlpha(153),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${pagesPerMinute.toStringAsFixed(1)}/min',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurface.withAlpha(153),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
      ),
      ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = widget.settingsViewModel.accentColorNotifier.value;

    final start = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final end = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);

    final groupedSessions = _groupSessionsByMonthAll();

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
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                _buildMonthNavigator(),
                GestureDetector(
                  onHorizontalDragEnd: (details) {
                    final velocity = details.primaryVelocity ?? 0;
                    if (velocity < -200) {
                      final now = DateTime.now();
                      if (_selectedMonth.isBefore(DateTime(now.year, now.month))) {
                        _stepMonth(1);
                      }
                    } else if (velocity > 200) {
                      final first = _firstSessionMonth;
                      if (first != null && _selectedMonth.isAfter(first)) {
                        _stepMonth(-1);
                      }
                    }
                  },
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) {
                      final isIncoming =
                          (child.key as ValueKey<DateTime>).value == _selectedMonth;
                      final begin = Offset(
                        isIncoming ? _monthStepDirection.toDouble() : -_monthStepDirection.toDouble(),
                        0,
                      );
                      return SlideTransition(
                        position: Tween<Offset>(begin: begin, end: Offset.zero)
                            .animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut)),
                        child: child,
                      );
                    },
                    layoutBuilder: (currentChild, previousChildren) => Stack(
                      children: [
                        ...previousChildren,
                        if (currentChild != null) currentChild,
                      ],
                    ),
                    child: KeyedSubtree(
                      key: ValueKey(_selectedMonth),
                      child: SessionsCalendar(
                        start: start,
                        end: end,
                        sessions: widget.sessions,
                        isCurrentMonth: true,
                      ),
                    ),
                  ),
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
              child: Icon(Icons.add, color: theme.colorScheme.onPrimary),
            )
          : null,
    );
  }
}
