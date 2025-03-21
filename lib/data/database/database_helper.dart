import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  static const int _databaseVersion = 3;

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
    print('Database opened. Current version: $version');

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
      rating REAL,
      is_completed INTEGER,
      book_type_id INTEGER,
      FOREIGN KEY(book_type_id) REFERENCES book_types(id)
    )
  ''');

    await db.execute('''
    CREATE TABLE sessions(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      book_id INTEGER,
      pages_read INTEGER,
      hours INTEGER,
      minutes INTEGER,
      date DATETIME,
      FOREIGN KEY(book_id) REFERENCES books(id) ON DELETE CASCADE
    )
  ''');

    await db.insert('book_types', {'name': 'Paperback'});
    await db.insert('book_types', {'name': 'Hardback'});
    await db.insert('book_types', {'name': 'EBook'});
    await db.insert('book_types', {'name': 'Audiobook'});
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      // Add the new 'book_type_id' column (default to 1)
      await db.execute(
          'ALTER TABLE books ADD COLUMN book_type_id INTEGER DEFAULT 1');

      // Create a new 'book_types' table if it doesn't exist
      await db.execute('''
      CREATE TABLE IF NOT EXISTS book_types (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      )
    ''');

      // Insert values
      await db.insert('book_types', {'name': 'Paperback'});
      await db.insert('book_types', {'name': 'Hardback'});
      await db.insert('book_types', {'name': 'EBook'});
      await db.insert('book_types', {'name': 'Audiobook'});

      // Recreate the 'books' table with the foreign key constraint and copy data over
      await db.execute('''
      CREATE TABLE books_new (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        author TEXT,
        word_count INTEGER DEFAULT 0,
        rating REAL,
        is_completed INTEGER,
        book_type_id INTEGER DEFAULT 1,
        FOREIGN KEY(book_type_id) REFERENCES book_types(id)
      )
    ''');

      // Copy data from the old 'books' table to 'books_new'
      await db.execute('''
      INSERT INTO books_new (id, title, author, word_count, rating, is_completed, book_type_id)
      SELECT id, title, author, word_count, rating, is_completed, book_type_id FROM books
    ''');

      // Drop the old 'books' table
      await db.execute('DROP TABLE books');

      // Rename 'books_new' to 'books'
      await db.execute('ALTER TABLE books_new RENAME TO books');

      print("Database upgraded from version $oldVersion to $newVersion");
    }
  }

  Future<void> printDatabaseVersion() async {
    final db = await database;
    final version = await db.getVersion();
    print('Current database version: $version');
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

  Future<List<Map<String, dynamic>>> getSessionsWithBooksByYear(
      int year) async {
    try {
      final db = await database;
      // Adjust the query to filter sessions by year
      final result = await db.rawQuery('''
      SELECT 
        sessions.*, 
        books.title as book_title 
      FROM sessions 
      INNER JOIN books ON sessions.book_id = books.id
      WHERE strftime('%Y', date) = ?
      ORDER BY sessions.date DESC
    ''', [year.toString()]); // Pass the year as a parameter to the query

      print('Sessions fetched: $result');
      return result;
    } catch (e) {
      print('Error fetching sessions: $e');
      return [];
    }
  }

  Future<List<int>> getValidYears() async {
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
      print('Error fetching valid years: $e');
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
