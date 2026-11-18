import 'dart:io';
import 'dart:ui' as ui;

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:intl/intl.dart';

import '/data/database/database_helper.dart';
import '/data/repositories/book_repository.dart';
import '/data/repositories/series_repository.dart';
import '/data/repositories/session_repository.dart';
import '/data/repositories/tag_repository.dart';
import '/data/services/cover_service.dart';
import '/data/models/tag.dart';
import '/data/utils/money.dart';
import '/data/utils/series_progress.dart';
import '/data/utils/series_title.dart';
import '/viewmodels/settings_view_model.dart';
import '/ui/widgets/book_cover.dart';
import '/ui/widgets/book_type.dart';
import '../sessions/session_form_page.dart';
import '../sessions/widgets/rate_book_dialog.dart';
import 'book_form_page.dart';
import 'series_page.dart';
import 'widgets/book_share_sheet.dart';
import 'widgets/book_sessions_content.dart';
import 'widgets/bulk_tag_sheet.dart';
import 'widgets/next_in_series_sheet.dart';
import 'widgets/series_strip.dart';

/// Opens a book's full page.
void openBookDetail(
  BuildContext context,
  Map<String, dynamic> book, {
  required TagRepository tagRepository,
  required BookRepository bookRepository,
  required SettingsViewModel settingsViewModel,
  required Function navigateToEditBookPage,
  required Function navigateToAddSessionPage,
  required Function confirmDelete,
  required VoidCallback refreshCallback,
  bool isPinned = false,
  void Function(int)? onTogglePin,
  bool Function(int bookId)? isPinnedFor,
}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => BookDetailPage(
        book: book,
        tagRepository: tagRepository,
        bookRepository: bookRepository,
        settingsViewModel: settingsViewModel,
        navigateToEditBookPage: navigateToEditBookPage,
        navigateToAddSessionPage: navigateToAddSessionPage,
        confirmDelete: confirmDelete,
        refreshCallback: refreshCallback,
        isPinned: isPinned,
        onTogglePin: onTogglePin,
        isPinnedFor: isPinnedFor,
      ),
    ),
  );
}

/// Everything about one book, as a page: the cover over a blur of itself, the
/// two things you'd do next, then sections that only appear when they have
/// something to say — progress while reading, a summary of the read, the
/// review, recent sessions, the series, tags and details.
///
/// Listens to the books and sessions tables, so whatever is changed from here
/// (an edit, a logged session, a rating) shows as soon as it's saved.
class BookDetailPage extends StatefulWidget {
  final Map<String, dynamic> book;
  final TagRepository tagRepository;
  final BookRepository bookRepository;
  final SettingsViewModel settingsViewModel;
  final Function navigateToEditBookPage;
  final Function navigateToAddSessionPage;
  final Function confirmDelete;
  final VoidCallback refreshCallback;
  final bool isPinned;

  /// Pins and unpins the book; without it (from Stats, which doesn't keep
  /// pins) there's no pin button.
  final void Function(int)? onTogglePin;
  final bool Function(int bookId)? isPinnedFor;

  const BookDetailPage({
    super.key,
    required this.book,
    required this.tagRepository,
    required this.bookRepository,
    required this.settingsViewModel,
    required this.navigateToEditBookPage,
    required this.navigateToAddSessionPage,
    required this.confirmDelete,
    required this.refreshCallback,
    this.isPinned = false,
    this.onTogglePin,
    this.isPinnedFor,
  });

  @override
  State<BookDetailPage> createState() => _BookDetailPageState();
}

class _BookDetailPageState extends State<BookDetailPage> {
  static const _recentSessions = 3;
  static const _coverWidth = 112.0;

  late Map<String, dynamic> _book = Map.of(widget.book);
  late bool _pinned = widget.isPinned;
  Map<String, dynamic> _stats = const {};
  List<Map<String, dynamic>> _sessions = const [];
  List<Tag> _tags = const [];
  List<Map<String, dynamic>> _shelves = const [];
  SeriesProgress? _series;
  int _currentPage = 0;
  bool _reviewExpanded = false;

  final _scroll = ScrollController();
  final _scrolled = ValueNotifier(false);

  int get _id => _book['id'] as int;
  int? get _shelfId => _book['shelf_id'] as int?;
  bool get _isAudio => _book['book_type_id'] == 4;
  String? get _cover {
    final p = _book['cover_path'] as String?;
    return p == null || p.isEmpty ? null : p;
  }

