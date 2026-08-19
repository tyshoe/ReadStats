import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '/data/models/monthly_recap.dart';
import '/data/services/recap_store.dart';
import '/ui/widgets/book_cover.dart';
import '/ui/widgets/month_picker_popup.dart';
import 'widgets/recap_share_sheet.dart';

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
          _MonthActivityStrip(recap: recap, color: theme.primaryColor),
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
            child: _HeroTile(
              label: 'Read time',
              value: MonthlyRecap.formatMinutes(recap.minutes),
              delta: _deltaLabel(recap.minutes, recap.previousMinutes),
              positive: recap.minutes >= recap.previousMinutes,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _HeroTile(
              label: 'Sessions',
              value: '${recap.sessions}',
              delta: _deltaLabel(recap.sessions, recap.previousSessions),
              positive: recap.sessions >= recap.previousSessions,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _HeroTile(
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
      _DetailTile(
        icon: Icons.calendar_today,
        label: 'Days read',
        value: '${recap.activeDays} of ${recap.daysInMonth}',
      ),
      if (recap.longestDayStreak > 1)
        _DetailTile(
          icon: Icons.local_fire_department,
          label: 'Best run',
          value: '${recap.longestDayStreak} days',
        ),
      if (recap.longestSessionMinutes > 0)
        _DetailTile(
          icon: Icons.timer,
          label: 'Longest session',
          value: MonthlyRecap.formatMinutes(recap.longestSessionMinutes),
        ),
      if (recap.avgSessionMinutes > 0)
        _DetailTile(
          icon: Icons.equalizer,
          label: 'Average session',
          value: MonthlyRecap.formatMinutes(recap.avgSessionMinutes),
        ),
      if (recap.bestDay != null)
        _DetailTile(
          // Not a star: filled, it would be the same mark as the average
          // rating two tiles over, for an unrelated fact.
          icon: Icons.bolt,
          label: 'Biggest day',
          value: MonthlyRecap.formatMinutes(recap.bestDayMinutes),
          caption: DateFormat('MMM d').format(recap.bestDay!),
        ),
      if (recap.topBookTitle != null && recap.topBookMinutes > 0)
        _DetailTile(
          icon: Icons.auto_stories,
          label: 'Most read',
          value: MonthlyRecap.formatMinutes(recap.topBookMinutes),
          caption: recap.topBookTitle,
        ),
      if (recap.averageRating > 0)
        _DetailTile(
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

/// One of the three headline numbers, with how it compares to last month.
class _HeroTile extends StatelessWidget {
  final String label;
  final String value;
  final String? delta;
  final bool positive;

  const _HeroTile({
    required this.label,
    required this.value,
    this.delta,
    this.positive = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 9,
                letterSpacing: 0.8,
                color: theme.colorScheme.onSurface.withAlpha(140),
              ),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              delta == null ? '—' : '$delta vs last',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: delta == null
                    ? theme.colorScheme.onSurface.withAlpha(90)
                    : (positive ? Colors.green : theme.colorScheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A supporting statistic: icon, label, value, and an optional line naming what
/// the value refers to.
class _DetailTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? caption;

  const _DetailTile({
    required this.icon,
    required this.label,
    required this.value,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, size: 15, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(153),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (caption != null && caption!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                caption!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(179),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}


/// Which unit the daily chart is drawn in. The app records all three per
/// session, and readers don't all log the same one — a timer user's month is
/// empty in pages, and a page counter's is empty in minutes.
enum _DayMetric { time, pages, sessions }

/// The month's shape: one bar per day, scaled to the biggest day. Shows at a
/// glance whether the reading was steady or came in bursts — which the totals
/// above can't say on their own.
class _MonthActivityStrip extends StatefulWidget {
  final MonthlyRecap recap;
  final Color color;

  const _MonthActivityStrip({required this.recap, required this.color});

  @override
  State<_MonthActivityStrip> createState() => _MonthActivityStripState();
}

class _MonthActivityStripState extends State<_MonthActivityStrip> {
  /// Tall enough for [TextTheme.labelSmall], which is all the axis holds.
  static const double _axisHeight = 14;

  /// The plot's height. Named because the average line is placed by measuring
  /// against it rather than by a fraction of its parent.
  static const double _chartHeight = 64;

  /// What the reader last picked, which is not necessarily what is drawn — see
  /// [_resolve]. Held so the choice survives flicking through the months.
  _DayMetric _preferred = _DayMetric.time;

  /// Only the units this month actually has. Offering "Pages" on a month that
  /// was timed instead would hand the reader a flat, empty chart.
  List<_DayMetric> get _available {
    final recap = widget.recap;
    return [
      if (recap.minutes > 0) _DayMetric.time,
      if (recap.pages > 0) _DayMetric.pages,
      if (recap.sessions > 0) _DayMetric.sessions,
    ];
  }

  /// The preference when the month can honour it, else whatever it does have.
  /// Falling back without writing the fallback down is what stops a month that
  /// only has sessions from quietly resetting a reader who prefers time.
  _DayMetric _resolve(List<_DayMetric> available) =>
      available.contains(_preferred) ? _preferred : available.first;

  Map<int, int> _byDay(_DayMetric metric) => switch (metric) {
        _DayMetric.time => widget.recap.minutesByDay,
        _DayMetric.pages => widget.recap.pagesByDay,
        _DayMetric.sessions => widget.recap.sessionsByDay,
      };

  static String _name(_DayMetric metric) => switch (metric) {
        _DayMetric.time => 'Time',
        _DayMetric.pages => 'Pages',
        _DayMetric.sessions => 'Sessions',
      };

  static String _amount(_DayMetric metric, int value) => switch (metric) {
        _DayMetric.time => MonthlyRecap.formatMinutes(value),
        _DayMetric.pages => '$value ${value == 1 ? 'page' : 'pages'}',
        _DayMetric.sessions => '$value ${value == 1 ? 'session' : 'sessions'}',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final available = _available;
    if (available.isEmpty) return const SizedBox.shrink();

    final metric = _resolve(available);
    final byDay = _byDay(metric);
    final daysInMonth = widget.recap.daysInMonth;
    final peak = byDay.values.fold<int>(0, (a, b) => a > b ? a : b);
    if (peak == 0) return const SizedBox.shrink();

    // Averaged over the days that were read, not over the month: the question
    // a reader asks of a bar is "was that a good day for me", and days off
    // aren't part of that comparison. Under three days there is no typical day
    // to speak of, so the line is left off rather than drawn through everything.
    final read = byDay.values.where((v) => v > 0).toList(growable: false);
    final average = read.length < 3
        ? 0
        : (read.reduce((a, b) => a + b) / read.length).round();

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The tallest bar is the only thing the chart is scaled to, so
            // saying what it was worth is what turns the shape into figures.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Daily reading',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(153),
                  ),
                ),
                Text(
                  average > 0
                      ? 'Avg ${_amount(metric, average)} · '
                          'Peak ${_amount(metric, peak)}'
                      : 'Peak ${_amount(metric, peak)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            // No row of chips for a month that only ever had one unit to be
            // read in — the choice would be a control that does nothing.
            if (available.length > 1) ...[
              const SizedBox(height: 10),
              _buildMetricPicker(theme, available, metric),
            ],
            const SizedBox(height: 12),
            SizedBox(
              height: _chartHeight,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var day = 1; day <= daysInMonth; day++)
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 0.8),
                              child: _bar(byDay[day] ?? 0, peak, theme),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Drawn through the same transform the bars are, so a bar
                  // standing above the line really was an above-average day.
                  // Sizing it off the raw fraction would put it wrong, because
                  // the bars are floored to stay visible rather than scaled
                  // straight from zero.
                  if (average > 0)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: _heightFactor(average, peak) * _chartHeight,
                      child: _dashedLine(theme),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            _buildAxis(theme, daysInMonth),
          ],
        ),
      ),
    );
  }

  /// The same chips the month picker at the top of the page uses, so the two
  /// rows of choices on this screen read as the same control.
  Widget _buildMetricPicker(
    ThemeData theme,
    List<_DayMetric> available,
    _DayMetric selected,
  ) {
    return Row(
      children: [
        for (final metric in available)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              label: Text(_name(metric)),
              selected: metric == selected,
              onSelected: (_) => setState(() => _preferred = metric),
              showCheckmark: false,
              labelStyle: theme.textTheme.labelSmall,
              labelPadding: const EdgeInsets.symmetric(horizontal: 6),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              selectedColor: theme.colorScheme.primaryContainer,
              elevation: 0,
              pressElevation: 0,
              side: BorderSide.none,
              shape: const StadiumBorder(),
            ),
          ),
      ],
    );
  }

  /// Week markers under the bars — the 1st, 8th, 15th and so on.
  ///
  /// Built from the same run of [Expanded] cells the bars are, so each number
  /// sits under the day it names; two labels pushed to the ends would only line
  /// up by accident. The numbers are wider than the ~9pt cell they belong to,
  /// so each is allowed to spill evenly either side of its own column rather
  /// than being squeezed or clipped.
  ///
  /// The row is given a height because [OverflowBox] takes its parent's
  /// constraints for its own size, and a bare row inside a column offers it an
  /// unbounded one.
  Widget _buildAxis(ThemeData theme, int daysInMonth) {
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurface.withAlpha(120),
    );
    return SizedBox(
      height: _axisHeight,
      child: Row(
        children: [
          for (var day = 1; day <= daysInMonth; day++)
            Expanded(
              child: day % 7 == 1
                  ? Center(
                      child: OverflowBox(
                        maxWidth: 40,
                        maxHeight: _axisHeight,
                        child: Text('$day', style: style, maxLines: 1),
                      ),
                    )
                  : const SizedBox(),
            ),
        ],
      ),
    );
  }

  /// How tall a bar of [value] stands, as a fraction of the plot.
  ///
  /// Not a straight proportion: a day worth two minutes would otherwise be a
  /// bar too short to see, so anything read at all starts at 12% and the rest
  /// of the plot is shared out above that. A day with nothing keeps a hairline
  /// so the month reads as a continuous strip rather than as gaps between bars.
  ///
  /// Shared with the average line, which has to sit where a bar of that value
  /// would stand or it isn't telling the truth.
  static double _heightFactor(int value, int peak) =>
      value == 0 ? 0.04 : 0.12 + (value / peak) * 0.88;

  Widget _bar(int value, int peak, ThemeData theme) {
    return FractionallySizedBox(
      alignment: Alignment.bottomCenter,
      heightFactor: _heightFactor(value, peak),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: value == 0
              ? theme.colorScheme.onSurface.withAlpha(30)
              : widget.color.withValues(alpha: 0.35 + (value / peak) * 0.65),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  /// The average, as a dashed rule across the plot. Dashed so it reads as an
  /// annotation over the month rather than as another day in it.
  Widget _dashedLine(ThemeData theme) {
    const dash = 3.0;
    const gap = 3.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = (constraints.maxWidth / (dash + gap)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < count; i++)
              SizedBox(
                width: dash,
                height: 1,
                child: ColoredBox(
                  color: theme.colorScheme.onSurface.withAlpha(90),
                ),
              ),
          ],
        );
      },
    );
  }
}
