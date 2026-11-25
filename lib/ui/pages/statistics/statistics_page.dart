import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
// For kAllWeekdays — the app's one definition of the week's display order.
import 'package:read_stats/data/models/notification_pref.dart';
import 'package:read_stats/data/repositories/book_repository.dart';
import 'package:read_stats/data/repositories/session_repository.dart';
import 'package:read_stats/data/repositories/tag_repository.dart';
import 'package:read_stats/data/services/cover_service.dart';
import 'package:read_stats/data/services/recap_store.dart';
import 'package:read_stats/data/utils/reading_clock.dart';
import 'package:read_stats/domain/monthly_recap.dart';
import 'package:read_stats/domain/year_wrapped.dart';
import 'package:read_stats/ui/pages/book/book_detail_page.dart';
import 'package:read_stats/ui/pages/book/book_form_page.dart';
import 'package:read_stats/ui/pages/series/widgets/next_in_series_sheet.dart';
import 'package:read_stats/ui/pages/sessions/session_form_page.dart';
import 'package:read_stats/ui/pages/statistics/monthly_recap_page.dart';
import 'package:read_stats/ui/pages/statistics/stats_data.dart';
import 'package:read_stats/ui/pages/statistics/widgets/activity_heatmap.dart';
import 'package:read_stats/ui/pages/statistics/widgets/bar_chart_single.dart';
import 'package:read_stats/ui/pages/statistics/widgets/habit_bar_chart.dart';
import 'package:read_stats/ui/pages/statistics/widgets/pie_chart.dart';
import 'package:read_stats/ui/pages/statistics/widgets/rated_books.dart';
import 'package:read_stats/ui/pages/statistics/widgets/rating_summary.dart';
import 'package:read_stats/ui/pages/statistics/widgets/stat_card.dart';
import 'package:read_stats/ui/pages/statistics/widgets/stats_entry_card.dart';
import 'package:read_stats/ui/pages/statistics/widgets/top_authors_chart.dart';
import 'package:read_stats/ui/pages/statistics/widgets/when_you_read_chart.dart';
import 'package:read_stats/ui/pages/statistics/widgets/year_summary.dart';
import 'package:read_stats/ui/pages/wrapped/wrapped_page.dart';
import 'package:read_stats/ui/pages/wrapped/wrapped_style.dart';
import 'package:read_stats/ui/settings_view_model.dart';

class StatisticsPage extends StatefulWidget {
  final BookRepository bookRepository;
  final SessionRepository sessionRepository;
  final SettingsViewModel settingsViewModel;

  /// The app-level lists, passed through to the monthly recap. It works from
  /// these rather than the repositories so a month can be recomputed instantly
  /// as the reader flicks back through the history — and because their cover
  /// paths have already been resolved.
  final List<Map<String, dynamic>> books;
  final List<Map<String, dynamic>> sessions;

  const StatisticsPage({
    super.key,
    required this.bookRepository,
    required this.sessionRepository,
    required this.settingsViewModel,
    required this.books,
    required this.sessions,
  });

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();

  /// Warm the stats cache at app startup so the first Statistics visit paints
  /// complete instead of computing after navigation. [year] is the persisted
  /// year filter so the warmed payload matches what the page will show.
  static Future<void> preload({
    required BookRepository bookRepo,
    required SessionRepository sessionRepo,
    required int year,
  }) async {
    final years = await StatsData.fetchYears(sessionRepo, bookRepo);
    _StatisticsPageState._cachedYears = years;
    final y = (year != 0 && !years.contains(year)) ? 0 : year;
    _StatisticsPageState._cachedData = await StatsData.compute(
      year: y,
      bookRepo: bookRepo,
      sessionRepo: sessionRepo,
    );
  }
}

class _StatisticsPageState extends State<StatisticsPage> {
  int selectedYear = 0;
  String _chartStyle = 'bars';

  bool get _cumulative => _chartStyle == 'cumulative';

  // The Statistics tab is rebuilt on every nav switch and recomputes from the
  // DB. Cache the last-computed payload (and available years) across instances
  // so a revisit paints immediately and just refreshes in the background,
  // instead of every chart popping in after the page appears.
  static List<int>? _cachedYears;
  static StatsData? _cachedData;

  List<int>? _years = _cachedYears;
  StatsData? _data = _cachedData;

