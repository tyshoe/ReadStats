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
    final bgColor = CupertinoColors.systemBackground.resolveFrom(context);
    final textColor = CupertinoColors.label.resolveFrom(context);
    final accentColor = widget.settingsViewModel.accentColorNotifier.value;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('Library', style: TextStyle(color: textColor)),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            if (widget.books.isEmpty)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/images/carl.png',
                        width: 100, height: 100),
                    const SizedBox(height: 16),
                    Text(
                      'Carl is hungry, add a book to your library',
                      style: TextStyle(fontSize: 16, color: textColor),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 16),
                        child: Text(
                          '${widget.books.length}',
                          style: TextStyle(fontSize: 16, color: textColor),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Scrollbar(
                        thickness: 2,
                        child: ListView.builder(
                          itemCount: widget.books.length,
                          itemBuilder: (context, index) {
                            final book = widget.books[index];
                            return BookRow(
                              book: book,
                              textColor: textColor,
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
                padding: const EdgeInsets.all(16),
                borderRadius: BorderRadius.circular(16),
                color: accentColor,
                onPressed: _navigateToAddBookPage,
                child: const Icon(CupertinoIcons.add,
                    color: CupertinoColors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
