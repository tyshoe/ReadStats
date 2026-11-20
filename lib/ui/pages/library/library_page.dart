import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:read_stats/data/models/shelf.dart';
import 'package:read_stats/data/repositories/book_repository.dart';
import 'package:read_stats/data/repositories/series_repository.dart';
import 'package:read_stats/data/repositories/session_repository.dart';
import 'package:read_stats/data/repositories/tag_repository.dart';
import 'package:read_stats/data/services/analytics_service.dart';
import 'package:read_stats/domain/library_filter.dart';
import 'package:read_stats/domain/series_progress.dart';
import 'package:read_stats/ui/pages/book/book_detail_page.dart';
import 'package:read_stats/ui/pages/book/book_form_page.dart';
import 'package:read_stats/ui/pages/book_search/book_search_sheet.dart';
import 'package:read_stats/ui/pages/library/widgets/book_grid.dart';
import 'package:read_stats/ui/pages/library/widgets/book_row.dart';
import 'package:read_stats/ui/pages/library/widgets/bulk_tag_sheet.dart';
import 'package:read_stats/ui/pages/library/widgets/filter_sort_sheet.dart';
import 'package:read_stats/ui/pages/library/widgets/library_empty_states.dart';
import 'package:read_stats/ui/pages/library/widgets/library_menu.dart';
import 'package:read_stats/ui/pages/library/widgets/planner_banner.dart';
import 'package:read_stats/ui/pages/library/widgets/random_book_picker.dart';
import 'package:read_stats/ui/pages/library/widgets/selection_actions.dart';
import 'package:read_stats/ui/pages/library/widgets/shelf_chips.dart';
import 'package:read_stats/ui/pages/planner/planner_page.dart';
import 'package:read_stats/ui/pages/series/series_page.dart';
import 'package:read_stats/ui/pages/series/widgets/bulk_series_sheet.dart';
import 'package:read_stats/ui/pages/series/widgets/next_in_series_sheet.dart';
import 'package:read_stats/ui/pages/series/widgets/series_detect_sheet.dart';
import 'package:read_stats/ui/pages/series/widgets/series_row.dart';
import 'package:read_stats/ui/pages/sessions/session_form_page.dart';
import 'package:read_stats/ui/settings_view_model.dart';
import 'package:read_stats/ui/widgets/app_snackbar.dart';
import 'package:share_plus/share_plus.dart';

class LibraryPage extends StatefulWidget {
  final List<Map<String, dynamic>> books;
  final Function() refreshBooks;
  final Function() refreshSessions;
  final SettingsViewModel settingsViewModel;
  final SessionRepository sessionRepository;
  final BookRepository bookRepository;

  const LibraryPage({
    super.key,
    required this.books,
    required this.refreshBooks,
    required this.refreshSessions,
    required this.settingsViewModel,
    required this.sessionRepository,
    required this.bookRepository,
  });

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  String _libraryBookView = 'rows';
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredBooks = [];
  String _selectedSortOption = 'Date added';
  bool _isAscending = false;
  bool _isFavorite = false;
  int? _selectedShelfId; // null = All shelves
  List<Map<String, dynamic>> _shelves = [];
  List<String> _selectedFinishedYears = [];
  List<String> _selectedBookTypes = [];
  List<String> _selectedTags = [];
  String _selectedTagFilterMode = 'any';
  bool _isReviewed = false;
  late TagRepository _tagRepository;
  List<String> _availableTags = [];
  Map<int, List<String>> _bookTagsCache = {};
  bool _selectionMode = false;
  final Set<int> _selectedBookIds = {};
  Set<int> _pinnedBookIds = {};
  final GlobalKey _selectedShelfChipKey = GlobalKey();
  bool _groupSeries = true;
  bool _seriesOnly = false;
  String _coverFilter = 'all';

  /// Series rows the reader has opened up, for this visit.
  final Set<int> _expandedSeries = {};

  /// Placeholders by series, for the series rows' strips and counts.
  Map<int, List<Map<String, dynamic>>> _placeholders = const {};

  Future<void> _loadPlaceholders() async {
    final map = await SeriesRepository().allPlaceholders();
    if (mounted) setState(() => _placeholders = map);
  }
  double _filterDividerOpacity = 0;

