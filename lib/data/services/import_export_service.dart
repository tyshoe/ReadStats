import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
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
import '../repositories/goal_repository.dart';
import '../utils/date_utils.dart';
import 'cover_service.dart';

class ImportExportResult {
  final bool success;
  final String message;
  const ImportExportResult({required this.success, required this.message});
}

class ImportExportService {
  final BookRepository bookRepository;
  final SessionRepository sessionRepository;
  final TagRepository tagRepository;
  final GoalRepository goalRepository;

  ImportExportService({
    required this.bookRepository,
    required this.sessionRepository,
    required this.tagRepository,
    required this.goalRepository,
  });

  // ─── DELETE ───────────────────────────────────────────────────────────────

  Future<ImportExportResult> deleteAllData() async {
    try {
      await bookRepository.deleteAllBooks();
      await tagRepository.deleteAllTags();
      await goalRepository.deleteAllGoals();
      return const ImportExportResult(success: true, message: 'All data deleted.');
    } catch (e) {
      if (kDebugMode) print('Delete error: $e');
      return ImportExportResult(success: false, message: 'Delete failed: $e');
    }
  }

  // ─── EXPORT ───────────────────────────────────────────────────────────────

  /// Export everything — the four data CSVs plus every cover image — as a
  /// single zip. Bundling the images is what lets covers survive an uninstall:
  /// the CSVs only reference cover filenames, they don't contain the pixels.
  Future<ImportExportResult> exportBackup() async {
    try {
      final books = await bookRepository.getBooks();
      final sessions = await sessionRepository.getSessions();
      final tags = await tagRepository.getAllTags();
      final bookTags = await tagRepository.getAllBookTagsForExport();

      final archive = Archive();
      void addCsv(String name, List<List<String>> rows) {
        final bytes =
            utf8.encode(const ListToCsvConverter().convert(rows));
        archive.addFile(ArchiveFile('$name.csv', bytes.length, bytes));
      }

      addCsv('books_data', _booksCsvRows(books));
      addCsv('sessions_data', _sessionsCsvRows(sessions));
      addCsv('tags_data', _tagsCsvRows(tags));
      addCsv('book_tags_data', _bookTagsCsvRows(bookTags));

      var coverCount = 0;
      final coversDir = await CoverService.coversDirectory();
      if (await coversDir.exists()) {
        await for (final entity in coversDir.list()) {
          if (entity is! File) continue;
          final bytes = await entity.readAsBytes();
          archive.addFile(ArchiveFile(
              'covers/${p.basename(entity.path)}', bytes.length, bytes));
          coverCount++;
        }
      }

      final zipBytes = ZipEncoder().encode(archive);
      if (zipBytes == null) throw Exception('Failed to encode backup zip.');

      final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final tempDir = await getTemporaryDirectory();
      final zipPath = p.join(tempDir.path, 'readstats_backup_$stamp.zip');
      await File(zipPath).writeAsBytes(zipBytes);

      await SharePlus.instance.share(ShareParams(files: [XFile(zipPath)]));

      return ImportExportResult(
        success: true,
        message:
            'Backup exported: ${books.length} books, $coverCount covers.',
      );
    } catch (e) {
      if (kDebugMode) print('Export error: $e');
      return ImportExportResult(success: false, message: 'Export failed: $e');
    }
  }

