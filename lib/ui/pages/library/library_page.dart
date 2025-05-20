import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../data/repositories/tag_repository.dart';
import 'widgets/book_card.dart';
import 'widgets/book_row.dart';
import 'widgets/filter_sort_modal.dart';
import 'book_form_page.dart';
import '../sessions/add_session_page.dart';
import '/data/database/database_helper.dart';
import '/viewmodels/SettingsViewModel.dart';
import '/data/repositories/session_repository.dart';
import '/data/repositories/book_repository.dart';

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
  List<String> _selectedFinishedYears = [];
  List<String> _selectedBookTypes = [];
  List<String> _selectedTags = [];
  late TagRepository _tagRepository;
  List<String> _availableTags = [];
  Map<int, List<String>> _bookTagsCache = {};

  @override
  void initState() {
    super.initState();
    _tagRepository = TagRepository(DatabaseHelper());
    _loadAvailableTags();
    _loadAllBookTags();

    _selectedSortOption = widget.settingsViewModel.librarySortOptionNotifier.value;
    _isAscending = widget.settingsViewModel.isLibrarySortAscendingNotifier.value;
    _selectedBookTypes = widget.settingsViewModel.libraryBookTypeFilterNotifier.value;
    _isFavorite = widget.settingsViewModel.libraryFavoriteFilterNotifier.value;
    _libraryBookView = widget.settingsViewModel.libraryBookViewNotifier.value;
    _selectedFinishedYears = widget.settingsViewModel.libraryFinishedYearFilterNotifier.value;

    _filteredBooks = _sortAndFilterBooks(
        List<Map<String, dynamic>>.from(widget.books),
        _selectedSortOption,
        _isAscending,
        _selectedBookTypes,
        _isFavorite,
        _selectedFinishedYears,
        _selectedTags
    );
    _searchController.addListener(_searchBooks);
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
            _selectedFinishedYears,
            _selectedTags
        );
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
          _selectedFinishedYears,
          _selectedTags,
        );
      }
    });
  }

  void _searchBooks() {
    setState(() {
      String query = _searchController.text.toLowerCase();
      _filteredBooks = widget.books.where((book) {
        String title = book['title'].toLowerCase();
        String author = book['author'].toLowerCase();
        return title.contains(query) || author.contains(query);
      }).toList();
    });
  }

  void _navigateToAddBookPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookFormPage(
          onSave: (book) async {
            await _dbHelper.insertBook(book);
            widget.refreshBooks();
          },
          settingsViewModel: widget.settingsViewModel,
        ),
      ),
    );
  }

  void _navigateToEditBookPage(Map<String, dynamic> book) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookFormPage(
          onSave: (updatedBook) async {
            await _dbHelper.updateBook(updatedBook);
            widget.refreshBooks();
          },
          settingsViewModel: widget.settingsViewModel,
          book: book,
        ),
      ),
    );
    await _refreshTags();
  }

  void _navigateToAddSessionPage(int? bookId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LogSessionPage(
          books: widget.books,
          initialBookId: bookId,
          refreshSessions: () {
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
              Navigator.pop(context);
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
        TagRepository(DatabaseHelper())
    );
  }

  List<Map<String, dynamic>> _sortAndFilterBooks(
      List<Map<String, dynamic>> books,
      String selectedSortOption,
      bool isAscending,
      List<String> selectedBookTypes,
      bool isFavorite,
      List<String> finishedYears,
      List<String> tags,
      ) {
    List<Map<String, dynamic>> filteredBooks = _filterBooks(
        books,
        selectedBookTypes,
        isFavorite,
        finishedYears,
        tags
    );

    widget.settingsViewModel.setLibrarySortOption(selectedSortOption);
    widget.settingsViewModel.setLibrarySortAscending(isAscending);
    widget.settingsViewModel.setLibraryBookTypeFilter(selectedBookTypes);
    widget.settingsViewModel.setLibraryIsFavorite(isFavorite);
    widget.settingsViewModel.setLibraryFinishedYearFilter(finishedYears);

    return _sortBooks(filteredBooks, selectedSortOption, isAscending);
  }

  List<Map<String, dynamic>> _filterBooks(
      List<Map<String, dynamic>> books,
      List<String> selectedBookTypes,
      bool isFavorite,
      List<String> finishedYears,
      List<String> selectedTags,
      ) {
    final selectedTypeIds = selectedBookTypes.map((type) {
      return bookTypeNames.entries
          .firstWhere(
            (entry) => entry.value == type,
        orElse: () => const MapEntry(-1, ''),
      )
          .key;
    }).where((id) => id != -1).toList();

    return books.where((book) {
      final typeMatch = selectedTypeIds.isEmpty ||
          (book['book_type_id'] != null && selectedTypeIds.contains(book['book_type_id']));

      final favoriteMatch = !isFavorite ||
          (book['is_favorite'] != null && book['is_favorite'] == 1);

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
        tagMatch = selectedTags.any((tag) => bookTags.contains(tag));
      }

      return typeMatch && favoriteMatch && yearMatch && tagMatch;
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
    books.sort((a, b) {
      int comparison = 0;

      if (selectedSortOption == 'Title') {
        comparison = a['title'].compareTo(b['title']);
      } else if (selectedSortOption == 'Author') {
        comparison = a['author'].compareTo(b['author']);
      } else if (selectedSortOption == 'Rating') {
        comparison = (a['rating'] as double).compareTo(b['rating'] as double);
      } else if (selectedSortOption == 'Pages') {
        comparison = (a['page_count'] as int).compareTo(b['page_count'] as int);
      } else if (selectedSortOption == 'Date started') {
        DateTime dateStartedA = a['date_started'] != null
            ? DateTime.parse(a['date_started'])
            : DateTime(0);
        DateTime dateStartedB = b['date_started'] != null
            ? DateTime.parse(b['date_started'])
            : DateTime(0);
        comparison = dateStartedA.compareTo(dateStartedB);
      } else if (selectedSortOption == 'Date finished') {
        DateTime dateFinishedA = a['date_finished'] != null
            ? DateTime.parse(a['date_finished'])
            : DateTime(0);
        DateTime dateFinishedB = b['date_finished'] != null
            ? DateTime.parse(b['date_finished'])
            : DateTime(0);
        comparison = dateFinishedA.compareTo(dateFinishedB);
      } else if (selectedSortOption == 'Date added') {
        DateTime dateAddedA = a['date_added'] != null
            ? DateTime.parse(a['date_added'])
            : DateTime(0);
        DateTime dateAddedB = b['date_added'] != null
            ? DateTime.parse(b['date_added'])
            : DateTime(0);
        comparison = dateAddedA.compareTo(dateAddedB);
      }

      return isAscending ? comparison : -comparison;
    });
    return books;
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
    );

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

            _filteredBooks = _sortAndFilterBooks(
                List<Map<String, dynamic>>.from(widget.books),
                _selectedSortOption,
                _isAscending,
                _selectedBookTypes,
                _isFavorite,
                _selectedFinishedYears,
                _selectedTags
            );
          });
        },
        availableYears: availableYears,
        settingsViewModel: widget.settingsViewModel,
        availableTags: _availableTags
    );
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
          if (kDebugMode)
            {
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
      ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = widget.settingsViewModel.accentColorNotifier.value;

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Search books...',
            border: InputBorder.none,
          ),
          autofocus: true,
          style: TextStyle(color: theme.colorScheme.onSurface),
        )
            : const Text('Library'),
        backgroundColor: theme.scaffoldBackgroundColor,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showSortFilterModal,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'random') {
                _showRandomBook();
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'random',
                child: Text('Random Book'),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          if (widget.books.isEmpty)
            Center(
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
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SizedBox(
                        height: 40,
                        child: ToggleButtons(
                          isSelected: [
                            _libraryBookView == "row_expanded",
                            _libraryBookView == "row_compact",
                          ],
                          onPressed: (index) {
                            _toggleView(index == 0 ? "row_expanded" : "row_compact");
                          },
                          constraints: const BoxConstraints(
                            minHeight: 30, // Match the SizedBox height
                            minWidth: 40, // Make buttons square
                          ),
                          borderWidth: 1,
                          borderColor: theme.colorScheme.outline,
                          selectedBorderColor: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(8),
                          children: const [
                            Icon(Icons.density_medium, size: 16),
                            Icon(Icons.density_small, size: 16),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          '${_filteredBooks.length}/${widget.books.length}',
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: Scrollbar(
                      child: ListView.builder(
                        itemCount: _filteredBooks.length,
                        itemBuilder: (context, index) {
                          final book = _filteredBooks[index];
                          return BookRow(
                            book: book,
                            textColor: theme.colorScheme.onSurface,
                            isCompactView: _libraryBookView == "row_compact",
                            showStars: widget.settingsViewModel.defaultRatingStyleNotifier.value == 0,
                            dateFormatString: widget.settingsViewModel.defaultDateFormatNotifier.value,
                            onTap: () => _showBookPopup(context, book),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: accentColor,
        onPressed: _navigateToAddBookPage,
        child: Icon(Icons.add, color: Theme.of(context).colorScheme.onPrimary),
      ),
    );
  }
}