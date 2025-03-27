import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'book_card.dart';
import 'book_row.dart';
import 'filter_sort_modal.dart';
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
  String _selectedFormat = 'All';

  @override
  void initState() {
    super.initState();
    _selectedSortOption =
        widget.settingsViewModel.librarySortOptionNotifier.value;
    _isAscending =
        widget.settingsViewModel.isLibrarySortAscendingNotifier.value;
    _selectedFormat = widget.settingsViewModel.libraryBookFormatFilterNotifier.value;
    _libraryBookView =
        widget.settingsViewModel.libraryBookViewNotifier.value;
    _filteredBooks = widget.books;
    _filteredBooks = _sortAndFilterBooks(
        List<Map<String, dynamic>>.from(widget.books),
        _selectedSortOption,
        _isAscending,
        _selectedFormat);
    _searchController.addListener(_searchBooks);
  }

  @override
  void didUpdateWidget(covariant LibraryPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if the books have been updated
    if (widget.books != oldWidget.books) {
      setState(() {
        _filteredBooks = widget.books;
        _filteredBooks = _sortAndFilterBooks(
            List<Map<String, dynamic>>.from(widget.books),
            _selectedSortOption,
            _isAscending,
            _selectedFormat);
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
            _selectedFormat);
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
        content: const Text(
            'Are you sure you want to delete this book and all its sessions?'),
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
      _navigateToEditBookPage,
      _navigateToAddSessionPage,
      _confirmDelete,
    );
  }

  List<Map<String, dynamic>> _sortAndFilterBooks(
      List<Map<String, dynamic>> books,
      String selectedSortOption,
      bool isAscending,
      String selectedFormat) {
    List<Map<String, dynamic>> filteredBooks =
        _filterBooks(books, selectedFormat);
    widget.settingsViewModel.setLibrarySortOption(selectedSortOption);
    widget.settingsViewModel.setLibrarySortAscending(isAscending);
    widget.settingsViewModel.setLibraryBookFormatFilter(selectedFormat);
    return _sortBooks(filteredBooks, selectedSortOption, isAscending);
  }

  List<Map<String, dynamic>> _filterBooks(
      List<Map<String, dynamic>> books, String selectedFormat) {
    int selectedFormatId = 0; // Default to 0 (All formats)
    if (selectedFormat != 'All') {
      selectedFormatId = bookTypeNames.entries
          .firstWhere((entry) => entry.value == selectedFormat)
          .key;
    }

    return books.where((book) {
      if (selectedFormatId == 0) {
        return true; // Return all books if no specific format is selected
      } else {
        return book['book_type_id'] ==
            selectedFormatId; // Filter books by selected format
      }
    }).toList();
  }

  static const Map<int, String> bookTypeNames = {
    1: "Paperback",
    2: "Hardback",
    3: "eBook",
    4: "Audiobook",
  };

  // Sorting method
  List<Map<String, dynamic>> _sortBooks(List<Map<String, dynamic>> books,
      String selectedSortOption, bool isAscending) {
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
        // Handle null values by comparing with DateTime(0) (early date) if null
        DateTime dateStartedA = a['date_started'] != null
            ? DateTime.parse(a['date_started'])
            : DateTime(0);
        DateTime dateStartedB = b['date_started'] != null
            ? DateTime.parse(b['date_started'])
            : DateTime(0);
        comparison = dateStartedA.compareTo(dateStartedB);
      } else if (selectedSortOption == 'Date finished') {
        // Handle null values by comparing with DateTime(0) (early date) if null
        DateTime dateFinishedA = a['date_finished'] != null
            ? DateTime.parse(a['date_finished'])
            : DateTime(0);
        DateTime dateFinishedB = b['date_finished'] != null
            ? DateTime.parse(b['date_finished'])
            : DateTime(0);
        comparison = dateFinishedA.compareTo(dateFinishedB);
      } else if (selectedSortOption == 'Date added') {
        // Handle null values by comparing with DateTime(0) (early date) if null
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

  // Show the filter/sort modal
  void _showSortFilterModal() {
    SortFilterPopup.showSortFilterPopup(context, (String selectedOption) {
      setState(() {
        _selectedSortOption = selectedOption;
        _filteredBooks = _sortAndFilterBooks(
            List<Map<String, dynamic>>.from(widget.books),
            _selectedSortOption,
            _isAscending,
            _selectedFormat);
      });
    }, (bool isAscending) {
      setState(() {
        _isAscending = isAscending;
        _filteredBooks = _sortAndFilterBooks(
            List<Map<String, dynamic>>.from(widget.books),
            _selectedSortOption,
            _isAscending,
            _selectedFormat);
      });
    }, _selectedSortOption, _isAscending, onFormatChange, _selectedFormat);
  }

  void onFormatChange(String newFormat) {
    setState(() {
      _selectedFormat = newFormat;
      _filteredBooks = _sortAndFilterBooks(
          List<Map<String, dynamic>>.from(widget.books),
          _selectedSortOption,
          _isAscending,
          _selectedFormat);
    });
  }

  @override
  Widget build(BuildContext context) {
    final textColor = CupertinoColors.label.resolveFrom(context);
    final accentColor = widget.settingsViewModel.accentColorNotifier.value;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: _isSearching
            ? CupertinoTextField(
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
                _isSearching
                    ? CupertinoIcons.clear_circled
                    : CupertinoIcons.search,
                color: textColor,
              ),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _showSortFilterModal, // Open the filter/sort modal
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
                    Image.asset('assets/images/carl.png',
                        width: 100, height: 100),
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
                    // Row for Segmented Control and Text
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: CupertinoSlidingSegmentedControl<String>(
                            groupValue: _libraryBookView,  // Store the current view as a string (either "row_compact" or "row_expanded")
                            onValueChanged: (String? value) {
                              if (value != null) {
                                _toggleView(value);  // Pass the new value to the toggle function
                              }
                            },
                            children: {
                              "row_expanded": Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Icon(CupertinoIcons.list_bullet, color: textColor), // Icon for row_compact
                              ),
                              "row_compact": Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Icon(CupertinoIcons.bars, color: textColor), // Icon for row_expanded
                              ),
                            },
                          ),
                        ),
                          Padding(
                            padding: const EdgeInsets.only(top: 16),  // Adjust this value to move the text further down
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
                child: Icon(CupertinoIcons.add, color: CupertinoColors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
