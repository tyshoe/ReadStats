import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'session_form_page.dart';
import 'widgets/rate_book_dialog.dart';
import '/viewmodels/SettingsViewModel.dart';
import '/data/repositories/session_repository.dart';
import '/data/repositories/book_repository.dart';
import '/data/repositories/goal_repository.dart';
import '/data/services/reading_timer_service.dart';
import 'widgets/session_calendar.dart';
import 'widgets/goals_tab.dart';
import 'widgets/reading_timer_widget.dart';

class SessionsPage extends StatefulWidget {
  final List<Map<String, dynamic>> books;
  final List<Map<String, dynamic>> sessions;
  final Function() refreshSessions;
  final Function() refreshBooks;
  final SettingsViewModel settingsViewModel;
  final SessionRepository sessionRepository;
  final BookRepository bookRepository;
  final GoalRepository goalRepository;
  final ReadingTimerService timerService;

  const SessionsPage({
    super.key,
    required this.books,
    required this.sessions,
    required this.refreshSessions,
    required this.refreshBooks,
    required this.settingsViewModel,
    required this.sessionRepository,
    required this.bookRepository,
    required this.goalRepository,
    required this.timerService,
  });

  @override
  State<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends State<SessionsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Map<int, Map<String, dynamic>> _bookMap;
  late String _dateFormatString;
  late final VoidCallback _formatListener;
  late DateTime _selectedMonth;
  int _monthStepDirection = 1;
  final GlobalKey _monthLabelKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
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
    _tabController.dispose();
    widget.settingsViewModel.defaultDateFormatNotifier.removeListener(_formatListener);
    super.dispose();
  }

  static const _shelfOrder = {
    1: 0, // Currently Reading
    2: 1, // Want to Read
    4: 2, // Unfinished
    3: 3, // Finished
  };

  List<Map<String, dynamic>> _sortedAvailableBooks() {
    final sorted = List<Map<String, dynamic>>.from(widget.books);
    sorted.sort((a, b) {
      final shelfA = _shelfOrder[a['shelf_id'] as int? ?? 0] ?? 99;
      final shelfB = _shelfOrder[b['shelf_id'] as int? ?? 0] ?? 99;
      if (shelfA != shelfB) return shelfA.compareTo(shelfB);
      final titleA = (a['title'] as String? ?? '').toLowerCase();
      final titleB = (b['title'] as String? ?? '').toLowerCase();
      return titleA.compareTo(titleB);
    });
    return sorted;
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
    final finishedBook = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => SessionFormPage(
          availableBooks: _sortedAvailableBooks(),
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

    if (finishedBook != null && mounted) {
      await _showRatingDialog(finishedBook);
    }
  }

  Future<void> _showRatingDialog(Map<String, dynamic> book) =>
      showRatingDialogForBook(
        context: context,
        book: book,
        bookRepository: widget.bookRepository,
        settingsViewModel: widget.settingsViewModel,
      );

  String _getMessageToDisplay() {
    if (widget.books.isEmpty) {
      return 'Add a book to your library';
    } else if (widget.sessions.isEmpty) {
      return 'No sessions, time to get cozy and read a few pages';
    }
    return '';
  }

  Map<String, dynamic>? _lastUsedBook() {
    if (widget.sessions.isEmpty) return null;
    final sorted = List<Map<String, dynamic>>.from(widget.sessions)
      ..sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
    return _bookMap[sorted.first['book_id']];
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

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    final firstMonth = _firstSessionMonth ?? currentMonth;

    final box =
        _monthLabelKey.currentContext?.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    const popupWidth = 300.0;

    final labelTopLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    final left = (labelTopLeft.dx + box.size.width / 2 - popupWidth / 2)
        .clamp(8.0, overlay.size.width - popupWidth - 8.0);
    final top = labelTopLeft.dy + box.size.height + 6;

    int displayYear = _selectedMonth.year;

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (dialogCtx, anim, _) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              width: popupWidth,
              child: FadeTransition(
                opacity: anim,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.9, end: 1.0).animate(curved),
                  alignment: Alignment.center,
                  child: Material(
                    color: cs.surfaceContainerHigh,
                    elevation: 12,
                    shadowColor: Colors.black.withValues(alpha: 0.35),
                    surfaceTintColor: Colors.transparent,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: cs.outlineVariant),
                    ),
                    child: StatefulBuilder(
                      builder: (ctx, setMenuState) {
                        bool inRange(int month) {
                          final m = DateTime(displayYear, month);
                          return !m.isBefore(firstMonth) &&
                              !m.isAfter(currentMonth);
                        }

                        Widget monthCell(int month) {
                          final enabled = inRange(month);
                          final selected = displayYear == _selectedMonth.year &&
                              month == _selectedMonth.month;
                          return Material(
                            color: selected
                                ? cs.primaryContainer
                                : cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(10),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: (!enabled || selected)
                                  ? null
                                  : () {
                                      Navigator.pop(dialogCtx);
                                      setState(() {
                                        final picked =
                                            DateTime(displayYear, month);
                                        _monthStepDirection =
                                            picked.isAfter(_selectedMonth)
                                                ? 1
                                                : -1;
                                        _selectedMonth = picked;
                                      });
                                    },
                              child: Center(
                                child: Text(
                                  DateFormat('MMM')
                                      .format(DateTime(displayYear, month)),
                                  style: TextStyle(
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: !enabled
                                        ? cs.onSurface.withValues(alpha: 0.3)
                                        : selected
                                            ? cs.onPrimaryContainer
                                            : cs.onSurface,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }

                        return Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.chevron_left),
                                    onPressed: displayYear > firstMonth.year
                                        ? () =>
                                            setMenuState(() => displayYear--)
                                        : null,
                                    color: cs.onSurface,
                                    disabledColor: cs.onSurface.withAlpha(40),
                                  ),
                                  Expanded(
                                    child: Text(
                                      '$displayYear',
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.chevron_right),
                                    onPressed: displayYear < currentMonth.year
                                        ? () =>
                                            setMenuState(() => displayYear++)
                                        : null,
                                    color: cs.onSurface,
                                    disabledColor: cs.onSurface.withAlpha(40),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              GridView.count(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisCount: 3,
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
                                childAspectRatio: 2.0,
                                children: [
                                  for (int mo = 1; mo <= 12; mo++) monthCell(mo),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
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
          child: InkWell(
            key: _monthLabelKey,
            borderRadius: BorderRadius.circular(8),
            onTap: _pickMonth,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('MMMM yyyy').format(_selectedMonth),
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.arrow_drop_down, size: 20, color: theme.colorScheme.onSurface),
                ],
              ),
            ),
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

    final uniqueDays = sessionsInRange
        .map((s) => s['date']?.toString().substring(0, 10))
        .whereType<String>()
        .toSet()
        .length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatCard("Time", _formatDuration(totalMinutes)),
              _buildStatCard("Sessions", "$totalSessions"),
              _buildStatCard("Days", "$uniqueDays"),
              _buildStatCard("Pages", "$totalPages"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
    final String? coverPath = book?['cover_path'] as String?;

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
          padding: coverPath != null
              ? const EdgeInsets.fromLTRB(8, 8, 14, 8)
              : const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (coverPath != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.file(
                    File(coverPath),
                    width: 42,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(width: 12),
              ],
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
      ),
    );
  }

  Widget _buildSessionsTab(ThemeData theme, Color accentColor) {
    final start = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final end = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);

    final groupedSessions = _groupSessionsByMonthAll()
      ..removeWhere((key, _) => key != DateFormat('MMMM yyyy').format(_selectedMonth));

    final sessionCards = groupedSessions.values.firstOrNull?.map(_buildSessionCard).toList() ?? [];

    final sessionsContent = widget.sessions.isEmpty
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
        : Scrollbar(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 88),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: SizedBox(height: 36, child: _buildMonthNavigator()),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: GestureDetector(
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
                          isIncoming
                              ? _monthStepDirection.toDouble()
                              : -_monthStepDirection.toDouble(),
                          0,
                        );
                        return SlideTransition(
                          position: Tween<Offset>(begin: begin, end: Offset.zero)
                              .animate(CurvedAnimation(
                                  parent: animation, curve: Curves.easeInOut)),
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
                ),
                const SizedBox(height: 8),
                _buildStats(start, end),
                const SizedBox(height: 8),
                Divider(color: Colors.grey[600], height: 1),
                const SizedBox(height: 8),
                if (sessionCards.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No sessions this month',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha(120),
                        ),
                      ),
                    ),
                  )
                else
                  ...sessionCards,
              ],
            ),
          );

    return Column(
      children: [
        ReadingTimerWidget(
          timerService: widget.timerService,
          books: widget.books,
          defaultBook: _lastUsedBook(),
          sessionRepository: widget.sessionRepository,
          bookRepository: widget.bookRepository,
          settingsViewModel: widget.settingsViewModel,
          onSessionSaved: () {
            widget.refreshSessions();
            widget.refreshBooks();
          },
        ),
        Expanded(
          child: Stack(
            children: [
              sessionsContent,
              if (widget.books.isNotEmpty)
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton(
                    heroTag: 'sessions_fab',
                    backgroundColor: accentColor,
                    onPressed: _navigateToAddSessionPage,
                    child: Icon(Icons.add, color: theme.colorScheme.onPrimary),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = widget.settingsViewModel.accentColorNotifier.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tracking'),
        backgroundColor: theme.scaffoldBackgroundColor,
        centerTitle: false,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: accentColor,
          labelColor: accentColor,
          unselectedLabelColor: theme.colorScheme.onSurface.withAlpha(160),
          tabs: const [
            Tab(height: 40, text: 'Sessions'),
            Tab(height: 40, text: 'Goals'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSessionsTab(theme, accentColor),
          GoalsTab(
            goalRepository: widget.goalRepository,
            settingsViewModel: widget.settingsViewModel,
          ),
        ],
      ),
    );
  }
}
