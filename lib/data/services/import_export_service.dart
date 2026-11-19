import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show FileImage, PaintingBinding;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:read_stats/data/demo/demo_covers.dart';
import 'package:read_stats/data/demo/demo_data.dart';
import 'package:read_stats/data/models/book.dart';
import 'package:read_stats/data/models/book_tag.dart';
import 'package:read_stats/data/models/cover_shape.dart';
import 'package:read_stats/data/models/session.dart';
import 'package:read_stats/data/models/shelf.dart';
import 'package:read_stats/data/models/tag.dart';
import 'package:read_stats/data/repositories/book_repository.dart';
import 'package:read_stats/data/repositories/goal_repository.dart';
import 'package:read_stats/data/repositories/planner_repository.dart';
import 'package:read_stats/data/repositories/series_repository.dart';
import 'package:read_stats/data/repositories/session_repository.dart';
import 'package:read_stats/data/repositories/tag_repository.dart';
import 'package:read_stats/data/services/cover_service.dart';
import 'package:read_stats/data/utils/date_utils.dart';
import 'package:read_stats/data/utils/series_title.dart';
import 'package:share_plus/share_plus.dart';

class ImportExportResult {
  final bool success;
  final String message;
  const ImportExportResult({required this.success, required this.message});
}

/// How far along an import is, for the screen that started it.
class ImportProgress {
  /// What is happening now: "Restoring covers · 12 of 69".
  final String label;

  /// How much of the whole import is done, 0 to 1 — or null while there is
  /// nothing to count yet.
  final double? fraction;

  const ImportProgress(this.label, [this.fraction]);
}

typedef ImportProgressCallback = void Function(ImportProgress progress);

/// Unpacks a backup zip off the UI thread: writes every cover into
/// [coversPath] and hands back the text of each CSV by filename.
///
/// The covers are most of a backup — tens of megabytes — and inflating them
/// where the app draws froze it for the length of the restore. [progress]
/// is sent `[done, total]` as each cover lands.
///
/// Top-level so the isolate's closure can only capture what is passed in.
Future<({Map<String, String> csvs, int covers})> _unpackBackup(
    String zipPath, String coversPath, SendPort progress) {
  return Isolate.run(() {
    final archive = ZipDecoder().decodeBytes(File(zipPath).readAsBytesSync());
    final csvs = <String, String>{};
    final covers = <(String, ArchiveFile)>[];
    for (final file in archive.files) {
      if (!file.isFile) continue;
      final name = file.name.replaceAll('\\', '/');
      final base = p.basename(name);
      if (base.isEmpty) continue;
      if (name.startsWith('covers/')) {
        covers.add((base, file));
      } else if (base.endsWith('.csv')) {
        csvs[base] = utf8.decode(file.content as List<int>);
        file.clear();
      }
    }

    Directory(coversPath).createSync(recursive: true);
    progress.send([0, covers.length]);
    for (var i = 0; i < covers.length; i++) {
      final (base, file) = covers[i];
      File(p.join(coversPath, base))
          .writeAsBytesSync(file.content as List<int>);
      file.clear();
      progress.send([i + 1, covers.length]);
    }
    return (csvs: csvs, covers: covers.length);
  });
}

