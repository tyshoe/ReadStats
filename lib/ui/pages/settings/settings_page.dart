import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:stylish_bottom_bar/stylish_bottom_bar.dart';
import '../../themes/app_theme.dart';
import '/data/repositories/book_repository.dart';
import '/data/repositories/session_repository.dart';
import '/viewmodels/SettingsViewModel.dart';
import '/data/models/book.dart';
import '/data/models/session.dart';
import 'font_page.dart';
import 'widgets/accent_color_picker.dart';
import 'widgets/nav_style_picker.dart';
import 'widgets/rating_style_picker.dart';
import '../settings/widgets/book_type_picker.dart';
import '../settings/widgets/theme_mode_picker.dart';
import 'widgets/default_tab_picker.dart';
import 'widgets/date_format_picker.dart';

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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: ListView(
        children: [
          // Appearance Section
          _buildSettingsSection(
            context,
            header: 'Appearance',
            children: [
              _buildSettingsTile(
                context,
                title: 'Theme',
                trailing: Text(
                  _getThemeModeString(themeMode),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                onTap: () => showThemeModePicker(
                    context, settingsViewModel, toggleTheme),
              ),
              _buildSettingsTile(
                context,
                title: 'Accent Color',
                trailing: Container(
                  width: 48,
                  height: 32,
                  decoration: BoxDecoration(
                    color: settingsViewModel.accentColorNotifier.value,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onTap: () => showAccentColorPickerModal(
                  context,
                  settingsViewModel.accentColorNotifier.value,
                  (newColor) => settingsViewModel.setAccentColor(newColor),
                ),
              ),
              _buildSettingsTile(
                context,
                title: 'Font',
                trailing: ValueListenableBuilder<String>(
                  valueListenable: settingsViewModel.selectedFontNotifier,
                  builder: (context, selectedFont, _) => Text(
                    selectedFont,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        FontSelectionPage(settingsViewModel: settingsViewModel),
                  ),
                ),
              ),
              _buildSettingsTile(
                context,
                title: 'Date Format',
                trailing: ValueListenableBuilder<String>(
                  valueListenable: settingsViewModel.defaultDateFormatNotifier,
                  builder: (context, format, _) => Text(
                    _getFormattedDate(DateTime.now(), format),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                onTap: () => showDateFormatPicker(context, settingsViewModel),
              ),
              _buildSettingsTile(
                context,
                title: 'Navigation Style',
                trailing: ValueListenableBuilder<IconStyle>(
                  valueListenable: settingsViewModel.navStyleNotifier,
                  builder: (context, value, _) =>
                      Text(_iconStyleToString(value), style: Theme.of(context).textTheme.bodyMedium,),
                ),
                onTap: () => showNavStylePicker(context, settingsViewModel),
              ),
            ],
          ),

          // Preferences Section
          _buildSettingsSection(
            context,
            header: 'Preferences',
            children: [
              _buildSettingsTile(
                context,
                title: 'Default Book Format',
                trailing: ValueListenableBuilder<int>(
                  valueListenable: settingsViewModel.defaultBookTypeNotifier,
                  builder: (context, type, _) =>
                      Text(bookTypeNames[type] ?? "Unknown", style: Theme.of(context).textTheme.bodyMedium,),
                ),
                onTap: () => showBookTypePicker(context, settingsViewModel),
              ),
              _buildSettingsTile(
                context,
                title: 'Rating Style',
                trailing: ValueListenableBuilder<int>(
                  valueListenable: settingsViewModel.defaultRatingStyleNotifier,
                  builder: (context, style, _) =>
                      Text(ratingStyleNames[style] ?? "Unknown", style: Theme.of(context).textTheme.bodyMedium,),
                ),
                onTap: () => showRatingStylePicker(context, settingsViewModel),
              ),
              _buildSettingsTile(
                context,
                title: 'Default Tab',
                trailing: ValueListenableBuilder<int>(
                  valueListenable: settingsViewModel.defaultTabNotifier,
                  builder: (context, index, _) => Text(_getTabName(index), style: Theme.of(context).textTheme.bodyMedium,),
                ),
                onTap: () => showDefaultTabPicker(context, settingsViewModel),
              ),
            ],
          ),

          // Data Management Section
          _buildSettingsSection(
            context,
            header: 'Manage Your Data',
            children: [
              _buildSettingsTile(
                context,
                title: 'Export data as CSV',
                onTap: exportDataToCSV,
              ),
              _buildSettingsTile(
                context,
                title: 'Import Books from CSV',
                onTap: _importBooksFromCSV,
              ),
              _buildSettingsTile(
                context,
                title: 'Import Sessions from CSV',
                onTap: _importSessionsFromCSV,
              ),
              _buildSettingsTile(
                context,
                title: 'Delete All Books',
                textColor: colors.error,
                onTap: () => _confirmDeleteBooks(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(
    BuildContext context, {
    required String header,
    required List<Widget> children,
  }) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              header,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
    Color? textColor,
  }) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(
            color: textColor ?? Theme.of(context).colorScheme.onSurface),
      ),
      trailing: trailing,
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  void _confirmDeleteBooks(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete All Books?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await bookRepository.deleteAllBooks();
              refreshBooks();
              refreshSessions();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _getTabName(int index) {
    switch (index) {
      case 0:
        return 'Library';
      case 1:
        return 'Sessions';
      case 2:
        return 'Stats';
      case 3:
      default:
        return 'Settings';
    }
  }

  String _getFormattedDate(DateTime date, String format) {
    try {
      // Using DateFormat to format the date
      return DateFormat(format).format(date);
    } catch (e) {
      // In case of an invalid format, return a fallback
      return DateFormat('yyyy-MM-dd').format(date);
    }
  }

  static Map<int, String> ratingStyleNames = {
    0: "Stars",
    1: "Numbers",
  };

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
      if (row.length < 12) continue; // Skip invalid rows

      try {
        Book book = Book(
          id: row[0] ?? 0,
          title: row[1].toString(),
          author: row[2].toString(),
          wordCount: int.tryParse(row[3].toString()) ?? 0,
          pageCount: int.tryParse(row[4].toString()) ?? 0,
          rating: double.tryParse(row[5].toString()) ?? 0.0,
          isCompleted: row[6] == 1 || row[6] == 'true',
          isFavorite: row[7] == 1 || row[7] == 'true',
          bookTypeId: int.tryParse(row[8].toString()) ?? 0,
          dateAdded: DateTime.tryParse(row[9].toString())
                  ?.toIso8601String()
                  .split('T')[0] ??
              DateTime.now().toIso8601String().split('T')[0],
          dateStarted: row[10]?.toString().isNotEmpty == true
              ? DateTime.tryParse(row[10].toString())
                  ?.toIso8601String()
                  .split('T')[0]
              : null,
          dateFinished: row[11]?.toString().isNotEmpty == true
              ? DateTime.tryParse(row[11].toString())
                  ?.toIso8601String()
                  .split('T')[0]
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
        'is_favorite',
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
            book.isFavorite.toString(),
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

  static String _iconStyleToString(IconStyle style) {
    switch (style) {
      case IconStyle.animated:
        return 'Animated';
      case IconStyle.Default:
        return 'Standard';
      default:
        return 'Simple';
    }
  }
}
