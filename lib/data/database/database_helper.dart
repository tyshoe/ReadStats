import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/book.dart';
import '../models/session.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  static const int _databaseVersion = 1;

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'books.db');

    final db = await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );

    // Print the database version after opening
    final version = await db.getVersion();
    if (kDebugMode) {
      print('Database opened. Current version: $version');
    }

    return db;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
        CREATE TABLE book_types(
           id INTEGER PRIMARY KEY AUTOINCREMENT,
           name TEXT NOT NULL
        )
      ''');

    await db.execute('''
      CREATE TABLE books(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        author TEXT,
        word_count INTEGER DEFAULT 0,
        page_count INTEGER DEFAULT 0,
        rating REAL DEFAULT NULL,
        is_completed INTEGER DEFAULT 0,
        is_favorite INTEGER DEFAULT 0,
        book_type_id INTEGER,
        date_added DATETIME DEFAULT CURRENT_TIMESTAMP,
        date_started DATETIME,
        date_finished DATETIME,
        FOREIGN KEY(book_type_id) REFERENCES book_types(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE sessions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id INTEGER,
        pages_read INTEGER,
        duration_minutes INTEGER,
        date DATETIME,
        FOREIGN KEY(book_id) REFERENCES books(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
    CREATE TABLE tags(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL UNIQUE,
      color INTEGER DEFAULT 0
    )
  ''');

    await db.execute('''
    CREATE TABLE book_tags(
      book_id INTEGER,
      tag_id INTEGER,
      PRIMARY KEY (book_id, tag_id),
      FOREIGN KEY(book_id) REFERENCES books(id) ON DELETE CASCADE,
      FOREIGN KEY(tag_id) REFERENCES tags(id) ON DELETE CASCADE
    )
  ''');

    await db.insert('book_types', {'name': 'Paperback'});
    await db.insert('book_types', {'name': 'Hardback'});
    await db.insert('book_types', {'name': 'EBook'});
    await db.insert('book_types', {'name': 'Audiobook'});
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (kDebugMode) {
      print("Database upgrade called from version $oldVersion to $newVersion");
    }
  }

  Future<void> printDatabaseVersion() async {
    final db = await database;
    final version = await db.getVersion();
    if (kDebugMode) {
      print('Current database version: $version');
    }
  }

  Future<int> insertSession(Map<String, dynamic> session) async {
    final db = await database;
    final id = await db.insert('sessions', session);
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

  Future<void> addBooksBatch(List<Book> books) async {
    final db = await database;
    Batch batch = db.batch();

    for (var book in books) {
      batch.insert(
        'books',
        book.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore, // Avoid duplicate ID errors
      );
    }

    await batch.commit(noResult: true);
    if (kDebugMode) {
      print('Batch book insert complete. ${books.length} books added.');
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

  Future<List<int>> getBookYears() async {
    final db = await database;
    try {
      final result = await db.rawQuery('''
      SELECT DISTINCT strftime('%Y', date_finished) AS year
      FROM books
      WHERE date_finished IS NOT NULL
      ORDER BY year DESC
    ''');

      // Convert the result to List<int> to return valid years
      return result.map((row) {
        return int.tryParse(row['year'].toString()) ?? 0;
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching valid book years: $e');
      }
      return [];
    }
  }

  Future<int> updateSession(Map<String, dynamic> session) async {
    final db = await database;
    return await db.update(
      'sessions',
      session,
      where: 'id = ?',
      whereArgs: [session['id']],
    );
  }

  Future<int> deleteSession(int id) async {
    final db = await database;
    return await db.delete(
      'sessions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, dynamic>?> getBookById(int bookId) async {
    final db = await database;
    List<Map<String, dynamic>> result = await db.query(
      'books',
      where: 'id = ?',
      whereArgs: [bookId],
    );

    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }

  Future<int> insertBook(Map<String, dynamic> book) async {
    final db = await database;
    if (kDebugMode) {
      print('Attempt add book: $book');
    }
    return await db.insert('books', book);
  }

  Future<List<Map<String, dynamic>>> getBooks({int yearFilter = 0}) async {
    try {
      final db = await database;

      // Base query
      String query = '''
    SELECT * FROM books
    ''';

      if (yearFilter != 0) {
        // Apply the year filter to the date_finished field
        query += '''
      WHERE strftime('%Y', date_finished) = ? 
      ''';
      }

      // Append ordering of the results (you can adjust this as needed)
      query += 'ORDER BY date_finished DESC';

      // Prepare the arguments.
      List<dynamic> arguments = yearFilter != 0 ? [yearFilter.toString()] : [];

      final result = await db.rawQuery(query, arguments);

      return result;
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching books: $e');
      }
      return [];
    }
  }

  Future<int> updateBook(Map<String, dynamic> book) async {
    final db = await database;
    return await db.update(
      'books',
      book,
      where: 'id = ?',
      whereArgs: [book['id']],
    );
  }

  Future<int> updateBookPartial(int id, Map<String, dynamic> updates) async {
    final db = await database;
    return await db.update(
      'books',
      updates,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteBook(int id) async {
    final db = await database;
    return await db.delete(
      'books',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteAllBooks() async {
    final db = await database;
    return await db.delete('books');
  }

  Future<List<Map<String, dynamic>>> getSessionsByBookId(int bookId) async {
    final db = await database;
    return await db.query(
      'sessions',
      where: 'book_id = ?',
      whereArgs: [bookId],
    );
  }

  Future<Map<String, dynamic>> getBookStats(int bookId) async {
    final db = await database;
    final result = await db.rawQuery('''
    SELECT 
      COUNT(sessions.id) AS session_count, 
      SUM(sessions.pages_read) AS total_pages,
      SUM(sessions.duration_minutes) AS total_time,  -- Converts time to duration_minutes
      SUM(sessions.pages_read) * 1.0 / SUM(sessions.duration_minutes) AS pages_per_minute,
      books.word_count * 1.0 / SUM(sessions.duration_minutes) AS words_per_minute,
      books.date_added,
      books.date_started,
      books.date_finished,
      ROUND(
        JULIANDAY(MAX(sessions.date)) - JULIANDAY(MIN(sessions.date))
      ) AS days_to_complete
    FROM books
    LEFT JOIN sessions ON books.id = sessions.book_id
    WHERE books.id = ?
    GROUP BY books.id
  ''', [bookId]);

    if (kDebugMode) {
      print(result);
    }
    if (result.isNotEmpty) {
      return result.first;
    } else {
      return {
        'session_count': 0,
        'total_pages': 0,
        'total_time': 0,
        'pages_per_minute': 0,
        'words_per_minute': 0,
        'date_added': null,
        'date_started': null,
        'date_finished': null,
      };
    }
  }

  Future<Map<String, dynamic>> getAllBookStats(int selectedYear) async {
    final db = await database;

    // If the selectedYear is not 0, filter by date_finished
    String yearFilter = '';
    if (selectedYear != 0) {
      yearFilter = "AND strftime('%Y', books.date_finished) = '$selectedYear'";
    }

    final result = await db.rawQuery('''
    WITH BookReadTimes AS (
      SELECT 
        books.id AS book_id,
        books.title AS book_title,
        books.rating,
        books.page_count,
        COALESCE(SUM(sessions.duration_minutes), 0) AS total_read_time
      FROM books
      LEFT JOIN sessions ON books.id = sessions.book_id
      WHERE 
        books.is_completed = 1
        $yearFilter
      GROUP BY books.id
    ),
    -- Filtered datasets for specific calculations
    ValidRatings AS (
      SELECT * FROM BookReadTimes WHERE rating IS NOT NULL
    ),
    ValidPages AS (
      SELECT * FROM BookReadTimes WHERE page_count > 0
    ),
    ValidReadTimes AS (
      SELECT * FROM BookReadTimes WHERE total_read_time > 0
    ),
    -- Statistics CTEs using appropriate filtered datasets
    MaxRating AS (
      SELECT book_id, book_title 
      FROM ValidRatings 
      WHERE rating = (SELECT MAX(rating) FROM ValidRatings)
      LIMIT 1
    ),
    MinRating AS (
      SELECT book_id, book_title 
      FROM ValidRatings 
      WHERE rating = (SELECT MIN(rating) FROM ValidRatings)
      LIMIT 1
    ),
    MaxPages AS (
      SELECT book_id, book_title 
      FROM ValidPages 
      WHERE page_count = (SELECT MAX(page_count) FROM ValidPages)
      LIMIT 1
    ),
    MinPages AS (
      SELECT book_id, book_title 
      FROM ValidPages 
      WHERE page_count = (SELECT MIN(page_count) FROM ValidPages)
      LIMIT 1
    ),
    SlowestRead AS (
      SELECT book_id, book_title 
      FROM ValidReadTimes 
      WHERE total_read_time = (SELECT MAX(total_read_time) FROM ValidReadTimes)
      LIMIT 1
    ),
    FastestRead AS (
      SELECT book_id, book_title 
      FROM ValidReadTimes 
      WHERE total_read_time = (SELECT MIN(total_read_time) FROM ValidReadTimes)
      LIMIT 1
    )
    
    SELECT 
      -- Rating stats (only from ValidRatings)
      (SELECT MAX(rating) FROM ValidRatings) AS highest_rating,
      (SELECT MIN(rating) FROM ValidRatings) AS lowest_rating,
      (SELECT AVG(rating) FROM ValidRatings) AS average_rating,
      
      -- Page stats (only from ValidPages)
      (SELECT MAX(page_count) FROM ValidPages) AS highest_pages,
      (SELECT MIN(page_count) FROM ValidPages) AS lowest_pages,
      (SELECT AVG(page_count) FROM ValidPages) AS average_pages,
      
      -- Read time stats (only from ValidReadTimes)
      (SELECT MAX(total_read_time) FROM ValidReadTimes) AS slowest_read_time,
      (SELECT MIN(total_read_time) FROM ValidReadTimes) AS fastest_read_time,
      
      -- Counts from base dataset
      COUNT(DISTINCT book_id) AS books_completed,
      
      -- Book references
      (SELECT book_id FROM MaxRating) AS highest_rating_book_id,
      (SELECT book_title FROM MaxRating) AS highest_rating_book_title,
      (SELECT book_id FROM MinRating) AS lowest_rating_book_id,
      (SELECT book_title FROM MinRating) AS lowest_rating_book_title,
      (SELECT book_id FROM MaxPages) AS highest_pages_book_id,
      (SELECT book_title FROM MaxPages) AS highest_pages_book_title,
      (SELECT book_id FROM MinPages) AS lowest_pages_book_id,
      (SELECT book_title FROM MinPages) AS lowest_pages_book_title,
      (SELECT book_id FROM SlowestRead) AS slowest_read_book_id,
      (SELECT book_title FROM SlowestRead) AS slowest_read_book_title,
      (SELECT book_id FROM FastestRead) AS fastest_read_book_id,
      (SELECT book_title FROM FastestRead) AS fastest_read_book_title
    FROM BookReadTimes
  ''');

    if (result.isNotEmpty) {
      return result.first;
    } else {
      return {
        'highest_rating': 0,
        'lowest_rating': 0,
        'average_rating': 0,
        'highest_pages': 0,
        'lowest_pages': 0,
        'average_pages': 0,
        'slowest_read_time': 0,
        'fastest_read_time': 0,
        'books_completed': 0,
        // Default null values for book references
        'highest_rating_book_id': null,
        'highest_rating_book_title': null,
        'lowest_rating_book_id': null,
        'lowest_rating_book_title': null,
        'highest_pages_book_id': null,
        'highest_pages_book_title': null,
        'lowest_pages_book_id': null,
        'lowest_pages_book_title': null,
        'slowest_read_book_id': null,
        'slowest_read_book_title': null,
        'fastest_read_book_id': null,
        'fastest_read_book_title': null,
      };
    }
  }

  Future<Map<double, int>> getRatingDistribution({int selectedYear = 0}) async {
    final db = await database;

    String yearFilter = '';
    if (selectedYear != 0) {
      yearFilter = "AND strftime('%Y', date_finished) = '$selectedYear'";
    }

    final result = await db.rawQuery('''
    SELECT rating, COUNT(*) as count
    FROM books
    WHERE is_completed = 1
      AND rating IS NOT NULL
      $yearFilter
    GROUP BY rating
    ORDER BY rating ASC
  ''');

    // Convert to Map<double, int>
    Map<double, int> distribution = {};
    for (var row in result) {
      double rating = (row['rating'] as num).toDouble(); // cast safely
      int count = row['count'] as int;
      distribution[rating] = count;
    }

    // Fill missing ratings 0–5 (e.g., 0.0, 0.5, 1.0, ..., 5.0)
    for (double i = 0; i <= 5; i += 0.5) {
      distribution[i] = distribution[i] ?? 0;
    }

    return distribution;
  }



  Future<Map<String, dynamic>> getCompleteBookStats(int bookId) async {
    final book = await getBookById(bookId);
    final stats = await getBookStats(bookId);

    if (book != null) {
      return {
        'book': book,
        'stats': stats,
      };
    } else {
      return {};
    }
  }

  Future<int> createTag(Map<String, dynamic> tag) async {
    final db = await database;
    return await db.insert('tags', tag);
  }

  Future<List<Map<String, dynamic>>> getAllTags() async {
    final db = await database;
    return await db.query('tags');
  }

  Future<int> addTagToBook(int bookId, int tagId) async {
    final db = await database;
    return await db.insert('book_tags', {
      'book_id': bookId,
      'tag_id': tagId,
    });
  }

  Future<int> removeTagFromBook(int bookId, int tagId) async {
    final db = await database;
    return await db.delete(
      'book_tags',
      where: 'book_id = ? AND tag_id = ?',
      whereArgs: [bookId, tagId],
    );
  }

  Future<List<Map<String, dynamic>>> getTagsForBook(int bookId) async {
    final db = await database;
    return await db.rawQuery('''
    SELECT tags.* FROM tags
    INNER JOIN book_tags ON tags.id = book_tags.tag_id
    WHERE book_tags.book_id = ?
  ''', [bookId]);
  }

  Future<List<Map<String, dynamic>>> getBooksForTag(int tagId) async {
    final db = await database;
    return await db.rawQuery('''
    SELECT books.* FROM books
    INNER JOIN book_tags ON books.id = book_tags.book_id
    WHERE book_tags.tag_id = ?
  ''', [tagId]);
  }

  Future<List<Map<String, dynamic>>> getBooksByTitleAndAuthor(String title, String author) async {
    final db = await database;
    return await db.query(
      'books',
      where: 'title = ? AND author = ?',
      whereArgs: [title, author],
    );
  }

  // Add to DatabaseHelper class
  Future<List<String>> getAuthorSuggestions(String query) async {
    final db = await database;
    final result = await db.rawQuery('''
    SELECT DISTINCT author FROM books 
    WHERE author LIKE ? 
    ORDER BY 
      CASE WHEN author LIKE ? THEN 0 ELSE 1 END,  -- Exact matches first
      author COLLATE NOCASE ASC
    LIMIT 5  -- Limit suggestions for performance
  ''', ['%$query%', '$query%']);
    return result.map((row) => row['author'] as String).toList();
  }

  Future<void> updateBookFavoriteStatus(int bookId, int isFavorite) async {
    final db = await database;
    await db.update(
      'books',
      {'is_favorite': isFavorite},
      where: 'id = ?',
      whereArgs: [bookId],
    );
  }
}
