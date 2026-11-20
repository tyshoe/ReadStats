import 'dart:io';
import 'dart:ui' as ui;

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:intl/intl.dart';
import 'package:read_stats/data/database/database_helper.dart';
import 'package:read_stats/data/models/book_type.dart';
import 'package:read_stats/data/models/cover_shape.dart';
import 'package:read_stats/data/models/shelf.dart';
import 'package:read_stats/data/models/tag.dart';
import 'package:read_stats/data/repositories/book_repository.dart';
import 'package:read_stats/data/repositories/series_repository.dart';
import 'package:read_stats/data/repositories/session_repository.dart';
import 'package:read_stats/data/repositories/tag_repository.dart';
import 'package:read_stats/data/services/analytics_service.dart';
import 'package:read_stats/data/services/cover_service.dart';
import 'package:read_stats/domain/series_progress.dart';
import 'package:read_stats/ui/pages/book/book_form_page.dart';
import 'package:read_stats/ui/pages/book/widgets/book_details_section.dart';
import 'package:read_stats/ui/pages/book/widgets/book_reading_card.dart';
import 'package:read_stats/ui/pages/book/widgets/book_review_section.dart';
import 'package:read_stats/ui/pages/book/widgets/book_series_section.dart';
import 'package:read_stats/ui/pages/book/widgets/book_sessions_content.dart';
import 'package:read_stats/ui/pages/book/widgets/book_sessions_section.dart';
import 'package:read_stats/ui/pages/book/widgets/book_share_sheet.dart';
import 'package:read_stats/ui/pages/book/widgets/book_tags_row.dart';
import 'package:read_stats/ui/pages/book/widgets/detail_section.dart';
import 'package:read_stats/ui/pages/library/widgets/bulk_tag_sheet.dart';
import 'package:read_stats/ui/pages/series/series_page.dart';
import 'package:read_stats/ui/pages/series/widgets/next_in_series_sheet.dart';
import 'package:read_stats/ui/pages/sessions/session_form_page.dart';
import 'package:read_stats/ui/pages/sessions/widgets/rate_book_dialog.dart';
import 'package:read_stats/ui/settings_view_model.dart';
import 'package:read_stats/ui/widgets/book_cover.dart';
import 'package:read_stats/ui/widgets/book_type.dart';

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
  static const _coverWidth = 112.0;

  late Map<String, dynamic> _book = Map.of(widget.book);
  late bool _pinned = widget.isPinned;
  Map<String, dynamic> _stats = const {};
  List<Map<String, dynamic>> _sessions = const [];
  List<Tag> _tags = const [];
  List<Map<String, dynamic>> _shelves = const [];
  SeriesProgress? _series;
  int _currentPage = 0;

  final _scroll = ScrollController();
  final _scrolled = ValueNotifier(false);

  int get _id => _book['id'] as int;
  int? get _shelfId => _book['shelf_id'] as int?;
  bool get _isAudio => _book['book_type_id'] == BookType.audiobook;
  String? get _cover {
    final p = _book['cover_path'] as String?;
    return p == null || p.isEmpty ? null : p;
  }

  DateFormat get _dateFormat =>
      DateFormat(widget.settingsViewModel.defaultDateFormatNotifier.value);

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.screen('book_detail');
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

    final sessionRepo = SessionRepository();
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
      final seriesRepo = SeriesRepository();
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
    final start = DetailFormat.parse(_book['date_started']);
    final finish = DetailFormat.parse(_book['date_finished']);
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
    if (shelfId == Shelf.finished) {
      AnalyticsService.instance
          .bookFinished(bookTypeId: _book['book_type_id'] as int?);
    }
    setState(() => _book = {..._book, 'shelf_id': shelfId});
    widget.refreshCallback();
    if (shelfId == Shelf.finished && mounted) {
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
          sessionRepository: SessionRepository(),
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
            sliver: SliverList.list(children: _sections()),
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
                if (_shelfId != Shelf.finished)
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
        CoverShape.aspectRatio(_book['cover_shape'] as int?);

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
              BookTagsRow(tags: _tags, onArt: onArt, onTap: _editTags),
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
      return mins > 0 ? DetailFormat.time(mins) : null;
    }
    final pages = (_book['page_count'] as int?) ?? 0;
    return pages > 0 ? '${DetailFormat.number(pages)} ${pages == 1 ? 'page' : 'pages'}' : null;
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
    final shelfName = _shelfId == Shelf.currentlyReading
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

    final primary = Shelf.acceptsSessions(_shelfId)
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

  List<Widget> _sections() {
    final reading = _shelfId == Shelf.currentlyReading;
    final wantToRead = _shelfId == Shelf.wantToRead;
    final review = (_book['user_review'] as String?) ?? '';
    final reviewSection = review.trim().isNotEmpty || !wantToRead
        ? BookReviewSection(
            key: const ValueKey('review'),
            review: review,
            onEdit: _rate,
          )
        : null;

    final readingCard = BookReadingCard(
      book: _book,
      stats: _stats,
      currentPage: _currentPage,
      dateFormat: _dateFormat,
    );
    final series = _series;
    final seriesSection = series != null && _book['series_name'] != null
        ? BookSeriesSection(
            book: _book,
            series: series,
            onOpenSeries: _openSeries,
            onOpenBook: _openBook,
          )
        : null;

    final sections = <Widget?>[
      if (!readingCard.isEmpty) readingCard,
      // A finished book leads with what they thought of it; one still being
      // read, with the sessions.
      if (!reading) reviewSection,
      // Once a book's done, what comes next in its series matters more than
      // how the sessions went.
      if (!reading) seriesSection,
      if (_sessions.isNotEmpty)
        BookSessionsSection(
          sessions: _sessions,
          onTapSession: _editSession,
          onShowAll: _allSessions,
        ),
      if (reading) reviewSection,
      if (reading) seriesSection,
      BookDetailsSection(
        book: _book,
        settingsViewModel: widget.settingsViewModel,
        length: _length(),
        onEdit: () => widget.navigateToEditBookPage(_book),
      ),
    ];
    final shown = sections.nonNulls.toList();
    return [
      for (var i = 0; i < shown.length; i++) ...[
        if (i > 0) const SizedBox(height: 20),
        shown[i],
      ],
    ];
  }

  static IconData _shelfIcon(int? shelfId) => switch (shelfId) {
    Shelf.currentlyReading => Icons.auto_stories,
    Shelf.wantToRead => Icons.bookmark,
    Shelf.finished => Icons.check_circle,
    Shelf.unfinished => Icons.do_not_disturb_on,
    _ => Icons.shelves,
  };
}
