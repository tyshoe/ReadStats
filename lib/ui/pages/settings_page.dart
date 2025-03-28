import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import '../themes/app_theme.dart';
import '/data/repositories/book_repository.dart';
import '/data/repositories/session_repository.dart';
import '/viewmodels/SettingsViewModel.dart';
import '/data/models/book.dart';
import '/data/models/session.dart';
import 'dart:developer';

class SettingsPage extends StatelessWidget {
  final Function(ThemeMode) toggleTheme;
  final ThemeMode themeMode;
  final BookRepository bookRepository;
  final SessionRepository sessionRepository;
  final Function() refreshBooks;
  final Function() refreshSessions;
  final SettingsViewModel settingsViewModel;

  const SettingsPage({
    super.key,
    required this.toggleTheme,
    required this.themeMode,
    required this.bookRepository,
    required this.sessionRepository,
    required this.refreshBooks,
    required this.refreshSessions,
    required this.settingsViewModel,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = (themeMode == ThemeMode.dark ||
            (themeMode == ThemeMode.system &&
                MediaQuery.of(context).platformBrightness == Brightness.dark))
        ? AppTheme.darkBackground
        : AppTheme.lightBackground;
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
                // Dark Mode Section
                GestureDetector(
                  onTap: () => _showThemeSelection(context),
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
                        const Text('Theme'),
                        Text(
                          _getThemeModeString(themeMode),
                        ),
                      ],
                    ),
                  ),
                ),
                // Accent Color Container
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
              header: const Text('Preferences'),
              backgroundColor: bgColor,
              children: [
                GestureDetector(
                  onTap: () => _showBookTypePicker(context),
                  child: Container(
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey5
                          .resolveFrom(context)
                          .withOpacity(0.8),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(10),
                        topRight: Radius.circular(10),
                        bottomLeft: Radius.circular(10),
                        bottomRight: Radius.circular(10),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                        vertical: 20, horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Default Book Format'),
                        ValueListenableBuilder<int>(
                          valueListenable:
                              settingsViewModel.defaultBookTypeNotifier,
                          builder: (context, defaultBookType, child) {
                            return Text(
                              bookTypeNames[defaultBookType] ?? "Unknown",
                            );
                          },
                        ),
                      ],
                    ),
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
                  onTap: () async {
                    await _importBooksFromCSV();
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey5
                          .resolveFrom(context)
                          .withOpacity(0.8),
                    ),
                    padding: const EdgeInsets.symmetric(
                        vertical: 20, horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Import Books from CSV'),
                      ],
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    await _importSessionsFromCSV();
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey5
                          .resolveFrom(context)
                          .withOpacity(0.8),
                    ),
                    padding: const EdgeInsets.symmetric(
                        vertical: 20, horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Import Sessions from CSV'),
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
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showThemeSelection(BuildContext context) {
    final textColor = CupertinoColors.label.resolveFrom(context);
    final currentThemeMode = settingsViewModel.themeModeNotifier.value;
    final accentColor = settingsViewModel.accentColorNotifier.value;

    showCupertinoModalPopup(
      context: context,
      builder: (context) => GestureDetector(
        onTap: () => Navigator.pop(context), // Dismiss when tapping outside
        child: Center(
          child: CupertinoPopupSurface(
            isSurfacePainted: true,
            child: Container(
              width: MediaQuery.of(context).size.width *
                  0.9, // Adjust width as needed
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start, // Align left
                children: [
                  const Text(
                    'Theme',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  CupertinoButton(
                    onPressed: () {
                      toggleTheme(ThemeMode.system);
                      Navigator.pop(context);
                    },
                    child: Row(
                      children: [
                        if (currentThemeMode == ThemeMode.system)
                          Icon(CupertinoIcons.check_mark, color: accentColor),
                        const SizedBox(width: 8), // Space between icon and text
                        Text(
                          'System',
                          style: TextStyle(
                            fontSize: 16,
                            color: currentThemeMode == ThemeMode.system
                                ? accentColor
                                : textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  CupertinoButton(
                    onPressed: () {
                      toggleTheme(ThemeMode.light);
                      Navigator.pop(context);
                    },
                    child: Row(
                      children: [
                        if (currentThemeMode == ThemeMode.light)
                          Icon(CupertinoIcons.check_mark, color: accentColor),
                        const SizedBox(width: 8),
                        Text(
                          'Light',
                          style: TextStyle(
                            fontSize: 16,
                            color: currentThemeMode == ThemeMode.light
                                ? accentColor
                                : textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  CupertinoButton(
                    onPressed: () {
                      toggleTheme(ThemeMode.dark);
                      Navigator.pop(context);
                    },
                    child: Row(
                      children: [
                        if (currentThemeMode == ThemeMode.dark)
                          Icon(CupertinoIcons.check_mark, color: accentColor),
                        const SizedBox(width: 8),
                        Text(
                          'Dark',
                          style: TextStyle(
                            fontSize: 16,
                            color: currentThemeMode == ThemeMode.dark
                                ? accentColor
                                : textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getThemeModeString(ThemeMode themeMode) {
    switch (themeMode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
      default:
        return 'System';
    }
  }

  static const Map<int, String> bookTypeNames = {
    1: "Paperback",
    2: "Hardback",
    3: "eBook",
    4: "Audiobook",
  };

  void _showBookTypePicker(BuildContext context) {
    final textColor = CupertinoColors.label.resolveFrom(context);
    final accentColor = settingsViewModel.accentColorNotifier.value;
    final int selectedBookType =
        settingsViewModel.defaultBookTypeNotifier.value;

    showCupertinoModalPopup(
      context: context,
      builder: (context) => GestureDetector(
        onTap: () => Navigator.pop(context), // Dismiss when tapping outside
        child: Center(
          child: CupertinoPopupSurface(
            isSurfacePainted: true,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start, // Align left
                children: [
                  const Text(
                    'Default Book Format',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  ...bookTypeNames.entries.map((entry) {
                    final int typeId = entry.key;
                    final String typeName = entry.value;
                    final bool isSelected = typeId == selectedBookType;

                    return CupertinoButton(
                      onPressed: () {
                        settingsViewModel.setDefaultBookType(typeId);
                        Navigator.pop(context);
                      },
                      child: Row(
                        children: [
                          if (isSelected)
                            Icon(CupertinoIcons.check_mark, color: accentColor),
                          const SizedBox(width: 8),
                          Text(
                            typeName,
                            style: TextStyle(
                              fontSize: 16,
                              color: isSelected ? accentColor : textColor,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _importBooksFromCSV() async {
    await _importCSV('books', _importBooks);
  }

  Future<void> _importSessionsFromCSV() async {
    await _importCSV('sessions', _importSessions);
  }

  Future<void> _importCSV(String type,
      Future<void> Function(List<List<dynamic>>) importFunction) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        // allowedExtensions: ['csv'],
      );

      if (result != null) {
        String filePath = result.files.single.path!;
        final file = File(filePath);
        String csvString = await file.readAsString();

        List<List<dynamic>> csvData =
            const CsvToListConverter().convert(csvString);

        if (csvData.isNotEmpty) {
          if (type == 'books') {
            await importFunction(csvData.skip(1).toList());
          } else if (type == 'sessions') {
            await importFunction(csvData.skip(1).toList());
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error importing CSV: $e');
      }
    }
  }

  Future<void> _importBooks(List<List<dynamic>> rows) async {
    List<Book> booksToInsert = [];

    for (var row in rows) {
      if (row.length < 11) continue; // Skip invalid rows

      try {
        Book book = Book(
          id: row[0] ?? 0,
          title: row[1].toString(),
          author: row[2].toString(),
          wordCount: int.tryParse(row[3].toString()) ?? 0,
          pageCount: int.tryParse(row[4].toString()) ?? 0,
          rating: double.tryParse(row[5].toString()) ?? 0.0,
          isCompleted: row[6] == 1 || row[6] == 'true',
          bookTypeId: int.tryParse(row[7].toString()) ?? 0,
          dateAdded: DateTime.tryParse(row[8].toString())?.toIso8601String().split('T')[0] ??
              DateTime.now().toIso8601String().split('T')[0],
          dateStarted: row[9]?.toString().isNotEmpty == true
              ? DateTime.tryParse(row[9].toString())?.toIso8601String().split('T')[0]
              : null,
          dateFinished: row[10]?.toString().isNotEmpty == true
              ? DateTime.tryParse(row[10].toString())?.toIso8601String().split('T')[0]
              : null,
        );

        booksToInsert.add(book);
      } catch (e) {
        if (kDebugMode) print('Error processing row: $row. Error: $e');
      }
    }

    if (booksToInsert.isNotEmpty) {
      await bookRepository.addBooksBatch(booksToInsert); // Use batch insert
    }

    refreshBooks();
  }

  Future<void> _importSessions(List<List<dynamic>> rows) async {
    if (rows.isEmpty) return;

    List<Session> sessions = [];

    for (var row in rows) {
      if (row.length >= 5) {
        sessions.add(
          Session(
            id: int.tryParse(row[0].toString()) ?? 0,
            bookId: int.tryParse(row[1].toString()) ?? 0,
            pagesRead: int.tryParse(row[2].toString()) ?? 0,
            durationMinutes: int.tryParse(row[3].toString()) ?? 0,
            date: DateTime.tryParse(row[4].toString())
                ?.toIso8601String()
                .split('T')[0] ??
                DateTime.now().toIso8601String().split('T')[0],
          ),
        );
      }
    }

    if (sessions.isNotEmpty) {
      await sessionRepository.addSessionsBatch(sessions); // Use batch insert
    }

    refreshSessions();
    if (kDebugMode) {
      print('${sessions.length} sessions imported successfully.');
    }
  }


  Future<void> exportDataToCSV() async {
    try {
      // Call the export functions and store file paths
      String booksFilePath =
          await exportBooksToCSV(await bookRepository.getBooks());
      String sessionsFilePath =
          await exportSessionsToCSV(await sessionRepository.getSessions());

      if (kDebugMode) {
        print('Books data exported to: $booksFilePath');
      }
      if (kDebugMode) {
        print('Sessions data exported to: $sessionsFilePath');
      }

      await Share.shareXFiles([XFile(booksFilePath), XFile(sessionsFilePath)]);

      if (kDebugMode) {
        print('Both books and sessions data exported successfully!');
      }
    } catch (e) {
      if (kDebugMode) {
        print('An error occurred while exporting data: $e');
      }
    }
  }

  // Function to export books data to CSV and return the file path
  Future<String> exportBooksToCSV(List<Book> booksData) async {
    String formattedDate = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/books_data_$formattedDate.csv';

    List<List<String>> rows = [
      [
        'id',
        'title',
        'author',
        'word_count',
        'page_count',
        'rating',
        'is_complete',
        'book_type_id',
        'date_added',
        'date_started',
        'date_finished'
      ],
      ...booksData.map((book) => [
            book.id.toString(),
            book.title,
            book.author,
            book.wordCount.toString(),
            book.pageCount.toString(),
            book.rating.toString(),
            book.isCompleted.toString(),
            book.bookTypeId.toString(),
            book.dateAdded.toString(),
            book.dateStarted.toString(),
            book.dateFinished.toString(),
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
      ['session_id', 'book_id', 'pages_read', 'duration_minutes', 'date'],
      ...sessionsData.map((session) => [
            session.id.toString(),
            session.bookId.toString(),
            session.pagesRead.toString(),
            session.durationMinutes.toString(),
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
              isDefaultAction: true,
              child: const Text('Cancel'),
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
