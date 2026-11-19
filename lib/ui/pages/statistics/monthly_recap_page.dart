import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:read_stats/data/services/analytics_service.dart';
import 'package:read_stats/data/services/recap_store.dart';
import 'package:read_stats/domain/monthly_recap.dart';
import 'package:read_stats/ui/pages/statistics/widgets/month_activity_strip.dart';
import 'package:read_stats/ui/pages/statistics/widgets/recap_share_sheet.dart';
import 'package:read_stats/ui/pages/statistics/widgets/recap_tiles.dart';
import 'package:read_stats/ui/widgets/book_cover.dart';
import 'package:read_stats/ui/widgets/month_picker_popup.dart';

/// A month of reading, on its own page: the month just gone by default, with
/// every earlier month still reachable from the picker at the top.
///
/// Reads the app-level book and session lists rather than the database, so the
/// cover paths have already been resolved and switching months costs nothing —
/// a recap is a pass over rows the app is already holding.
class MonthlyRecapPage extends StatefulWidget {
  final List<Map<String, dynamic>> books;
  final List<Map<String, dynamic>> sessions;

  /// Which month to open on. Defaults to the last completed month, since that
  /// is the one a recap is about; falls back to the current month on an install
  /// with no history behind it.
  final DateTime? initialMonth;

  const MonthlyRecapPage({
    super.key,
    required this.books,
    required this.sessions,
    this.initialMonth,
  });

  @override
  State<MonthlyRecapPage> createState() => _MonthlyRecapPageState();
}

class _MonthlyRecapPageState extends State<MonthlyRecapPage> {
  /// The same star yellow the library rows and share cards use.
  static const Color _starColor = Color(0xFFFBCB04);

  final GlobalKey _monthLabelKey = GlobalKey();

  /// Which way the last month change went, so the outgoing month leaves the
  /// side the incoming one came from. +1 is forward in time.
  int _monthStepDirection = 1;

