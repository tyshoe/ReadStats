import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

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

    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE books(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        author TEXT,
        word_count INTEGER DEFAULT 0,
        rating REAL,
        is_completed INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE sessions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id INTEGER,
        pages_read INTEGER,
        hours INTEGER,
        minutes INTEGER,
        date TEXT,
        FOREIGN KEY(book_id) REFERENCES books(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<int> insertSession(Map<String, dynamic> session) async {
    final db = await database;
    final id = await db.insert('sessions', session);
    return id;
  }

  Future<List<Map<String, dynamic>>> getSessionsWithBooks() async {
    try {
      final db = await database;
      final result = await db.rawQuery('''
        SELECT 
          sessions.*, 
          books.title as book_title 
        FROM sessions 
        INNER JOIN books ON sessions.book_id = books.id
        ORDER BY sessions.date DESC
      ''');
      print('Sessions fetched: $result');
      return result;
    } catch (e) {
      print('Error fetching sessions: $e');
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
    return await db.insert('books', book);
  }

  Future<List<Map<String, dynamic>>> getBooks() async {
    final db = await database;
    return await db.query('books');
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
      SUM(sessions.hours * 60 + sessions.minutes) AS total_time,  -- Converts time to minutes
      SUM(sessions.pages_read) * 1.0 / SUM(sessions.hours * 60 + sessions.minutes) AS pages_per_minute,
      books.word_count * 1.0 / SUM(sessions.hours * 60 + sessions.minutes) AS words_per_minute,
      MIN(sessions.date) AS start_date,
      MAX(sessions.date) AS finish_date,
      ROUND(
        JULIANDAY(MAX(sessions.date)) - JULIANDAY(MIN(sessions.date))
      ) AS days_to_complete
    FROM books
    LEFT JOIN sessions ON books.id = sessions.book_id
    WHERE books.id = ?
    GROUP BY books.id
  ''', [bookId]);

    print(result);
    if (result.isNotEmpty) {
      return result.first;
    } else {
      return {
        'session_count': 0,
        'total_pages': 0,
        'total_time': 0,
        'pages_per_minute': 0,
        'words_per_minute': 0,
      };
    }
  }

  Future<Map<String, dynamic>> getAllBookStats() async {
    final db = await database;
    final result = await db.rawQuery('''
    WITH BookCompletionTimes AS (
    SELECT 
      books.id AS book_id,
      CAST(ROUND((JULIANDAY(MAX(sessions.date)) - JULIANDAY(MIN(sessions.date))) * 24 * 60) AS INTEGER) AS minutes_to_complete
    FROM books
    JOIN sessions ON books.id = sessions.book_id
    WHERE 
      books.is_completed = 1
    GROUP BY 
      books.id
    )
    SELECT 
      COALESCE(MAX(books.rating), 0) AS highest_rating,
      COALESCE(MIN(books.rating), 0) AS lowest_rating,
      COALESCE(AVG(books.rating), 0) AS average_rating,
      COALESCE(MAX(BookCompletionTimes.minutes_to_complete), 0) AS slowest_read_time,
      COALESCE(MIN(BookCompletionTimes.minutes_to_complete), 0) AS fastest_read_time,
      COALESCE(COUNT(DISTINCT books.id), 0) AS books_completed
    FROM books
    LEFT JOIN BookCompletionTimes ON books.id = BookCompletionTimes.book_id
    WHERE 
        books.is_completed = 1;
    ''');

    print(result);
    if (result.isNotEmpty) {
      return result.first;
    } else {
      return {
        'highest_rating': 0,
        'lowest_rating': 0,
        'average_rating': 0,
        'slowest_read_time': 0,
        'fastest_read_time': 0,
        'books_completed': 0,
      };
    }
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
}
