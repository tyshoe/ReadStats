part of 'database_helper.dart';

/// Series and the placeholders held for books not owned yet.
extension SeriesQueries on DatabaseHelper {
  /// Placeholders in [seriesId], in order.
  Future<List<Map<String, dynamic>>> getSeriesPlaceholders(int seriesId) async {
    final db = await database;
    return db.query('series_placeholders',
        where: 'series_id = ?', whereArgs: [seriesId], orderBy: 'position');
  }

  /// Every placeholder, with its series' name — for the library and backups.
  Future<List<Map<String, dynamic>>> getAllSeriesPlaceholders() async {
    final db = await database;
    return db.rawQuery('''
      SELECT p.*, se.name AS series_name FROM series_placeholders p
      INNER JOIN series se ON p.series_id = se.id
      ORDER BY se.name COLLATE NOCASE, p.position
    ''');
  }

  /// Holds [position] in [seriesId], replacing any placeholder already there.
  Future<void> saveSeriesPlaceholder(
      int seriesId, double position, String? title) async {
    final db = await database;
    await db.insert(
      'series_placeholders',
      {'series_id': seriesId, 'position': position, 'title': title},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    DatabaseHelper.booksChanged.notify();
  }

  /// Moves or renames a placeholder. Taking a number another placeholder
  /// holds replaces that one.
  Future<void> updateSeriesPlaceholder(
      int id, int seriesId, double position, String? title) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('series_placeholders',
          where: 'series_id = ? AND position = ? AND id != ?',
          whereArgs: [seriesId, position, id]);
      await txn.update('series_placeholders',
          {'position': position, 'title': title},
          where: 'id = ?', whereArgs: [id]);
    });
    DatabaseHelper.booksChanged.notify();
  }

  /// Moves several placeholders at once — a drag that swaps two of them.
  /// Each first steps aside to a number nothing uses, or the one-per-number
  /// rule would refuse the swap halfway.
  Future<void> repositionSeriesPlaceholders(
      Map<int, double> positionsById) async {
    if (positionsById.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      for (final id in positionsById.keys) {
        await txn.update('series_placeholders', {'position': -id},
            where: 'id = ?', whereArgs: [id]);
      }
      for (final e in positionsById.entries) {
        await txn.update('series_placeholders', {'position': e.value},
            where: 'id = ?', whereArgs: [e.key]);
      }
    });
    DatabaseHelper.booksChanged.notify();
  }

  Future<void> deleteSeriesPlaceholders(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    await db.delete('series_placeholders',
        where: 'id IN (${ids.map((_) => '?').join(', ')})', whereArgs: ids);
    DatabaseHelper.booksChanged.notify();
  }

  /// The id of the series called [name], creating it if needed. Matching
  /// ignores case, punctuation and a leading "The" or trailing "Series"
  /// (see [SeriesTitle.matchKey]), so names from Open Library join the
  /// reader's own; the first spelling used is kept.
  Future<int> seriesIdFor(String name) async {
    final db = await database;
    final clean = name.trim();
    final existing = await db.query('series',
        columns: ['id'], where: 'name = ?', whereArgs: [clean], limit: 1);
    if (existing.isNotEmpty) return existing.first['id'] as int;
    final key = SeriesTitle.matchKey(clean);
    if (key.isNotEmpty) {
      for (final row in await db.query('series', columns: ['id', 'name'])) {
        if (SeriesTitle.matchKey(row['name'] as String) == key) {
          return row['id'] as int;
        }
      }
    }
    return db.insert('series', {'name': clean});
  }

  /// The reader's own spelling of the series [name] is, if they have it.
  Future<String?> existingSeriesName(String name) async {
    final db = await database;
    final key = SeriesTitle.matchKey(name);
    if (key.isEmpty) return null;
    for (final row in await db.query('series', columns: ['name'])) {
      final existing = row['name'] as String;
      if (SeriesTitle.matchKey(existing) == key) return existing;
    }
    return null;
  }

  /// Names of series that still have at least one book, A–Z — for suggestions.
  Future<List<String>> getSeriesNames() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT DISTINCT se.name FROM series se
      INNER JOIN books b ON b.series_id = se.id
      ORDER BY se.name COLLATE NOCASE
    ''');
    return [for (final r in rows) r['name'] as String];
  }

  /// Every book in [seriesId], in reading order; unnumbered books last.
  Future<List<Map<String, dynamic>>> getBooksInSeries(int seriesId) async {
    final db = await database;
    return db.rawQuery('''
      SELECT b.*, s.name AS shelf_name, se.name AS series_name
      FROM books b
      LEFT JOIN shelves s ON b.shelf_id = s.id
      LEFT JOIN series se ON b.series_id = se.id
      WHERE b.series_id = ?
      ORDER BY b.series_position IS NULL, b.series_position, b.title
    ''', [seriesId]);
  }

  /// The highest number used in the series called [name] (any case), not
  /// counting [excludeBookIds], or null when there's none — where a bulk add
  /// continues from. The books being added are excluded so renumbering them
  /// doesn't count past themselves.
  Future<double?> getSeriesMaxPosition(String name,
      {List<int> excludeBookIds = const []}) async {
    final db = await database;
    final exclude = excludeBookIds.isEmpty
        ? ''
        : 'AND b.id NOT IN (${List.filled(excludeBookIds.length, '?').join(',')})';
    final rows = await db.rawQuery('''
      SELECT MAX(b.series_position) AS max_position FROM books b
      INNER JOIN series se ON b.series_id = se.id
      WHERE se.name = ? $exclude
    ''', [name.trim(), ...excludeBookIds]);
    return (rows.first['max_position'] as num?)?.toDouble();
  }

  /// Links books to series in one go: each entry's `title` (if given),
  /// `series_id` and `series_position`, by book `id`.
  Future<void> linkBooksToSeries(List<Map<String, dynamic>> updates) async {
    final db = await database;
    final batch = db.batch();
    for (final u in updates) {
      batch.update(
        'books',
        {
          if (u['title'] != null) 'title': u['title'],
          'series_id': u['series_id'],
          'series_position': u['series_position'],
        },
        where: 'id = ?',
        whereArgs: [u['id']],
      );
    }
    await batch.commit(noResult: true);
    DatabaseHelper.booksChanged.notify();
  }
}
