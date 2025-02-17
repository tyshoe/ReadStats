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
      version: 1,
      onCreate: _onCreate,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON'); // Enable foreign keys
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE books(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        author TEXT,
        wordCount INTEGER,
        rating REAL,
        isCompleted INTEGER
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
        FOREIGN KEY(book_id) REFERENCES books(id)
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
      print('Sessions fetched: $result'); // Debug statement
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

}