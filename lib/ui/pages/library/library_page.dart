import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'widgets/book_card.dart';
import 'widgets/book_row.dart';
import 'widgets/filter_sort_modal.dart';  // This imports SortFilterOptions
import 'package:intl/intl.dart';
import '../add_book_page.dart';
import '../edit_book_page.dart';
import '../add_session_page.dart';
import '/data/database/database_helper.dart';
import '/viewmodels/SettingsViewModel.dart';
import '/data/repositories/session_repository.dart';

class LibraryPage extends StatefulWidget {
  final List<Map<String, dynamic>> books;
  final Function() refreshBooks;
  final Function() refreshSessions;
  final SettingsViewModel settingsViewModel;
  final SessionRepository sessionRepository;

  const LibraryPage({
    super.key,
    required this.books,
    required this.refreshBooks,
    required this.refreshSessions,
    required this.settingsViewModel,
    required this.sessionRepository,
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
  // String _selectedBookType = 'All';
  bool _isFavorite = false;
  List<String> _selectedFinishedYears = [];
  List<String> _selectedBookTypes = [];

// Update initState:
  @override
  void initState() {
    super.initState();
    _selectedSortOption = widget.settingsViewModel.librarySortOptionNotifier.value;
    _isAscending = widget.settingsViewModel.isLibrarySortAscendingNotifier.value;

    // Get the saved book types list directly from the ValueNotifier
    _selectedBookTypes = List<String>.from(widget.settingsViewModel.libraryBookTypeFilterNotifier.value);

    _libraryBookView = widget.settingsViewModel.libraryBookViewNotifier.value;
    _filteredBooks = _sortAndFilterBooks(
      List<Map<String, dynamic>>.from(widget.books),
      _selectedSortOption,
      _isAscending,
      _selectedBookTypes,
      _isFavorite,
      _selectedFinishedYears,
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
        );
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
      CupertinoPageRoute(
        builder: (context) => AddBookPage(
          addBook: (book) async {
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
      CupertinoPageRoute(
        builder: (context) => EditBookPage(
          book: book,
          updateBook: (updatedBook) async {
            await _dbHelper.updateBook(updatedBook);
            widget.refreshBooks();
          },
          settingsViewModel: widget.settingsViewModel,
        ),
      ),
    );
  }

  void _navigateToAddSessionPage(int? bookId) async {
    await Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => LogSessionPage(
          books: widget.books,
          initialBookId: bookId,
          refreshSessions: () {
            widget.refreshSessions();
          },
          settingsViewModel: widget.settingsViewModel,
          sessionRepository: widget.sessionRepository,
        ),
      ),
    );
  }

  void _confirmDelete(int bookId) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete Book'),
        content: const Text('Are you sure you want to delete this book and all its sessions?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            isDefaultAction: true,
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
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
    );
  }

  List<Map<String, dynamic>> _sortAndFilterBooks(
      List<Map<String, dynamic>> books,
      String selectedSortOption,
      bool isAscending,
      List<String> selectedBookTypes,
      bool isFavorite,
      List<String> finishedYears,
      ) {
    List<Map<String, dynamic>> filteredBooks = _filterBooks(
      books,
      selectedBookTypes,
      isFavorite,
      finishedYears,
    );

    // Save sorting preferences
    widget.settingsViewModel.setLibrarySortOption(selectedSortOption);
    widget.settingsViewModel.setLibrarySortAscending(isAscending);

    // Save the complete list of book types
    widget.settingsViewModel.setLibraryBookTypeFilter(selectedBookTypes);

    return _sortBooks(filteredBooks, selectedSortOption, isAscending);
  }

  List<Map<String, dynamic>> _filterBooks(
      List<Map<String, dynamic>> books,
      List<String> selectedBookTypes,
      bool isFavorite,
      List<String> finishedYears,
      ) {
    // Convert book type names to IDs
    final selectedTypeIds = <int>[];
    for (final type in selectedBookTypes) {
      final entry = bookTypeNames.entries.firstWhere(
            (entry) => entry.value == type,
        orElse: () => const MapEntry(-1, ''),
      );
      if (entry.key != -1) {
        selectedTypeIds.add(entry.key);
      }
    }

    return books.where((book) {
      bool formatMatch = selectedTypeIds.isEmpty ||
          selectedTypeIds.contains(book['book_type_id']);
      bool favoriteMatch = !isFavorite || (book['is_favorite'] == 1);
      bool yearMatch = finishedYears.isEmpty;

      if (!yearMatch && book['date_finished'] != null) {
        try {
          final date = DateTime.parse(book['date_finished'].toString());
          yearMatch = finishedYears.contains(date.year.toString());
        } catch (e) {
          yearMatch = false;
        }
      }

      return formatMatch && favoriteMatch && yearMatch;
    }).toList();
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
    );

    SortFilterPopup.showSortFilterPopup(
      context: context,
      currentOptions: currentOptions,
      onOptionsChange: (newOptions) {
        setState(() {
          _selectedSortOption = newOptions.sortOption;
          _isAscending = newOptions.isAscending;
          _selectedBookTypes = newOptions.bookTypes;
          _isFavorite = newOptions.isFavorite;
          _selectedFinishedYears = newOptions.finishedYears;

          _filteredBooks = _sortAndFilterBooks(
            List<Map<String, dynamic>>.from(widget.books),
            _selectedSortOption,
            _isAscending,
            _selectedBookTypes,
            _isFavorite,
            _selectedFinishedYears,
          );
        });
      },
      availableYears: availableYears,
      settingsViewModel: widget.settingsViewModel,
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
        } catch (e) {}
      }
    }
    return years.toList()..sort((a, b) => b.compareTo(a));
  }

  Color _getIconColorBasedOnAccentColor(Color color) {
    HSLColor hslColor = HSLColor.fromColor(color);
    double lightness = hslColor.lightness;
    return lightness < 0.5 ? CupertinoColors.white : CupertinoColors.black;
  }

  @override
  Widget build(BuildContext context) {
    final textColor = CupertinoColors.label.resolveFrom(context);
    final accentColor = widget.settingsViewModel.accentColorNotifier.value;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: _isSearching
            ? CupertinoTextField(
          onTapOutside: (event) => FocusManager.instance.primaryFocus?.unfocus(),
          controller: _searchController,
          placeholder: 'Search books...',
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          style: TextStyle(color: textColor),
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey5,
            borderRadius: BorderRadius.circular(8),
          ),
        )
            : Text('Library', style: TextStyle(color: textColor)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _toggleSearch,
              child: Icon(
                _isSearching ? CupertinoIcons.clear_circled : CupertinoIcons.search,
                color: textColor,
              ),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _showSortFilterModal,
              child: Icon(Icons.filter_list, color: textColor),
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            if (_filteredBooks.isEmpty)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/images/carl.png', width: 100, height: 100),
                    SizedBox(height: 16),
                    Text(
                      'Carl is hungry, add a book to your library',
                      style: TextStyle(fontSize: 16, color: textColor),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: CupertinoSlidingSegmentedControl<String>(
                            groupValue: _libraryBookView,
                            onValueChanged: (String? value) {
                              if (value != null) _toggleView(value);
                            },
                            children: {
                              "row_expanded": Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Icon(CupertinoIcons.list_bullet, color: textColor),
                              ),
                              "row_compact": Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Icon(CupertinoIcons.bars, color: textColor),
                              ),
                            },
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.only(top: 16),
                          child: Text(
                            '${_filteredBooks.length}/${widget.books.length}',
                            style: TextStyle(fontSize: 16, color: textColor),
                          ),
                        ),
                      ],
                    ),
                    Expanded(
                      child: CupertinoScrollbar(
                        thickness: 2,
                        child: ListView.builder(
                          itemCount: _filteredBooks.length,
                          itemBuilder: (context, index) {
                            final book = _filteredBooks[index];
                            return BookRow(
                              book: book,
                              textColor: textColor,
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
            Positioned(
              bottom: 20,
              right: 20,
              child: CupertinoButton(
                padding: EdgeInsets.all(16),
                borderRadius: BorderRadius.circular(16),
                color: accentColor,
                onPressed: _navigateToAddBookPage,
                child: Icon(
                  CupertinoIcons.add,
                  color: _getIconColorBasedOnAccentColor(accentColor),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}