  // Fade a hairline in under the pinned filter band once the book list scrolls
  // beneath it, so the cue lands where scroll content begins (not on the app
  // bar, which sits above the static shelf chips). Mirrors the bottom nav line.
  bool _onBodyScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;
    final raw = (n.metrics.pixels / 12).clamp(0.0, 1.0);
    final stepped = (raw * 8).round() / 8;
    if (stepped != _filterDividerOpacity) {
      setState(() => _filterDividerOpacity = stepped);
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _tagRepository = TagRepository();
    _loadAvailableTags();
    _loadAllBookTags();
    _loadShelves();
    _loadPlaceholders();

    _selectedSortOption = widget.settingsViewModel.librarySortOptionNotifier.value;
    _isAscending = widget.settingsViewModel.isLibrarySortAscendingNotifier.value;
    _selectedBookTypes = widget.settingsViewModel.libraryBookTypeFilterNotifier.value;
    _isFavorite = widget.settingsViewModel.libraryFavoriteFilterNotifier.value;
    _libraryBookView = widget.settingsViewModel.libraryBookViewNotifier.value;
    _selectedFinishedYears = widget.settingsViewModel.libraryFinishedYearFilterNotifier.value;
    _selectedTagFilterMode = widget.settingsViewModel.libraryTagFilterModeNotifier.value;
    _isReviewed = widget.settingsViewModel.libraryReviewedFilterNotifier.value;
    _pinnedBookIds = widget.settingsViewModel.pinnedBookIdsNotifier.value.toSet();
    _selectedShelfId = widget.settingsViewModel.libraryShelfFilterNotifier.value;
    _groupSeries = widget.settingsViewModel.libraryGroupSeriesNotifier.value;
    _seriesOnly = widget.settingsViewModel.librarySeriesOnlyNotifier.value;
    _coverFilter = widget.settingsViewModel.libraryCoverFilterNotifier.value;

    _filteredBooks = _sortAndFilterBooks();
    _searchController.addListener(_searchBooks);
  }

