import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'add_book_page.dart';
import 'edit_book_page.dart';
import 'log_session_page.dart';
import '../database/database_helper.dart';

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

  void _showBookPopup(BuildContext context, Map<String, dynamic> book) async {
    final stats = await _dbHelper.getBookStats(book['id']);
    final DateFormat dateFormat = DateFormat('M/d/yy');

    String formatTime(int totalTimeInMinutes) {
      int days = totalTimeInMinutes ~/ (24 * 60); // Divide by the number of minutes in a day
      int hours = (totalTimeInMinutes % (24 * 60)) ~/ 60; // Remainder after days, then divide by 60 to get hours
      int minutes = totalTimeInMinutes % 60; // Remainder after hours, gives minutes

      // Build the formatted string
      String formattedTime = '';

      if (days > 0) {
        formattedTime += '${days}d ';
      }
      if (hours > 0 || days > 0) {
        formattedTime += '${hours}h ';
      }
      formattedTime += '${minutes}m';

      return formattedTime;
    }

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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Book Title and Stats
                Text(
                  book['title'],
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 3),
                Text(
                  book['author'],
                  style: const TextStyle(fontSize: 14),
                ),
                Text(
                    "${book['word_count']?.toString() ?? '0'} words", // Null check for word count
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _statCard(
                        title: 'Sessions',
                        value: stats['session_count']?.toString() ?? '0'),
                    _statCard(
                        title: 'Pages Read',
                        value: stats['total_pages']?.toString() ?? '0'),
                    _statCard(
                        title: 'Read Time',
                        value: formatTime(stats['total_time'] ?? 0)),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _statCard(
                        title: 'Pages/Minute',
                        value: stats['avg_pages_per_minute']?.toString() ?? '0'),
                    _statCard(
                        title: 'Words/Minute',
                        value: stats['avg_words_per_minute']?.toString() ?? '0'),
                  ],
                ),
                _dateStatsCard(
                  startDate: dateFormat.format(DateTime.parse(stats['start_date'] ?? '1970-01-01')),
                  finishDate: dateFormat.format(DateTime.parse(stats['finish_date'] ?? '1970-01-01')),
                  daysToComplete: stats['days_to_complete']?.toString() ?? '0',
                ),
                const SizedBox(height: 16),

                // Actions
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

  Widget _statCard({required String title, required String value}) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey5.resolveFrom(context).withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Title label at the top
          Text(
            title,
            style: const TextStyle(fontSize: 16, color: CupertinoColors.systemGrey),
          ),
          const SizedBox(height: 12),
          // Value in center, bold
          Text(
            value,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _dateStatsCard({
    required String startDate,
    required String finishDate,
    required String daysToComplete,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey5.resolveFrom(context).withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            children: [
              Text(
                'Start Date',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(startDate, style: const TextStyle(fontSize: 16)),
            ],
          ),
          Column(
            children: [
              Text(
                'Finish Date',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(finishDate, style: const TextStyle(fontSize: 16)),
            ],
          ),
          Column(
            children: [
              Text(
                'Days to Complete',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                daysToComplete,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
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
    final bgColor = CupertinoColors.systemBackground.resolveFrom(context);
    final textColor = CupertinoColors.label.resolveFrom(context);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('Library', style: TextStyle(color: textColor)),
        backgroundColor: bgColor,
      ),
      child: SafeArea(
        child: Stack(
          children: [
            widget.books.isEmpty
                ? Center(
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
                      color: CupertinoColors.secondarySystemBackground
                          .resolveFrom(context),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: CupertinoListTile(
                      title: Text(book['title'],
                          style: TextStyle(color: textColor)),
                      subtitle: Text(book['author'],
                          style: TextStyle(color: textColor)),
                      trailing: Icon(CupertinoIcons.chevron_right,
                          color: textColor),
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
                onPressed: _navigateToAddBookPage,
                child:
                const Icon(CupertinoIcons.add, color: CupertinoColors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

}
