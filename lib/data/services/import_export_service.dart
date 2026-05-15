import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import '../models/book.dart';
import '../models/session.dart';
import '../models/tag.dart';
import '../models/book_tag.dart';
import '../database/database_helper.dart';
import '../repositories/book_repository.dart';
import '../repositories/session_repository.dart';
import '../repositories/tag_repository.dart';
import '../utils/date_utils.dart';

class ImportExportResult {
  final bool success;
  final String message;
  const ImportExportResult({required this.success, required this.message});
}

class ImportExportService {
  final BookRepository bookRepository;
  final SessionRepository sessionRepository;
  final TagRepository tagRepository;

  ImportExportService({
    required this.bookRepository,
    required this.sessionRepository,
    required this.tagRepository,
  });

  // ─── DELETE ───────────────────────────────────────────────────────────────

  Future<ImportExportResult> deleteAllData() async {
    try {
      await bookRepository.deleteAllBooks();
      await tagRepository.deleteAllTags();
      return const ImportExportResult(success: true, message: 'All data deleted.');
    } catch (e) {
      if (kDebugMode) print('Delete error: $e');
      return ImportExportResult(success: false, message: 'Delete failed: $e');
    }
  }

  // ─── EXPORT ───────────────────────────────────────────────────────────────

  Future<ImportExportResult> exportDataToCSV() async {
    try {
      final books = await bookRepository.getBooks();
      final sessions = await sessionRepository.getSessions();
      final tags = await tagRepository.getAllTags();
      final bookTags = await tagRepository.getAllBookTagsForExport();

      final files = await Future.wait([
        _exportBooksToCSV(books),
        _exportSessionsToCSV(sessions),
        _exportTagsToCSV(tags),
        _exportBookTagsToCSV(bookTags),
      ]);

      await SharePlus.instance.share(ShareParams(
        files: files.map((path) => XFile(path)).toList(),
      ));

      return const ImportExportResult(success: true, message: 'Data exported successfully.');
    } catch (e) {
      if (kDebugMode) print('Export error: $e');
      return ImportExportResult(success: false, message: 'Export failed: $e');
    }
  }

  Future<String> _exportBooksToCSV(List<Book> books) async {
    final path = await _buildFilePath('books_data');
    final rows = [
      [
        'id', 'title', 'author', 'word_count', 'page_count', 'rating',
        'is_complete', 'is_favorite', 'book_type_id', 'date_added',
        'date_started', 'date_finished', 'isbn', 'user_review',
        'duration_minutes', 'shelf_id',
      ],
      ...books.map((b) => [
        b.id.toString(),
        b.title,
        b.author,
        b.wordCount.toString(),
        b.pageCount.toString(),
        b.rating?.toString() ?? '',
        b.isFinished.toString(),
        b.isFavorite.toString(),
        b.bookTypeId.toString(),
        b.dateAdded,
        b.dateStarted ?? '',
        b.dateFinished ?? '',
        b.isbn ?? '',
        b.userReview ?? '',
        b.durationMinutes.toString(),
        b.shelfId.toString(),
      ]),
    ];
    await _writeCSV(path, rows);
    return path;
  }

  Future<String> _exportSessionsToCSV(List<Session> sessions) async {
    final path = await _buildFilePath('sessions_data');
    final rows = [
      ['session_id', 'book_id', 'pages_read', 'duration_minutes', 'date', 'notes'],
      ...sessions.map((s) => [
        s.id.toString(),
        s.bookId.toString(),
        s.pagesRead.toString(),
        s.durationMinutes.toString(),
        s.date.toString(),
        s.notes ?? '',
      ]),
    ];
    await _writeCSV(path, rows);
    return path;
  }

  Future<String> _exportTagsToCSV(List<Tag> tags) async {
    final path = await _buildFilePath('tags_data');
    final rows = [
      ['id', 'name', 'color'],
      ...tags.map((t) => [
        t.id?.toString() ?? '',
        t.name,
        t.color.toString(),
      ]),
    ];
    await _writeCSV(path, rows);
    return path;
  }

  Future<String> _exportBookTagsToCSV(List<BookTag> bookTags) async {
    final path = await _buildFilePath('book_tags_data');
    final rows = [
      ['book_id', 'tag_id'],
      ...bookTags.map((bt) => [
        bt.bookId.toString(),
        bt.tagId.toString(),
      ]),
    ];
    await _writeCSV(path, rows);
    return path;
  }

  Future<String> _buildFilePath(String prefix) async {
    final dir = await getApplicationDocumentsDirectory();
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    return '${dir.path}/${prefix}_$stamp.csv';
  }

  Future<void> _writeCSV(String path, List<List<String>> rows) async {
    await File(path).writeAsString(const ListToCsvConverter().convert(rows));
  }