  late List<DateTime> _months;
  late DateTime _selected;
  late MonthlyRecap _recap;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.screen('monthly_recap');
    AnalyticsService.instance.recapOpened();
    _months = MonthlyRecap.availableMonths(
      books: widget.books,
      sessions: widget.sessions,
    );
    _selected = _resolveInitialMonth();
    _recap = _computeFor(_selected);
    RecapStore.instance.markSeen(_selected.year, _selected.month);
  }

  /// The requested month when it exists, else the newest completed month, else
  /// whatever the picker's first entry is (the current month).
  DateTime _resolveInitialMonth() {
    bool sameMonth(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month;

    final requested = widget.initialMonth;
    if (requested != null) {
      for (final month in _months) {
        if (sameMonth(month, requested)) return month;
      }
    }
    final now = DateTime.now();
    for (final month in _months) {
      if (!sameMonth(month, now)) return month;
    }
    return _months.first;
  }

  MonthlyRecap _computeFor(DateTime month) => MonthlyRecap.forMonth(
    books: widget.books,
    sessions: widget.sessions,
    year: month.year,
    month: month.month,
  );

  void _select(DateTime month) {
    if (month == _selected) return;
    setState(() {
      // Set here rather than in the callers, so the chevrons, the swipe and the
      // grid all slide the way the reader would expect from what they did.
      _monthStepDirection = month.isAfter(_selected) ? 1 : -1;
      _selected = month;
      _recap = _computeFor(month);
    });
    RecapStore.instance.markSeen(month.year, month.month);
  }

  void _share() {
    final cover = _headerCover();
    showRecapShareSheet(
      context: context,
      recap: _recap,
      coverPath: cover?.$1,
      coverShape: cover?.$2,
    );
  }

  /// The cover that stands in for the month on the share cards.
  ///
  /// The most-read book first — a month spent inside one book should look like
  /// that book. But it only has one when the month's sessions carry durations
  /// and the winner happens to have a cover, so a month logged by pages alone,
  /// or one whose books were read earlier and only finished here, would leave
  /// the card with no artwork and the sheet with no Cover toggle. Any finished
  /// book's cover is a better answer than none.
  (String, int?)? _headerCover() {
    final top = _recap.topBookCoverPath;
    if (top != null && top.isNotEmpty) return (top, _recap.topBookCoverShape);
    for (final book in _recap.booksFinished) {
      final path = book.coverPath;
      if (path != null && path.isNotEmpty) return (path, book.coverShape);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Recap'),
        // The same surface Settings gives its bar. It stops at the bar: the
        // month navigator below sits on the page, since it belongs to the
        // month being read rather than to the screen's chrome.
        backgroundColor: theme.colorScheme.surfaceContainer,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            // The same mark the book detail sheet shares from, so the action
            // looks like one action wherever it is offered.
            icon: const Icon(FluentIcons.share_16_filled),
            tooltip: 'Share',
            // A month with nothing in it has no card worth making.
            onPressed: _recap.isEmpty ? null : _share,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildMonthNavigator(theme),
          Divider(height: .5, thickness: .25, color: theme.dividerColor),
          Expanded(
            // The whole month is swipeable, empty state included — a reader who
            // lands on a quiet month should be able to keep going the way they
            // arrived rather than reaching for the chevrons.
            child: GestureDetector(
              onHorizontalDragEnd: _onSwipe,
              // Opaque, not the default deferToChild: an empty month's child is
              // all layout widgets — Center, Padding, Column — none of which
              // hit-test themselves, so the swipe would only answer on the icon
              // and the text glyphs. This makes the whole month the target.
              behavior: HitTestBehavior.opaque,
              // Clipped because the two months are stacked side by side while
              // they cross, and the one on its way out would otherwise paint
              // across whatever sits beside the body.
              child: ClipRect(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) {
                    final incoming =
                        (child.key as ValueKey<DateTime>).value == _selected;
                    // The month arriving comes from the side it was reached
                    // from; the one leaving goes out the opposite side.
                    final begin = Offset(
                      incoming
                          ? _monthStepDirection.toDouble()
                          : -_monthStepDirection.toDouble(),
                      0,
                    );
                    return SlideTransition(
                      position:
                          Tween<Offset>(begin: begin, end: Offset.zero).animate(
                        CurvedAnimation(
                            parent: animation, curve: Curves.easeInOut),
                      ),
                      child: child,
                    );
                  },
                  layoutBuilder: (currentChild, previousChildren) => Stack(
                    children: [...previousChildren, ?currentChild],
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(_selected),
                    child: _recap.isEmpty
                        ? _buildEmptyState(theme)
                        : _buildContent(theme),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The oldest month worth offering, and the newest. Any month between them
  /// can be looked at, including ones with nothing in them — those get the
  /// empty state, which is an answer in itself.
  DateTime get _firstMonth => _months.last;

  DateTime get _currentMonth {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  bool get _canGoOlder => _selected.isAfter(_firstMonth);

  bool get _canGoNewer => _selected.isBefore(_currentMonth);

  /// Steps by the calendar rather than by the months that happen to have
  /// reading in them: the picker can land on any month in range, so the
  /// chevrons have to walk the same ground or they would strand a reader who
  /// jumped to an empty one.
  void _stepMonth(int delta) {
    final next = DateTime(_selected.year, _selected.month + delta);
    if (next.isBefore(_firstMonth) || next.isAfter(_currentMonth)) return;
    _select(next);
  }

  /// One month at a time, stepped either way — the same control Tracking uses
  /// for its calendar, because this page is looking at exactly one month too.
  ///
  /// A row of chips had to be scrolled sideways to reach anything, and grew
  /// without bound: a reader two years in was dragging past twenty-four of
  /// them to reach last March.
  Widget _buildMonthNavigator(ThemeData theme) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Older month',
          onPressed: _canGoOlder ? () => _stepMonth(-1) : null,
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
                  Flexible(
                    child: Text(
                      DateFormat('MMMM yyyy').format(_selected),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.arrow_drop_down,
                      size: 20, color: theme.colorScheme.onSurface),
                ],
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Newer month',
          onPressed: _canGoNewer ? () => _stepMonth(1) : null,
          color: theme.colorScheme.onSurface,
          disabledColor: theme.colorScheme.onSurface.withAlpha(40),
        ),
      ],
    );
  }

  /// The year-and-grid chooser Tracking hangs off its own month label.
  Future<void> _pickMonth() async {
    final picked = await showMonthPickerPopup(
      context: context,
      anchorKey: _monthLabelKey,
      selected: _selected,
      firstMonth: _firstMonth,
      lastMonth: _currentMonth,
    );
    if (picked != null && mounted) _select(picked);
  }

  /// Swiped the way Tracking's calendar is: left for the month after, right
  /// for the one before.
  void _onSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -200 && _canGoNewer) {
      _stepMonth(1);
    } else if (velocity > 200 && _canGoOlder) {
      _stepMonth(-1);
    }
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_stories,
              size: 48,
              color: theme.colorScheme.onSurface.withAlpha(60),
            ),
            const SizedBox(height: 16),
            Text(
              'No reading logged in ${_recap.monthNameOnly}',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Text(
              _recap.isInProgress
                  ? 'Log a session and this month starts filling in.'
                  : 'Pick another month above to see its recap.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    final recap = _recap;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 32),
      children: [
        if (recap.isInProgress) ...[
          _buildInProgressMark(theme),
          const SizedBox(height: 16),
        ],
        _buildHeroRow(theme),
        // Sessions per day is drawable whenever there were any, so this is the
        // one condition that covers all three units. The strip collapsing on
        // its own would leave both of its gaps behind.
        if (recap.sessions > 0) ...[
          const SizedBox(height: 16),
          MonthActivityStrip(recap: recap, color: theme.primaryColor),
        ],
        if (recap.booksFinished.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildFinishedBooks(theme),
        ],
        const SizedBox(height: 16),
        _buildDetailGrid(theme),
      ],
    );
  }

  /// A month still being lived in is a running total, not a verdict.
  ///
  /// All that is left of the heading: the navigator above already names the
  /// month, and setting it again in headline type two rows down was the same
  /// fact twice before the reader reached a single number.
  Widget _buildInProgressMark(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'In progress',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// [IntrinsicHeight] is what bounds the stretch: inside the page's list the
  /// row has no height to stretch to, and asking for one would be infinite.
  Widget _buildHeroRow(ThemeData theme) {
    final recap = _recap;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: RecapHeroTile(
              label: 'Read time',
              value: MonthlyRecap.formatMinutes(recap.minutes),
              delta: _deltaLabel(recap.minutes, recap.previousMinutes),
              positive: recap.minutes >= recap.previousMinutes,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RecapHeroTile(
              label: 'Sessions',
              value: '${recap.sessions}',
              delta: _deltaLabel(recap.sessions, recap.previousSessions),
              positive: recap.sessions >= recap.previousSessions,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RecapHeroTile(
              label: 'Pages',
              value: NumberFormat('#,###').format(recap.pages),
              delta: _deltaLabel(recap.pages, recap.previousPages),
              positive: recap.pages >= recap.previousPages,
            ),
          ),
        ],
      ),
    );
  }

  /// "+18%" against the same figure last month, or nothing when there is no
  /// month before to measure against — a first month is neither up nor down.
  String? _deltaLabel(int current, int previous) {
    if (previous == 0) return null;
    final change = ((current - previous) / previous * 100).round();
    if (change == 0) return 'same';
    return '${change > 0 ? '+' : ''}$change%';
  }

  Widget _buildFinishedBooks(ThemeData theme) {
    final books = _recap.booksFinished;
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${books.length} ${books.length == 1 ? 'book' : 'books'} finished',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(153),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              // Tall enough for a portrait cover (66 wide is 99 high), the
              // rating line, and two lines of title; the title takes whatever
              // is left over, so a larger system font shortens the title
              // instead of overflowing.
              height: 160,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: books.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final book = books[index];
                  return SizedBox(
                    width: 66,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (book.coverPath != null &&
                            book.coverPath!.isNotEmpty)
                          BookCover(
                            path: book.coverPath!,
                            shape: book.coverShape,
                            width: 66,
                          )
                        else
                          Container(
                            width: 66,
                            height: 99,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.menu_book,
                              size: 20,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        const SizedBox(height: 6),
                        // An unrated book keeps the row's height so the titles
                        // stay lined up across the strip.
                        SizedBox(
                          height: 14,
                          child: book.rating > 0
                              ? Row(
                                  children: [
                                    const Icon(
                                      Icons.star_rounded,
                                      size: 13,
                                      color: _starColor,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      book.rating.toStringAsFixed(1),
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ],
                                )
                              : null,
                        ),
                        const SizedBox(height: 2),
                        Expanded(
                          child: Text(
                            book.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The rest of the month's numbers, two to a row. Only the ones that have
  /// something to say are built — a month with no timed session has no longest
  /// session, and an empty card is worse than a shorter list.
  Widget _buildDetailGrid(ThemeData theme) {
    final recap = _recap;
    final tiles = <Widget>[
      RecapDetailTile(
        icon: Icons.calendar_today,
        label: 'Days read',
        value: '${recap.activeDays} of ${recap.daysInMonth}',
      ),
      if (recap.longestDayStreak > 1)
        RecapDetailTile(
          icon: Icons.local_fire_department,
          label: 'Best run',
          value: '${recap.longestDayStreak} days',
        ),
      if (recap.longestSessionMinutes > 0)
        RecapDetailTile(
          icon: Icons.timer,
          label: 'Longest session',
          value: MonthlyRecap.formatMinutes(recap.longestSessionMinutes),
        ),
      if (recap.avgSessionMinutes > 0)
        RecapDetailTile(
          icon: Icons.equalizer,
          label: 'Average session',
          value: MonthlyRecap.formatMinutes(recap.avgSessionMinutes),
        ),
      if (recap.bestDay != null)
        RecapDetailTile(
          // Not a star: filled, it would be the same mark as the average
          // rating two tiles over, for an unrelated fact.
          icon: Icons.bolt,
          label: 'Biggest day',
          value: MonthlyRecap.formatMinutes(recap.bestDayMinutes),
          caption: DateFormat('MMM d').format(recap.bestDay!),
        ),
      if (recap.topBookTitle != null && recap.topBookMinutes > 0)
        RecapDetailTile(
          icon: Icons.auto_stories,
          label: 'Most read',
          value: MonthlyRecap.formatMinutes(recap.topBookMinutes),
          caption: recap.topBookTitle,
        ),
      if (recap.averageRating > 0)
        RecapDetailTile(
          icon: Icons.star_rate_rounded,
          label: 'Average rating',
          value: recap.averageRating.toStringAsFixed(1),
          caption: 'books finished',
        ),
    ];

    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += 2) {
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 8));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: tiles[i]),
              const SizedBox(width: 8),
              // An odd tile out keeps its half of the row rather than stretching
              // across, so the grid stays a grid.
              Expanded(
                child: i + 1 < tiles.length ? tiles[i + 1] : const SizedBox(),
              ),
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}
