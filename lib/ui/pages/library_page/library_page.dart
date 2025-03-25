import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'book_card.dart';
import 'book_row.dart';
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
  bool _isCompactRowView = true;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredBooks = [];

  @override
  void initState() {
    super.initState();
    _filteredBooks = widget.books;
    _searchController.addListener(_filterBooks);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleView() {
    setState(() {
      _isCompactRowView = !_isCompactRowView;
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _filteredBooks = widget.books;
      }
    });
  }

  void _filterBooks() {
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
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
            isDefaultAction: true,
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
              onPressed: _toggleView,
              child: Icon(
                _isCompactRowView
                    ? CupertinoIcons.list_bullet
                    : CupertinoIcons.bars,
                color: textColor,
              ),
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
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: EdgeInsets.only(top: 8, bottom: 16),
                        child: Text(
                          _isSearching
                              ? '${_filteredBooks.length}/${widget.books.length}' // Show filtered count when searching
                              : '${widget.books.length}', // Show total count when not searching
                          style: TextStyle(fontSize: 16, color: textColor),
                        ),
                      ),
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
                              isCompactView: _isCompactRowView,
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
