import 'package:flutter/cupertino.dart';
import 'add_book_page.dart';
import 'edit_book_page.dart';
import 'log_session_page.dart';
import '../database_helper.dart';

class LibraryPage extends StatefulWidget {
  final List<Map<String, dynamic>> books;
  final Function() refreshBooks;

  const LibraryPage(
      {super.key, required this.books, required this.refreshBooks});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();

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
          ),
          CupertinoDialogAction(
            child: const Text('Delete'),
            isDestructiveAction: true,
            onPressed: () async {
              await _dbHelper.deleteBook(bookId);
              widget.refreshBooks();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
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
        ),
      ),
    );
  }

  void _navigateToAddSessionPage(int? bookId) async {
    await Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => LogSessionPage(
          books: widget.books, // Passes the full book list
          initialBookId: bookId, // Preselects book if provided
          refreshSessions: () {
            // Placeholder for refreshing sessions later
          },
        ),
      ),
    );
  }

  void _showBookPopup(BuildContext context, Map<String, dynamic> book) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) {
        return CupertinoPopupSurface(
          isSurfacePainted: true,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            width: double.infinity,
            decoration: BoxDecoration(
              color: CupertinoColors.systemBackground.resolveFrom(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  book['title'],
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _popupAction(
                      icon: CupertinoIcons.pencil,
                      label: 'Edit',
                      onTap: () {
                        Navigator.pop(context);
                        _navigateToEditBookPage(book);
                      },
                    ),
                    _popupAction(
                      icon: CupertinoIcons.book,
                      label: 'Add Session',
                      onTap: () {
                        Navigator.pop(context);
                        _navigateToAddSessionPage(book['id']);
                      },
                    ),
                    _popupAction(
                      icon: CupertinoIcons.trash,
                      label: 'Delete',
                      color: CupertinoColors.destructiveRed,
                      onTap: () {
                        Navigator.pop(context);
                        _confirmDelete(book['id']);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _popupAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = CupertinoColors.activeBlue,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(fontSize: 14, color: color),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Library'),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            widget.books.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/images/carl.png',
                          width: 100,
                          height: 100,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Carl is hungry, add a book to your library',
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: widget.books.length,
                    itemBuilder: (context, index) {
                      final book = widget.books[index];
                      return GestureDetector(
                        onTap: () => _showBookPopup(context, book),
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                              vertical: 4, horizontal: 8),
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemGrey6,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: CupertinoListTile(
                            title: Text(book['title']),
                            subtitle: Text('${book['author']}'),
                            trailing: const Icon(CupertinoIcons.chevron_right),
                          ),
                        ),
                      );
                    },
                  ),
            Positioned(
              bottom: 20,
              right: 20,
              child: CupertinoButton(
                padding: const EdgeInsets.all(16),
                borderRadius: BorderRadius.circular(30),
                color: CupertinoColors.activeBlue,
                child: const Icon(CupertinoIcons.add,
                    color: CupertinoColors.white),
                onPressed: _navigateToAddBookPage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