  DateFormat get _dateFormat =>
      DateFormat(widget.settingsViewModel.defaultDateFormatNotifier.value);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() => _scrolled.value = _scroll.offset > 140);
    DatabaseHelper.booksChanged.addListener(_load);
    DatabaseHelper.sessionsChanged.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    DatabaseHelper.booksChanged.removeListener(_load);
    DatabaseHelper.sessionsChanged.removeListener(_load);
    _scroll.dispose();
    _scrolled.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final db = DatabaseHelper();
    final fresh = await widget.bookRepository.getBookById(_id);
    // Deleted. Library's delete closes the page itself; anywhere else, close
    // it here — unless something (the delete dialog) is still on top.
    if (fresh == null) {
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.pop(context);
      }
      return;
    }
    final book = Map<String, dynamic>.from(fresh);
    final rawCover = book['cover_path'] as String?;
    if (rawCover != null && rawCover.isNotEmpty) {
      book['cover_path'] = await CoverService.resolveFullPath(rawCover);
    }

    final sessionRepo = SessionRepository(db);
    final stats = await widget.bookRepository.getBookStats(_id);
    final sessions =
        List<Map<String, dynamic>>.from(
          await sessionRepo.getSessionRowsByBookId(_id),
        )..sort(
          (a, b) => (b['date'] as String? ?? '').compareTo(
            a['date'] as String? ?? '',
          ),
        );
    final last = await sessionRepo.getLastPage(
      _id,
      DateTime.now().add(const Duration(days: 1)),
    );
    final tags = await widget.tagRepository.getTagsForBook(_id);
    final shelves = await widget.bookRepository.getShelves();

    SeriesProgress? series;
    final seriesId = book['series_id'] as int?;
    if (seriesId != null) {
      final seriesRepo = SeriesRepository(db);
      series = SeriesProgress.from(seriesId, [
        for (final row in await seriesRepo.booksIn(seriesId))
          {
            ...row,
            if ((row['cover_path'] as String?)?.isNotEmpty == true)
              'cover_path': await CoverService.resolveFullPath(
                row['cover_path'] as String,
              ),
          },
      ], placeholders: await seriesRepo.placeholdersIn(seriesId));
    }

    if (!mounted) return;
    setState(() {
      _book = book;
      _stats = stats;
      _sessions = sessions;
      _currentPage = last?.page ?? 0;
      _tags = tags;
      _shelves = shelves;
      _series = series;
    });
  }

  // ── Actions ────────────────────────────────────────────────────────────

  Future<void> _toggleFavorite() async {
    final next = _book['is_favorite'] != 1;
    await widget.bookRepository.toggleFavoriteStatus(_id, next);
    setState(() => _book = {..._book, 'is_favorite': next ? 1 : 0});
    widget.refreshCallback();
  }

  void _togglePin() {
    widget.onTogglePin?.call(_id);
    setState(() => _pinned = !_pinned);
  }

  Future<void> _rate() => showRatingDialogForBook(
    context: context,
    book: _book,
    bookRepository: widget.bookRepository,
    settingsViewModel: widget.settingsViewModel,
    onSaved: (rating, review) {
      setState(
        () => _book = {..._book, 'rating': rating, 'user_review': review},
      );
      widget.refreshCallback();
    },
  );

  Future<void> _editTags() async {
    await showBulkTagSheet(
      context: context,
      selectedBookIds: [_id],
      tagRepository: widget.tagRepository,
    );
    if (!mounted) return;
    final tags = await widget.tagRepository.getTagsForBook(_id);
    setState(() => _tags = tags);
    widget.refreshCallback();
  }

  void _share() => BookShareSheet.show(
    context,
    _book,
    _stats,
    widget.settingsViewModel.defaultRatingStyleNotifier.value,
    _dateRange(),
  );

  String _dateRange() {
    final start = _parse(_book['date_started']);
    final finish = _parse(_book['date_finished']);
    final f = _dateFormat;
    if (start != null && finish != null) {
      return '${f.format(start)} - ${f.format(finish)}';
    }
    if (start != null) return 'Started ${f.format(start)}';
    if (finish != null) return 'Finished ${f.format(finish)}';
    return '';
  }

  void _duplicate() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookFormPage(
          book: {
            'title': '${_book['title']} (Copy)',
            'author': _book['author'],
            'word_count': _book['word_count'],
            'page_count': _book['page_count'],
            'book_type_id': _book['book_type_id'],
            'narrator': _book['narrator'],
            'rating': null,
            'is_favorite': 0,
            'date_started': null,
            'date_finished': null,
            'date_added': DateTime.now().toIso8601String(),
          },
          onSave: (_) => widget.refreshCallback(),
          settingsViewModel: widget.settingsViewModel,
        ),
      ),
    );
  }

  /// Puts the book on [shelfId]; finishing it offers the next in its series.
  Future<void> _moveToShelf(int shelfId) async {
    if (shelfId == _shelfId) return;
    await widget.bookRepository.updateBookShelf(_id, shelfId);
    setState(() => _book = {..._book, 'shelf_id': shelfId});
    widget.refreshCallback();
    if (shelfId == DatabaseHelper.shelfFinished && mounted) {
      await showNextInSeries(
        context: context,
        finishedBookId: _id,
        bookRepository: widget.bookRepository,
        settingsViewModel: widget.settingsViewModel,
      );
    }
  }

  Future<void> _openSeries() async {
    final seriesId = _book['series_id'] as int?;
    if (seriesId == null) return;
    // A book picked there opens over the series in one transition; picking
    // this one just closes the series.
    await openSeriesPage(
      context: context,
      seriesId: seriesId,
      currentBookId: _id,
      settingsViewModel: widget.settingsViewModel,
      onOpenBook: _openBook,
    );
  }

  /// Another book's page, pushed over [from] (this page, or the series page
  /// opened from it) like any other page, so back retraces the way here.
  void _openBook(BuildContext from, Map<String, dynamic> book) {
    if (book['id'] == _id) return;
    Navigator.of(from).push(
      MaterialPageRoute(
        builder: (_) => BookDetailPage(
          book: book,
          tagRepository: widget.tagRepository,
          bookRepository: widget.bookRepository,
          settingsViewModel: widget.settingsViewModel,
          navigateToEditBookPage: widget.navigateToEditBookPage,
          navigateToAddSessionPage: widget.navigateToAddSessionPage,
          confirmDelete: widget.confirmDelete,
          refreshCallback: widget.refreshCallback,
          isPinned: widget.isPinnedFor?.call(book['id'] as int) ?? false,
          onTogglePin: widget.onTogglePin,
          isPinnedFor: widget.isPinnedFor,
        ),
      ),
    );
  }

  void _editSession(Map<String, dynamic> session) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SessionFormPage(
          session: session,
          book: _book,
          availableBooks: const [],
          onSave: widget.refreshCallback,
          settingsViewModel: widget.settingsViewModel,
          sessionRepository: SessionRepository(DatabaseHelper()),
          bookRepository: widget.bookRepository,
        ),
      ),
    );
  }

  void _allSessions() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text('Sessions · ${_book['title']}')),
          body: BookSessionsContent(
            book: _book,
            dateFormatString:
                widget.settingsViewModel.defaultDateFormatNotifier.value,
            settingsViewModel: widget.settingsViewModel,
            onChanged: widget.refreshCallback,
            expandable: false,
          ),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ValueListenableBuilder<bool>(
          valueListenable: _scrolled,
          builder: (context, scrolled, _) => _appBar(theme, scrolled),
        ),
      ),
      body: CustomScrollView(
        controller: _scroll,
        slivers: [
          SliverToBoxAdapter(child: _hero(theme)),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              16,
              4,
              16,
              24 + MediaQuery.paddingOf(context).bottom,
            ),
            sliver: SliverList.list(children: _sections(theme)),
          ),
        ],
      ),
    );
  }

  Widget _appBar(ThemeData theme, bool scrolled) {
    final cs = theme.colorScheme;
    // Over the blurred cover the icons are white; once the hero has scrolled
    // away the bar takes the page's colours and the title.
    final overArt = !scrolled && _cover != null;
    final fg = overArt ? Colors.white : cs.onSurface;
    final fav = _book['is_favorite'] == 1;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      color: scrolled ? cs.surfaceContainer : Colors.transparent,
      child: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: fg,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: overArt || theme.brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        title: AnimatedOpacity(
          opacity: scrolled ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: Text(
            _book['title'] as String? ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        actions: [
          if (widget.onTogglePin != null)
            IconButton(
              tooltip: _pinned ? 'Unpin' : 'Pin',
              icon: Icon(_pinned ? Icons.push_pin : Icons.push_pin_outlined),
              onPressed: _togglePin,
            ),
          IconButton(
            tooltip: fav ? 'Remove from favorites' : 'Favorite',
            icon: Icon(
              fav ? Icons.favorite : Icons.favorite_border,
              color: fav ? Colors.redAccent : null,
            ),
            onPressed: _toggleFavorite,
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (v) => switch (v) {
              'edit' => widget.navigateToEditBookPage(_book),
              'share' => _share(),
              'duplicate' => _duplicate(),
              'delete' => widget.confirmDelete(_id),
              _ => null,
            },
            itemBuilder: (ctx) {
              PopupMenuItem<String> item(
                String value,
                IconData icon,
                String label, {
                Color? color,
              }) => PopupMenuItem(
                value: value,
                child: Row(
                  children: [
                    Icon(icon, size: 20, color: color),
                    const SizedBox(width: 12),
                    Text(label, style: TextStyle(color: color)),
                  ],
                ),
              );
              return [
                item('edit', Icons.edit, 'Edit'),
                if (_shelfId != DatabaseHelper.shelfFinished)
                  item('share', FluentIcons.share_16_filled, 'Share'),
                item('duplicate', Icons.copy, 'Duplicate'),
                const PopupMenuDivider(),
                item('delete', Icons.delete, 'Delete', color: cs.error),
              ];
            },
          ),
        ],
      ),
    );
  }

  // ── Hero ───────────────────────────────────────────────────────────────

  /// Cover beside everything that identifies the book — title, author,
  /// format, rating, tags — over a blur of the cover, then the two actions.
  Widget _hero(ThemeData theme) {
    final cs = theme.colorScheme;
    final top = MediaQuery.paddingOf(context).top + kToolbarHeight;
    final cover = _cover;
    final onArt = cover != null;
    final coverHeight =
        _coverWidth /
        DatabaseHelper.coverAspectRatio(_book['cover_shape'] as int?);

    // Over the darkened art the text is white; without art, the theme's.
    final strong = onArt ? Colors.white : cs.onSurface;
    final muted = onArt
        ? Colors.white.withValues(alpha: 0.75)
        : cs.onSurfaceVariant;
    final narrator = _isAudio
        ? (_book['narrator'] as String? ?? '').trim()
        : '';
    final (typeIcon, type) = bookTypeDetails(_book['book_type_id'] as int?);
    final meta = [type, ?_length()].join(' · ');

    return Stack(
      children: [
        Positioned.fill(
          child: onArt
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    // Clipped with clamped edges, or the blur spills past the
                    // box and leaves a seam where it ends. It also stops short
                    // of the bottom, under solid surface: when an overscroll
                    // stretches the page, an image reaching the very edge
                    // shows through as a thin line.
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      bottom: 16,
                      child: ClipRect(
                        child: ImageFiltered(
                          imageFilter: ui.ImageFilter.blur(
                            sigmaX: 40,
                            sigmaY: 40,
                            tileMode: TileMode.clamp,
                          ),
                          child: Image.file(File(cover), fit: BoxFit.cover),
                        ),
                      ),
                    ),
                    // Dark enough behind the title and tags to read white in
                    // either theme, fading into the page only behind the
                    // buttons, and fully surface before the image ends.
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.5),
                            Colors.black.withValues(alpha: 0.4),
                            cs.surface,
                            cs.surface,
                          ],
                          stops: const [0, 0.78, 0.96, 1],
                        ),
                      ),
                    ),
                  ],
                )
              : DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [cs.primary.withValues(alpha: 0.22), cs.surface],
                    ),
                  ),
                ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, top + 4, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: onArt
                        ? BookCover(
                            path: cover,
                            shape: _book['cover_shape'] as int?,
                            width: _coverWidth,
                            borderRadius: 8,
                          )
                        : _coverPlaceholder(theme, coverHeight),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _book['title'] as String? ?? '',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                            color: strong,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _book['author'] as String? ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: muted,
                          ),
                        ),
                        if (narrator.isNotEmpty)
                          Text(
                            'Narrated by $narrator',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: muted,
                            ),
                          ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(typeIcon, size: 15, color: muted),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                meta,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        _ratingRow(theme, strong),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _tagsRow(theme, onArt),
              const SizedBox(height: 14),
              _actions(theme),
            ],
          ),
        ),
      ],
    );
  }

  Widget _coverPlaceholder(ThemeData theme, double height) {
    final cs = theme.colorScheme;
    final (icon, _) = bookTypeDetails(_book['book_type_id'] as int?);
    return Container(
      width: _coverWidth,
      height: height,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 36, color: cs.onSurfaceVariant),
    );
  }

  String? _length() {
    if (_isAudio) {
      final mins = (_book['duration_minutes'] as int?) ?? 0;
      return mins > 0 ? _formatTime(mins) : null;
    }
    final pages = (_book['page_count'] as int?) ?? 0;
    return pages > 0 ? '${_n(pages)} ${pages == 1 ? 'page' : 'pages'}' : null;
  }

  Widget _ratingRow(ThemeData theme, Color strong) {
    final rating = (_book['rating'] as num?)?.toDouble();
    final stars =
        widget.settingsViewModel.defaultRatingStyleNotifier.value == 0;
    const gold = Color(0xFFFBCB04);
    final empty = strong.withValues(alpha: 0.3);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _rate,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (rating != null) ...[
              Text(
                rating.toStringAsFixed(1),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: strong,
                ),
              ),
              const SizedBox(width: 6),
            ],
            if (stars || rating == null)
              RatingBarIndicator(
                rating: rating ?? 0,
                itemCount: 5,
                itemSize: 20,
                unratedColor: empty,
                itemBuilder: (_, _) =>
                    const Icon(Icons.star_rounded, color: gold),
              )
            else
              const Icon(Icons.star_rounded, size: 20, color: gold),
            if (rating == null) ...[
              const SizedBox(width: 6),
              Text(
                'Rate',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: strong.withValues(alpha: 0.75),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// The shelf it's on, and the obvious next thing: log a session while it
  /// takes them, share it once it's finished.
  Widget _actions(ThemeData theme) {
    // "Currently Reading" doesn't fit half a row.
    final shelfName = _shelfId == DatabaseHelper.shelfCurrentlyReading
        ? 'Reading'
        : _shelves.firstWhere(
                (s) => s['id'] == _shelfId,
                orElse: () => {'name': _book['shelf_name'] ?? 'Shelf'},
              )['name']
              as String;
    const height = 44.0;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );

    // The shelves drop down from the button itself, as wide as it is.
    final shelf = LayoutBuilder(
      builder: (context, constraints) => MenuAnchor(
        alignmentOffset: const Offset(0, 6),
        style: MenuStyle(
          // The panel sizes itself to its items whatever its size style
          // says, so the items carry the width (below) and the panel adds
          // nothing beside them.
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(vertical: 8),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        menuChildren: [
          for (final s in _shelves)
            Builder(
              builder: (context) {
                final current = s['id'] == _shelfId;
                final color = current ? theme.colorScheme.primary : null;
                return SizedBox(
                  width: constraints.maxWidth,
                  child: MenuItemButton(
                    leadingIcon: Icon(
                      _shelfIcon(s['id'] as int?),
                      color: color,
                    ),
                    trailingIcon: current
                        ? Icon(Icons.check_rounded, color: color)
                        : null,
                    onPressed: () => _moveToShelf(s['id'] as int),
                    child: Text(
                      s['name'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color,
                        fontWeight: current ? FontWeight.w600 : null,
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
        builder: (context, controller, _) => FilledButton.tonal(
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(height),
            shape: shape,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_shelfIcon(_shelfId), size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  shelfName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                controller.isOpen ? Icons.expand_less : Icons.expand_more,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );

    final primary = DatabaseHelper.acceptsSessions(_shelfId)
        ? FilledButton.icon(
            onPressed: () => widget.navigateToAddSessionPage(_book),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(height),
              shape: shape,
            ),
            icon: const Icon(FluentIcons.calendar_add_16_filled, size: 18),
            label: const Text('Log session'),
          )
        : FilledButton.icon(
            onPressed: _share,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(height),
              shape: shape,
            ),
            icon: const Icon(FluentIcons.share_16_filled, size: 18),
            label: const Text('Share'),
          );

    return Row(
      children: [
        Expanded(child: shelf),
        const SizedBox(width: 10),
        Expanded(child: primary),
      ],
    );
  }

  // ── Sections ───────────────────────────────────────────────────────────

  List<Widget> _sections(ThemeData theme) {
    final reading = _shelfId == DatabaseHelper.shelfCurrentlyReading;
    final wantToRead = _shelfId == DatabaseHelper.shelfWantToRead;
    final hasReview =
        (_book['user_review'] as String?)?.trim().isNotEmpty ?? false;
    final review = hasReview || (!wantToRead) ? _reviewSection(theme) : null;

    final sections = <Widget?>[
      _readingCard(theme),
      // A finished book leads with what they thought of it; one still being
      // read, with the sessions.
      if (!reading) review,
      // Once a book's done, what comes next in its series matters more than
      // how the sessions went.
      if (!reading) _seriesSection(theme),
      _sessionsSection(theme),
      if (reading) review,
      if (reading) _seriesSection(theme),
      _detailsSection(theme),
    ];
    final shown = sections.nonNulls.toList();
    return [
      for (var i = 0; i < shown.length; i++) ...[
        if (i > 0) const SizedBox(height: 20),
        shown[i],
      ],
    ];
  }

  Widget _heading(
    ThemeData theme,
    String title, {
    String? trailing,
    VoidCallback? onTrailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Row(
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          if (trailing != null)
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onTrailing,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      trailing,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _card(
    ThemeData theme,
    Widget child, {
    EdgeInsets padding = const EdgeInsets.all(14),
    VoidCallback? onTap,
  }) {
    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }

  /// One card for the read itself: progress while reading (or when it was
  /// read, once done), then every number that has a value, three to a row.
  Widget? _readingCard(ThemeData theme) {
    final cs = theme.colorScheme;
    final reading = _shelfId == DatabaseHelper.shelfCurrentlyReading;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: cs.onSurfaceVariant,
    );

    final top = reading ? _progress(theme) : _dates(theme);
    final cells = _statCells();
    if (top == null && cells.isEmpty) return null;

    return _card(
      theme,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ?top,
          if (top != null && cells.isNotEmpty)
            Divider(
              height: 24,
              color: cs.outlineVariant.withValues(alpha: 0.5),
            ),
          for (var r = 0; r < cells.length; r += 3) ...[
            if (r > 0) const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = r; i < r + 3; i++)
                  Expanded(
                    child: i < cells.length
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cells[i].$1,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(cells[i].$2, style: muted),
                            ],
                          )
                        : const SizedBox(),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Big percentage, the bar, and where they are in it.
  Widget? _progress(ThemeData theme) {
    final cs = theme.colorScheme;
    final total = _isAudio
        ? (_book['duration_minutes'] as int?) ?? 0
        : (_book['page_count'] as int?) ?? 0;
    if (total <= 0) return null;
    final done = _isAudio
        ? (_stats['total_time'] as num?)?.toInt() ?? 0
        : (_stats['total_pages'] as num?)?.toInt() ?? 0;
    final fraction = (done / total).clamp(0.0, 1.0);

    String? left;
    if (_isAudio) {
      if (done < total) left = '${_formatTime(total - done)} left';
    } else {
      final ppm = (_stats['pages_per_minute'] as num?)?.toDouble() ?? 0;
      if (ppm > 0 && done < total) {
        left = '${_formatTime(((total - done) / ppm).round())} left';
      }
    }

    final where = _isAudio
        ? '${_formatTime(done)} of ${_formatTime(total)}'
        : _currentPage > 0
        ? 'Page ${_n(_currentPage)} of ${_n(total)}'
        : '${_n(done)} of ${_n(total)} pages';
    final start = _parse(_book['date_started']);
    final since = start == null
        ? null
        : 'Day ${_daysBetween(start, DateTime.now()) + 1} · since ${DateFormat.MMMd().format(start)}';
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: cs.onSurfaceVariant,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '${(fraction * 100).round()}%',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: cs.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                where,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
            if (left != null)
              Text(
                left,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 8,
            backgroundColor: cs.surfaceContainerHighest,
          ),
        ),
        if (since != null) ...[
          const SizedBox(height: 6),
          Text(since, style: muted),
        ],
      ],
    );
  }

  /// "Oct 27 – Nov 5, 2026" with "9 days" at the end.
  Widget? _dates(ThemeData theme) {
    final cs = theme.colorScheme;
    final start = _parse(_book['date_started']);
    final finish = _parse(_book['date_finished']);
    final f = _dateFormat;
    final String text;
    String? span;
    if (start != null && finish != null) {
      text = '${f.format(start)} – ${f.format(finish)}';
      final d = _daysBetween(start, finish).clamp(1, 1 << 31);
      span = '$d ${d == 1 ? 'day' : 'days'}';
    } else if (start != null) {
      text = 'Started ${f.format(start)}';
    } else if (finish != null) {
      text = 'Finished ${f.format(finish)}';
    } else {
      return null;
    }
    return Row(
      children: [
        Icon(Icons.event, size: 18, color: cs.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (span != null)
          Text(
            span,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
      ],
    );
  }

  /// Every reading number that has a value.
  List<(String, String)> _statCells() {
    final sessions = (_stats['session_count'] as int?) ?? 0;
    if (sessions == 0) return const [];
    final minutes = (_stats['total_time'] as num?)?.toInt() ?? 0;
    final pages = (_stats['total_pages'] as num?)?.toInt() ?? 0;
    final ppm = (_stats['pages_per_minute'] as num?)?.toDouble() ?? 0;
    final wpm = (_stats['words_per_minute'] as num?)?.toDouble() ?? 0;
    final reading = _shelfId == DatabaseHelper.shelfCurrentlyReading;
    return [
      if (minutes > 0)
        (_formatTime(minutes), _isAudio ? 'listened' : 'read time'),
      ('$sessions', sessions == 1 ? 'session' : 'sessions'),
      if (minutes > 0)
        (_formatTime((minutes / sessions).round()), 'avg session'),
      // Progress already says how many pages while reading.
      if (!_isAudio && pages > 0 && !reading) (_n(pages), 'pages read'),
      if (!_isAudio && ppm > 0) ('${(ppm * 60).round()}', 'pages/hr'),
      if (wpm > 0) ('${wpm.round()}', 'words/min'),
    ];
  }

  Widget _reviewSection(ThemeData theme) {
    final cs = theme.colorScheme;
    final review = (_book['user_review'] as String?)?.trim() ?? '';

    if (review.isEmpty) {
      return _card(
        theme,
        onTap: _rate,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        Row(
          children: [
            Icon(FluentIcons.compose_16_filled, size: 20, color: cs.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Write a review',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
          ],
        ),
      );
    }

    final style = theme.textTheme.bodyMedium?.copyWith(
      height: 1.5,
      color: cs.onSurface,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading(theme, 'Your review', trailing: 'Edit', onTrailing: _rate),
        _card(
          theme,
          onTap: () => setState(() => _reviewExpanded = !_reviewExpanded),
          LayoutBuilder(
            builder: (context, constraints) {
              final overflows = (TextPainter(
                text: TextSpan(text: review, style: style),
                maxLines: 4,
                textDirection: Directionality.of(context),
              )..layout(maxWidth: constraints.maxWidth)).didExceedMaxLines;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    alignment: Alignment.topCenter,
                    child: Text(
                      review,
                      style: style,
                      maxLines: _reviewExpanded ? null : 4,
                      overflow: _reviewExpanded
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                    ),
                  ),
                  if (overflows) ...[
                    const SizedBox(height: 6),
                    Text(
                      _reviewExpanded ? 'Show less' : 'Read more',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: cs.primary,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget? _sessionsSection(ThemeData theme) {
    if (_sessions.isEmpty) return null;
    final cs = theme.colorScheme;
    final shown = _sessions.take(_recentSessions).toList();
    final more = _sessions.length > _recentSessions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading(
          theme,
          more ? 'Recent sessions' : 'Sessions',
          trailing: more ? 'All ${_sessions.length}' : null,
          onTrailing: more ? _allSessions : null,
        ),
        Material(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < shown.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    indent: 64,
                    color: cs.outlineVariant.withValues(alpha: 0.5),
                  ),
                _sessionRow(theme, shown[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _sessionRow(ThemeData theme, Map<String, dynamic> s) {
    final cs = theme.colorScheme;
    final date = _parse(s['date']);
    final minutes = (s['duration_minutes'] as int?) ?? 0;
    final pages = (s['pages_read'] as int?) ?? 0;
    final notes = (s['notes'] as String?)?.trim() ?? '';
    final detail = [
      if (pages > 0) '$pages pp',
      if (pages > 0 && minutes > 0) '${(pages * 60 / minutes).round()}/hr',
    ].join(' · ');
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: cs.onSurfaceVariant,
    );

    return InkWell(
      onTap: () => _editSession(s),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Row(
          children: [
            // Day of the month over its month, like a calendar tile.
            SizedBox(
              width: 36,
              child: Column(
                children: [
                  Text(
                    date == null ? '–' : DateFormat('d').format(date),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    date == null
                        ? ''
                        : DateFormat('MMM').format(date).toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    date == null ? '' : DateFormat('EEEE').format(date),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (notes.isNotEmpty)
                    Text(
                      notes,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: muted,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (minutes > 0)
                  Text(
                    _formatTime(minutes),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (detail.isNotEmpty) Text(detail, style: muted),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// The series this book belongs to: how far through it the reader is, every
  /// number as a cover (tap one to open it), and what's up next.
  Widget? _seriesSection(ThemeData theme) {
    final series = _series;
    final name = _book['series_name'] as String?;
    if (series == null || name == null) return null;
    final cs = theme.colorScheme;
    final position = (_book['series_position'] as num?)?.toDouble();
    final total = series.total;
    final done = series.isComplete;
    final finishedColor = seriesFinishedColor(cs);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: cs.onSurfaceVariant,
    );

    // Up next, unless it's this book.
    final next = series.nextUp;
    final showNext =
        next != null && !(next.book != null && next.book!['id'] == _id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading(theme, 'Series', trailing: 'View', onTrailing: _openSeries),
        _card(
          theme,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    done ? 'Complete' : '${series.read} of $total read',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: done ? finishedColor : cs.onSurfaceVariant,
                      fontWeight: done ? FontWeight.w700 : null,
                    ),
                  ),
                ],
              ),
              if (position != null)
                Text(
                  'This is book ${SeriesTitle.formatPosition(position)}',
                  style: muted,
                ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : series.read / total,
                  minHeight: 4,
                  color: finishedColor,
                  backgroundColor: cs.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 14),
              SeriesStrip(
                progress: series,
                highlight: position,
                onTap: (slot) => slot.book == null
                    ? _openSeries()
                    : _openBook(context, slot.book!),
              ),
              if (showNext) ...[
                Divider(
                  height: 24,
                  color: cs.outlineVariant.withValues(alpha: 0.5),
                ),
                _upNextRow(theme, next),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// "Up next · Book 3 — Title", opening that book; a number missing from
  /// the library opens the series, where it can be found.
  Widget _upNextRow(ThemeData theme, SeriesSlot next) {
    final cs = theme.colorScheme;
    final book = next.book;
    final cover = book?['cover_path'] as String?;
    final reading = next.state == SeriesSlotState.reading;
    final title =
        book?['title'] as String? ?? next.plannedTitle ?? 'Not in your library';
    final label = reading
        ? 'Reading now'
        : book == null
        ? 'Missing'
        : 'Up next';

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => book == null ? _openSeries() : _openBook(context, book),
      child: Row(
        children: [
          if (cover != null && cover.isNotEmpty)
            BookCover(
              path: cover,
              shape: book?['cover_shape'] as int?,
              width: 36,
              borderRadius: 4,
            )
          else
            Container(
              width: 36,
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Icon(
                book == null ? Icons.search : Icons.menu_book,
                size: 16,
                color: cs.onSurfaceVariant,
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$label · ${SeriesProgress.label(next.position)}'
                      .toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: book == null ? cs.onSurfaceVariant : null,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
        ],
      ),
    );
  }

  /// The facts about the copy, two to a row.
  Widget _detailsSection(ThemeData theme) {
    final cs = theme.colorScheme;
    final f = _dateFormat;
    final (_, type) = bookTypeDetails(_book['book_type_id'] as int?);
    final words = (_book['word_count'] as int?) ?? 0;
    final added = _parse(_book['date_added']);
    final narrator = _isAudio
        ? (_book['narrator'] as String? ?? '').trim()
        : '';
    final isbn = (_book['isbn'] as String? ?? '').trim();

    String? paid;
    if (widget.settingsViewModel.spendingEnabledNotifier.value) {
      final price = (_book['price_paid'] as num?)?.toDouble();
      if (price != null) {
        final bought = _parse(_book['date_purchased']);
        paid = [
          Money.format(price, widget.settingsViewModel.currencyNotifier.value),
          if (bought != null) DateFormat.yMMMd().format(bought),
        ].join(' · ');
      }
    }

    final cells = <(String, String)>[
      ('Format', type),
      if (_length() case final l?) (_isAudio ? 'Length' : 'Pages', l),
      if (!_isAudio && words > 0) ('Words', _n(words)),
      if (narrator.isNotEmpty) ('Narrator', narrator),
      if (isbn.isNotEmpty) ('ISBN', isbn),
      if (added != null) ('Added', f.format(added)),
      if (paid != null) ('Paid', paid),
    ];
    final label = theme.textTheme.bodySmall?.copyWith(
      color: cs.onSurfaceVariant,
    );
    final value = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading(
          theme,
          'Details',
          trailing: 'Edit',
          onTrailing: () => widget.navigateToEditBookPage(_book),
        ),
        _card(
          theme,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var r = 0; r < cells.length; r += 2) ...[
                if (r > 0) const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = r; i < r + 2; i++)
                      Expanded(
                        child: i < cells.length
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(cells[i].$1, style: label),
                                  const SizedBox(height: 1),
                                  Text(
                                    cells[i].$2,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: value,
                                  ),
                                ],
                              )
                            : const SizedBox(),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// The book's tags under the cover, each opening the tag editor.
  Widget _tagsRow(ThemeData theme, bool onArt) {
    final muted = onArt
        ? Colors.white.withValues(alpha: 0.75)
        : theme.colorScheme.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6, right: 10),
          child: Icon(Icons.sell, size: 16, color: muted),
        ),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tag in _tags)
                _tagChip(theme, tag.name, onArt: onArt, filled: true),
              _tagChip(
                theme,
                _tags.isEmpty ? 'Add tags' : 'Add',
                onArt: onArt,
                icon: Icons.add,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tagChip(
    ThemeData theme,
    String label, {
    required bool onArt,
    bool filled = false,
    IconData? icon,
  }) {
    final cs = theme.colorScheme;
    // The outlined "Add" chip goes white over the art, where theme outlines
    // vanish.
    final fg = filled
        ? cs.onSecondaryContainer
        : onArt
        ? Colors.white.withValues(alpha: 0.85)
        : cs.onSurfaceVariant;
    final outline = onArt
        ? Colors.white.withValues(alpha: 0.45)
        : cs.outlineVariant;
    return Material(
      color: filled ? cs.secondaryContainer : Colors.transparent,
      shape: StadiumBorder(
        side: filled ? BorderSide.none : BorderSide(color: outline),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: _editTags,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: fg),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  static IconData _shelfIcon(int? shelfId) => switch (shelfId) {
    DatabaseHelper.shelfCurrentlyReading => Icons.auto_stories,
    DatabaseHelper.shelfWantToRead => Icons.bookmark,
    DatabaseHelper.shelfFinished => Icons.check_circle,
    DatabaseHelper.shelfUnfinished => Icons.do_not_disturb_on,
    _ => Icons.shelves,
  };

  static DateTime? _parse(Object? v) =>
      v is String ? DateTime.tryParse(v) : null;

  static int _daysBetween(DateTime a, DateTime b) => DateTime.utc(
    b.year,
    b.month,
    b.day,
  ).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

  static String _n(int n) => NumberFormat.decimalPattern().format(n);

  static String _formatTime(int minutes) {
    final h = minutes ~/ 60, m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${_n(h)}h';
    return '${_n(h)}h ${m}m';
  }
}
