import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:read_stats/ui/pages/library/widgets/book_grid.dart';
import '../../../data/repositories/tag_repository.dart';
import 'widgets/bulk_tag_sheet.dart';
import 'widgets/book_detail_sheet.dart';
import 'widgets/book_row.dart';
import 'widgets/filter_sort_sheet.dart';
import 'book_form_page.dart';
import '../sessions/session_form_page.dart';
import '/data/database/database_helper.dart';
import '/viewmodels/SettingsViewModel.dart';
import '/data/repositories/session_repository.dart';
import '/data/repositories/book_repository.dart';
import '../planner/planner_page.dart';

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
  final DatabaseHelper _dbHelper = DatabaseHelper();
  String _libraryBookView = 'row_expanded';
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
  late TagRepository _tagRepository;
  List<String> _availableTags = [];
  Map<int, List<String>> _bookTagsCache = {};
  bool _selectionMode = false;
  final Set<int> _selectedBookIds = {};
  Set<int> _pinnedBookIds = {};
  final GlobalKey _selectedShelfChipKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tagRepository = TagRepository(DatabaseHelper());
    _loadAvailableTags();
    _loadAllBookTags();
    _loadShelves();

    _selectedSortOption = widget.settingsViewModel.librarySortOptionNotifier.value;
    _isAscending = widget.settingsViewModel.isLibrarySortAscendingNotifier.value;
    _selectedBookTypes = widget.settingsViewModel.libraryBookTypeFilterNotifier.value;
    _isFavorite = widget.settingsViewModel.libraryFavoriteFilterNotifier.value;
    _libraryBookView = widget.settingsViewModel.libraryBookViewNotifier.value;
    _selectedFinishedYears = widget.settingsViewModel.libraryFinishedYearFilterNotifier.value;
    _selectedTagFilterMode = widget.settingsViewModel.libraryTagFilterModeNotifier.value;
    _pinnedBookIds = widget.settingsViewModel.pinnedBookIdsNotifier.value.toSet();
    _selectedShelfId = widget.settingsViewModel.libraryShelfFilterNotifier.value;

    _filteredBooks = _sortAndFilterBooks(
      List<Map<String, dynamic>>.from(widget.books),
      _selectedSortOption,
      _isAscending,
      _selectedBookTypes,
      _isFavorite,
      _selectedShelfId,
      _selectedFinishedYears,
      _selectedTags,
      _selectedTagFilterMode,
    );
    _searchController.addListener(_searchBooks);
  }

  Future<void> _loadShelves() async {
    final shelves = await DatabaseHelper().getShelves();
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
      setState(() {
        _filteredBooks = _sortAndFilterBooks(
            List<Map<String, dynamic>>.from(widget.books),
            _selectedSortOption,
            _isAscending,
            _selectedBookTypes,
            _isFavorite,
            _selectedShelfId,
            _selectedFinishedYears,
            _selectedTags,
            _selectedTagFilterMode);
      });
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

  void _clearSelection() {
    setState(() {
      _selectionMode = false;
      _selectedBookIds.clear();
    });
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
      _filteredBooks = _sortAndFilterBooks(
          List<Map<String, dynamic>>.from(widget.books),
          _selectedSortOption,
          _isAscending,
          _selectedBookTypes,
          _isFavorite,
          _selectedShelfId,
          _selectedFinishedYears,
          _selectedTags,
          _selectedTagFilterMode);
    });
    widget.settingsViewModel.setPinnedBookIds(_pinnedBookIds.toList());
    _clearSelection();
  }

  Future<void> _tagSelectedBooks() async {
    final updatedCount = await showBulkTagSheet(
      context: context,
      selectedBookIds: _selectedBookIds.toList(),
      tagRepository: TagRepository(DatabaseHelper()),
    );

    if (updatedCount == null || updatedCount == 0 || !mounted) return;

    await _refreshTags();

    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final bookWord = updatedCount == 1 ? 'book' : 'books';

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Tags updated for $updatedCount $bookWord'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          duration: const Duration(seconds: 2),
        ),
      );

    _clearSelection();
  }

  Future<void> _moveSelectedBooksToShelf() async {
    final shelf = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text('Move to shelf', style: theme.textTheme.titleMedium),
              ),
              const Divider(height: 1),
              ..._shelves.map((shelf) => ListTile(
                    leading: const Icon(Icons.bookmarks_outlined),
                    title: Text(shelf['name'] as String),
                    onTap: () => Navigator.pop(ctx, shelf),
                  )),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (shelf == null || !mounted) return;

    final shelfId = shelf['id'] as int;
    final bookRepository = BookRepository(DatabaseHelper());
    for (final id in _selectedBookIds) {
      await bookRepository.updateBookShelf(id, shelfId);
    }

    final count = _selectedBookIds.length;
    widget.refreshBooks();
    _clearSelection();

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('${count == 1 ? '1 book' : '$count books'} moved to ${shelf['name']}'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        duration: const Duration(seconds: 2),
      ));
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
        _filteredBooks = _sortAndFilterBooks(
            List<Map<String, dynamic>>.from(widget.books),
            _selectedSortOption,
            _isAscending,
            _selectedBookTypes,
            _isFavorite,
            _selectedShelfId,
            _selectedFinishedYears,
            _selectedTags,
            _selectedTagFilterMode);
      }
    });
  }

  void _searchBooks() {
    setState(() {
      final query = _searchController.text.toLowerCase();
      final baseFiltered = _filterBooks(
        List<Map<String, dynamic>>.from(widget.books),
        _selectedBookTypes,
        _isFavorite,
        _selectedShelfId,
        _selectedFinishedYears,
        _selectedTags,
        _selectedTagFilterMode,
      );
      _filteredBooks = query.isEmpty
          ? _sortBooks(baseFiltered, _selectedSortOption, _isAscending)
          : baseFiltered.where((book) {
              final title = (book['title'] as String? ?? '').toLowerCase();
              final author = (book['author'] as String? ?? '').toLowerCase();
              return title.contains(query) || author.contains(query);
            }).toList();
    });
  }

  void _navigateToPlannerPage() {
    final wantToReadBooks = widget.books
        .where((b) => b['shelf_id'] == DatabaseHelper.shelfWantToRead)
        .toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlannerPage(wantToReadBooks: wantToReadBooks),
      ),
    );
  }

  void _navigateToAddBookPage() async {    await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => BookFormPage(
        onSave: (book) async {
          widget.refreshBooks();
        },
        settingsViewModel: widget.settingsViewModel,
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
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SessionFormPage(
          availableBooks: widget.books.where((book) => book['is_completed'] == 0).toList(),
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
              await _dbHelper.deleteBook(bookId);
              widget.refreshBooks();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showBookPopup(BuildContext context, Map<String, dynamic> book) async {
    BookPopup.showBookPopup(
      context,
      book,
      widget.settingsViewModel.defaultRatingStyleNotifier.value,
      widget.settingsViewModel.defaultDateFormatNotifier.value,
      _navigateToEditBookPage,
      _navigateToAddSessionPage,
      _confirmDelete,
      TagRepository(DatabaseHelper()),
      BookRepository(DatabaseHelper()),
      widget.settingsViewModel,
      refreshCallback: () {
        widget.refreshBooks();
      },
    );
  }

  List<Map<String, dynamic>> _sortAndFilterBooks(
      List<Map<String, dynamic>> books,
      String selectedSortOption,
      bool isAscending,
      List<String> selectedBookTypes,
      bool isFavorite,
      int? selectedShelfId,
      List<String> finishedYears,
      List<String> tags,
      String tagFilterMode) {
    List<Map<String, dynamic>> filteredBooks =
    _filterBooks(books, selectedBookTypes, isFavorite, selectedShelfId, finishedYears, tags, tagFilterMode);

    widget.settingsViewModel.setLibrarySortOption(selectedSortOption);
    widget.settingsViewModel.setLibrarySortAscending(isAscending);
    widget.settingsViewModel.setLibraryBookTypeFilter(selectedBookTypes);
    widget.settingsViewModel.setLibraryIsFavorite(isFavorite);
    widget.settingsViewModel.setLibraryFinishedYearFilter(finishedYears);
    widget.settingsViewModel.setLibraryTagFilterMode(tagFilterMode);

    return _sortBooks(filteredBooks, selectedSortOption, isAscending);
  }

  List<Map<String, dynamic>> _filterBooks(
      List<Map<String, dynamic>> books,
      List<String> selectedBookTypes,
      bool isFavorite,
      int? selectedShelfId,
      List<String> finishedYears,
      List<String> selectedTags,
      String tagFilterMode,
      ) {
    final selectedTypeIds = selectedBookTypes
        .map((type) {
      return bookTypeNames.entries
          .firstWhere(
            (entry) => entry.value == type,
        orElse: () => const MapEntry(-1, ''),
      )
          .key;
    })
        .where((id) => id != -1)
        .toList();

    return books.where((book) {
      final typeMatch = selectedTypeIds.isEmpty ||
          (book['book_type_id'] != null && selectedTypeIds.contains(book['book_type_id']));

      final favoriteMatch =
          !isFavorite || (book['is_favorite'] != null && book['is_favorite'] == 1);

      final shelfMatch = selectedShelfId == null ||
          (book['shelf_id'] as int?) == selectedShelfId;

      bool yearMatch = finishedYears.isEmpty;
      if (!yearMatch && book['date_finished'] != null) {
        try {
          final date = DateTime.parse(book['date_finished'].toString());
          yearMatch = finishedYears.contains(date.year.toString());
        } catch (_) {
          yearMatch = false;
        }
      }

      bool tagMatch = selectedTags.isEmpty;
      if (!tagMatch) {
        final bookTags = _extractBookTags(book);

        switch (tagFilterMode) {
          case 'any':
            tagMatch = selectedTags.any((tag) => bookTags.contains(tag));
            break;
          case 'all':
            tagMatch = selectedTags.every((tag) => bookTags.contains(tag));
            break;
          case 'exclude':
            tagMatch = !selectedTags.any((tag) => bookTags.contains(tag));
            break;
          default:
            tagMatch = selectedTags.any((tag) => bookTags.contains(tag));
        }
      }

      return typeMatch && favoriteMatch && shelfMatch && yearMatch && tagMatch;
    }).toList();
  }

  List<String> _extractBookTags(Map<String, dynamic> book) {
    final bookId = book['id'] as int;
    return _bookTagsCache[bookId] ?? [];
  }

  static const Map<int, String> bookTypeNames = {
    1: "Paperback",
    2: "Hardback",
    3: "eBook",
    4: "Audiobook",
  };

  List<Map<String, dynamic>> _sortBooks(
      List<Map<String, dynamic>> books,
      String selectedSortOption,
      bool isAscending,
      ) {
    books = List.from(books);

    final pinned = books.where((b) => _pinnedBookIds.contains(b['id'])).toList();
    final unpinned = books.where((b) => !_pinnedBookIds.contains(b['id'])).toList();

    unpinned.sort((a, b) {
      int comparison = 0;

      if (selectedSortOption == 'Title') {
        comparison = (a['title'] ?? '').compareTo(b['title'] ?? '');
      } else if (selectedSortOption == 'Author') {
        comparison = (a['author'] ?? '').compareTo(b['author'] ?? '');
      } else if (selectedSortOption == 'Rating') {
        double ratingA = (a['rating'] ?? 0.0).toDouble();
        double ratingB = (b['rating'] ?? 0.0).toDouble();
        comparison = ratingA.compareTo(ratingB);
      } else if (selectedSortOption == 'Pages') {
        int pagesA = (a['page_count'] ?? 0).toInt();
        int pagesB = (b['page_count'] ?? 0).toInt();
        comparison = pagesA.compareTo(pagesB);
      } else if (selectedSortOption == 'Date started') {
        DateTime dateStartedA = a['date_started'] != null
            ? DateTime.tryParse(a['date_started']) ?? DateTime(0)
            : DateTime(0);
        DateTime dateStartedB = b['date_started'] != null
            ? DateTime.tryParse(b['date_started']) ?? DateTime(0)
            : DateTime(0);
        comparison = dateStartedA.compareTo(dateStartedB);
      } else if (selectedSortOption == 'Date finished') {
        DateTime dateFinishedA = a['date_finished'] != null
            ? DateTime.tryParse(a['date_finished']) ?? DateTime(0)
            : DateTime(0);
        DateTime dateFinishedB = b['date_finished'] != null
            ? DateTime.tryParse(b['date_finished']) ?? DateTime(0)
            : DateTime(0);
        comparison = dateFinishedA.compareTo(dateFinishedB);
      } else if (selectedSortOption == 'Date added') {
        DateTime dateAddedA = a['date_added'] != null
            ? DateTime.tryParse(a['date_added']) ?? DateTime(0)
            : DateTime(0);
        DateTime dateAddedB = b['date_added'] != null
            ? DateTime.tryParse(b['date_added']) ?? DateTime(0)
            : DateTime(0);
        comparison = dateAddedA.compareTo(dateAddedB);
      }

      return isAscending ? comparison : -comparison;
    });

    return [...pinned, ...unpinned];
  }

  void _showSortFilterModal() {
    final availableYears = _getAvailableYears(widget.books);

    final currentOptions = SortFilterOptions(
        sortOption: _selectedSortOption,
        isAscending: _isAscending,
        bookTypes: _selectedBookTypes,
        isFavorite: _isFavorite,
        finishedYears: _selectedFinishedYears,
        tags: _selectedTags,
        tagFilterMode: _selectedTagFilterMode);

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

            _filteredBooks = _sortAndFilterBooks(
                List<Map<String, dynamic>>.from(widget.books),
                _selectedSortOption,
                _isAscending,
                _selectedBookTypes,
                _isFavorite,
                _selectedShelfId,
                _selectedFinishedYears,
                _selectedTags,
                _selectedTagFilterMode);
          });
        },
        availableYears: availableYears,
        settingsViewModel: widget.settingsViewModel,
        availableTags: _availableTags);
  }

  List<String> _getAvailableYears(List<Map<String, dynamic>> books) {
    final years = <String>{};
    for (final book in books) {
      final dateFinished = book['date_finished'];
      if (dateFinished != null) {
        try {
          final date = DateTime.parse(dateFinished);
          years.add(date.year.toString());
        } catch (e) {
          if (kDebugMode) {
            print('Error getting available years: $e');
          }
        }
      }
    }
    return years.toList()..sort((a, b) => b.compareTo(a));
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

  void _showRandomBook() {
    if (_filteredBooks.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('No books available to choose from'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: EdgeInsets.only(
              left: 20,
              right: 20,
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      return;
    }

    final randomBook = (_filteredBooks.toList()..shuffle()).first;
    _showBookPopup(context, randomBook);
  }

  Future<void> _deleteSelectedBooks() async {
    final count = _selectedBookIds.length;
    final bookWord = count == 1 ? 'book' : 'books';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $count $bookWord?'),
        content: const Text('This will also delete all sessions for these books. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(ctx).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final bookRepository = BookRepository(DatabaseHelper());
    await bookRepository.deleteBooksBatch(_selectedBookIds.toList());

    widget.refreshBooks();
    _clearSelection();

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$count $bookWord deleted'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          duration: const Duration(seconds: 2),
        ),
      );
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
            : const Text('Library'),
        leading: _selectionMode
            ? IconButton(
          icon: const Icon(Icons.close),
          onPressed: _clearSelection,
        )
            : null,
        backgroundColor: _isSearching
            ? theme.colorScheme.surfaceContainerHighest
            : theme.scaffoldBackgroundColor,
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
                  _selectedBookTypes.isNotEmpty ||
                  _selectedFinishedYears.isNotEmpty ||
                  _selectedTags.isNotEmpty,
              smallSize: 8,
              backgroundColor: theme.colorScheme.primary,
              child: const Icon(Icons.filter_list),
            ),
            onPressed: _showSortFilterModal,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'random') {
                _showRandomBook();
              } else if (value == 'view_row_expanded' ||
                  value == 'view_row_compact' ||
                  value == 'view_grid') {
                _toggleView(value.replaceFirst('view_', ''));
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'random',
                child: Text('Random Book'),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'view_row_expanded',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.density_medium, size: 20),
                  title: const Text('Expanded rows'),
                  trailing: _libraryBookView == 'row_expanded'
                      ? Icon(Icons.check, size: 18, color: theme.colorScheme.primary)
                      : null,
                ),
              ),
              PopupMenuItem<String>(
                value: 'view_row_compact',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.density_small, size: 20),
                  title: const Text('Compact rows'),
                  trailing: _libraryBookView == 'row_compact'
                      ? Icon(Icons.check, size: 18, color: theme.colorScheme.primary)
                      : null,
                ),
              ),
              PopupMenuItem<String>(
                value: 'view_grid',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.grid_view, size: 20),
                  title: const Text('Grid'),
                  trailing: _libraryBookView == 'grid'
                      ? Icon(Icons.check, size: 18, color: theme.colorScheme.primary)
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: widget.books.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset('assets/images/carl.png', width: 100, height: 100),
                      const SizedBox(height: 16),
                      Text(
                        'Carl is hungry, add a book to your library',
                        style: theme.textTheme.bodyLarge,
                      ),
                    ],
                  ),
                )
                    : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    children: [
                      // Shelf filter chips
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 32,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            // One chip per shelf, built from the DB
                            ..._shelves.map((shelf) {
                              final id = shelf['id'] as int;
                              final name = shelf['name'] as String;
                              final isSelected = _selectedShelfId == id;
                              return Padding(
                                key: isSelected ? _selectedShelfChipKey : null,
                                padding: const EdgeInsets.only(right: 6),
                                child: FilterChip(
                                  label: Text(name),
                                  selected: isSelected,
                                  onSelected: (_) {
                                    setState(() {
                                      _selectedShelfId = isSelected ? null : id;
                                      _filteredBooks = _sortAndFilterBooks(
                                        List<Map<String, dynamic>>.from(widget.books),
                                        _selectedSortOption,
                                        _isAscending,
                                        _selectedBookTypes,
                                        _isFavorite,
                                        _selectedShelfId,
                                        _selectedFinishedYears,
                                        _selectedTags,
                                        _selectedTagFilterMode,
                                      );
                                    });
                                    widget.settingsViewModel.setLibraryShelfFilter(_selectedShelfId);
                                    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelectedChip());
                                  },
                                  showCheckmark: false,
                                  labelStyle: theme.textTheme.bodySmall,
                                  labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                  selectedColor: theme.colorScheme.primaryContainer,
                                  elevation: 0,
                                  pressElevation: 0,
                                  side: BorderSide.none,
                                shape: const StadiumBorder(),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${_filteredBooks.length}/${widget.books.length}',
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                      if (_selectedShelfId == DatabaseHelper.shelfWantToRead) ...[
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: _navigateToPlannerPage,
                          borderRadius: BorderRadius.circular(12),
                          child: Ink(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.menu_book_rounded,
                                    color: theme.colorScheme.onSecondaryContainer,
                                    size: 28,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Reading Planner',
                                          style: theme.textTheme.titleMedium?.copyWith(
                                            color: theme.colorScheme.onSecondaryContainer,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          'Plan and prioritize your reading order',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: theme.colorScheme.onSecondaryContainer,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    color: theme.colorScheme.onSecondaryContainer,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Expanded(
                        child: _filteredBooks.isEmpty
                            ? Center(
                                child: Builder(builder: (context) {
                                  final bool isShelfEmpty = _selectedShelfId != null &&
                                      !_isSearching &&
                                      !_isFavorite &&
                                      _selectedBookTypes.isEmpty &&
                                      _selectedFinishedYears.isEmpty &&
                                      _selectedTags.isEmpty;
                                  final IconData emptyIcon = _isSearching
                                      ? Icons.search_off_rounded
                                      : isShelfEmpty
                                          ? Icons.library_books_outlined
                                          : Icons.filter_list_off_rounded;
                                  final String emptyMessage = _isSearching
                                      ? 'No books match your search.'
                                      : isShelfEmpty
                                          ? 'No books on this shelf yet.'
                                          : 'No books match the active filters.';
                                  return Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        emptyIcon,
                                        size: 48,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        emptyMessage,
                                        style: theme.textTheme.bodyLarge?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  );
                                }),
                              )
                            : Scrollbar(
                          child: _libraryBookView == "grid"
                              ? GridView.builder(
                            padding: const EdgeInsets.only(top: 0),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              childAspectRatio: 0.58,
                              crossAxisSpacing: 0,
                              mainAxisSpacing: 0,
                            ),
                            itemCount: _filteredBooks.length,
                            itemBuilder: (context, index) {
                              final book = _filteredBooks[index];
                              return GestureDetector(
                                onLongPress: () => _startSelection(book['id']),
                                onTap: () {
                                  if (_selectionMode) {
                                    _toggleSelection(book['id']);
                                  } else {
                                    _showBookPopup(context, book);
                                  }
                                },
                                child: BookGridItem(
                                  book: book,
                                  onTap: () {
                                    if (_selectionMode) {
                                      _toggleSelection(book['id']);
                                    } else {
                                      _showBookPopup(context, book);
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
                            itemCount: _filteredBooks.length,
                            itemBuilder: (context, index) {
                              final book = _filteredBooks[index];
                              final isSelected = _selectedBookIds.contains(book['id']);
                              return GestureDetector(
                                onLongPress: () => _startSelection(book['id']),
                                onTap: () {
                                  if (_selectionMode) {
                                    _toggleSelection(book['id']);
                                  } else {
                                    _showBookPopup(context, book);
                                  }
                                },
                                child: BookRow(
                                  book: book,
                                  textColor: theme.colorScheme.onSurface,
                                  isCompactView: _libraryBookView == "row_compact",
                                  showStars: widget.settingsViewModel
                                      .defaultRatingStyleNotifier.value ==
                                      0,
                                  dateFormatString: widget
                                      .settingsViewModel.defaultDateFormatNotifier.value,
                                  isSelected: isSelected,
                                  selectionColor: theme.colorScheme.primary,
                                  isPinned: _pinnedBookIds.contains(book['id']),
                                  onTap: () {
                                    if (_selectionMode) {
                                      _toggleSelection(book['id']);
                                    } else {
                                      _showBookPopup(context, book);
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: _selectionMode

          ? Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'delete',
            backgroundColor: Theme.of(context).colorScheme.error,
            onPressed: _deleteSelectedBooks,
            child: Icon(
              Icons.delete,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'pin',
            backgroundColor: accentColor,
            onPressed: _pinSelectedBooks,
            child: Icon(
              Icons.push_pin,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'tag',
            backgroundColor: accentColor,
            onPressed: _tagSelectedBooks,
            child: Icon(
              Icons.sell,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ],
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