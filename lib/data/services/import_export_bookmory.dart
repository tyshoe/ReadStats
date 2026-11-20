part of 'import_export_service.dart';

/// Reading a Bookmory backup's books store into ReadStats books, with
/// their tags and (best-effort) covers.
extension _BookmoryImport on ImportExportService {
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
}