  Map<String, dynamic> get _stats => _data?.stats ?? StatsData.emptyStats;

  @override
  void initState() {
    super.initState();
    selectedYear = widget.settingsViewModel.statsYearFilterNotifier.value;
    _chartStyle = widget.settingsViewModel.statsChartStyleNotifier.value;
    WidgetsBinding.instance.addPostFrameCallback((_) => loadStats());
  }

  /// Single entry point for (re)loading the page: refresh the available years,
  /// validate the selected year, then recompute the full payload in one pass.
  /// Previously loaded data stays on screen while the new data loads (no flash).
  Future<void> loadStats() async {
    final years =
        await StatsData.fetchYears(widget.sessionRepository, widget.bookRepository);
    _cachedYears = years;
    if (mounted) setState(() => _years = years);

    // Safeguard: if the saved year no longer has any data, fall back to All.
    if (selectedYear != 0 && !years.contains(selectedYear)) {
      selectedYear = 0;
      widget.settingsViewModel.setStatsYearFilter(0);
    }

    final data = await StatsData.compute(
      year: selectedYear,
      bookRepo: widget.bookRepository,
      sessionRepo: widget.sessionRepository,
    );
    _cachedData = data;
    if (!mounted) return;
    setState(() => _data = data);
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withAlpha(120),
              letterSpacing: 1.2,
            ),
      ),
    );
  }

  List<Widget> _spaced(List<Widget> children, {double gap = 8, double sectionGap = 20}) {
    final result = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      result.add(children[i]);
      if (i < children.length - 1) {
        final isNextSection = children[i + 1] is Padding;
        result.add(SizedBox(height: isNextSection ? sectionGap : gap));
      }
    }
    return result;
  }

  Widget _buildPair(Widget left, Widget right) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: left),
          const SizedBox(width: 8),
          Expanded(child: right),
        ],
      ),
    );
  }

  String _shortFormatMinutes(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    return '${hours}h';
  }

  Widget _buildReadingTimeChart() {
    final data = _data!.readingTimeDist;
    final activeMinutes = data.values.where((v) => v > 0).toList();
    final avgMinutes = activeMinutes.isEmpty
        ? '0'
        : _shortFormatMinutes(
            (activeMinutes.reduce((a, b) => a + b) / activeMinutes.length)
                .round());
    return BarChartWidget(
      data: data,
      selectedYear: selectedYear,
      barColor: Theme.of(context).primaryColor,
      title: 'Reading Time',
      subtitleValue: _stats['totalTimeSpent'],
      averageValue: avgMinutes,
      averageLabel: _averageLabel,
      shortFormatter: _shortFormatMinutes,
      tooltipFormatter: StatsData.formatMinutes,
      cumulative: _cumulative,
      dailyData: _data!.readingTimeDaily,
    );
  }

  Widget _buildPagesChart() {
    final data = _data!.pagesDist;
    final activePages = data.values.where((v) => v > 0).toList();
    final avgPages = activePages.isEmpty
        ? '0'
        : NumberFormat('#,###').format(
            (activePages.reduce((a, b) => a + b) / activePages.length).round());
    return BarChartWidget(
      data: data,
      selectedYear: selectedYear,
      barColor: Theme.of(context).primaryColor,
      title: 'Pages Read',
      subtitleValue: NumberFormat('#,###').format(_stats['totalPagesRead']),
      averageValue: avgPages,
      averageLabel: _averageLabel,
      cumulative: _cumulative,
      dailyData: _data!.pagesDaily,
    );
  }

  /// The averages skip empty months (or years), so the label says so — "Avg/
  /// month" read as a straight divide by the calendar.
  String get _averageLabel =>
      selectedYear == 0 ? 'Avg/active year' : 'Avg/active month';

  String _formatAverage(Map<String, int> data) {
    final active = data.values.where((v) => v > 0).toList();
    if (active.isEmpty) return '0';
    return (active.reduce((a, b) => a + b) / active.length).round().toString();
  }

  Widget _buildBooksChart() {
    final data = _data!.booksDist;
    return BarChartWidget(
      data: data,
      selectedYear: selectedYear,
      barColor: Theme.of(context).primaryColor,
      title: 'Books Finished',
      subtitleValue: _stats['booksCompleted'].toString(),
      averageValue: _formatAverage(data),
      averageLabel: _averageLabel,
      cumulative: _cumulative,
      dailyData: _data!.booksDaily,
    );
  }

  // ── Reading habits ─────────────────────────────────────────────────────────

  /// Whether the habit charts are weighted by minutes read rather than by
  /// session count. Duration is optional on a session, so a reader who only
  /// ever logs pages has no minutes to chart — count their sessions instead of
  /// showing them two empty cards.
  ///
  /// Minutes are the better measure where they exist: counting sessions rewards
  /// five five-minute check-ins over one long evening sitting.
  bool get _habitsUseMinutes =>
      _data!.weekdayMinutes.values.any((v) => v > 0);

  String _habitValue(int value) =>
      _habitsUseMinutes ? _shortFormatMinutes(value) : value.toString();

  List<List<int>> get _clockGrid =>
      _habitsUseMinutes ? _data!.clockMinutes : _data!.clockSessions;

  Widget _buildWhenYouReadChart() {
    return WhenYouReadChart(
      grid: _clockGrid,
      weekdayTotals:
          _habitsUseMinutes ? _data!.weekdayMinutes : _data!.weekdaySessions,
      color: Theme.of(context).primaryColor,
      valueFormatter: _habitValue,
      measureLabel: _habitsUseMinutes ? 'reading time' : 'sessions',
    );
  }

  Widget _buildWeekdayChart() {
    final source =
        _habitsUseMinutes ? _data!.weekdayMinutes : _data!.weekdaySessions;
    return HabitBarChart(
      // Sunday-first, matching the heatmap and the reminder settings.
      bars: [
        for (final day in kAllWeekdays)
          HabitBar(kWeekdayShort[day]!, source[day] ?? 0),
      ],
      title: _habitsUseMinutes ? 'Reading Time by Day' : 'Sessions by Day',
      color: Theme.of(context).primaryColor,
      valueFormatter: _habitValue,
      emptyMessage: 'No sessions logged yet',
    );
  }

  Widget _buildDaypartChart() {
    final source = daypartTotalsOf(_clockGrid);
    return HabitBarChart(
      bars: [
        for (var i = 0; i < kDaypartLabels.length; i++)
          HabitBar(kDaypartLabels[i], source[i] ?? 0),
      ],
      title: _habitsUseMinutes
          ? 'Reading Time by Time of Day'
          : 'Sessions by Time of Day',
      color: Theme.of(context).primaryColor,
      valueFormatter: _habitValue,
      emptyMessage: 'No session start times yet',
    );
  }

  Widget _buildActivityHeatmap() {
    return ActivityHeatmap(
      dailyCounts: _data!.sessionsDaily,
      selectedYear: selectedYear,
      color: Theme.of(context).primaryColor,
    );
  }

  Widget _buildSessionsChart() {
    final data = _data!.sessionsDist;
    return BarChartWidget(
      data: data,
      selectedYear: selectedYear,
      barColor: Theme.of(context).primaryColor,
      title: 'Sessions',
      subtitleValue: _stats['totalSessions'].toString(),
      averageValue: _formatAverage(data),
      averageLabel: _averageLabel,
      cumulative: _cumulative,
      dailyData: _data!.sessionsDaily,
    );
  }

  /// Returns [candidate] unchanged unless its hue is within [threshold]
  /// degrees of [primary], in which case it rotates the hue 120° away.
  Color _safeColor(Color candidate, Color primary, {double threshold = 30.0}) {
    final primaryHue = HSLColor.fromColor(primary).hue;
    final candidateHSL = HSLColor.fromColor(candidate);
    final diff = (primaryHue - candidateHSL.hue).abs();
    final distance = diff > 180 ? 360 - diff : diff;
    if (distance < threshold) {
      final newHue = (candidateHSL.hue + 120) % 360;
      return candidateHSL.withHue(newHue).toColor();
    }
    return candidate;
  }

  static const _typeIcons = {
    'Paperback': Icons.menu_book,
    'Hardback':  Icons.auto_stories,
    'EBook':     Icons.tablet_android,
    'Audiobook': Icons.headphones,
  };

  Widget _buildBookTypeChart() {
    return PieChartWidget(
      title: 'Book Formats',
      data: _data!.bookTypeData,
      icons: _typeIcons,
      sortByCount: true,
      colors: {
        'Paperback':  Theme.of(context).primaryColor,
        'Hardback':   _safeColor(const Color(0xFF9575CD), Theme.of(context).primaryColor),
        'EBook':      _safeColor(const Color(0xFF4CAF50), Theme.of(context).primaryColor),
        'Audiobook':  _safeColor(const Color(0xFFFF9800), Theme.of(context).primaryColor),
      },
    );
  }

  /// Compact segmented control (bars / cumulative line) that flips how every
  /// time-series chart on the page is drawn. Persisted like the year filter.
  Widget _buildChartStyleToggle() {
    final theme = Theme.of(context);

    Widget segment(IconData icon, String style, String tooltip) {
      final selected = _chartStyle == style;
      return Tooltip(
        message: tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (_chartStyle == style) return;
            setState(() => _chartStyle = style);
            widget.settingsViewModel.setStatsChartStyle(style);
          },
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: selected
                  ? theme.colorScheme.primaryContainer
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              size: 16,
              color: selected
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.onSurface.withAlpha(140),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          segment(Icons.bar_chart, 'bars', 'Per-period bars'),
          segment(Icons.show_chart, 'cumulative', 'Cumulative total'),
        ],
      ),
    );
  }

  Widget _buildTopAuthorsChart() {
    return TopAuthorsChart(
      title: 'Top Authors',
      data: _data!.topAuthors,
    );
  }

  Widget _buildRatingSummary() {
    return RatingSummaryWidget(
      ratingData: _data!.ratingDist,
      selectedYear: selectedYear,
      title: 'My Ratings',
      onStarTap: (star) {
        // The same buckets the bars count: half stars round to the nearest.
        final books = [
          for (final b in _ratedBooks)
            if (ratingOf(b).round().clamp(1, 5) == star) b,
        ];
        _openRatedBooks('$star★ books', books);
      },
    );
  }

  /// Finished books with a rating, in the selected year — the books behind
  /// the rating bars.
  List<Map<String, dynamic>> get _ratedBooks => [
        for (final b in widget.books)
          if (b['rating'] != null)
            if (DateTime.tryParse(b['date_finished'] as String? ?? '')
                case final finished?
                when selectedYear == 0 || finished.year == selectedYear)
              b,
      ];

  /// The top or bottom of the ratings: every book sharing the highest (or
  /// lowest) rating, newest finished first. Null when nothing is rated.
  ({double rating, List<Map<String, dynamic>> books})? _ratingExtreme(
      {required bool highest}) {
    final rated = _ratedBooks;
    if (rated.isEmpty) return null;
    final ratings = rated.map(ratingOf);
    final target = highest
        ? ratings.reduce((a, b) => a > b ? a : b)
        : ratings.reduce((a, b) => a < b ? a : b);
    final books = [
      for (final b in rated)
        if (ratingOf(b) == target) b,
    ]..sort((a, b) => (b['date_finished'] as String? ?? '')
        .compareTo(a['date_finished'] as String? ?? ''));
    return (rating: target, books: books);
  }

  Widget _buildRatingExtremes() {
    final top = _ratingExtreme(highest: true);
    final bottom = _ratingExtreme(highest: false);
    if (top == null || bottom == null) return const SizedBox.shrink();

    Widget card(String title, ({double rating, List<Map<String, dynamic>> books}) e) =>
        RatedBooksCard(
          title: title,
          rating: e.rating,
          books: e.books,
          onTap: () => e.books.length == 1
              ? _onStatCardTap(e.books.first['id'] as int?)
              : _openRatedBooks('${formatRating(e.rating)}★ books', e.books),
        );

    // Everything rated alike: one card says it all.
    if (top.rating == bottom.rating) return card('Top Rated', top);
    return _buildPair(card('Lowest Rated', bottom), card('Top Rated', top));
  }

  Future<void> _openRatedBooks(
      String title, List<Map<String, dynamic>> books) async {
    final picked =
        await showRatedBooksSheet(context: context, title: title, books: books);
    if (picked == null || !mounted) return;
    _onStatCardTap(picked['id'] as int?);
  }

  void _onStatCardTap(int? bookId) async {
    if (bookId == null) return;
    final book = await widget.bookRepository.getBookById(bookId);
    if (book == null || !mounted) return;

    final mutableBook = Map<String, dynamic>.from(book);
    final rawCover = mutableBook['cover_path'];
    if (rawCover != null && (rawCover as String).isNotEmpty) {
      mutableBook['cover_path'] = await CoverService.resolveFullPath(rawCover);
    }

    if (!mounted) return;
    openBookDetail(
      context,
      mutableBook,
      navigateToEditBookPage: _navigateToEditBookPage,
      navigateToAddSessionPage: _navigateToAddSessionPage,
      confirmDelete: _confirmDelete,
      tagRepository: TagRepository(),
      bookRepository: BookRepository(),
      settingsViewModel: widget.settingsViewModel,
      refreshCallback: loadStats,
    );
  }

  void _navigateToEditBookPage(Map<String, dynamic>? book) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookFormPage(
          onSave: (_) async => loadStats(),
          settingsViewModel: widget.settingsViewModel,
          book: book,
        ),
      ),
    );
  }

  void _navigateToAddSessionPage(Map<String, dynamic> book) async {
    final books = await widget.bookRepository.getBooks();
    if (!mounted) return;
    final finishedBook = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => SessionFormPage(
          availableBooks: books.map((b) => b.toMap()).toList(),
          book: book,
          onSave: loadStats,
          settingsViewModel: widget.settingsViewModel,
          sessionRepository: widget.sessionRepository,
          bookRepository: widget.bookRepository,
        ),
      ),
    );

    if (finishedBook != null && mounted) {
      await afterFinishingBook(
        context: context,
        book: finishedBook,
        bookRepository: widget.bookRepository,
        settingsViewModel: widget.settingsViewModel,
      );
      if (mounted) loadStats();
    }
  }

  void _confirmDelete(int bookId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Book'),
        content: const Text('Are you sure you want to delete this book and all its sessions?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              // Repository delete also removes the stored cover image file.
              await widget.bookRepository.deleteBook(bookId);
              if (context.mounted) Navigator.pop(context);
              loadStats();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  /// The way into the recap, at the head of the stats.
  ///
  /// It was a text button in the app bar, which is why it needed a dot and a
  /// notification to be found at all — a 40pt toolbar is where actions on the
  /// current screen live, not where a different screen gets announced. As a row
  /// with the month's own numbers in it, it says what it is worth opening for.
  ///
  /// Always present, so the reader can reach the history from a quiet month;
  /// what changes is whether it leads with last month or with the invitation.
  ///
  /// [compact] is the half-width tile used beside the Wrapped entry.
  Widget _buildRecapCard(ThemeData theme, {bool compact = false}) {
    return ValueListenableBuilder<int>(
      valueListenable: RecapStore.instance.lastSeenMonth,
      builder: (context, lastSeen, _) {
        final recap = _recapForLastMonth();
        final hasMonth = !recap.isEmpty;
        final accent = theme.colorScheme.primary;

        return StatsEntryCard(
          compact: compact,
          onTap: _openRecap,
          title: !hasMonth
              ? 'Monthly recap'
              : compact
                  ? '${recap.monthNameOnly} recap'
                  : '${recap.monthLabel} recap',
          subtitle: !hasMonth
              ? (compact
                  ? 'Look back at any month'
                  : 'Look back at any month of reading')
              : _recapTeaser(recap, max: compact ? 2 : 3),
          unseen: hasMonth && recap.key > lastSeen,
          accent: accent,
          iconBackground: accent.withValues(alpha: 0.14),
          titleColor: theme.colorScheme.onSurface,
          mutedColor: theme.colorScheme.onSurfaceVariant,
        );
      },
    );
  }

  /// Enough of the month to be worth a tap, in the order the recap ranks them.
  static String _recapTeaser(MonthlyRecap recap, {int max = 3}) {
    final parts = <String>[
      if (recap.minutes > 0) MonthlyRecap.formatMinutes(recap.minutes),
      if (recap.booksFinishedCount > 0)
        '${recap.booksFinishedCount} '
            '${recap.booksFinishedCount == 1 ? 'book' : 'books'}',
      if (recap.pages > 0) '${recap.pages} pages',
      if (recap.sessions > 0) '${recap.sessions} sessions',
    ];
    return parts.take(max).join('  ·  ');
  }

  // Last month's recap, cached against the lists it was worked out from. The
  // page calls setState while scrolling, and building it means a pass over
  // every session — not something to do on each scroll tick.
  List<Map<String, dynamic>>? _recapBooks;
  List<Map<String, dynamic>>? _recapSessions;
  MonthlyRecap? _lastMonthRecap;

  MonthlyRecap _recapForLastMonth() {
    final cached = _lastMonthRecap;
    if (cached != null &&
        identical(_recapBooks, widget.books) &&
        identical(_recapSessions, widget.sessions)) {
      return cached;
    }
    _recapBooks = widget.books;
    _recapSessions = widget.sessions;
    final month = MonthlyRecap.previousMonthOf(DateTime.now());
    return _lastMonthRecap = MonthlyRecap.forMonth(
      books: widget.books,
      sessions: widget.sessions,
      year: month.year,
      month: month.month,
    );
  }

  // ── Wrapped ────────────────────────────────────────────────────────────────

  // Years with a Wrapped to open, cached against the lists like the recap.
  List<Map<String, dynamic>>? _wrappedBooks;
  List<Map<String, dynamic>>? _wrappedSessions;
  List<int> _wrappedYears = const [];

  List<int> _availableWrappedYears() {
    if (identical(_wrappedBooks, widget.books) &&
        identical(_wrappedSessions, widget.sessions)) {
      return _wrappedYears;
    }
    _wrappedBooks = widget.books;
    _wrappedSessions = widget.sessions;
    return _wrappedYears = YearWrapped.availableYears(
      books: widget.books,
      sessions: widget.sessions,
    );
  }

  void _openWrapped(int year) {
    Navigator.of(context).push(WrappedPage.route(
      books: widget.books,
      sessions: widget.sessions,
      year: year,
    ));
  }

  /// The Wrapped year the year chips point at: the newest one under "All", the
  /// chosen year if it has one, otherwise none. The chips are how older years
  /// are reached, so the entry needs no picker of its own.
  int? _wrappedYearForFilter() {
    final years = _availableWrappedYears();
    if (years.isEmpty) return null;
    if (selectedYear == 0) return years.first;
    return years.contains(selectedYear) ? selectedYear : null;
  }

  /// The way into Wrapped, beside the monthly recap. Drawn in Wrapped's own
  /// colours rather than the app's, so it reads as the event it opens.
  ///
  /// Only there once a year is unlocked and has reading in it — the current
  /// year from December 1st, every earlier year always.
  Widget _buildWrappedCard(ThemeData theme, int year, {bool compact = false}) {
    final inProgress = year == DateTime.now().year;
    const palette = WrappedPalette.intro;

    return ValueListenableBuilder<int>(
      valueListenable: RecapStore.instance.lastSeenWrappedYear,
      builder: (context, lastSeen, _) => StatsEntryCard(
        compact: compact,
        onTap: () => _openWrapped(year),
        title: compact ? '$year Wrapped' : 'Your $year Wrapped',
        subtitle: compact
            ? (inProgress ? 'Your year so far' : 'Your year in reading')
            : (inProgress
                ? 'Your year in reading, so far'
                : 'Your year in reading, told in slides'),
        unseen: year > lastSeen,
        accent: palette.accent,
        iconBackground: Colors.white.withValues(alpha: 0.16),
        titleColor: Colors.white,
        mutedColor: Colors.white.withValues(alpha: 0.8),
        pillTextColor: Colors.black,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette.gradient,
        ),
      ),
    );
  }

  /// Wrapped and the monthly recap share one row when both are there, so the
  /// stats don't start two cards down; the recap alone keeps the full row.
  Widget _buildRecapEntries(ThemeData theme) {
    final wrappedYear = _wrappedYearForFilter();
    if (wrappedYear == null) return _buildRecapCard(theme);
    return _buildPair(
      _buildWrappedCard(theme, wrappedYear, compact: true),
      _buildRecapCard(theme, compact: true),
    );
  }

  void _openRecap() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MonthlyRecapPage(
          books: widget.books,
          sessions: widget.sessions,
        ),
      ),
    );
  }

  double _statsDividerOpacity = 0;

  // Fade a hairline in under the pinned year-filter row once the stats content
  // scrolls beneath it, matching the bottom nav line. Keeps the app bar flush.
  bool _onStatsScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;
    final raw = (n.metrics.pixels / 12).clamp(0.0, 1.0);
    final stepped = (raw * 8).round() / 8;
    if (stepped != _statsDividerOpacity) {
      setState(() => _statsDividerOpacity = stepped);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 40,
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: _onStatsScroll,
        child: Column(
        children: [
          // Year selection row
          if (_years != null)
            Builder(builder: (context) {
              final allYears = [0, ..._years!];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 32,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          itemCount: allYears.length,
                          itemBuilder: (context, index) {
                            final year = allYears[index];
                            final isSelected = selectedYear == year;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: FilterChip(
                                label: Text(year == 0 ? 'All' : year.toString()),
                                selected: isSelected,
                                onSelected: (_) {
                                  setState(() => selectedYear = year);
                                  widget.settingsViewModel.setStatsYearFilter(year);
                                  loadStats();
                                },
                                showCheckmark: false,
                                labelStyle: theme.textTheme.bodySmall,
                                labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                selectedColor: theme.colorScheme.primaryContainer,
                                elevation: 0,
                                pressElevation: 0,
                                side: BorderSide.none,
                                shape: const StadiumBorder(),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildChartStyleToggle(),
                    const SizedBox(width: 8),
                  ],
                ),
              );
            }),

          Divider(
            height: .5,
            thickness: .25,
            color: theme.dividerColor
                .withAlpha((128 * _statsDividerOpacity).round()),
          ),
          // Statistics content
          Expanded(
            child: _data == null
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _spaced([
                  YearSummary(
                    books: widget.books,
                    sessions: widget.sessions,
                    year: selectedYear,
                  ),
                  _buildRecapEntries(theme),
                  _buildSectionHeader('Overview'),
                  _buildBookTypeChart(),
                  _buildBooksChart(),
                  _buildSessionsChart(),
                  _buildActivityHeatmap(),
                  _buildTopAuthorsChart(),
                  _buildSectionHeader('Reading Habits'),
                  _buildWhenYouReadChart(),
                  _buildWeekdayChart(),
                  _buildDaypartChart(),
                  _buildSectionHeader('Ratings'),
                  _buildRatingSummary(),
                  _buildRatingExtremes(),
                  _buildSectionHeader('Reading Time'),
                  _buildReadingTimeChart(),
                  _buildPair(
                    StatCard(
                      title: 'Fastest Read',
                      value: _stats['fastestReadTime'].toString(),
                      bookTitle: _stats['fastestReadBookTitle'],
                      coverPath: _stats['fastestReadCoverPath'],
                      coverShape: _stats['fastestReadCoverShape'],
                      onTap: () => _onStatCardTap(_stats['fastestReadBookId']),
                    ),
                    StatCard(
                      title: 'Slowest Read',
                      value: _stats['slowestReadTime'].toString(),
                      bookTitle: _stats['slowestReadBookTitle'],
                      coverPath: _stats['slowestReadCoverPath'],
                      coverShape: _stats['slowestReadCoverShape'],
                      onTap: () => _onStatCardTap(_stats['slowestReadBookId']),
                    ),
                  ),
                  _buildSectionHeader('Pages'),
                  _buildPagesChart(),
                  _buildPair(
                    StatCard(
                      title: 'Shortest Book',
                      value: _stats['lowestPages'].toString(),
                      bookTitle: _stats['lowestPagesBookTitle'],
                      coverPath: _stats['lowestPagesCoverPath'],
                      coverShape: _stats['lowestPagesCoverShape'],
                      onTap: () => _onStatCardTap(_stats['lowestPagesBookId']),
                    ),
                    StatCard(
                      title: 'Longest Book',
                      value: _stats['highestPages'].toString(),
                      bookTitle: _stats['highestPagesBookTitle'],
                      coverPath: _stats['highestPagesCoverPath'],
                      coverShape: _stats['highestPagesCoverShape'],
                      onTap: () => _onStatCardTap(_stats['highestPagesBookId']),
                    ),
                  ),
                  StatCard(
                    title: 'Avg Pages/Hour',
                    value: (_stats['avgPagesPerMinute'] * 60).round().toString(),
                  ),
                ]),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}