  List<List<String>> _booksCsvRows(List<Book> books) {
    return [
      [
        'id', 'title', 'author', 'word_count', 'page_count', 'rating',
        'is_complete', 'is_favorite', 'book_type_id', 'date_added',
        'date_started', 'date_finished', 'isbn', 'user_review',
        'duration_minutes', 'shelf_id', 'cover_path', 'open_library_key',
        'cover_shape', 'narrator',
      ],
      ...books.map((b) => [
        b.id.toString(),
        b.title,
        b.author,
        b.wordCount?.toString() ?? '',
        b.pageCount?.toString() ?? '',
        b.rating?.toString() ?? '',
        b.isFinished.toString(),
        b.isFavorite.toString(),
        b.bookTypeId.toString(),
        b.dateAdded,
        b.dateStarted ?? '',
        b.dateFinished ?? '',
        b.isbn ?? '',
        b.userReview ?? '',
        b.durationMinutes?.toString() ?? '',
        b.shelfId.toString(),
        // Filename only — absolute paths are device-specific and would be
        // meaningless after a reinstall or on another device.
        b.coverPath == null ? '' : p.basename(b.coverPath!),
        b.openLibraryKey ?? '',
        // Appended last so older exports, which stop at open_library_key, still
        // line up column-for-column on import.
        b.coverShape.toString(),
        b.narrator ?? '',
      ]),
    ];
  }

  List<List<String>> _sessionsCsvRows(List<Session> sessions) {
    return [
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
  }

  List<List<String>> _tagsCsvRows(List<Tag> tags) {
    return [
      ['id', 'name', 'color'],
      ...tags.map((t) => [
        t.id?.toString() ?? '',
        t.name,
        t.color.toString(),
      ]),
    ];
  }

  List<List<String>> _bookTagsCsvRows(List<BookTag> bookTags) {
    return [
      ['book_id', 'tag_id'],
      ...bookTags.map((bt) => [
        bt.bookId.toString(),
        bt.tagId.toString(),
      ]),
    ];
  }

  // ─── IMPORT ───────────────────────────────────────────────────────────────

  /// Restore a backup zip produced by [exportBackup]: cover images are copied
  /// back into the covers directory and all four CSVs are imported. Also
  /// accepts a legacy books CSV from the old CSV-only export.
  Future<ImportExportResult> importBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result == null) {
        return const ImportExportResult(success: false, message: 'Cancelled.');
      }

      final path = result.files.single.path!;
      if (p.extension(path).toLowerCase() != '.zip') {
        // Legacy export: a lone CSV from the old per-type export. Detect
        // which table it holds from the header row (no images back then).
        return _importLegacyCsv(await File(path).readAsString());
      }

      final archive = ZipDecoder().decodeBytes(await File(path).readAsBytes());

      // Restore cover images first so books display them as soon as the rows
      // land.
      var coverCount = 0;
      final coversDir = await CoverService.coversDirectory();
      for (final file in archive.files) {
        if (!file.isFile) continue;
        final name = file.name.replaceAll('\\', '/');
        if (!name.startsWith('covers/')) continue;
        final base = p.basename(name);
        if (base.isEmpty) continue;
        await File(p.join(coversDir.path, base))
            .writeAsBytes(file.content as List<int>);
        coverCount++;
      }

      List<List<dynamic>> csvRows(String prefix) {
        for (final file in archive.files) {
          final base = p.basename(file.name.replaceAll('\\', '/'));
          if (file.isFile &&
              base.startsWith(prefix) &&
              base.endsWith('.csv')) {
            final rows = const CsvToListConverter()
                .convert(utf8.decode(file.content as List<int>));
            return rows.length <= 1 ? const [] : rows.skip(1).toList();
          }
        }
        return const [];
      }

      // Books and tags first — sessions and book_tags reference them by id.
      final booksCount = await _parseAndInsertBooks(csvRows('books_data'));
      final tagsCount = await _parseAndInsertTags(csvRows('tags_data'));
      final sessionsCount =
          await _parseAndInsertSessions(csvRows('sessions_data'));
      await _parseAndInsertBookTags(csvRows('book_tags_data'));

