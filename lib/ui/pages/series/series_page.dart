import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:read_stats/data/models/book_type.dart';
import 'package:read_stats/data/models/shelf.dart';
import 'package:read_stats/data/repositories/book_repository.dart';
import 'package:read_stats/data/repositories/planner_repository.dart';
import 'package:read_stats/data/repositories/series_repository.dart';
import 'package:read_stats/data/services/analytics_service.dart';
import 'package:read_stats/data/services/cover_service.dart';
import 'package:read_stats/data/utils/series_title.dart';
import 'package:read_stats/domain/series_progress.dart';
import 'package:read_stats/ui/pages/series/widgets/inline_edit_fields.dart';
import 'package:read_stats/ui/pages/series/widgets/next_in_series_sheet.dart';
import 'package:read_stats/ui/pages/series/widgets/series_strip.dart';
import 'package:read_stats/ui/settings_view_model.dart';
import 'package:read_stats/ui/widgets/app_snackbar.dart';
import 'package:read_stats/ui/widgets/book_cover.dart';
import 'package:read_stats/ui/widgets/book_picker_sheet.dart';

/// Opens a series' page. Returns the book the reader tapped (cover path
/// resolved, ready for the detail sheet), or null if they went back.
///
/// [currentBookId] marks the book it was opened from, if any. With
/// [onOpenBook], a tapped book opens on top of the series instead of being
/// returned, so it arrives in one transition and back leads to the series.
Future<Map<String, dynamic>?> openSeriesPage({
  required BuildContext context,
  required int seriesId,
  required SettingsViewModel settingsViewModel,
  int? currentBookId,
  void Function(BuildContext context, Map<String, dynamic> book)? onOpenBook,
}) {
  return Navigator.of(context).push<Map<String, dynamic>>(
    MaterialPageRoute(
      builder: (_) => SeriesPage(
        seriesId: seriesId,
        currentBookId: currentBookId,
        settingsViewModel: settingsViewModel,
        onOpenBook: onOpenBook,
      ),
    ),
  );
}

/// Everything about one series: how far along the reader is, what's next,
/// and every book in order — including the numbers they don't have yet,
/// which they can hold with a placeholder until the book exists.
///
/// Edits happen in place: Edit turns the numbers (and placeholder titles)
/// into fields, and the add panel sits at the end of the list.
class SeriesPage extends StatefulWidget {
  final int seriesId;
  final int? currentBookId;
  final SettingsViewModel settingsViewModel;

  /// Opens a tapped book on top of this page. Without it, the page closes
  /// and hands the book back.
  final void Function(BuildContext context, Map<String, dynamic> book)?
      onOpenBook;

  const SeriesPage({
    super.key,
    required this.seriesId,
    required this.settingsViewModel,
    this.currentBookId,
    this.onOpenBook,
  });

  @override
  State<SeriesPage> createState() => _SeriesPageState();
}

class _SeriesPageState extends State<SeriesPage> {
  final _repo = SeriesRepository();
  final _planner = PlannerRepository();
  SeriesProgress? _progress;
  bool _nextInPlanner = false;
  bool _editing = false;

  /// Edit mode's list: every numbered book and placeholder, in order, as the
  /// drag shows it.
  List<_EditItem> _editOrder = const [];

