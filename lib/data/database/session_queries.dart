part of 'database_helper.dart';

/// Reading sessions.
extension SessionQueries on DatabaseHelper {
  Future<int> insertSession(Map<String, dynamic> session) async {
    final db = await database;
    final id = await db.insert('sessions', session);
    DatabaseHelper.sessionsChanged.notify();
    return id;
  }

  Future<List<Map<String, dynamic>>> getSessionsWithBooks({int yearFilter = 0}) async {
    try {
      final db = await database;

      // If yearFilter is not 0, filter by year using the date field in sessions.
      String query = '''
      SELECT 
        sessions.*, 
        books.title as book_title 
      FROM sessions 
      INNER JOIN books ON sessions.book_id = books.id
    ''';

      if (yearFilter != 0) {
        // Apply the year filter to the query.
        query += '''
        WHERE strftime('%Y', sessions.date) = ? 
      ''';
      }

      // Append ordering of the results.
      query += 'ORDER BY sessions.date DESC';

      // Prepare the arguments.
      List<dynamic> arguments = yearFilter != 0 ? [yearFilter.toString()] : [];

      final result = await db.rawQuery(query, arguments);

      return result;
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching sessions: $e');
      }
      return [];
    }
  }

  Future<void> addSessionsBatch(List<Session> sessions) async {
    final db = await database;
    Batch batch = db.batch();

    for (var session in sessions) {
      batch.insert(
        'sessions',
        session.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore, // Avoid duplicate ID errors
      );
    }

    await batch.commit(noResult: true);
    DatabaseHelper.sessionsChanged.notify();
    if (kDebugMode) {
      print('Batch session insert complete. ${sessions.length} sessions added.');
    }
  }

  Future<List<int>> getSessionYears() async {
    final db = await database;
    try {
      final result = await db.rawQuery('''
        SELECT DISTINCT strftime('%Y', date) AS year
        FROM sessions
        ORDER BY year DESC
      ''');

      // Convert result to List<int> to return the valid years
      return result.map((row) {
        return int.tryParse(row['year'].toString()) ?? 0;
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching valid years: $e');
      }
      return [];
    }
  }

  Future<int> updateSession(Map<String, dynamic> session) async {
    final db = await database;
    final result = await db.update(
      'sessions',
      session,
      where: 'id = ?',
      whereArgs: [session['id']],
    );
    DatabaseHelper.sessionsChanged.notify();
    return result;
  }

  Future<int> deleteSession(int id) async {
    final db = await database;
    final result = await db.delete(
      'sessions',
      where: 'id = ?',
      whereArgs: [id],
    );
    DatabaseHelper.sessionsChanged.notify();
    return result;
  }

  /// The page the reader was on in [bookId] before [before] (an ISO
  /// timestamp) — the next one to read — or null when nothing with pages was
  /// logged by then.
  ///
  /// Taken from the last session that recorded the page it stopped on, plus
  /// the page counts of any sessions after it that didn't; with no such
  /// session, the counts are taken from page 1. `exact` is false when counts
  /// had to be added in — a book logged before page numbers were kept is only
  /// as right as its counts are.
  Future<({int page, bool exact})?> getLastPage(
      int bookId, String before) async {
    final db = await database;
    final last = await db.query(
      'sessions',
      columns: ['end_page', 'date'],
      where: 'book_id = ? AND end_page IS NOT NULL AND date < ?',
      whereArgs: [bookId, before],
      orderBy: 'date DESC',
      limit: 1,
    );
    final lastPage = last.isEmpty ? null : last.first['end_page'] as int;
    final counted = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(pages_read), 0) AS pages FROM sessions
      WHERE book_id = ? AND date < ? AND date > ?
      ''',
      [bookId, before, last.isEmpty ? '' : last.first['date']],
    );
    final extra = (counted.first['pages'] as num).toInt();
    if (lastPage == null && extra == 0) return null;
    return (page: (lastPage ?? 1) + extra, exact: extra == 0);
  }

  /// The pages logged for [bookId] before and after [date] (an ISO
  /// timestamp), and whether any session comes after it — what a session
  /// needs to place itself in the book and square its pages with the book's
  /// length. [excludeId] leaves out the session being edited.
  Future<({int pagesBefore, int pagesAfter, bool hasLater})> getPagesAround(
      int bookId, String date,
      {int? excludeId}) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT
        COALESCE(SUM(CASE WHEN date < ? THEN pages_read END), 0) AS before,
        COALESCE(SUM(CASE WHEN date > ? THEN pages_read END), 0) AS after,
        COUNT(CASE WHEN date > ? THEN 1 END) AS later
      FROM sessions
      WHERE book_id = ? AND id != ?
      ''',
      [date, date, date, bookId, excludeId ?? -1],
    );
    return (
      pagesBefore: (rows.first['before'] as num).toInt(),
      pagesAfter: (rows.first['after'] as num).toInt(),
      hasLater: (rows.first['later'] as int) > 0,
    );
  }

  Future<List<Map<String, dynamic>>> getSessionsByBookId(int bookId) async {
    final db = await database;
    return await db.query(
      'sessions',
      where: 'book_id = ?',
      whereArgs: [bookId],
    );
  }
}
