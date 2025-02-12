import 'package:flutter/cupertino.dart';
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
        content: const Text('Are you sure you want to delete this book?'),
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

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Library'),
      ),
      child: widget.books.isEmpty
          ? const Center(child: Text('No books added yet.'))
          : ListView.builder(
              itemCount: widget.books.length,
              itemBuilder: (context, index) {
                final book = widget.books[index];
                return CupertinoListTile(
                  title: Text(book['title']),
                  subtitle: Text('Author: ${book['author']}'),
                  trailing: CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const Icon(CupertinoIcons.trash, color: CupertinoColors.destructiveRed),
                    onPressed: () => _confirmDelete(book['id']),
                  ),
                );
              },
            ),
    );
  }
}
