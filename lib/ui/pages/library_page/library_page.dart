import 'package:flutter/cupertino.dart';
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

  Widget _buildRatingStars(double rating) {
    int fullStars = rating.floor();
    bool hasHalfStar = (rating - fullStars) >= 0.5;

    return Row(
      children: List.generate(5, (index) {
        if (index < fullStars) {
          return const Icon(CupertinoIcons.star_fill,
              color: CupertinoColors.systemYellow);
        } else if (index == fullStars && hasHalfStar) {
          return const Icon(CupertinoIcons.star_lefthalf_fill,
              color: CupertinoColors.systemYellow);
        } else {
          return const Icon(CupertinoIcons.star,
              color: CupertinoColors.systemGrey);
        }
      }),
    );
  }

  void _showBookPopup(BuildContext context, Map<String, dynamic> book) async {
    final stats = await _dbHelper.getBookStats(book['id']);
    final DateFormat dateFormat = DateFormat('M/d/yy');

    String formatTime(int totalTimeInMinutes) {
      int days = totalTimeInMinutes ~/ (24 * 60);
      int hours = (totalTimeInMinutes % (24 * 60)) ~/ 60;
      int minutes = totalTimeInMinutes % 60;

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

    String completionStatus = '';
    IconData completionIcon;
    Color completionColor;

    if (book['is_completed'] == 1) {
      completionStatus = 'Completed';
      completionIcon = CupertinoIcons.check_mark;
      completionColor = CupertinoColors.activeGreen;
    } else if (book['is_completed'] == 0 && stats['start_date'] != null) {
      // In progress
      completionStatus = 'In Progress';
      completionIcon = CupertinoIcons.hourglass;
      completionColor = CupertinoColors.systemBlue;
    } else {
      // Not started
      completionStatus = 'Not Started';
      completionIcon = CupertinoIcons.circle;
      completionColor = CupertinoColors.systemGrey;
    }

    showCupertinoModalPopup(
      context: context,
      builder: (context) {
        return CupertinoPopupSurface(
          isSurfacePainted: true,
          child: Container(
            padding: const EdgeInsets.all(16),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Book Title, Author, and Word Count
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            book['title'],
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow
                                .ellipsis, // Ensures long titles are truncated
                          ),
                          const SizedBox(height: 3),
                          Text(
                            "by ${book['author']}",
                            style:
                                const TextStyle(fontSize: 14, wordSpacing: 2),
                            maxLines: 1,
                            overflow: TextOverflow
                                .ellipsis, // Truncate long author names
                          ),
                          const SizedBox(height: 3),
                          Text(
                            "${book['word_count']?.toString() ?? '0'} words",
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(
                        width: 10), // Adds spacing between text and rating

                    // Rating and Completion Status to the right
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildRatingStars(book['rating'] ?? 0),
                        Row(
                          children: [
                            Icon(
                              completionIcon,
                              color: completionColor,
                              size: 18,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              completionStatus,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Stats (Sessions, Pages, Read Time, etc.)
                Row(
                  children: [
                    Expanded(
                      child: _statCard(
                        title: 'Sessions',
                        value: stats['session_count']?.toString() ?? '0',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _statCard(
                        title: 'Pages Read',
                        value: stats['total_pages']?.toString() ?? '0',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _statCard(
                        title: 'Read Time',
                        value: formatTime(stats['total_time'] ?? 0),
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Expanded(
                      child: _statCard(
                        title: 'Pages/Minute',
                        value: stats['pages_per_minute']?.toStringAsFixed(2) ??
                            '0',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _statCard(
                        title: 'Words/Minute',
                        value: stats['words_per_minute']?.toStringAsFixed(2) ??
                            '0',
                      ),
                    ),
                  ],
                ),
                _dateStatsCard(
                  startDate: dateFormat.format(
                      DateTime.parse(stats['start_date'] ?? '1999-11-15')),
                  finishDate: book['is_completed'] == 1
                      ? dateFormat.format(
                          DateTime.parse(stats['finish_date'] ?? '1999-11-15'))
                      : 'n/a',
                  daysToComplete: book['is_completed'] == 1
                      ? stats['days_to_complete']?.toString() ?? '0'
                      : 'n/a',
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
                      color: book['is_completed'] == 1
                          ? CupertinoColors.systemGrey
                          : CupertinoColors.activeBlue,
                      onTap: book['is_completed'] == 1
                          ? () {} // Disable interaction by providing an empty function
                          : () {
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
        color:
            CupertinoColors.systemGrey5.resolveFrom(context).withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Title label at the top
          Text(
            title,
            style: const TextStyle(
                fontSize: 14, color: CupertinoColors.systemGrey),
          ),
          const SizedBox(height: 12),
          // Value in center, bold, with text scaling
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
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
        color:
            CupertinoColors.systemGrey5.resolveFrom(context).withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            children: [
              Text(
                'Start Date',
                style: const TextStyle(
                    fontSize: 16, color: CupertinoColors.systemGrey),
              ),
              const SizedBox(height: 6),
              Text(startDate, style: const TextStyle(fontSize: 16)),
            ],
          ),
          Column(
            children: [
              Text(
                'Finish Date',
                style: const TextStyle(
                    fontSize: 16, color: CupertinoColors.systemGrey),
              ),
              const SizedBox(height: 6),
              Text(finishDate, style: const TextStyle(fontSize: 16)),
            ],
          ),
          Column(
            children: [
              Text(
                'Days to Complete',
                style: const TextStyle(
                    fontSize: 16, color: CupertinoColors.systemGrey),
              ),
              const SizedBox(height: 6),
              Text(daysToComplete, style: const TextStyle(fontSize: 16)),
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
                          // Format: books_shown (total_books)
                          style: TextStyle(fontSize: 16, color: textColor),
                        ),
                      ),
                    ),
                    Expanded(
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