  // The add panel.
  bool _adding = false;
  final _addNumber = TextEditingController();
  final _addTitle = TextEditingController();
  final _addKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.screen('series');
    _load();
  }

  @override
  void dispose() {
    _addNumber.dispose();
    _addTitle.dispose();
    super.dispose();
  }

  static Future<Map<String, dynamic>> _withCover(
      Map<String, dynamic> row) async {
    final book = Map<String, dynamic>.from(row);
    final cover = book['cover_path'] as String?;
    if (cover != null && cover.isNotEmpty) {
      book['cover_path'] = await CoverService.resolveFullPath(cover);
    }
    return book;
  }

  Future<void> _load() async {
    final rows = await _repo.booksIn(widget.seriesId);
    final books = [for (final r in rows) await _withCover(r)];
    var placeholders = await _repo.placeholdersIn(widget.seriesId);

    // A book that arrived at a held number takes its place for good.
    final owned = {
      for (final b in books)
        if (b['series_position'] != null)
          (b['series_position'] as num).toDouble(),
    };
    final filled = [
      for (final p in placeholders)
        if (owned.contains((p['position'] as num).toDouble())) p['id'] as int,
    ];
    if (filled.isNotEmpty) {
      await _repo.deletePlaceholders(filled);
      placeholders = await _repo.placeholdersIn(widget.seriesId);
    }

    final progress = SeriesProgress.from(widget.seriesId, books,
        placeholders: placeholders);
    final next = progress.nextUp?.book;
    final inPlanner = next != null &&
        await _planner.isInPlanner(next['id'] as int);
    if (!mounted) return;
    setState(() {
      _progress = progress;
      _nextInPlanner = inPlanner;
      _editOrder = _editItems(progress);
    });
  }

  static List<_EditItem> _editItems(SeriesProgress p) => [
        for (final s in p.slots)
          if (s.isPlanned)
            _EditItem(s.position, placeholder: s.placeholder)
          else
            for (final b in s.books) _EditItem(s.position, book: b),
      ];

  /// A drag: the numbers stay where they are and the books move between
  /// them, so gaps and in-between numbers (#1.5) survive a reorder.
  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    if (newIndex == oldIndex) return;
    final numbers = [for (final i in _editOrder) i.position];
    final items = [..._editOrder];
    items.insert(newIndex, items.removeAt(oldIndex));
    final placed = [
      for (var i = 0; i < items.length; i++) items[i].at(numbers[i]),
    ];
    setState(() => _editOrder = placed);

    final books = <Map<String, dynamic>>[];
    final held = <int, double>{};
    for (var i = 0; i < placed.length; i++) {
      final item = placed[i];
      if (item.position == item.originalPosition) continue; // Didn't move.
      if (item.book != null) {
        books.add({
          'id': item.book!['id'],
          'series_id': widget.seriesId,
          'series_position': item.position,
        });
      } else {
        held[item.placeholder!['id'] as int] = item.position;
      }
    }
    if (books.isNotEmpty) await _repo.link(books);
    await _repo.repositionPlaceholders(held);
    _load();
  }

  bool _owns(double number) => _progress!.slots
      .any((s) => s.position == number && !s.isMissing);

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _findOnline(double position, {String? title}) async {
    final p = _progress!;
    await addMissingSeriesBook(
      context: context,
      settingsViewModel: widget.settingsViewModel,
      seriesName: p.name,
      position: position,
      author: p.author,
      title: title,
    );
    // Back from adding — show the book if it landed here.
    if (mounted) _load();
  }

  Future<void> _addToPlanner(Map<String, dynamic> book) async {
    await _planner.addBookById(book['id'] as int);
    AppSnackbar.show('${book['title']} added to your planner');
    if (mounted) setState(() => _nextInPlanner = true);
  }

  void _openBook(Map<String, dynamic> book) {
    if (book['id'] == widget.currentBookId) {
      Navigator.pop(context);
      return;
    }
    final open = widget.onOpenBook;
    if (open != null) {
      open(context, book);
    } else {
      Navigator.pop(context, book);
    }
  }

  /// Opens the add panel at [number], scrolled into view.
  void _openAdd({double? number, String? title}) {
    setState(() {
      _adding = true;
      _addNumber.text =
          SeriesProgress.formatNumber(number ?? _progress!.nextFreeNumber);
      _addTitle.text = title ?? '';
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _addKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx,
            duration: const Duration(milliseconds: 250), alignment: 0.3);
      }
    });
  }

  void _closeAdd() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _adding = false);
  }

  /// The panel's number, or null (with a message) if it isn't one.
  double? _panelNumber() {
    final n = double.tryParse(_addNumber.text.trim());
    if (n == null || n <= 0) {
      AppSnackbar.show('Enter the book\'s number in the series', isError: true);
      return null;
    }
    return n;
  }

  Future<void> _addBySearch() async {
    final n = _panelNumber();
    if (n == null) return;
    final title = _addTitle.text.trim();
    _closeAdd();
    await _findOnline(n, title: title.isEmpty ? null : title);
  }

  Future<void> _addFromLibrary() async {
    final n = _panelNumber();
    if (n == null) return;
    final p = _progress!;
    final rows = await BookRepository().getBookRows();
    final candidates = [
      for (final r in rows)
        if (r['series_id'] != widget.seriesId) await _withCover(r),
    ]..sort((a, b) => (a['title'] as String? ?? '')
        .toLowerCase()
        .compareTo((b['title'] as String? ?? '').toLowerCase()));
    if (!mounted) return;

    final picked = await showBookPickerSheet(
      context: context,
      books: candidates,
      title: 'Add as ${SeriesProgress.label(n)}',
      emptyMessage: 'Every book in your library is already in this series',
    );
    if (picked == null || !mounted) return;

    // A Goodreads-style title naming this same series — "The Sign of the Four
    // (Sherlock Holmes #2)" — comes off the title, as "Find series in titles"
    // does.
    final parsed = SeriesTitle.parse(picked['title'] as String? ?? '');
    final named = parsed != null &&
        parsed.series.toLowerCase() == p.name.toLowerCase();

    await _repo.link([
      {
        'id': picked['id'],
        if (named) 'title': parsed.title,
        'series_id': widget.seriesId,
        'series_position': n,
      },
    ]);
    AppSnackbar.show('${named ? parsed.title : picked['title']} added as '
        '${SeriesProgress.label(n)}');
    _closeAdd();
    _load();
  }

  Future<void> _addPlaceholder() async {
    final n = _panelNumber();
    if (n == null) return;
    if (_owns(n)) {
      AppSnackbar.show(
          '${SeriesProgress.label(n)} is already in your library',
          isError: true);
      return;
    }
    await _repo.savePlaceholder(widget.seriesId, n, _addTitle.text);
    _closeAdd();
    _load();
  }

  // Edit mode.

  Future<void> _renumberBook(Map<String, dynamic> book, double? n) async {
    await _repo.link([
      {'id': book['id'], 'series_id': widget.seriesId, 'series_position': n},
    ]);
    _load();
  }

  Future<void> _removeBook(Map<String, dynamic> book) async {
    await _repo.link([
      {'id': book['id'], 'series_id': null, 'series_position': null},
    ]);
    AppSnackbar.show('${book['title']} removed from the series');
    _load();
  }

  Future<void> _editPlaceholder(
      Map<String, dynamic> ph, double? n, String? title) async {
    final number = n ?? (ph['position'] as num).toDouble();
    if (_owns(number) && number != (ph['position'] as num).toDouble()) {
      AppSnackbar.show(
          '${SeriesProgress.label(number)} is already in your library',
          isError: true);
      setState(() {}); // Puts the old number back in the field.
      return;
    }
    await _repo.updatePlaceholder(ph['id'] as int, widget.seriesId, number,
        title ?? ph['title'] as String?);
    _load();
  }

  Future<void> _removePlaceholder(Map<String, dynamic> ph) async {
    await _repo.deletePlaceholders([ph['id'] as int]);
    _load();
  }

  // ── Layout ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = _progress;

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (p != null)
            _editing
                ? TextButton(
                    onPressed: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      setState(() => _editing = false);
                    },
                    child: const Text('Done'),
                  )
                : IconButton(
                    tooltip: 'Edit series',
                    icon: const Icon(Icons.edit),
                    onPressed: () => setState(() {
                      _editing = true;
                      _adding = false;
                      _editOrder = _editItems(p);
                    }),
                  ),
        ],
      ),
      body: p == null
          ? const Center(child: CircularProgressIndicator())
          : GestureDetector(
              // Tapping off a field commits it.
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              behavior: HitTestBehavior.translucent,
              child: CustomScrollView(
                slivers: [
                  _padded(SliverList.list(children: [
                    const SizedBox(height: 12),
                    _header(theme, p),
                    const SizedBox(height: 24),
                    _progressSection(theme, p),
                    if (!_editing && !p.isComplete && p.nextUp != null) ...[
                      const SizedBox(height: 16),
                      _upNextCard(theme, p.nextUp!),
                    ],
                    if (!_editing) ...[
                      const SizedBox(height: 12),
                      _statsRow(theme, p),
                    ],
                    const SizedBox(height: 28),
                    _booksHeading(theme),
                    const SizedBox(height: 4),
                  ])),
                  if (_editing)
                    _padded(SliverReorderableList(
                      itemCount: _editOrder.length,
                      onReorder: _onReorder,
                      proxyDecorator: (child, _, _) => Material(
                        elevation: 6,
                        color: theme.colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                        child: child,
                      ),
                      itemBuilder: (_, i) {
                        final item = _editOrder[i];
                        return item.book != null
                            ? _bookRow(theme, item.book!, item.position,
                                dragIndex: i)
                            : _plannedRow(theme, item.position,
                                item.placeholder!, dragIndex: i);
                      },
                    ))
                  else
                    _padded(SliverList.list(children: [
                      for (final s in p.slots)
                        if (s.isPlanned)
                          _plannedRow(theme, s.position, s.placeholder!)
                        else if (s.isMissing)
                          _gapRow(theme, s)
                        else
                          for (final b in s.books)
                            _bookRow(theme, b, s.position),
                    ])),
                  _padded(
                    SliverList.list(children: [
                      // Unnumbered books sit outside the drag: give one a
                      // number and it joins the order.
                      for (final b in p.unnumbered) _bookRow(theme, b, null),
                      const SizedBox(height: 8),
                      KeyedSubtree(
                        key: _addKey,
                        child: _adding ? _addPanel(theme) : _addRow(theme),
                      ),
                    ]),
                    bottom: 32 + MediaQuery.paddingOf(context).bottom,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _padded(Widget sliver, {double bottom = 0}) => SliverPadding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, bottom),
        sliver: sliver,
      );

  /// In edit mode: the Planner's drag handle, then the number field.
  Widget _editNumber(ThemeData theme, int? dragIndex, Widget field) {
    if (dragIndex == null) return field;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ReorderableDragStartListener(
          index: dragIndex,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 12, 8, 12),
            child: Icon(Icons.drag_handle,
                size: 22,
                color: theme.colorScheme.onSurfaceVariant
                    .withValues(alpha: 0.6)),
          ),
        ),
        field,
      ],
    );
  }

  Widget _header(ThemeData theme, SeriesProgress p) {
    final muted = theme.colorScheme.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (p.books.isNotEmpty) ...[
          SeriesCoverStack(books: p.books, coverWidth: 76),
          const SizedBox(width: 16),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SERIES',
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: muted,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(p.name,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
              if (p.author != null) ...[
                const SizedBox(height: 4),
                Text(p.author!,
                    style: theme.textTheme.bodyLarge?.copyWith(color: muted)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// "2 of 4 read" over the strip of little books.
  Widget _progressSection(ThemeData theme, SeriesProgress p) {
    final muted = theme.colorScheme.onSurfaceVariant;
    final percent = p.total == 0 ? 0 : (p.read * 100 / p.total).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            if (p.isComplete) ...[
              Icon(Icons.check_circle,
                  size: 18,
                  color: seriesFinishedColor(theme.colorScheme)),
              const SizedBox(width: 6),
              Text('Series complete',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ] else
              Text.rich(TextSpan(children: [
                TextSpan(
                    text: '${p.read}',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
                TextSpan(
                    text: ' of ${p.total} read',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: muted)),
              ])),
            const Spacer(),
            Text('$percent%',
                style: theme.textTheme.bodySmall?.copyWith(color: muted)),
          ],
        ),
        const SizedBox(height: 12),
        SeriesStrip(
          progress: p,
          highlight: widget.currentBookId == null
              ? null
              : p.books
                  .where((b) => b['id'] == widget.currentBookId)
                  .map((b) => (b['series_position'] as num?)?.toDouble())
                  .firstOrNull,
          onTap: (s) => s.isMissing
              ? _openAdd(number: s.position, title: s.plannedTitle)
              : _openBook(s.book!),
        ),
      ],
    );
  }

  /// The book to pick up next, with the one action that fits it.
  Widget _upNextCard(ThemeData theme, SeriesSlot next) {
    final muted = theme.colorScheme.onSurfaceVariant;
    final reading = next.state == SeriesSlotState.reading;
    final book = next.book;
    final cover = book?['cover_path'] as String?;

    final Widget action;
    if (next.isMissing) {
      action = FilledButton.tonalIcon(
        onPressed: () => _findOnline(next.position, title: next.plannedTitle),
        icon: const Icon(Icons.search, size: 18),
        label: const Text('Find'),
      );
    } else if (reading) {
      action = FilledButton.tonal(
        onPressed: () => _openBook(book!),
        child: const Text('Open'),
      );
    } else if (_nextInPlanner) {
      action = FilledButton.tonalIcon(
        onPressed: null,
        icon: const Icon(Icons.check, size: 18),
        label: const Text('Planned'),
      );
    } else {
      action = FilledButton.tonalIcon(
        onPressed: () => _addToPlanner(book!),
        icon: const Icon(Icons.playlist_add, size: 18),
        label: const Text('Plan'),
      );
    }

    final String title;
    if (book != null) {
      title = book['title'] as String? ?? '';
    } else if (next.plannedTitle != null) {
      title = next.plannedTitle!;
    } else {
      title = next.isPlanned ? 'Not out yet' : 'Not in your library yet';
    }

    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: book == null
            ? () => _openAdd(number: next.position, title: next.plannedTitle)
            : () => _openBook(book),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (next.isMissing)
                MissingCover(
                    width: 44,
                    icon: next.isPlanned ? Icons.schedule : Icons.search)
              else if (cover != null && cover.isNotEmpty)
                BookCover(
                  path: cover,
                  shape: book!['cover_shape'] as int?,
                  width: 44,
                  borderRadius: 4,
                )
              else
                const MissingCover(width: 44, icon: Icons.menu_book_rounded),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${reading ? 'READING NOW' : 'UP NEXT'} · '
                      '${SeriesProgress.label(next.position).toUpperCase()}',
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: book == null && next.plannedTitle == null
                            ? muted
                            : null,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              action,
            ],
          ),
        ),
      ),
    );
  }

  /// How much of the series is read and when it was started and last
  /// finished — numbers only the books' own lengths and dates are needed for.
  ///
  /// A series can be read in any mix of formats, so how much is counted both
  /// ways: the pages of the finished print and ebooks, and the length of the
  /// finished audiobooks. Each shows when it has something to count; a series
  /// with nothing finished shows the one its books are.
  Widget _statsRow(ThemeData theme, SeriesProgress p) {
    bool isAudio(Map<String, dynamic> b) => b['book_type_id'] == BookType.audiobook;
    final finished = p.books
        .where((b) => b['shelf_id'] == Shelf.finished)
        .toList();
    final pages = finished.where((b) => !isAudio(b)).fold<int>(
        0, (sum, b) => sum + ((b['page_count'] as num?)?.toInt() ?? 0));
    final minutes = finished.where(isAudio).fold<int>(
        0, (sum, b) => sum + ((b['duration_minutes'] as num?)?.toInt() ?? 0));
    final showListened = minutes > 0 ||
        (pages == 0 && p.books.isNotEmpty && p.books.every(isAudio));
    final showPages = pages > 0 || !showListened;
    final hours = minutes ~/ 60, mins = minutes % 60;
    final listened = hours == 0
        ? '${mins}m'
        : mins == 0
            ? '${NumberFormat.decimalPattern().format(hours)}h'
            : '${NumberFormat.decimalPattern().format(hours)}h ${mins}m';
    DateTime? parse(Object? v) => v is String ? DateTime.tryParse(v) : null;
    final starts = p.books.map((b) => parse(b['date_started'])).nonNulls;
    final ends = finished.map((b) => parse(b['date_finished'])).nonNulls;
    final started =
        starts.isEmpty ? null : starts.reduce((a, b) => a.isBefore(b) ? a : b);
    final last =
        ends.isEmpty ? null : ends.reduce((a, b) => a.isAfter(b) ? a : b);
    final fmt = DateFormat('MMM y');

    final tiles = [
      if (showPages)
        (NumberFormat.decimalPattern().format(pages), 'pages read'),
      if (showListened) (listened, 'listened'),
      (started == null ? '–' : fmt.format(started), 'started'),
      (last == null ? '–' : fmt.format(last), 'last finished'),
    ];
    Widget row(List<(String, String)> tiles) => Row(
          children: [
            for (var i = 0; i < tiles.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tiles[i].$1,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(tiles[i].$2,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
    // Four don't fit across a phone, so both counts get a row of their own.
    if (tiles.length < 4) return row(tiles);
    return Column(
      children: [
        row(tiles.sublist(0, 2)),
        const SizedBox(height: 8),
        row(tiles.sublist(2)),
      ],
    );
  }

  Widget _booksHeading(ThemeData theme) {
    return Row(
      children: [
        Text('Books', style: theme.textTheme.titleMedium),
        const Spacer(),
        if (_editing)
          Text('Drag to reorder, or tap a number',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }

  /// "1" in a fixed column, so titles line up whatever the number.
  Widget _number(ThemeData theme, double? position, {bool faded = false}) {
    return SizedBox(
      width: 40,
      child: Text(
        position == null ? '–' : SeriesProgress.formatNumber(position),
        textAlign: TextAlign.center,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: faded
              ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _bookRow(
      ThemeData theme, Map<String, dynamic> book, double? position,
      {int? dragIndex}) {
    final cs = theme.colorScheme;
    final isCurrent = book['id'] == widget.currentBookId;
    final cover = book['cover_path'] as String?;
    final rating = (book['rating'] as num?)?.toDouble();
    final (IconData icon, String label, Color color) =
        switch (book['shelf_id'] as int?) {
      Shelf.finished =>
        (
          Icons.check_circle,
          'Finished',
          seriesFinishedColor(cs),
        ),
      Shelf.currentlyReading =>
        (Icons.menu_book_rounded, 'Reading', cs.primary),
      Shelf.unfinished =>
        (Icons.do_not_disturb_on, 'Unfinished', cs.onSurfaceVariant),
      _ => (Icons.bookmark, 'Want to read', cs.onSurfaceVariant),
    };

    return InkWell(
      key: ValueKey('book-${book['id']}'),
      borderRadius: BorderRadius.circular(12),
      onTap: _editing ? null : () => _openBook(book),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            if (_editing)
              _editNumber(
                theme,
                dragIndex,
                InlineNumberField(
                  value: position,
                  allowEmpty: true,
                  onCommit: (n) => _renumberBook(book, n),
                ),
              )
            else
              _number(theme, position),
            const SizedBox(width: 8),
            if (cover != null && cover.isNotEmpty)
              BookCover(
                path: cover,
                shape: book['cover_shape'] as int?,
                width: 40,
                borderRadius: 4,
              )
            else
              const MissingCover(width: 40, icon: Icons.menu_book_rounded),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book['title'] as String? ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(icon, size: 14, color: color),
                      const SizedBox(width: 4),
                      // The check says finished; only the book being
                      // read has its word in colour too.
                      Text(label,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: book['shelf_id'] ==
                                      Shelf.currentlyReading
                                  ? color
                                  : cs.onSurfaceVariant)),
                      if (rating != null && rating > 0) ...[
                        const SizedBox(width: 10),
                        const Icon(Icons.star_rounded,
                            size: 14, color: Color(0xFFFBCB04)),
                        const SizedBox(width: 2),
                        Text(rating.toStringAsFixed(rating % 1 == 0 ? 0 : 1),
                            style: theme.textTheme.bodySmall),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (_editing)
              IconButton(
                tooltip: 'Remove from series',
                icon: Icon(Icons.remove_circle_outline, color: cs.error),
                onPressed: () => _removeBook(book),
              )
            else if (isCurrent)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('Viewing',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: cs.onSecondaryContainer)),
              ),
          ],
        ),
      ),
    );
  }

  /// A number held for a book the reader doesn't have — not out yet, or
  /// not bought. In edit mode its number and title are fields.
  Widget _plannedRow(
      ThemeData theme, double position, Map<String, dynamic> ph,
      {int? dragIndex}) {
    final cs = theme.colorScheme;
    final title = ph['title'] as String?;

    return InkWell(
      key: ValueKey('placeholder-${ph['id']}'),
      borderRadius: BorderRadius.circular(12),
      onTap: _editing
          ? null
          : () => _openAdd(number: position, title: title),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            if (_editing)
              _editNumber(
                theme,
                dragIndex,
                InlineNumberField(
                  value: position,
                  onCommit: (n) => _editPlaceholder(ph, n, null),
                ),
              )
            else
              _number(theme, position),
            const SizedBox(width: 8),
            const MissingCover(width: 40, icon: Icons.schedule),
            const SizedBox(width: 14),
            Expanded(
              child: _editing
                  ? InlineTextField(
                      value: title ?? '',
                      hint: 'Untitled',
                      onCommit: (t) => _editPlaceholder(ph, null, t),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title ?? 'Untitled',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontStyle:
                                title == null ? FontStyle.italic : null,
                            color: title == null ? cs.onSurfaceVariant : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.schedule,
                                size: 14, color: cs.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text('Placeholder',
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: cs.onSurfaceVariant)),
                          ],
                        ),
                      ],
                    ),
            ),
            if (_editing)
              IconButton(
                tooltip: 'Remove placeholder',
                icon: Icon(Icons.remove_circle_outline, color: cs.error),
                onPressed: () => _removePlaceholder(ph),
              )
            else
              TextButton(
                onPressed: () => _findOnline(position, title: title),
                child: const Text('Find'),
              ),
          ],
        ),
      ),
    );
  }

  /// A number nobody holds yet. Tapping opens the add panel at it.
  Widget _gapRow(ThemeData theme, SeriesSlot s) {
    final muted = theme.colorScheme.onSurfaceVariant;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _openAdd(number: s.position),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            _number(theme, s.position, faded: true),
            const SizedBox(width: 8),
            const MissingCover(width: 40),
            const SizedBox(width: 14),
            Expanded(
              child: Text('Not in your library',
                  style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
            ),
            TextButton(
              onPressed: () => _openAdd(number: s.position),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  /// The closed add panel: a row like the books', ready to tap.
  Widget _addRow(ThemeData theme) {
    final next = _progress!.nextFreeNumber;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _openAdd(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            _number(theme, next, faded: true),
            const SizedBox(width: 8),
            const MissingCover(width: 40),
            const SizedBox(width: 14),
            Text('Add a book',
                style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  /// Number and title, then the three ways in: search online, link a book
  /// already owned, or hold the number with a placeholder.
  Widget _addPanel(ThemeData theme) {
    final cs = theme.colorScheme;
    InputDecoration field(String label, {String? prefix}) => InputDecoration(
          labelText: label,
          prefixText: prefix,
          isDense: true,
          filled: true,
          fillColor: cs.surfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        );

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Add a book', style: theme.textTheme.titleSmall),
              const Spacer(),
              IconButton(
                tooltip: 'Cancel',
                icon: const Icon(Icons.close),
                onPressed: _closeAdd,
              ),
            ],
          ),
          Row(
            children: [
              SizedBox(
                width: 76,
                child: TextField(
                  controller: _addNumber,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: field('No.', prefix: '#'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _addTitle,
                  textCapitalization: TextCapitalization.words,
                  decoration: field('Title (optional)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _addBySearch,
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('Search'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _addFromLibrary,
                  icon: const Icon(Icons.library_books, size: 18),
                  label: const Text('Library'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _addPlaceholder,
            icon: const Icon(Icons.schedule, size: 18),
            label: const Text('Save as placeholder'),
          ),
          const SizedBox(height: 6),
          Text(
            'For a book that isn\'t out yet, or you don\'t have.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// One row of edit mode's reorderable list: a numbered book or a placeholder.
class _EditItem {
  final double position;
  final Map<String, dynamic>? book;
  final Map<String, dynamic>? placeholder;

  /// Where it was before the drag, to tell what moved.
  final double originalPosition;

  _EditItem(this.position, {this.book, this.placeholder})
      : originalPosition = position;

  _EditItem._moved(this.position, this.originalPosition,
      {this.book, this.placeholder});

  _EditItem at(double newPosition) => _EditItem._moved(
      newPosition, originalPosition,
      book: book, placeholder: placeholder);
}