  // ─── IMPORT ───────────────────────────────────────────────────────────────

  Future<ImportExportResult> importBooksFromCSV() async {
    return _runImport('books', _parseAndInsertBooks, goodreads: false);
  }

  Future<ImportExportResult> importSessionsFromCSV() async {
    return _runImport('sessions', _parseAndInsertSessions, goodreads: false);
  }

  Future<ImportExportResult> importTagsFromCSV() async {
    return _runImport('tags', _parseAndInsertTags, goodreads: false);
  }

  Future<ImportExportResult> importBookTagsFromCSV() async {
    return _runImport('book_tags', _parseAndInsertBookTags, goodreads: false);
  }

  Future<ImportExportResult> importGoodreadsCSV() async {
    return _runImport('goodreads_books', _parseAndInsertGoodreadsBooks, goodreads: true);
  }

  Future<ImportExportResult> _runImport(
      String type,
      Future<int> Function(List<List<dynamic>>) parser, {
        required bool goodreads,
      }) async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result == null) {
        return const ImportExportResult(success: false, message: 'Cancelled.');
      }

      final csvString = await File(result.files.single.path!).readAsString();
      final rows = goodreads
          ? _parseGoodreadsCSV(csvString)
          : const CsvToListConverter().convert(csvString);

      if (rows.length <= 1) throw Exception('CSV has no data rows.');

      final rowsToProcess = goodreads ? rows : rows.skip(1).toList();
      final count = await parser(rowsToProcess);
      return ImportExportResult(
        success: true,
        message: 'Imported $count $type successfully.',
      );
    } catch (e) {
      if (kDebugMode) print('Import error ($type): $e');
      return ImportExportResult(success: false, message: 'Import failed: $e');
    }
  }

  List<List<dynamic>> _parseGoodreadsCSV(String csvString) {
    final raw = CsvToListConverter(
      eol: '\n',
      fieldDelimiter: ',',
      textDelimiter: '"',
      shouldParseNumbers: false,
    ).convert(csvString);

    return raw.map((row) => row.map((cell) {
      if (cell is String) {
        return cell.replaceAll(RegExp(r'^="|"$'), '').replaceAll('""', '"');
      }
      return cell;
    }).toList()).toList();
  }

  String? _nullableString(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    return (s.isEmpty || s == 'null') ? null : s;
  }

  Future<int> _parseAndInsertBooks(List<List<dynamic>> rows) async {
    final books = <Book>[];
    for (final row in rows) {
      if (row.length < 12) continue;
      try {
        // Legacy exports include is_complete at index 6. Use it only to
        // backfill date_finished when importing old CSVs that predate the
        // date_finished field.
        final wasComplete = row[6] == 1 || row[6].toString().toLowerCase() == 'true';
        final dateAdded = DateUtils.parseAndFormatDate(row[9].toString());
        final dateFinished = row[11]?.toString().isNotEmpty == true
            ? DateUtils.parseAndFormatOptionalDate(row[11].toString())
            : (wasComplete ? dateAdded : null);

        books.add(Book(
          id: row[0] ?? 0,
          title: row[1].toString(),
          author: row[2].toString(),
          wordCount: int.tryParse(row[3].toString()) ?? 0,
          pageCount: int.tryParse(row[4].toString()) ?? 0,
          rating: double.tryParse(row[5].toString()),
          isFavorite: row[7] == 1 || row[7].toString().toLowerCase() == 'true',
          bookTypeId: int.tryParse(row[8].toString()) ?? 0,
          dateAdded: dateAdded,
          dateStarted: row[10]?.toString().isNotEmpty == true
              ? DateUtils.parseAndFormatOptionalDate(row[10].toString())
              : null,
          dateFinished: dateFinished,
          isbn: row.length > 12 ? _nullableString(row[12]) : null,
          userReview: row.length > 13 ? _nullableString(row[13]) : null,
          durationMinutes: row.length > 14
              ? int.tryParse(row[14].toString()) ?? 0
              : 0,
          shelfId: row.length > 15
              ? int.tryParse(row[15].toString()) ?? DatabaseHelper.shelfWantToRead
              : DatabaseHelper.shelfWantToRead,
        ));
      } catch (e) {
        if (kDebugMode) print('Skipping book row: $e');
      }
    }
    if (books.isNotEmpty) await bookRepository.addBooksBatch(books);
    return books.length;
  }

  Future<int> _parseAndInsertSessions(List<List<dynamic>> rows) async {
    final sessions = <Session>[];
    for (final row in rows) {
      if (row.length < 5) continue;
      try {
        sessions.add(Session(
          id: int.tryParse(row[0].toString()) ?? 0,
          bookId: int.tryParse(row[1].toString()) ?? 0,
          pagesRead: int.tryParse(row[2].toString()) ?? 0,
          durationMinutes: int.tryParse(row[3].toString()) ?? 0,
          date: DateUtils.parseAndFormatDate(row[4].toString()),
          notes: row.length > 5 ? _nullableString(row[5]) : null,
        ));
      } catch (e) {
        if (kDebugMode) print('Skipping session row: $e');
      }
    }
    if (sessions.isNotEmpty) await sessionRepository.addSessionsBatch(sessions);
    return sessions.length;
  }

  Future<int> _parseAndInsertTags(List<List<dynamic>> rows) async {
    final tags = <Tag>[];
    for (final row in rows) {
      if (row.length < 3) continue;
      try {
        tags.add(Tag(
          id: int.tryParse(row[0].toString()),
          name: row[1].toString(),
          color: int.tryParse(row[2].toString()) ?? 0,
        ));
      } catch (e) {
        if (kDebugMode) print('Skipping tag row: $e');
      }
    }
    if (tags.isNotEmpty) await tagRepository.addTagsBatch(tags);
    return tags.length;
  }

  Future<int> _parseAndInsertBookTags(List<List<dynamic>> rows) async {
    final bookTags = <BookTag>[];
    for (final row in rows) {
      if (row.length < 2) continue;
      try {
        bookTags.add(BookTag(
          bookId: int.tryParse(row[0].toString()) ?? 0,
          tagId: int.tryParse(row[1].toString()) ?? 0,
        ));
      } catch (e) {
        if (kDebugMode) print('Skipping book_tag row: $e');
      }
    }
    if (bookTags.isNotEmpty) await tagRepository.addBookTagsBatch(bookTags);
    return bookTags.length;
  }

  Future<int> _parseAndInsertGoodreadsBooks(List<List<dynamic>> rows) async {
    if (rows.isEmpty) return 0;

    final header = rows.first.map((e) {
      return e.toString()
          .replaceAll(RegExp(r'^="|"$'), '')
          .replaceAll('""', '"')
          .trim();
    }).toList();

    final colIndex = <String, int>{
      for (var i = 0; i < header.length; i++) header[i]: i,
    };

    String? getString(List<dynamic> row, String name) {
      if (!colIndex.containsKey(name) || colIndex[name]! >= row.length) return null;
      return row[colIndex[name]!]?.toString()
          .replaceAll(RegExp(r'^="|"$'), '')
          .replaceAll('""', '"');
    }

    DateTime? parseGoodreadsDate(String? s) {
      if (s == null || s.isEmpty) return null;
      try {
        final parts = s.split('/');
        if (parts.length == 3) {
          return DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );
        }
      } catch (_) {}
      return null;
    }

    final books = <Book>[];
    for (final row in rows.skip(1)) {
      try {
        final r = row.map((cell) => cell is String
            ? cell.replaceAll(RegExp(r'^="|"$'), '').replaceAll('""', '"')
            : cell).toList();

        final isCompleted = getString(r, 'Date Read')?.isNotEmpty ?? false;
        final dateRead = parseGoodreadsDate(getString(r, 'Date Read'))
            ?.toIso8601String()
            .split('T')[0];

        books.add(Book(
          id: null,
          title: getString(r, 'Title') ?? 'Unknown',
          author: getString(r, 'Author') ?? 'Unknown',
          wordCount: 0,
          pageCount: int.tryParse(getString(r, 'Number of Pages') ?? '') ?? 0,
          rating: double.tryParse(getString(r, 'My Rating') ?? '') ?? 0.0,
          isFavorite: false,
          bookTypeId: _bookTypeIdFromBinding(getString(r, 'Binding') ?? ''),
          dateAdded: parseGoodreadsDate(getString(r, 'Date Added'))
              ?.toIso8601String()
              .split('T')[0] ??
              DateTime.now().toIso8601String().split('T')[0],
          dateStarted: isCompleted ? dateRead : null,
          dateFinished: isCompleted ? dateRead : null,
          isbn: getString(r, 'ISBN13'),
          userReview: getString(r, 'My Review'),
        ));
      } catch (e) {
        if (kDebugMode) print('Skipping Goodreads row: $e');
      }
    }

    if (books.isNotEmpty) await bookRepository.addBooksBatch(books);
    return books.length;
  }

  int _bookTypeIdFromBinding(String binding) {
    final b = binding.toLowerCase();
    if (['audible audio', 'audio cassette', 'audio cd', 'audiobook'].contains(b)) return 4;
    if (['kindle edition', 'nook', 'ebook', 'digital', 'epub', 'pdf', 'mobi'].contains(b)) return 3;
    if (['hardcover', 'board book', 'library binding', 'leather bound', 'hardback'].contains(b)) return 2;
    return 1;
  }
}