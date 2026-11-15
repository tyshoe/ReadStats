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

  /// Where the reader is in [bookId] before [before] (an ISO timestamp), and
  /// how its sessions are logged, which is how the next one starts out.
  ///
  /// `lastStop` is the time the player showed when the last session that
  /// recorded its times stopped — time left, counting down, or time played,
  /// as `countsDown` says — and `minutesSince` what sessions after it logged
  /// as a bare duration. With no such session `lastStop` is null and
  /// `minutesSince` is everything logged, so a book in progress from before
  /// the times were kept can still be placed against its length. A place
  /// that leans on `minutesSince` is only as right as those durations are.
  ///
  /// `byDuration` says the reader has gone back to a bare duration: for this
  /// book, when it has times and then sessions without; otherwise by the
  /// last audiobook session of any book, since the choice follows the app
  /// the reader listens in. With no times logged anywhere it is time left:
  /// the figure most players show.
  Future<
      ({
        int? lastStop,
        int minutesSince,
        bool countsDown,
        bool byDuration,
      })> getLastPosition(int bookId, String before) async {
    final db = await database;
    bool timed(Map<String, Object?> row) =>
        row['start_position'] != null && row['end_position'] != null;
    bool down(Map<String, Object?> row) =>
        (row['start_position'] as int) >= (row['end_position'] as int);

    final last = await db.query(
      'sessions',
      columns: ['start_position', 'end_position', 'date'],
      where: 'book_id = ? AND start_position IS NOT NULL '
          'AND end_position IS NOT NULL AND date < ?',
      whereArgs: [bookId, before],
      orderBy: 'date DESC',
      limit: 1,
    );
    final since = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(duration_minutes), 0) AS minutes, COUNT(*) AS sessions
      FROM sessions
      WHERE book_id = ? AND date < ? AND date > ?
      ''',
      [bookId, before, last.isEmpty ? '' : last.first['date']],
    );
    final minutesSince = (since.first['minutes'] as num).toInt();
    if (last.isNotEmpty) {
      return (
        lastStop: last.first['end_position'] as int,
        minutesSince: minutesSince,
        countsDown: down(last.first),
        byDuration: (since.first['sessions'] as int) > 0,
      );
    }

    final lastTimed = await db.query(
      'sessions',
      columns: ['start_position', 'end_position'],
      where: 'start_position IS NOT NULL AND end_position IS NOT NULL',
      orderBy: 'date DESC',
      limit: 1,
    );
    final lastAudio = await db.rawQuery('''
      SELECT s.start_position, s.end_position FROM sessions s
      INNER JOIN books b ON b.id = s.book_id
      WHERE b.book_type_id = 4
      ORDER BY s.date DESC LIMIT 1
    ''');
    return (
      lastStop: null,
      minutesSince: minutesSince,
      countsDown: lastTimed.isEmpty || down(lastTimed.first),
      byDuration: lastTimed.isNotEmpty &&
          lastAudio.isNotEmpty &&
          !timed(lastAudio.first),
    );
  }

  /// The minutes logged for [bookId] before and after [date] (an ISO
  /// timestamp). [excludeId] leaves out the session being edited.
  Future<({int before, int after})> getMinutesAround(int bookId, String date,
      {int? excludeId}) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT
        COALESCE(SUM(CASE WHEN date < ? THEN duration_minutes END), 0) AS before,
        COALESCE(SUM(CASE WHEN date > ? THEN duration_minutes END), 0) AS after
      FROM sessions
      WHERE book_id = ? AND id != ?
      ''',
      [date, date, bookId, excludeId ?? -1],
    );
    return (
      before: (rows.first['before'] as num).toInt(),
      after: (rows.first['after'] as num).toInt(),
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