      return ImportExportResult(
        success: true,
        message: 'Restored $booksCount books, $sessionsCount sessions, '
            '$tagsCount tags, $coverCount covers.',
      );
    } catch (e) {
      if (kDebugMode) print('Import error (backup): $e');
      return ImportExportResult(success: false, message: 'Restore failed: $e');
    }
  }

  /// Import a single CSV from the old per-type export, identifying the table
  /// by its header row.
  Future<ImportExportResult> _importLegacyCsv(String csvString) async {
    final rows = const CsvToListConverter().convert(csvString);
    if (rows.length <= 1) throw Exception('CSV has no data rows.');

    final header =
        rows.first.map((c) => c.toString().trim().toLowerCase()).toSet();
    final data = rows.skip(1).toList();

    final int count;
    final String type;
    if (header.contains('session_id')) {
      count = await _parseAndInsertSessions(data);
      type = 'sessions';
    } else if (header.contains('title') && header.contains('author')) {
      count = await _parseAndInsertBooks(data);
      type = 'books';
    } else if (header.contains('color')) {
      count = await _parseAndInsertTags(data);
      type = 'tags';
    } else if (header.contains('book_id') && header.contains('tag_id')) {
      count = await _parseAndInsertBookTags(data);
      type = 'book tags';
    } else {
      throw Exception('Unrecognized CSV format — expected a ReadStats export.');
    }

    return ImportExportResult(
      success: true,
      message: 'Imported $count $type.',
    );
  }

  Future<ImportExportResult> importGoodreadsCSV() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result == null) {
        return const ImportExportResult(success: false, message: 'Cancelled.');
      }

      final csvString = await File(result.files.single.path!).readAsString();
      final rows = _parseGoodreadsCSV(csvString);
      if (rows.length <= 1) throw Exception('CSV has no data rows.');

      final count = await _parseAndInsertGoodreadsBooks(rows);
      return ImportExportResult(
        success: true,
        message: 'Imported $count books successfully.',
      );
    } catch (e) {
      if (kDebugMode) print('Import error (goodreads): $e');
      return ImportExportResult(success: false, message: 'Import failed: $e');
    }
  }

  // ─── BOOKMORY IMPORT ───────────────────────────────────────────────────────

  /// Import books from a Bookmory backup. The picked `.bookmory` file is a zip
  /// whose portable data lives in `bookmory.db` — a sembast text database where
  /// the first line is metadata and every other line is one JSON record
  /// `{"key":…,"store":…,"value":{…}}`. We only read the `books` store (plus
  /// `collections`, to resolve the "Favorite" collection). Sessions and notes
  /// are intentionally not imported. Cover images are best-effort: Bookmory
  /// stores only a URL, so each is re-downloaded and any failures are skipped.
  Future<ImportExportResult> importBookmory() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result == null) {
        return const ImportExportResult(success: false, message: 'Cancelled.');
      }

      final bytes = await File(result.files.single.path!).readAsBytes();

      // A .bookmory file is a zip (PK magic); extracted, it's the raw db text.
      String? dbText;
      final isZip = bytes.length >= 2 && bytes[0] == 0x50 && bytes[1] == 0x4B;
      if (isZip) {
        final archive = ZipDecoder().decodeBytes(bytes);
        for (final f in archive.files) {
          if (f.isFile &&
              p.basename(f.name.replaceAll('\\', '/')) == 'bookmory.db') {
            dbText = utf8.decode(f.content as List<int>);
            break;
          }
        }
        if (dbText == null) {
          throw Exception(
              'Not a Bookmory Database backup. In Bookmory, export using the '
              '"Database" (.bookmory) format.');
        }
      } else {
        dbText = utf8.decode(bytes);
      }

      return await _parseAndInsertBookmory(dbText);
    } catch (e) {
      if (kDebugMode) print('Import error (bookmory): $e');
      return ImportExportResult(success: false, message: 'Import failed: $e');
    }
  }

  Future<ImportExportResult> _parseAndInsertBookmory(String dbText) async {
    final books = <Map<String, dynamic>>[];
    final collectionNames = <String, String>{}; // key → name

    for (final raw in const LineSplitter().convert(dbText)) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      Map<String, dynamic> rec;
      try {
        final decoded = jsonDecode(line);
        if (decoded is! Map<String, dynamic>) continue;
        rec = decoded;
      } catch (_) {
        continue; // meta line or malformed row
      }
      final store = rec['store'];
      final value = rec['value'];
      if (store == 'books' && value is Map) {
        books.add(Map<String, dynamic>.from(value));
      } else if (store == 'collections' && value is Map) {
        collectionNames[rec['key'].toString()] =
            (value['name'] ?? '').toString();
      }
    }

    if (books.isEmpty) {
      throw Exception(
          'No books found. In Bookmory, export using the "Database" '
          '(.bookmory) format.');
    }

    var inserted = 0;
    var covers = 0;
    for (final b in books) {
      try {
        final book = _bookFromBookmory(b, collectionNames);
        final id = await bookRepository.addBook(book);
        book.id = id;
        await _attachBookmoryTags(id, b['tags']);

        // Covers are best-effort: Bookmory only keeps a URL, so re-download
        // and persist it locally; a failed/blocked URL just leaves no cover.
        final url = _nullableString(b['image']);
        if (url != null && url.startsWith('http')) {
          final file = await CoverService.downloadFromUrl(url);
          if (file != null) {
            book.coverPath = await CoverService.saveFromPath(id, file.path);
            await bookRepository.updateBook(book);
            covers++;
          }
        }
        inserted++;
      } catch (e) {
        if (kDebugMode) print('Skipping Bookmory book: $e');
      }
    }

    return ImportExportResult(
      success: true,
      message: 'Imported $inserted books, $covers covers from Bookmory.',
    );
  }

  Book _bookFromBookmory(
      Map<String, dynamic> b, Map<String, String> collectionNames) {
    final reads = (b['reads'] as List?) ?? const [];
    final Map? lastRead = reads.isNotEmpty ? reads.last as Map : null;

    // Rating: last read's stars (fall back to book level). Bookmory writes 0.0
    // for unrated books, so treat only a positive value as a real rating.
    double? rating;
    final star = lastRead?['star'] ?? b['last_read_done_star'];
    if (star is num && star > 0) rating = star.toDouble();

    // Duration: sum every timed sitting (elapsed_sec) across all reads.
    var totalSec = 0;
    for (final r in reads) {
      final timers = (r as Map)['read_timer_list'] as List? ?? const [];
      for (final t in timers) {
        final sec = (t as Map)['elapsed_sec'];
        if (sec is num) totalSec += sec.toInt();
      }
    }

    final status = _bookmoryStatus(b);
    final shelfId = switch (status) {
      'DONE' => DatabaseHelper.shelfFinished,
      'READING' => DatabaseHelper.shelfCurrentlyReading,
      'GIVE_UP' => DatabaseHelper.shelfUnfinished,
      _ => DatabaseHelper.shelfWantToRead,
    };

    return Book(
      title: (b['title'] ?? 'Unknown').toString(),
      author: _bookmoryAuthor(b),
      wordCount: 0,
      pageCount: _asInt(b['real_total_page']) ?? _asInt(b['total_page']),
      rating: rating,
      isFavorite: _bookmoryIsFavorite(b, collectionNames),
      bookTypeId: _bookTypeIdFromBookmory(b['book_type']?.toString()),
      dateAdded: _bookmoryDate(b['created_at']) ?? _todayIso(),
      dateStarted: _bookmoryDate(b['first_read_start_date']),
      dateFinished:
          status == 'DONE' ? _bookmoryDate(b['last_read_done_date']) : null,
      isbn: _nullableString(b['isbn']),
      userReview: _nullableString(lastRead?['comment']),
      durationMinutes: totalSec > 0 ? (totalSec / 60).round() : null,
      shelfId: shelfId,
    );
  }

  String _bookmoryAuthor(Map<String, dynamic> b) {
    final authors = (b['authors'] as List?)
            ?.map((e) => e.toString().trim())
            .where((s) => s.isNotEmpty)
            .toList() ??
        const [];
    if (authors.isNotEmpty) return authors.join(', ');
    return _nullableString(b['author']) ?? 'Unknown';
  }

  String _bookmoryStatus(Map<String, dynamic> b) {
    final list = b['status_list'] as List?;
    if (list != null && list.isNotEmpty) return list.last.toString();
    final reads = b['reads'] as List?;
    if (reads != null && reads.isNotEmpty) {
      return ((reads.last as Map)['status'] ?? '').toString();
    }
    return b['wishlist'] == true ? 'WISHLIST' : '';
  }

  bool _bookmoryIsFavorite(
      Map<String, dynamic> b, Map<String, String> collectionNames) {
    final keys = (b['collection_keys'] as List?) ?? const [];
    for (final k in keys) {
      if (collectionNames[k.toString()]?.toLowerCase() == 'favorite') {
        return true;
      }
    }
    return false;
  }

  int _bookTypeIdFromBookmory(String? t) {
    switch (t) {
      case 'audioBook':
        return 4;
      case 'eBook':
        return 3;
      case 'hardCover':
        return 2;
      case 'paperBook':
      default:
        return 1;
    }
  }

  /// Look up an existing tag by exact (case-insensitive) name or create it,
  /// then link it to [bookId]. Bookmory stores tags as a `#a #b` string.
  Future<void> _attachBookmoryTags(int bookId, dynamic tagsField) async {
    if (tagsField == null) return;
    final names = tagsField
        .toString()
        .split(RegExp(r'\s+'))
        .map((t) => t.replaceFirst('#', '').trim())
        .where((t) => t.isNotEmpty)
        .toSet();

    for (final name in names) {
      int? tagId = await _findTagIdByName(name);
      tagId ??= await () async {
        try {
          return await tagRepository.createTag(Tag(name: name));
        } on TagAlreadyExistsException {
          return await _findTagIdByName(name);
        }
      }();
      if (tagId != null) await tagRepository.addTagToBook(bookId, tagId);
    }
  }

  Future<int?> _findTagIdByName(String name) async {
    // searchTags is a LIKE match, so narrow to an exact case-insensitive hit.
    final matches = await tagRepository.searchTags(name);
    for (final t in matches) {
      if (t.name.toLowerCase() == name.toLowerCase()) return t.id;
    }
    return null;
  }

  String? _bookmoryDate(dynamic ms) {
    if (ms is! num) return null;
    final v = ms.toInt();
    if (v <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(v)
        .toIso8601String()
        .split('T')[0];
  }

  String _todayIso() => DateTime.now().toIso8601String().split('T')[0];

  int? _asInt(dynamic v) =>
      v is num ? v.toInt() : int.tryParse(v?.toString() ?? '');

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
          wordCount: int.tryParse(row[3].toString()),
          pageCount: int.tryParse(row[4].toString()),
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
              ? int.tryParse(row[14].toString())
              : null,
          shelfId: row.length > 15
              ? int.tryParse(row[15].toString()) ?? DatabaseHelper.shelfWantToRead
              : DatabaseHelper.shelfWantToRead,
          // Older exports stored absolute paths; keep only the filename so it
          // resolves against this device's covers directory.
          coverPath: row.length > 16 && _nullableString(row[16]) != null
              ? p.basename(_nullableString(row[16])!)
              : null,
          openLibraryKey: row.length > 17 ? _nullableString(row[17]) : null,
          // Absent from exports made before cover shapes existed — those covers
          // were all cropped 2:3, which is what portrait means.
          coverShape: row.length > 18
              ? int.tryParse(row[18].toString()) ??
                  DatabaseHelper.coverShapePortrait
              : DatabaseHelper.coverShapePortrait,
          narrator: row.length > 19 ? _nullableString(row[19]) : null,
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