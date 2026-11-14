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

  Future<List<Map<String, dynamic>>> getSessionsByBookId(int bookId) async {
    final db = await database;
    return await db.query(
      'sessions',
      where: 'book_id = ?',
      whereArgs: [bookId],
    );
  }
}
