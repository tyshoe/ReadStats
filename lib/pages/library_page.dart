import 'package:flutter/cupertino.dart';
import 'add_book_page.dart'; // Import the AddBookPage
import 'edit_book_page.dart'; // Import the EditBookPage
import '../database_helper.dart';

class LibraryPage extends StatefulWidget {
  final List<Map<String, dynamic>> books;
  final Function() refreshBooks;

  const LibraryPage({super.key, required this.books, required this.refreshBooks});

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
        content: const Text('Are you sure you want to delete this book and all its sessions?'),
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
              widget.refreshBooks(); // Refresh the book list
              Navigator.pop(context); // Close the dialog
            },
          ),
        ],
      ),
    );
  }

  void _navigateToAddBookPage() async {
    // Navigate to AddBookPage and wait for a result
    await Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => AddBookPage(
          addBook: (book) async {
            await _dbHelper.insertBook(book);
            widget.refreshBooks(); // Refresh the book list after adding a new book
          },
        ),
      ),
    );
  }

  void _navigateToEditBookPage(Map<String, dynamic> book) async {
    // Navigate to EditBookPage and wait for a result
    await Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => EditBookPage(
          book: book,
          updateBook: (updatedBook) async {
            await _dbHelper.updateBook(updatedBook);
            widget.refreshBooks(); // Refresh the book list after updating
          },
        ),
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
                    'assets/images/carl.png', // Path to your PNG image
                    width: 100, // Adjust the width as needed
                    height: 100, // Adjust the height as needed
                  ),
                  const SizedBox(height: 16), // Add some spacing
                  const Text(
                    'Carl is hungry, add a book to your library',
                    style: TextStyle(
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              itemCount: widget.books.length,
              itemBuilder: (context, index) {
                final book = widget.books[index];
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8), // Add margin
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey6, // Light grey background
                    borderRadius: BorderRadius.circular(8), // Rounded corners
                  ),
                  child: CupertinoListTile(
                    title: Text(book['title']),
                    subtitle: Text('${book['author']}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          child: const Icon(CupertinoIcons.pencil, color: CupertinoColors.activeBlue),
                          onPressed: () => _navigateToEditBookPage(book),
                        ),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          child: const Icon(CupertinoIcons.trash, color: CupertinoColors.destructiveRed),
                          onPressed: () => _confirmDelete(book['id']),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            // Cupertino-style floating button
            Positioned(
              bottom: 20,
              right: 20,
              child: CupertinoButton(
                padding: const EdgeInsets.all(16),
                borderRadius: BorderRadius.circular(30),
                color: CupertinoColors.activeBlue,
                child: const Icon(CupertinoIcons.add, color: CupertinoColors.white),
                onPressed: _navigateToAddBookPage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}