/// Packs a backup zip off the UI thread: [csvs] by filename, then every file
/// in [coversPath], written straight to [zipPath]. Returns how many covers
/// went in.
///
/// The covers are read and written one at a time, so the backup is never
/// held whole in memory, and stored rather than deflated — a cover is
/// already compressed, and squeezing it again only cost time. [progress] is
/// sent `[done, total]` as each one is packed.
///
/// Top-level so the isolate's closure can only capture what is passed in.
Future<int> _packBackup(String zipPath, Map<String, String> csvs,
    String coversPath, SendPort progress) {
  return Isolate.run(() {
    final output = OutputFileStream(zipPath);
    try {
      final encoder = ZipEncoder()..startEncode(output);
      csvs.forEach((name, text) {
        final bytes = utf8.encode(text);
        encoder.addFile(ArchiveFile(name, bytes.length, bytes));
      });

      final dir = Directory(coversPath);
      final covers = dir.existsSync()
          ? dir.listSync().whereType<File>().toList()
          : const <File>[];
      progress.send([0, covers.length]);
      for (var i = 0; i < covers.length; i++) {
        final bytes = covers[i].readAsBytesSync();
        encoder.addFile(ArchiveFile.noCompress(
            'covers/${p.basename(covers[i].path)}', bytes.length, bytes));
        progress.send([i + 1, covers.length]);
      }
      encoder.endEncode();
      return covers.length;
    } finally {
      output.closeSync();
    }
  });
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

  // ─── DEMO ─────────────────────────────────────────────────────────────────

  /// Replace everything with the generated demo library (see [DemoData]).
  ///
  /// With [onlyIfEmpty], refuses when the library already has books — the
  /// onboarding entry, which has no confirmation step of its own.
  Future<ImportExportResult> loadDemoData({
    bool onlyIfEmpty = false,
    ImportProgressCallback? onProgress,
  }) async {
    try {
      if (onlyIfEmpty && (await bookRepository.getBooks()).isNotEmpty) {
        return const ImportExportResult(
          success: false,
          message: 'Your library already has books. '
              'Load demo data from Settings to replace them.',
        );
      }

      onProgress?.call(const ImportProgress('Clearing your library…'));
      final wipe = await deleteAllData();
      if (!wipe.success) return wipe;

      final demo = DemoData.generate(DateTime.now());

      // Goals first, as in a restore: screens reload goals when books change.
      await goalRepository.restoreBackupRows(demo.goals, demo.goalTargets);
      await tagRepository.addTagsBatch(demo.tags);

      // Downloaded a few at a time — quick enough, and gentle on Open Library.
      final coversDir = await CoverService.coversDirectory();
      final withCovers = demo.books.where((b) => b.coverPath != null).toList();
      for (var i = 0; i < withCovers.length; i += 6) {
        // The downloads are nearly all of the wait.
        onProgress?.call(ImportProgress(
          'Fetching covers · $i of ${withCovers.length}',
          0.9 * i / withCovers.length,
        ));
        await Future.wait(withCovers.skip(i).take(6).map((book) async {
          final file = File(p.join(coversDir.path, book.coverPath!));
          await file.writeAsBytes(await DemoCovers.obtain(
            url: demo.coverUrls[book.id],
            title: book.title,
            author: book.author,
            square: book.coverShape == CoverShape.square,
          ));
          // Reloading the demo rewrites the same paths.
          await FileImage(file).evict();
        }));
      }

      onProgress
          ?.call(const ImportProgress('Adding books and sessions…', 0.9));
      await SeriesRepository().resolveNames(demo.books);
      await bookRepository.addBooksBatch(demo.books);
      await sessionRepository.addSessionsBatch(demo.sessions);
      await tagRepository.addBookTagsBatch(demo.bookTags);
      for (final entry in demo.planner) {
        await PlannerRepository().addPlannerRow(entry);
      }
      await SeriesRepository()
          .restorePlaceholders(demo.seriesPlaceholders);

      return ImportExportResult(
        success: true,
        message: 'Demo library loaded: ${demo.books.length} books, '
            '${demo.sessions.length} sessions.',
      );
    } catch (e) {
      if (kDebugMode) print('Demo data error: $e');
      return ImportExportResult(
          success: false, message: 'Loading demo data failed: $e');
    }
  }

  // ─── EXPORT ───────────────────────────────────────────────────────────────

  /// Export everything — the data CSVs plus every cover image — as a
  /// single zip. Bundling the images is what lets covers survive an uninstall:
  /// the CSVs only reference cover filenames, they don't contain the pixels.
  ///
  /// [onProgress] follows the packing; it goes quiet once the share sheet is
  /// up, since what happens to the file from there — an upload to a cloud
  /// folder, say — is the receiving app's and can't be seen from here.
  Future<ImportExportResult> exportBackup(
      {ImportProgressCallback? onProgress}) async {
    try {
      onProgress?.call(const ImportProgress('Preparing backup…'));
      final clock = Stopwatch()..start();
      final books = await bookRepository.getBooks();
      final sessions = await sessionRepository.getSessions();
      final tags = await tagRepository.getAllTags();
      final bookTags = await tagRepository.getAllBookTagsForExport();
      final (goals, goalTargets) = await goalRepository.getBackupRows();

      final csvs = <String, String>{};
      void addCsv(String name, List<List<String>> rows) =>
          csvs['$name.csv'] = const ListToCsvConverter().convert(rows);

      addCsv('books_data', _booksCsvRows(books));
      addCsv('sessions_data', _sessionsCsvRows(sessions));
      addCsv('tags_data', _tagsCsvRows(tags));
      addCsv('book_tags_data', _bookTagsCsvRows(bookTags));
      addCsv('goals_data', _goalsCsvRows(goals));
      addCsv('goal_target_changes_data', _goalTargetsCsvRows(goalTargets));
      addCsv('series_placeholders_data', [
        ['series_name', 'position', 'title'],
        for (final r in await SeriesRepository()
            .allPlaceholderRows())
          [
            r['series_name'].toString(),
            r['position'].toString(),
            (r['title'] as String?) ?? '',
          ],
      ]);

      // Earlier backups stay behind in the temp folder otherwise, each the
      // size of the whole library's covers.
      final tempDir = await getTemporaryDirectory();
      await for (final entity in tempDir.list()) {
        final name = p.basename(entity.path);
        if (entity is File &&
            name.startsWith('readstats_backup_') &&
            name.endsWith('.zip')) {
          await entity.delete();
        }
      }

      final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final zipPath = p.join(tempDir.path, 'readstats_backup_$stamp.zip');
      final coversDir = await CoverService.coversDirectory();
      final port = ReceivePort();
      port.listen((message) {
        final [done as int, total as int] = message as List;
        if (total == 0) return;
        onProgress?.call(ImportProgress(
            'Packing covers · $done of $total', done / total));
      });
      final int coverCount;
      try {
        coverCount =
            await _packBackup(zipPath, csvs, coversDir.path, port.sendPort);
      } finally {
        port.close();
      }
      if (kDebugMode) {
        print('Export: packed $coverCount covers, '
            '${File(zipPath).lengthSync() ~/ 1024} KB, in '
            '${clock.elapsedMilliseconds} ms');
      }

      // Over to the share sheet: nothing more to show from here.
      onProgress?.call(const ImportProgress('Backup ready', 1));
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
        'cover_shape', 'narrator', 'series_name', 'series_position',
        'price_paid', 'date_purchased',
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
        // By name, not id: series ids are local and get recreated on restore.
        b.seriesName ?? '',
        b.seriesPosition?.toString() ?? '',
        b.pricePaid?.toString() ?? '',
        b.datePurchased ?? '',
      ]),
    ];
  }

  List<List<String>> _sessionsCsvRows(List<Session> sessions) {
    return [
      [
        'session_id', 'book_id', 'pages_read', 'duration_minutes', 'date',
        'notes', 'start_page', 'end_page', 'start_position', 'end_position',
      ],
      ...sessions.map((s) => [
        s.id.toString(),
        s.bookId.toString(),
        s.pagesRead.toString(),
        s.durationMinutes.toString(),
        s.date.toString(),
        s.notes ?? '',
        s.startPage?.toString() ?? '',
        s.endPage?.toString() ?? '',
        s.startPosition?.toString() ?? '',
        s.endPosition?.toString() ?? '',
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

  // Dates are written exactly as stored: effective_from is compared as a
  // yyyy-MM-dd string, so reformatting it would misplace every target.
  List<List<String>> _goalsCsvRows(List<Map<String, dynamic>> goals) {
    return [
      ['id', 'metric', 'period', 'target', 'created_at'],
      ...goals.map((g) => [
        g['id'].toString(),
        g['metric'].toString(),
        g['period'].toString(),
        g['target'].toString(),
        g['created_at'].toString(),
      ]),
    ];
  }

  List<List<String>> _goalTargetsCsvRows(List<Map<String, dynamic>> changes) {
    return [
      ['goal_id', 'target', 'effective_from'],
      ...changes.map((c) => [
        c['goal_id'].toString(),
        c['target'].toString(),
        c['effective_from'].toString(),
      ]),
    ];
  }

  /// Goals from a backup. Absent from backups made before goals were included,
  /// which then simply restore none.
  Future<int> _parseAndInsertGoals(
    List<List<dynamic>> goalRows,
    List<List<dynamic>> targetRows,
  ) async {
    final goals = <Map<String, dynamic>>[];
    for (final row in goalRows) {
      if (row.length < 5) continue;
      final id = int.tryParse(row[0].toString());
      final target = int.tryParse(row[3].toString());
      if (id == null || target == null) continue;
      goals.add({
        'id': id,
        'metric': row[1].toString(),
        'period': row[2].toString(),
        'target': target,
        'created_at': row[4].toString(),
      });
    }

    final changes = <Map<String, dynamic>>[];
    for (final row in targetRows) {
      if (row.length < 3) continue;
      final goalId = int.tryParse(row[0].toString());
      final target = int.tryParse(row[1].toString());
      if (goalId == null || target == null) continue;
      changes.add({
        'goal_id': goalId,
        'target': target,
        'effective_from': row[2].toString(),
      });
    }

    if (goals.isEmpty) return 0;
    return goalRepository.restoreBackupRows(goals, changes);
  }

  // ─── IMPORT ───────────────────────────────────────────────────────────────
  /// Deletes the copies the picker made of the files it handed over. It
  /// keeps every one, and a backup is tens of megabytes each time.
  void _clearPickedFiles() {
    FilePicker.platform.clearTemporaryFiles().catchError((_) => false);
  }

  /// Asks for the file to import.
  ///
  /// A file chosen from a cloud folder is downloaded before the picker hands
  /// it over, which for a backup with its covers is a wait of its own — so
  /// [onProgress] hears about it as soon as the choice is made.
  Future<FilePickerResult?> _pickFile(ImportProgressCallback? onProgress) {
    return FilePicker.platform.pickFiles(
      type: FileType.any,
      onFileLoading: (status) {
        if (status == FilePickerStatus.picking) {
          onProgress?.call(const ImportProgress('Fetching file…'));
        }
      },
    );
  }

  /// Restore a backup zip produced by [exportBackup]: cover images are copied
  /// back into the covers directory and every CSV is imported. Also
  /// accepts a legacy books CSV from the old CSV-only export.
  ///
  /// [onProgress] hears nothing until a file is chosen, so a screen can wait
  /// for the first report before showing anything.
  Future<ImportExportResult> importBackup(
      {ImportProgressCallback? onProgress}) async {
    try {
      final result = await _pickFile(onProgress);
      if (result == null) {
        return const ImportExportResult(success: false, message: 'Cancelled.');
      }

      final path = result.files.single.path!;
      if (p.extension(path).toLowerCase() != '.zip') {
        // Legacy export: a lone CSV from the old per-type export. Detect
        // which table it holds from the header row (no images back then).
        onProgress?.call(const ImportProgress('Importing…'));
        return _importLegacyCsv(await File(path).readAsString());
      }

      onProgress?.call(const ImportProgress('Reading backup…'));
      final clock = Stopwatch()..start();

      // Restore cover images first so books display them as soon as the rows
      // land. They are nearly all of a restore's work, so they get most of
      // the bar; the rows go in as a handful of batches after.
      const coverShare = 0.85;
      final coversDir = await CoverService.coversDirectory();
      final port = ReceivePort();
      port.listen((message) {
        final [done as int, total as int] = message as List;
        if (total == 0) return;
        onProgress?.call(ImportProgress(
          'Restoring covers · $done of $total',
          coverShare * done / total,
        ));
      });
      final ({Map<String, String> csvs, int covers}) unpacked;
      try {
        unpacked = await _unpackBackup(path, coversDir.path, port.sendPort);
      } finally {
        port.close();
      }
      final coverCount = unpacked.covers;
      if (kDebugMode) {
        print('Restore: unpacked $coverCount covers in '
            '${clock.elapsedMilliseconds} ms');
      }

      // Covers written over ones already on screen have to be read again.
      PaintingBinding.instance.imageCache.clear();

      List<List<dynamic>> csvRows(String prefix) {
        for (final entry in unpacked.csvs.entries) {
          if (entry.key.startsWith(prefix)) {
            final rows = const CsvToListConverter().convert(entry.value);
            return rows.length <= 1 ? const [] : rows.skip(1).toList();
          }
        }
        return const [];
      }

      void step(String label, double done) => onProgress
          ?.call(ImportProgress(label, coverShare + (1 - coverShare) * done));

      // Goals before books: screens reload their goals when the book list
      // changes, so they have to be in place by the time books land.
      step('Restoring goals…', 0);
      final goalsCount = await _parseAndInsertGoals(
        csvRows('goals_data'),
        csvRows('goal_target_changes_data'),
      );

      // Books and tags first — sessions and book_tags reference them by id.
      step('Restoring books…', 0.1);
      final booksCount = await _parseAndInsertBooks(csvRows('books_data'));
      final tagsCount = await _parseAndInsertTags(csvRows('tags_data'));
      step('Restoring sessions…', 0.5);
      final sessionsCount =
          await _parseAndInsertSessions(csvRows('sessions_data'));
      step('Finishing up…', 0.9);
      await _parseAndInsertBookTags(csvRows('book_tags_data'));
      // After books, so series are already there by name. Absent from
      // backups made before placeholders existed.
      await SeriesRepository().restorePlaceholders([
        for (final row in csvRows('series_placeholders_data'))
          if (row.length >= 2)
            {
              'series_name': row[0].toString(),
              'position': double.tryParse(row[1].toString()),
              'title': row.length > 2 ? row[2].toString() : null,
            },
      ]);

      if (kDebugMode) {
        print('Restore: done in ${clock.elapsedMilliseconds} ms');
      }
      return ImportExportResult(
        success: true,
        message: 'Restored $booksCount books, $sessionsCount sessions, '
            '$tagsCount tags, $goalsCount goals, $coverCount covers.',
      );
    } catch (e) {
      if (kDebugMode) print('Import error (backup): $e');
      return ImportExportResult(success: false, message: 'Restore failed: $e');
    } finally {
      _clearPickedFiles();
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

  Future<ImportExportResult> importGoodreadsCSV(
      {ImportProgressCallback? onProgress}) async {
    try {
      final result = await _pickFile(onProgress);
      if (result == null) {
        return const ImportExportResult(success: false, message: 'Cancelled.');
      }

      onProgress?.call(const ImportProgress('Importing books…'));
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
    } finally {
      _clearPickedFiles();
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
  Future<ImportExportResult> importBookmory(
      {ImportProgressCallback? onProgress}) async {
    try {
      final result = await _pickFile(onProgress);
      if (result == null) {
        return const ImportExportResult(success: false, message: 'Cancelled.');
      }

      onProgress?.call(const ImportProgress('Reading export…'));
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

      return await _parseAndInsertBookmory(dbText, onProgress);
    } catch (e) {
      if (kDebugMode) print('Import error (bookmory): $e');
      return ImportExportResult(success: false, message: 'Import failed: $e');
    } finally {
      _clearPickedFiles();
    }
  }

  Future<ImportExportResult> _parseAndInsertBookmory(
      String dbText, ImportProgressCallback? onProgress) async {
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
    for (final (i, b) in books.indexed) {
      // Each book waits on its cover's download, so this is the whole wait.
      onProgress?.call(ImportProgress(
        'Importing books · $i of ${books.length}',
        i / books.length,
      ));
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
      'DONE' => Shelf.finished,
      'READING' => Shelf.currentlyReading,
      'GIVE_UP' => Shelf.unfinished,
      _ => Shelf.wantToRead,
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
              ? int.tryParse(row[15].toString()) ?? Shelf.wantToRead
              : Shelf.wantToRead,
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
                  CoverShape.portrait
              : CoverShape.portrait,
          narrator: row.length > 19 ? _nullableString(row[19]) : null,
          seriesName: row.length > 20 ? _nullableString(row[20]) : null,
          seriesPosition:
              row.length > 21 ? double.tryParse(row[21].toString()) : null,
          // Absent from backups made before prices were kept.
          pricePaid:
              row.length > 22 ? double.tryParse(row[22].toString()) : null,
          datePurchased: row.length > 23 ? _nullableString(row[23]) : null,
        ));
      } catch (e) {
        if (kDebugMode) print('Skipping book row: $e');
      }
    }
    await SeriesRepository().resolveNames(books);
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
          // Absent from backups made before page numbers were kept.
          startPage: row.length > 6 ? int.tryParse(row[6].toString()) : null,
          endPage: row.length > 7 ? int.tryParse(row[7].toString()) : null,
          // And from ones made before audiobook positions were.
          startPosition:
              row.length > 8 ? int.tryParse(row[8].toString()) : null,
          endPosition: row.length > 9 ? int.tryParse(row[9].toString()) : null,
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

        // Goodreads puts the series in the title: "Legendary (Caraval #2)".
        final rawTitle = getString(r, 'Title') ?? 'Unknown';
        final series = SeriesTitle.parse(rawTitle);

        books.add(Book(
          id: null,
          title: series?.title ?? rawTitle,
          seriesName: series?.series,
          seriesPosition: series?.position,
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

    await SeriesRepository().resolveNames(books);
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