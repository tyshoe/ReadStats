import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import '../themes/app_theme.dart';
import '/data/repositories/book_repository.dart';
import '/data/repositories/session_repository.dart';
import '/viewmodels/SettingsViewModel.dart';
import '/data/models/book.dart';
import '/data/models/session.dart';

class SettingsPage extends StatelessWidget {
  final Function(bool) toggleTheme;
  final bool isDarkMode;
  final BookRepository bookRepository;
  final SessionRepository sessionRepository;
  final Function() refreshBooks;
  final Function() refreshSessions;
  final SettingsViewModel settingsViewModel;
  const SettingsPage({
    super.key,
    required this.toggleTheme,
    required this.isDarkMode,
    required this.bookRepository,
    required this.sessionRepository,
    required this.refreshBooks,
    required this.refreshSessions,
    required this.settingsViewModel,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor =
        isDarkMode ? AppTheme.darkBackground : AppTheme.lightBackground;
    final textColor = CupertinoColors.label.resolveFrom(context);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Settings'),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            CupertinoFormSection.insetGrouped(
              header: const Text('Appearance'),
              backgroundColor: bgColor,
              children: [
                // Dark Mode Container (Rounded Top)
                Container(
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey5
                        .resolveFrom(context)
                        .withOpacity(0.8),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(10),
                      topRight: Radius.circular(10),
                    ),
                  ),
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  // color: CupertinoColors.systemTeal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Dark Mode'),
                      CupertinoSwitch(
                        value: isDarkMode,
                        onChanged: toggleTheme,
                        applyTheme: false,
                      ),
                    ],
                  ),
                ),
                // Accent Color Container (Rounded Bottom)
                Container(
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey5
                        .resolveFrom(context)
                        .withOpacity(0.8),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(10),
                      bottomRight: Radius.circular(10),
                    ),
                  ),
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Accent Color'),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: Container(
                          width: 48,
                          height: 32,
                          decoration: BoxDecoration(
                            color: settingsViewModel.accentColorNotifier.value,
                            shape: BoxShape.rectangle,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => _showColorPicker(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            CupertinoFormSection.insetGrouped(
              header: const Text('Manage Your Data'),
              backgroundColor: bgColor,
              children: [
                GestureDetector(
                  onTap: () async {
                    await exportDataToCSV();
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey5
                          .resolveFrom(context)
                          .withOpacity(0.8),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(10),
                        topRight: Radius.circular(10),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                        vertical: 20, horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Export data as CSV'),
                      ],
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => _confirmDeleteBooks(context),
                  child: Container(
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey5
                          .resolveFrom(context)
                          .withOpacity(0.8),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(10),
                        bottomRight: Radius.circular(10),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                        vertical: 20, horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Delete All Books'),
                      ],
                    ),
                  ),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> exportDataToCSV() async {
    try {
      // Call the export functions and store file paths
      String booksFilePath =
          await exportBooksToCSV(await bookRepository.getBooks());
      String sessionsFilePath =
          await exportSessionsToCSV(await sessionRepository.getSessions());

      print('Books data exported to: $booksFilePath');
      print('Sessions data exported to: $sessionsFilePath');

      await Share.shareXFiles([XFile(booksFilePath), XFile(sessionsFilePath)]);

      print('Both books and sessions data exported successfully!');
    } catch (e) {
      print('An error occurred while exporting data: $e');
    }
  }

// Function to export books data to CSV and return the file path
  Future<String> exportBooksToCSV(List<Book> booksData) async {
    String formattedDate = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/books_data_$formattedDate.csv';

    List<List<String>> rows = [
      ['Title', 'Author', 'Word Count', 'Rating', 'Completion Status'],
      ...booksData.map((book) => [
            book.title,
            book.author,
            book.wordCount.toString(),
            book.rating.toString(),
            book.isCompleted ? 'Completed' : 'Not Completed',
          ])
    ];

    String csv = const ListToCsvConverter().convert(rows);
    final file = File(filePath);
    await file.writeAsString(csv);

    return filePath;
  }

// Function to export sessions data to CSV and return the file path
  Future<String> exportSessionsToCSV(List<Session> sessionsData) async {
    String formattedDate = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/sessions_data_$formattedDate.csv';

    List<List<String>> rows = [
      ['SessionId', 'Book Id', 'Pages Read', 'Hours', 'Minutes', 'Date'],
      ...sessionsData.map((session) => [
            session.id.toString(),
            session.bookId.toString(),
            session.pagesRead.toString(),
            session.hours.toString(),
            session.minutes.toString(),
            session.date.toString(),
          ])
    ];

    String csv = const ListToCsvConverter().convert(rows);
    final file = File(filePath);
    await file.writeAsString(csv);

    return filePath;
  }

  void _confirmDeleteBooks(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext ctx) {
        return CupertinoAlertDialog(
          title: const Text('Delete All Books?'),
          content: const Text(
              'This action cannot be undone. Are you sure you want to delete all books?'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
              isDefaultAction: true,
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () async {
                Navigator.pop(ctx);
                await bookRepository.deleteAllBooks();
                refreshBooks(); // Refresh the book list
                refreshSessions(); // Refresh the session list
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _showColorPicker(BuildContext context) {
    final List<Color> colors = [
      CupertinoColors.systemPink,
      CupertinoColors.systemOrange,
      CupertinoColors.systemYellow,
      CupertinoColors.systemGreen,
      CupertinoColors.systemTeal,
      CupertinoColors.systemCyan,
      CupertinoColors.systemBlue,
      CupertinoColors.systemIndigo,
      CupertinoColors.systemPurple,
      CupertinoColors.systemMint,
      CupertinoColors.systemBrown,
      CupertinoColors.systemGrey,
    ];

    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext ctx) {
        return Container(
          height: 250,
          padding: const EdgeInsets.all(16),
          color: CupertinoColors.systemGrey5.resolveFrom(context),
          child: Column(
            children: [
              const Text('Choose Accent Color', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: colors.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () {
                        settingsViewModel.setAccentColor(colors[index]);
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: colors[index],
                          shape: BoxShape.rectangle,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