  Future<void> _loadShelves() async {
    final shelves = await widget.bookRepository.getShelves();
    if (mounted) {
      setState(() {
        _shelves = shelves;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelectedChip());
    }
  }

  void _scrollToSelectedChip() {
    final ctx = _selectedShelfChipKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          alignment: 0.5, duration: const Duration(milliseconds: 300));
    }
  }

  @override
  void didUpdateWidget(covariant LibraryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.books != oldWidget.books) {
      _searchBooks();
      // Placeholder edits announce themselves as book changes.
      _loadPlaceholders();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _startSelection(int bookId) {
    setState(() {
      _selectionMode = true;
      _selectedBookIds.add(bookId);
    });
  }

  void _toggleSelection(int bookId) {
    setState(() {
      if (_selectedBookIds.contains(bookId)) {
        _selectedBookIds.remove(bookId);
        if (_selectedBookIds.isEmpty) {
          _selectionMode = false;
        }
      } else {
        _selectedBookIds.add(bookId);
      }
    });
  }

  /// Selects every book of a series row, as a long press on a book does.
  void _startGroupSelection(List<Map<String, dynamic>> books) {
    setState(() {
      _selectionMode = true;
      _selectedBookIds.addAll(books.map((b) => b['id'] as int));
    });
  }

  /// Selects a series row's books, or clears them if they all are.
  void _toggleGroupSelection(List<Map<String, dynamic>> books) {
    final ids = books.map((b) => b['id'] as int).toList();
    setState(() {
      if (ids.every(_selectedBookIds.contains)) {
        _selectedBookIds.removeAll(ids);
        if (_selectedBookIds.isEmpty) _selectionMode = false;
      } else {
        _selectedBookIds.addAll(ids);
      }
    });
  }

  Future<void> _openSeries(int seriesId) async {
    // The book opens over the series, so back returns to it.
    await openSeriesPage(
      context: context,
      seriesId: seriesId,
      settingsViewModel: widget.settingsViewModel,
      onOpenBook: _openBookPage,
    );
  }

  /// What the Library shows: books, with a series' books gathered into one
  /// [_SeriesGroup] when grouping is on.
  ///
  /// A series takes the place of its first book in the current sort — except
  /// by title, where its own name decides. A series with a single book on
  /// screen stays a plain book (unless only series are shown), and pinned
  /// books stay on their own at the top.
  List<Object> _libraryItems() {
    if (!_groupSeries) return _filteredBooks;

    bool groupable(Map<String, dynamic> b) =>
        b['series_id'] != null && !_pinnedBookIds.contains(b['id']);

    final groups = <int, List<Map<String, dynamic>>>{};
    for (final b in _filteredBooks.where(groupable)) {
      groups.putIfAbsent(b['series_id'] as int, () => []).add(b);
    }
    final minSize = _seriesOnly ? 1 : 2;

    final items = <Object>[];
    final placed = <int>{};
    for (final b in _filteredBooks) {
      final id = b['series_id'] as int?;
      final group = groupable(b) ? groups[id] : null;
      if (group == null || group.length < minSize) {
        items.add(b);
      } else if (placed.add(id!)) {
        group.sort((a, c) => ((a['series_position'] as num?) ?? 1e9)
            .compareTo((c['series_position'] as num?) ?? 1e9));
        items.add(_SeriesGroup(id, group));
      }
    }

    if (_selectedSortOption != 'Title' || placed.isEmpty) return items;
    String label(Object i) => (i is _SeriesGroup
            ? i.books.first['series_name'] as String? ?? ''
            : (i as Map<String, dynamic>)['title'] as String? ?? '')
        .toLowerCase();
    final pinned = items
        .takeWhile((i) => i is Map && _pinnedBookIds.contains(i['id']))
        .length;
    final rest = items.sublist(pinned)
      ..sort((a, b) => _isAscending
          ? label(a).compareTo(label(b))
          : label(b).compareTo(label(a)));
    return [...items.take(pinned), ...rest];
  }

  bool _seriesExpanded(int seriesId) =>
      _expandedSeries.contains(seriesId) ||
      _selectionMode ||
      (_isSearching && _searchController.text.trim().isNotEmpty);

  void _clearSelection() {
    setState(() {
      _selectionMode = false;
      _selectedBookIds.clear();
    });
  }

  void _togglePin(int bookId) {
    setState(() {
      if (_pinnedBookIds.contains(bookId)) {
        _pinnedBookIds.remove(bookId);
      } else {
        _pinnedBookIds.add(bookId);
      }
      _filteredBooks = _sortAndFilterBooks();
    });
    widget.settingsViewModel.setPinnedBookIds(_pinnedBookIds.toList());
  }

  void _pinSelectedBooks() {
    setState(() {
      for (final id in _selectedBookIds) {
        if (_pinnedBookIds.contains(id)) {
          _pinnedBookIds.remove(id);
        } else {
          _pinnedBookIds.add(id);
        }
      }
      _filteredBooks = _sortAndFilterBooks();
    });
    widget.settingsViewModel.setPinnedBookIds(_pinnedBookIds.toList());
    _clearSelection();
  }

  Future<void> _tagSelectedBooks() async {
    final updatedCount = await showBulkTagSheet(
      context: context,
      selectedBookIds: _selectedBookIds.toList(),
      tagRepository: _tagRepository,
    );

    if (updatedCount == null || updatedCount == 0 || !mounted) return;

    await _refreshTags();

    if (!mounted) return;

    final bookWord = updatedCount == 1 ? 'book' : 'books';
    AppSnackbar.show('Tags updated for $updatedCount $bookWord');

    _clearSelection();
  }

  /// Puts the selection into one series, in the order the books were tapped.
  Future<void> _addSelectedToSeries() async {
    final byId = {for (final b in widget.books) b['id'] as int: b};
    final books = [
      for (final id in _selectedBookIds)
        if (byId[id] != null) byId[id]!,
    ];
    final added = await showBulkSeriesSheet(context: context, books: books);
    if (added == null || added == 0 || !mounted) return;
    AppSnackbar.show('Added $added ${added == 1 ? 'book' : 'books'} to series');
    _clearSelection();
  }

  Future<void> _refreshTags() async {
    await _loadAvailableTags();
    await _loadAllBookTags();
    setState(() {});
  }

  Future<void> _loadAllBookTags() async {
    _bookTagsCache = await _tagRepository.getAllBookTags();
  }

  void _toggleView(String newView) {
    setState(() {
      _libraryBookView = newView;
    });
    widget.settingsViewModel.setLibraryBookView(_libraryBookView);
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _filteredBooks = _sortAndFilterBooks();
      }
    });
  }

  void _searchBooks() {
    setState(() {
      final query = _searchController.text.toLowerCase();
      final baseFiltered = _filter.apply(widget.books, _bookTagsCache);
      _filteredBooks = query.isEmpty
          ? LibraryFilter.sort(
              baseFiltered, _selectedSortOption, _isAscending, _pinnedBookIds)
          : baseFiltered.where((book) {
              final title = (book['title'] as String? ?? '').toLowerCase();
              final author = (book['author'] as String? ?? '').toLowerCase();
              final series =
                  (book['series_name'] as String? ?? '').toLowerCase();
              return title.contains(query) ||
                  author.contains(query) ||
                  series.contains(query);
            }).toList();
    });
  }

  void _navigateToPlannerPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PlannerPage(),
      ),
    );
  }

  void _navigateToAddBookPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookSearchSheet(
          settingsViewModel: widget.settingsViewModel,
          onSave: (book) async {
            widget.refreshBooks();
          },
        ),
      ),
    );
  }

  void _navigateToEditBookPage(Map<String, dynamic>? book) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookFormPage(
          onSave: (updatedBook) async {
            widget.refreshBooks();
          },
          settingsViewModel: widget.settingsViewModel,
          book: book,
        ),
      ),
    );
    await _refreshTags();
  }

  void _navigateToAddSessionPage(Map<String, dynamic> book) async {
    final finishedBook = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => SessionFormPage(
          availableBooks: widget.books,
          book: book,
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
      await afterFinishingBook(
        context: context,
        book: finishedBook,
        bookRepository: widget.bookRepository,
        settingsViewModel: widget.settingsViewModel,
      );
      if (mounted) widget.refreshBooks();
    }
  }

  void _confirmDelete(int bookId) {
    final pageContext = context;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Book'),
        content: const Text('Are you sure you want to delete this book and all its sessions?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () async {
              await widget.bookRepository.deleteBooksBatch([bookId]);
              widget.refreshBooks();
              if (dialogContext.mounted && pageContext.mounted) {
                Navigator.pop(dialogContext);
                Navigator.pop(pageContext);
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _openBookPage(BuildContext context, Map<String, dynamic> book) async {
    openBookDetail(
      context,
      book,
      navigateToEditBookPage: _navigateToEditBookPage,
      navigateToAddSessionPage: _navigateToAddSessionPage,
      confirmDelete: _confirmDelete,
      tagRepository: _tagRepository,
      bookRepository: widget.bookRepository,
      settingsViewModel: widget.settingsViewModel,
      refreshCallback: () {
        widget.refreshBooks();
        _refreshTags();
      },
      isPinned: _pinnedBookIds.contains(book['id']),
      onTogglePin: _togglePin,
      isPinnedFor: (id) => _pinnedBookIds.contains(id),
    );
  }

  LibraryFilter get _filter => LibraryFilter(
        bookTypes: _selectedBookTypes,
        favoritesOnly: _isFavorite,
        reviewedOnly: _isReviewed,
        shelfId: _selectedShelfId,
        seriesOnly: _seriesOnly,
        coverFilter: _coverFilter,
        finishedYears: _selectedFinishedYears,
        tags: _selectedTags,
        tagMode: _selectedTagFilterMode,
      );

  /// The library with the current filters and sort applied.
  List<Map<String, dynamic>> _sortAndFilterBooks() => LibraryFilter.sort(
        _filter.apply(widget.books, _bookTagsCache),
        _selectedSortOption,
        _isAscending,
        _pinnedBookIds,
      );

  List<String> _extractBookTags(Map<String, dynamic> book) =>
      _bookTagsCache[book['id'] as int] ?? [];

  void _showSortFilterModal() {
    final availableYears = LibraryFilter.finishedYearsOf(widget.books);

    final currentOptions = SortFilterOptions(
        sortOption: _selectedSortOption,
        isAscending: _isAscending,
        bookTypes: _selectedBookTypes,
        isFavorite: _isFavorite,
        finishedYears: _selectedFinishedYears,
        tags: _selectedTags,
        tagFilterMode: _selectedTagFilterMode,
        isReviewed: _isReviewed,
        groupSeries: _groupSeries,
        seriesOnly: _seriesOnly,
        coverFilter: _coverFilter);

    SortFilterPopup.show(
        context: context,
        currentOptions: currentOptions,
        onOptionsChange: (newOptions) {
          setState(() {
            _selectedSortOption = newOptions.sortOption;
            _isAscending = newOptions.isAscending;
            _selectedBookTypes = newOptions.bookTypes;
            _isFavorite = newOptions.isFavorite;
            _selectedFinishedYears = newOptions.finishedYears;
            _selectedTags = newOptions.tags;
            _selectedTagFilterMode = newOptions.tagFilterMode;
            _isReviewed = newOptions.isReviewed;
            _groupSeries = newOptions.groupSeries;
            _seriesOnly = newOptions.seriesOnly;
            _coverFilter = newOptions.coverFilter;
          });
          _searchBooks();
          widget.settingsViewModel.setLibrarySortOption(_selectedSortOption);
          widget.settingsViewModel.setLibrarySortAscending(_isAscending);
          widget.settingsViewModel.setLibraryBookTypeFilter(_selectedBookTypes);
          widget.settingsViewModel.setLibraryIsFavorite(_isFavorite);
          widget.settingsViewModel.setLibraryFinishedYearFilter(_selectedFinishedYears);
          widget.settingsViewModel.setLibraryTagFilterMode(_selectedTagFilterMode);
          widget.settingsViewModel.setLibraryReviewed(_isReviewed);
          widget.settingsViewModel.setLibraryGroupSeries(_groupSeries);
          widget.settingsViewModel.setLibrarySeriesOnly(_seriesOnly);
          widget.settingsViewModel.setLibraryCoverFilter(_coverFilter);
        },
        availableYears: availableYears,
        settingsViewModel: widget.settingsViewModel,
        availableTags: _availableTags);
  }

  Future<void> _loadAvailableTags() async {
    try {
      final tags = await _tagRepository.getAllTags();
      setState(() {
        _availableTags = tags.map((tag) => tag.name).toList();
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error loading tags: $e');
      }
    }
  }

  Future<void> _showRandomBook() async {
    if (_filteredBooks.isEmpty) return;

    final picked = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (_) => RandomBookPicker(
        books: _filteredBooks,
        scopeLabel: _randomScopeLabel(),
      ),
    );
    if (picked != null && mounted) {
      _openBookPage(context, picked);
    }
  }

  /// Names the pool the random pick is drawn from (current shelf, or all
  /// books) plus its size, so the picker makes its scope explicit.
  String _randomScopeLabel() {
    final count = _filteredBooks.length;
    final noun = count == 1 ? 'book' : 'books';

    String scope = 'All books';
    if (_selectedShelfId != null) {
      final shelf = _shelves.firstWhere(
        (s) => s['id'] == _selectedShelfId,
        orElse: () => const {},
      );
      final name = shelf['name'] as String?;
      if (name != null && name.isNotEmpty) scope = name;
    }
    return '$scope · $count $noun';
  }

  /// Offers to link books whose titles name a series, after review. The
  /// library reloads itself when the links are written.
  Future<void> _findSeriesInTitles() async {
    if (booksWithSeriesInTitle(widget.books).isEmpty) {
      AppSnackbar.show('No series found in your book titles');
      return;
    }
    final linked = await showSeriesDetectSheet(
      context: context,
      books: widget.books,
    );
    if (linked == null || linked == 0 || !mounted) return;
    AppSnackbar.show('Linked $linked ${linked == 1 ? 'book' : 'books'} to series');
  }

  Future<void> _shareLibraryAsText() async {
    if (_filteredBooks.isEmpty) {
      AppSnackbar.show('No books to share');
      return;
    }

    final count = _filteredBooks.length;
    final bookWord = count == 1 ? 'book' : 'books';

    String header = 'My Reading List';
    if (_selectedShelfId != null) {
      final shelf = _shelves.firstWhere(
        (s) => s['id'] == _selectedShelfId,
        orElse: () => const {},
      );
      final name = shelf['name'] as String?;
      if (name != null && name.isNotEmpty) header = name;
    }

    final bullets = _filteredBooks.map((book) {
      final title = (book['title'] as String? ?? '').trim();
      final author = (book['author'] as String? ?? '').trim();
      return author.isEmpty ? '• $title' : '• $title — $author';
    }).join('\n');

    final text = '$header ($count $bookWord)\n\n$bullets\n\nShared from ReadStats';

    AnalyticsService.instance.shared('library_list');
    await SharePlus.instance.share(ShareParams(text: text));
  }

  Future<void> _deleteSelectedBooks() async {
    final count = _selectedBookIds.length;
    final bookWord = count == 1 ? 'book' : 'books';
    if (!await confirmDeleteBooks(context, count) || !mounted) return;

    await widget.bookRepository.deleteBooksBatch(_selectedBookIds.toList());

    widget.refreshBooks();
    _clearSelection();
    AppSnackbar.show('$count $bookWord deleted');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = widget.settingsViewModel.accentColorNotifier.value;

    return Scaffold(
      appBar: AppBar(
        title: _selectionMode
            ? Text("${_selectedBookIds.length} selected")
            : _isSearching
            ? TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search your library',
            border: InputBorder.none,
            hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
          autofocus: true,
          style: TextStyle(color: theme.colorScheme.onSurface),
        )
            : Text(
                'Library',
                style: theme.textTheme.titleLarge,
              ),
        leading: _selectionMode
            ? IconButton(
          icon: const Icon(Icons.close),
          onPressed: _clearSelection,
        )
            : null,
        backgroundColor: _isSearching
            ? theme.colorScheme.surfaceContainerHighest
            : theme.scaffoldBackgroundColor,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 40,
        actions: _selectionMode
            ? null
            : [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
          ),
          IconButton(
            icon: Badge(
              isLabelVisible: _isFavorite ||
                  _isReviewed ||
                  _coverFilter != 'all' ||
                  _selectedBookTypes.isNotEmpty ||
                  _selectedFinishedYears.isNotEmpty ||
                  _selectedTags.isNotEmpty,
              smallSize: 8,
              backgroundColor: theme.colorScheme.primary,
              child: const Icon(Icons.filter_list),
            ),
            onPressed: _showSortFilterModal,
          ),
          LibraryMenu(
            view: _libraryBookView,
            onSelected: (action) => switch (action) {
              LibraryMenuAction.random => _showRandomBook(),
              LibraryMenuAction.shareText => _shareLibraryAsText(),
              LibraryMenuAction.findSeries => _findSeriesInTitles(),
              LibraryMenuAction.viewRows => _toggleView('rows'),
              LibraryMenuAction.viewGrid => _toggleView('grid'),
            },
          ),
        ],
      ),
      body: widget.books.isEmpty
                    ? const EmptyLibrary()
                    : NotificationListener<ScrollNotification>(
                  onNotification: _onBodyScroll,
                  child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    children: [
                      // Shelf filter chips
                      const SizedBox(height: 4),
                      ShelfChips(
                        shelves: _shelves,
                        selectedShelfId: _selectedShelfId,
                        selectedKey: _selectedShelfChipKey,
                        onSelected: (id) {
                          setState(() => _selectedShelfId = id);
                          _searchBooks();
                          widget.settingsViewModel.setLibraryShelfFilter(_selectedShelfId);
                          WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelectedChip());
                        },
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${_filteredBooks.length}/${widget.books.length}',
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                      if (_selectedShelfId == Shelf.wantToRead) ...[
                        const SizedBox(height: 8),
                        PlannerBanner(onTap: _navigateToPlannerPage),
                        const SizedBox(height: 8),
                      ],
                      // Break out of the body's 8px horizontal padding so the
                      // hairline spans the full screen width like the bottom nav.
                      SizedBox(
                        height: .5,
                        child: OverflowBox(
                          minWidth: MediaQuery.of(context).size.width,
                          maxWidth: MediaQuery.of(context).size.width,
                          child: Divider(
                            height: .5,
                            thickness: .25,
                            color: theme.dividerColor
                                .withAlpha((128 * _filterDividerOpacity).round()),
                          ),
                        ),
                      ),
                      Expanded(
                        child: _filteredBooks.isEmpty
                            ? NoMatchingBooks(
                                searching: _isSearching,
                                shelfEmpty: _selectedShelfId != null &&
                                    !_isSearching &&
                                    !_isFavorite &&
                                    !_isReviewed &&
                                    !_seriesOnly &&
                                    _coverFilter == 'all' &&
                                    _selectedBookTypes.isEmpty &&
                                    _selectedFinishedYears.isEmpty &&
                                    _selectedTags.isEmpty,
                              )
                            : Builder(builder: (context) {
                          final items = _libraryItems();
                          // Each series in full — the strip and counts cover
                          // the whole series, not just what's on screen.
                          final allBySeries =
                              SeriesProgress.bySeries(widget.books);
                          SeriesProgress seriesProgress(int id) =>
                              SeriesProgress.from(
                                  id, allBySeries[id] ?? const [],
                                  placeholders: _placeholders[id] ?? const []);
                          return Scrollbar(
                          child: _libraryBookView == "grid"
                              ? GridView.builder(
                            // Tiles have no margin, so the cell is exactly
                            // the 2:3 cover shape and covers aren't cropped.
                            padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              childAspectRatio: 2 / 3,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final item = items[index];
                              if (item is _SeriesGroup) {
                                return SeriesGridTile(
                                  progress: seriesProgress(item.seriesId),
                                  books: item.books,
                                  selected: item.books.every(
                                      (b) => _selectedBookIds.contains(b['id'])),
                                  selectionColor: theme.colorScheme.primary,
                                  onTap: () => _selectionMode
                                      ? _toggleGroupSelection(item.books)
                                      : _openSeries(item.seriesId),
                                  onLongPress: () =>
                                      _startGroupSelection(item.books),
                                );
                              }
                              final book = item as Map<String, dynamic>;
                              return GestureDetector(
                                onLongPress: () => _startSelection(book['id']),
                                child: BookGridItem(
                                  book: book,
                                  onTap: () {
                                    if (_selectionMode) {
                                      _toggleSelection(book['id']);
                                    } else {
                                      _openBookPage(context, book);
                                    }
                                  },
                                  isPinned: _pinnedBookIds.contains(book['id']),
                                  isSelected: _selectedBookIds.contains(book['id']),
                                  selectionMode: _selectionMode,
                                  selectionColor: theme.colorScheme.primary,
                                ),
                              );
                            },
                          )
                              : ListView.builder(
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final item = items[index];
                              if (item is _SeriesGroup) {
                                final id = item.seriesId;
                                return SeriesRow(
                                  key: ValueKey('series-$id'),
                                  progress: seriesProgress(id),
                                  books: item.books,
                                  expanded: _seriesExpanded(id),
                                  onToggle: () => setState(() {
                                    if (!_expandedSeries.remove(id)) {
                                      _expandedSeries.add(id);
                                    }
                                  }),
                                  onOpen: () => _selectionMode
                                      ? _toggleGroupSelection(item.books)
                                      : _openSeries(id),
                                  onLongPress: () =>
                                      _startGroupSelection(item.books),
                                  onBookTap: (b) => _selectionMode
                                      ? _toggleSelection(b['id'] as int)
                                      : _openBookPage(context, b),
                                  onBookLongPress: (b) =>
                                      _startSelection(b['id'] as int),
                                  isSelected: _selectedBookIds.contains,
                                  selectionColor: theme.colorScheme.primary,
                                  showStars: widget.settingsViewModel
                                          .defaultRatingStyleNotifier.value ==
                                      0,
                                );
                              }
                              final book = item as Map<String, dynamic>;
                              final isSelected = _selectedBookIds.contains(book['id']);
                              return GestureDetector(
                                onLongPress: () => _startSelection(book['id']),
                                child: BookRow(
                                  book: book,
                                  showStars: widget.settingsViewModel
                                      .defaultRatingStyleNotifier.value ==
                                      0,
                                  tags: _extractBookTags(book),
                                  isSelected: isSelected,
                                  selectionColor: theme.colorScheme.primary,
                                  isPinned: _pinnedBookIds.contains(book['id']),
                                  onTap: () {
                                    if (_selectionMode) {
                                      _toggleSelection(book['id']);
                                    } else {
                                      _openBookPage(context, book);
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                        );
                        }),
                      ),
                    ],
                  ),
                ),
                ),
      floatingActionButton: _selectionMode

          ? SelectionActions(
              accentColor: accentColor,
              onDelete: _deleteSelectedBooks,
              onPin: _pinSelectedBooks,
              onAddToSeries: _addSelectedToSeries,
              onTag: _tagSelectedBooks,
            )
          : FloatingActionButton(
        heroTag: 'add',
        backgroundColor: accentColor,
        onPressed: _navigateToAddBookPage,
        child: Icon(
          Icons.add,
          color: Theme.of(context).colorScheme.onPrimary,
        ),
      ),
    );
  }
}
/// A series' books as one Library entry — those that passed the filters, in
/// series order.
class _SeriesGroup {
  final int seriesId;
  final List<Map<String, dynamic>> books;

  const _SeriesGroup(this.seriesId, this.books);
}
