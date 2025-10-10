import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:stylish_bottom_bar/stylish_bottom_bar.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app_config.dart';
import '../../../data/models/tag.dart';
import '../../../data/models/book_tag.dart';
import '../../../data/repositories/tag_repository.dart';
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
  final TagRepository tagRepository;
  final Function() refreshBooks;
  final Function() refreshSessions;
  final SettingsViewModel settingsViewModel;

  const SettingsPage({
    super.key,
    required this.toggleTheme,
    required this.themeMode,
    required this.bookRepository,
    required this.sessionRepository,
    required this.tagRepository,
    required this.refreshBooks,
    required this.refreshSessions,
    required this.settingsViewModel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: false,
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
                onTap: () => showThemeModePicker(context, settingsViewModel, toggleTheme),
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
                    builder: (context) => FontSelectionPage(settingsViewModel: settingsViewModel),
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
                  builder: (context, value, _) => Text(
                    _iconStyleToString(value),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
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
                  builder: (context, type, _) => Text(
                    bookTypeNames[type] ?? "Unknown",
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                onTap: () => showBookTypePicker(context, settingsViewModel),
              ),
              _buildSettingsTile(
                context,
                title: 'Rating Style',
                trailing: ValueListenableBuilder<int>(
                  valueListenable: settingsViewModel.defaultRatingStyleNotifier,
                  builder: (context, style, _) => Text(
                    ratingStyleNames[style] ?? "Unknown",
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                onTap: () => showRatingStylePicker(context, settingsViewModel),
              ),
              _buildSettingsTile(
                context,
                title: 'Default Tab',
                trailing: ValueListenableBuilder<int>(
                  valueListenable: settingsViewModel.defaultTabNotifier,
                  builder: (context, index, _) => Text(
                    _getTabName(index),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
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
                title: 'Import Goodreads data',
                onTap: _importBooksFromGoodreadsCSV,
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
                title: 'Import Tags from CSV',
                onTap: _importTagsFromCSV,
              ),
              _buildSettingsTile(
                context,
                title: 'Import Book Tags from CSV',
                onTap: _importBookTagsFromCSV,
              ),
              _buildSettingsTile(
                context,
                title: 'Delete All Data',
                textColor: colors.error,
                onTap: () => _confirmDeleteData(context),
              ),
            ],
          ),

          _buildSettingsSection(
            context,
            header: 'About',
            children: [
              _buildSettingsTile(
                context,
                title: 'Join our Discord',
                onTap: () => _launchUrl('https://discord.gg/cA6CDkUY4x'),
              ),
              _buildSettingsTile(
                context,
                title: 'GitHub',
                onTap: () => _launchUrl('https://github.com/tyshoe/ReadStats'),
              ),
              _buildSettingsTile(
                context,
                title: 'App Version',
                trailing: Text(
                  (AppConfig.version),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
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
        style: TextStyle(color: textColor ?? Theme.of(context).colorScheme.onSurface),
      ),
      trailing: trailing,
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      throw Exception('Could not launch $url');
    }
  }

  void _confirmDeleteData(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete All Data?'),
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
              await tagRepository.deleteAllTags();
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
      return DateFormat(format).format(date);
    } catch (e) {
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

  Future<void> _importTagsFromCSV() async {
    await _importCSV('tags', _importTags);
  }

  Future<void> _importBookTagsFromCSV() async {
    await _importCSV('book_tags', _importBookTags);
  }

  Future<void> _importBooksFromGoodreadsCSV() async {
    await _importGoodreadsCSV('goodreads_books', _importGoodreadsBooks);
  }

  Future<void> _importCSV(
      String type, Future<void> Function(List<List<dynamic>>) importFunction) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        // allowedExtensions: ['csv'],
      );

      if (result == null) return; // User canceled

      String filePath = result.files.single.path!;
      final file = File(filePath);
      String csvString = await file.readAsString();

      List<List<dynamic>> csvData = const CsvToListConverter().convert(csvString);

      if (csvData.length <= 1) {
        throw Exception('CSV has no data rows.');
      }

      // Always skip header row for now
      await importFunction(csvData.skip(1).toList());

      if (kDebugMode) {
        print('CSV import for $type completed. Rows: ${csvData.length - 1}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error importing CSV for $type: $e');
      }
    }
  }

  Future<void> _importGoodreadsCSV(
      String type, Future<void> Function(List<List<dynamic>>) importFunction) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        // allowedExtensions: ['csv'],
      );

      if (result == null) return; // User canceled

      String filePath = result.files.single.path!;
      final file = File(filePath);
      String csvString = await file.readAsString();

      // Convert CSV
      List<List<dynamic>> csvData = const CsvToListConverter(
        eol: '\n',
        fieldDelimiter: ',',
        textDelimiter: '"',
        shouldParseNumbers: false,
      ).convert(csvString);

      if (csvData.length <= 1) throw Exception('CSV has no data rows.');

      // Clean rows: remove ="" wrapping (Goodreads export quirk)
      List<List<dynamic>> cleanedData = csvData.map((row) {
        return row.map((cell) {
          if (cell is String) {
            // Remove leading ="" and trailing ""
            cell = cell.replaceAll(RegExp(r'^="|"$'), '');
            cell = cell.replaceAll('""', '"'); // Replace double quotes with single
          }
          return cell;
        }).toList();
      }).toList();

      // Skip header row
      await importFunction(cleanedData.toList());

      if (kDebugMode) {
        print('Goodreads CSV import for $type completed. Rows: ${cleanedData.length - 1}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error importing Goodreads CSV for $type: $e');
      }
    }
  }

  String parseAndFormatDate(String dateString) {
    DateTime? parsedDate;

    // Parse the date string
    if (dateString.contains('T')) {
      // Already in ISO format
      parsedDate = DateTime.tryParse(dateString);
    } else if (dateString.contains(' ')) {
      // Format: "2025-02-08 0:00:00" or "2025-09-24 16:18:55"
      // Convert space to 'T' and add milliseconds
      String isoString = dateString.replaceFirst(' ', 'T');
      if (!isoString.contains('.')) {
        isoString += '.000';
      }
      parsedDate = DateTime.tryParse(isoString);
    } else {
      // Format: "2025-02-09" - add time and milliseconds
      parsedDate = DateTime.tryParse('${dateString}T00:00:00.000');
    }

    // If parsing failed, try direct parsing as fallback
    parsedDate ??= DateTime.tryParse(dateString);

    // Return formatted date or current date if parsing fails
    if (parsedDate != null) {
      return parsedDate.toIso8601String();
    } else {
      return DateTime.now().toIso8601String();
    }
  }

  String? parseAndFormatOptionalDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return null;

    DateTime? parsedDate;

    // Parse the date string
    if (dateString.contains('T')) {
      // Already in ISO format
      parsedDate = DateTime.tryParse(dateString);
    } else if (dateString.contains(' ')) {
      // Format: "2025-02-08 0:00:00" or "2025-09-24 16:18:55"
      // Convert space to 'T' and add milliseconds
      String isoString = dateString.replaceFirst(' ', 'T');
      if (!isoString.contains('.')) {
        isoString += '.000';
      }
      parsedDate = DateTime.tryParse(isoString);
    } else {
      // Format: "2025-02-09" - add time and milliseconds
      parsedDate = DateTime.tryParse('${dateString}T00:00:00.000');
    }

    // If parsing failed, try direct parsing as fallback
    parsedDate ??= DateTime.tryParse(dateString);

    // Return formatted date or null if parsing fails
    return parsedDate?.toIso8601String();
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
          rating: double.tryParse(row[5].toString()),
          isCompleted: row[6] == 1 || row[6] == 'true',
          isFavorite: row[7] == 1 || row[7] == 'true',
          bookTypeId: int.tryParse(row[8].toString()) ?? 0,
          dateAdded: parseAndFormatDate(row[9].toString()),
          dateStarted: row[10]?.toString().isNotEmpty == true
              ? parseAndFormatOptionalDate(row[10].toString())
              : null,
          dateFinished: row[11]?.toString().isNotEmpty == true
              ? parseAndFormatOptionalDate(row[11].toString())
              : null,
        );
        booksToInsert.add(book);
      } catch (e) {
        if (kDebugMode) print('Error processing row: $row. Error: $e');
      }
    }

    if (booksToInsert.isNotEmpty) {
      await bookRepository.addBooksBatch(booksToInsert); // Use batch insert
      if (kDebugMode) {
        print('Batch book insert complete. ${booksToInsert.length} books added. $booksToInsert');
      }
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
            date: parseAndFormatDate(row[4].toString()),
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

  Future<void> _importTags(List<List<dynamic>> rows) async {
    List<Tag> tagsToInsert = [];

    for (var row in rows) {
      if (row.length < 3) continue; // id, name, color
      try {
        tagsToInsert.add(
          Tag(
            id: int.tryParse(row[0].toString()),
            name: row[1].toString(),
            color: int.tryParse(row[2].toString()) ?? 0,
          ),
        );
      } catch (e) {
        if (kDebugMode) print('Error processing tag row: $row. Error: $e');
      }
    }

    if (tagsToInsert.isNotEmpty) {
      await tagRepository.addTagsBatch(tagsToInsert);
    }
  }

  Future<void> _importBookTags(List<List<dynamic>> rows) async {
    List<BookTag> bookTagsToInsert = [];

    for (var row in rows) {
      if (row.length < 2) continue; // book_id, tag_id
      try {
        bookTagsToInsert.add(
          BookTag(
            bookId: int.tryParse(row[0].toString()) ?? 0,
            tagId: int.tryParse(row[1].toString()) ?? 0,
          ),
        );
      } catch (e) {
        if (kDebugMode) print('Error processing book_tag row: $row. Error: $e');
      }
    }

    if (bookTagsToInsert.isNotEmpty) {
      await tagRepository.addBookTagsBatch(bookTagsToInsert);
    }
  }

  Future<void> _importGoodreadsBooks(List<List<dynamic>> rows) async {
    if (rows.isEmpty) return;

    // Clean the header row
    final cleanedHeader = rows.first.map((e) {
      String header = e.toString();
      header = header.replaceAll(RegExp(r'^="|"$'), '');
      header = header.replaceAll('""', '"');
      return header.trim();
    }).toList();

    final colIndex = <String, int>{};
    for (var i = 0; i < cleanedHeader.length; i++) {
      colIndex[cleanedHeader[i]] = i;
    }

    List<Book> booksToInsert = [];

    String? getString(List<dynamic> row, String name) {
      if (!colIndex.containsKey(name) || colIndex[name]! >= row.length) return null;
      var value = row[colIndex[name]!]?.toString();
      if (value != null) {
        value = value.replaceAll(RegExp(r'^="|"$'), '');
        value = value.replaceAll('""', '"');
      }
      return value;
    }

    int? getInt(List<dynamic> row, String name) {
      final value = getString(row, name);
      if (value == null || value.isEmpty) return null;
      return int.tryParse(value);
    }

    double? getDouble(List<dynamic> row, String name) {
      final value = getString(row, name);
      if (value == null || value.isEmpty) return null;
      return double.tryParse(value);
    }

    DateTime? parseGoodreadsDate(String? dateString) {
      if (dateString == null || dateString.isEmpty) return null;
      try {
        final parts = dateString.split('/');
        if (parts.length == 3) {
          return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        }
      } catch (_) {}
      return null;
    }

    for (var row in rows.skip(1)) {
      try {
        final cleanedRow = row.map((cell) {
          if (cell is String) {
            String cleaned = cell.replaceAll(RegExp(r'^="|"$'), '');
            cleaned = cleaned.replaceAll('""', '"');
            return cleaned;
          }
          return cell;
        }).toList();

        bool isCompleted = (getString(cleanedRow, 'Date Read')?.isNotEmpty ?? false);
        String? binding = getString(cleanedRow, 'Binding');
        String? title = getString(cleanedRow, 'Title');
        String? author = getString(cleanedRow, 'Author');

        Book book = Book(
          id: null,
          title: title ?? 'Unknown',
          author: author ?? 'Unknown',
          wordCount: 0,
          pageCount: getInt(cleanedRow, 'Number of Pages') ?? 0,
          rating: getDouble(cleanedRow, 'My Rating') ?? 0.0,
          isCompleted: isCompleted,
          isFavorite: false,
          bookTypeId: getBookTypeIdFromBinding(binding ?? ''),
          dateAdded: parseGoodreadsDate(getString(cleanedRow, 'Date Added'))
                  ?.toIso8601String()
                  .split('T')[0] ??
              DateTime.now().toIso8601String().split('T')[0],
          dateStarted: isCompleted
              ? parseGoodreadsDate(getString(cleanedRow, 'Date Read'))
                  ?.toIso8601String()
                  .split('T')[0]
              : null,
          dateFinished: isCompleted
              ? parseGoodreadsDate(getString(cleanedRow, 'Date Read'))
                  ?.toIso8601String()
                  .split('T')[0]
              : null,
        );

        booksToInsert.add(book);
      } catch (e) {
        if (kDebugMode) print('Error processing row: $e');
      }
    }

    if (booksToInsert.isNotEmpty) {
      await bookRepository.addBooksBatch(booksToInsert);
      if (kDebugMode) print('Imported ${booksToInsert.length} books from Goodreads');
    }

    refreshBooks();
  }

  int getBookTypeIdFromBinding(String binding) {
    final bindingLower = binding.toLowerCase();

    // Audiobook formats
    if (bindingLower == 'audible audio' ||
        bindingLower == 'audio cassette' ||
        bindingLower == 'audio cd' ||
        bindingLower == 'audiobook') {
      return 4; // Audiobook
    }

    // Ebook formats
    else if (bindingLower == 'kindle edition' ||
        bindingLower == 'nook' ||
        bindingLower == 'ebook' ||
        bindingLower == 'digital' ||
        bindingLower == 'epub' ||
        bindingLower == 'pdf' ||
        bindingLower == 'mobi') {
      return 3; // Ebook
    }

    // Paperback formats
    else if (bindingLower == 'mass market paperback' ||
        bindingLower == 'paperback' ||
        bindingLower == 'chapbook' ||
        bindingLower == 'trade paperback' ||
        bindingLower == 'pocket book' ||
        bindingLower == 'softcover') {
      return 1; // Paperback
    }

    // Hardcover formats
    else if (bindingLower == 'hardcover' ||
        bindingLower == 'board book' ||
        bindingLower == 'library binding' ||
        bindingLower == 'leather bound' ||
        bindingLower == 'hardback') {
      return 2; // Hardcover
    }

    // Other physical formats
    else if (bindingLower == 'spiral bound' ||
        bindingLower == 'ring bound' ||
        bindingLower == 'comic' ||
        bindingLower == 'graphic novel' ||
        bindingLower == 'magazine') {
      return 1; // Default to paperback for other physical formats
    }

    // Default to paperback for unknown formats
    else {
      return 1; // Paperback
    }
  }

  Future<void> exportDataToCSV() async {
    try {
      // Call the export functions and store file paths
      String booksFilePath = await exportBooksToCSV(await bookRepository.getBooks());
      String sessionsFilePath = await exportSessionsToCSV(await sessionRepository.getSessions());
      String tagsFilePath = await exportTagsToCSV(await tagRepository.getAllTags());
      String bookTagsFilePath =
          await exportBookTagsToCSV(await tagRepository.getAllBookTagsForExport());

      if (kDebugMode) {
        print('Books data exported to: $booksFilePath');
        print('Sessions data exported to: $sessionsFilePath');
        print('Tags data exported to: $tagsFilePath');
        print('Book-Tags data exported to: $bookTagsFilePath');
      }
      await SharePlus.instance.share(ShareParams(files: [
        XFile(booksFilePath),
        XFile(sessionsFilePath),
        XFile(tagsFilePath),
        XFile(bookTagsFilePath),
      ]));

      if (kDebugMode) {
        print('All data exported successfully!');
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

  // Function to export tags data to CSV
  Future<String> exportTagsToCSV(List<Tag> tagsData) async {
    String formattedDate = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/tags_data_$formattedDate.csv';

    List<List<String>> rows = [
      ['id', 'name', 'color'], // Column headers
      ...tagsData.map((tag) => [
            tag.id?.toString() ?? '', // Handle nullable id
            tag.name,
            tag.color.toString(), // Or use toRadixString(16) for hex format
          ])
    ];

    String csv = const ListToCsvConverter().convert(rows);
    final file = File(filePath);
    await file.writeAsString(csv);

    return filePath;
  }

// Function to export book_tags data to CSV
  Future<String> exportBookTagsToCSV(List<BookTag> bookTagsData) async {
    String formattedDate = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/book_tags_data_$formattedDate.csv';

    List<List<String>> rows = [
      ['book_id', 'tag_id'], // Column headers
      ...bookTagsData.map((bookTag) => [
            bookTag.bookId.toString(),
            bookTag.tagId.toString(),
          ])
    ];

    String csv = const ListToCsvConverter().convert(rows);
    final file = File(filePath);
    await file.writeAsString(csv);

    return filePath;
  }
}
