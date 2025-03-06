import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/data/repositories/book_repository.dart';

class SettingsPage extends StatelessWidget {
  final Function(bool) toggleTheme;
  final bool isDarkMode;
  final BookRepository bookRepository;
  final Function() refreshBooks;
  final Function() refreshSessions;

  const SettingsPage({
    super.key,
    required this.toggleTheme,
    required this.isDarkMode,
    required this.bookRepository,
    required this.refreshBooks,
    required this.refreshSessions,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = CupertinoColors.systemBackground.resolveFrom(context);
    final textColor = CupertinoColors.label.resolveFrom(context);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Settings'),
        backgroundColor: bgColor,
      ),
      child: SafeArea(
        child: ListView(
          children: [
            CupertinoFormSection.insetGrouped(
              header: const Text('Appearance'),
              backgroundColor: bgColor,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey5.resolveFrom(context).withOpacity(0.8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Dark Mode'),
                      CupertinoSwitch(
                        value: isDarkMode,
                        onChanged: toggleTheme,
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
                CupertinoButton(
                  color: CupertinoColors.systemRed,
                  child: Text('Delete All Books', style: TextStyle(color: CupertinoColors.white)),
                  onPressed: () => _confirmDeleteBooks(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () async {
                Navigator.pop(ctx);
                await bookRepository.deleteAllBooks();
                refreshBooks();  // Refresh the book list
                refreshSessions(); // Refresh the session list
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

}
