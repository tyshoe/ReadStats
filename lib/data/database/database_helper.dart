import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/book.dart';
import '../models/session.dart';
import '../models/tag.dart';

part 'book_queries.dart';
part 'goal_queries.dart';
part 'planner_queries.dart';
part 'series_queries.dart';
part 'session_queries.dart';
part 'shelf_queries.dart';
part 'stats_queries.dart';
part 'tag_queries.dart';

/// A [ChangeNotifier] whose notify is public, for broadcasting table changes.
class TableChangeNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();

  static Database? _database;

  static const int _databaseVersion = 13;

  // System shelf IDs — stable because shelves are seeded in a fixed order
  // and only exist from v2 onwards (v1 had no shelves).
  static const int shelfCurrentlyReading = 1;

  static const int shelfWantToRead       = 2;

  static const int shelfFinished         = 3;

  static const int shelfUnfinished       = 4;

  /// Whether a book on [shelfId] can take new reading sessions.
  ///
  /// The shelf is the only thing that decides this — deliberately not
  /// `date_finished`, which stays a plain timestamp for stats and goals. A
  /// book moved off the Finished shelf is readable again immediately, even
  /// though it keeps the date of the read it already completed. Unfinished
  /// (DNF) still accepts sessions: picking one back up is normal.
  static bool acceptsSessions(int? shelfId) => shelfId != shelfFinished;

  // How a book's cover is framed — a per-book choice, not tied to book type.
  // Audiobook art is square, but the user can pick either shape for any book.
  static const int coverShapePortrait = 0;

  static const int coverShapeSquare   = 1;

  /// The shape a new book of [bookTypeId] starts with: square for an
  /// audiobook (4), as that is how their art is made, portrait otherwise.
  /// Only a starting point — see above.
  static int defaultCoverShape(int bookTypeId) =>
      bookTypeId == 4 ? coverShapeSquare : coverShapePortrait;

  /// Width / height for [shape]. Drives both the crop frame and every place a
  /// cover is drawn, so what the user framed is what the library shows.
  static double coverAspectRatio(int? shape) =>
      shape == coverShapeSquare ? 1 : 2 / 3;

  /// Fires after any write that changes what [getBooks] returns, so the
  /// app-level book list can reload itself.
  ///
  /// Book writes reach SQLite by several routes — the repository a page was
  /// handed, the ad-hoc `BookRepository(DatabaseHelper())` instances some
  /// widgets build, direct helper calls — and every one of those callers had
  /// to remember to call `refreshBooks` afterwards. The ones that forgot left
  /// the library showing stale rows (a rating and review saved from the rating
  /// dialog, for one, until the app was restarted). Broadcasting from the one
  /// place every write funnels through means forgetting is no longer possible.
  ///
  /// Shelves are included: book rows carry a joined `shelf_name`.
  static final TableChangeNotifier booksChanged = TableChangeNotifier();

  /// Same contract as [booksChanged], for the sessions table.
  static final TableChangeNotifier sessionsChanged = TableChangeNotifier();

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
      CREATE TABLE shelves(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        is_system INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Seed the 4 system shelves — IDs 1–4 are fixed constants (see shelfXxx above)
    await db.insert('shelves', {'name': 'Currently Reading', 'is_system': 1, 'sort_order': 0});
    await db.insert('shelves', {'name': 'Want to Read',      'is_system': 1, 'sort_order': 1});
    await db.insert('shelves', {'name': 'Finished',          'is_system': 1, 'sort_order': 2});
    await db.insert('shelves', {'name': 'Unfinished',        'is_system': 1, 'sort_order': 3});

    await db.execute(_createSeriesTable);
    await db.execute(_createSeriesPlaceholdersTable);

    await db.execute('''
      CREATE TABLE books(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        author TEXT,
        word_count INTEGER DEFAULT 0,
        page_count INTEGER DEFAULT 0,
        rating REAL DEFAULT NULL,
        is_favorite INTEGER DEFAULT 0,
        book_type_id INTEGER,
        date_added DATETIME DEFAULT CURRENT_TIMESTAMP,
        date_started DATETIME,
        date_finished DATETIME,
        isbn TEXT,
        user_review TEXT,
        duration_minutes INTEGER DEFAULT 0,
        shelf_id INTEGER NOT NULL DEFAULT 2,
        cover_path TEXT,
        cover_shape INTEGER NOT NULL DEFAULT 0,
        open_library_key TEXT,
        narrator TEXT,
        series_id INTEGER REFERENCES series(id) ON DELETE SET NULL,
        series_position REAL,
        FOREIGN KEY(book_type_id) REFERENCES book_types(id),
        FOREIGN KEY(shelf_id) REFERENCES shelves(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE sessions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id INTEGER,
        pages_read INTEGER,
        duration_minutes INTEGER,
        date DATETIME,
        notes TEXT,
        start_page INTEGER,
        end_page INTEGER,
        start_position INTEGER,
        end_position INTEGER,
        FOREIGN KEY(book_id) REFERENCES books(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE goals(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        metric TEXT NOT NULL,
        period TEXT NOT NULL,
        target INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        UNIQUE(metric, period)
      )
    ''');

    await db.execute('''
      CREATE TABLE goal_target_changes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        goal_id INTEGER NOT NULL,
        target INTEGER NOT NULL,
        effective_from TEXT NOT NULL,
        FOREIGN KEY(goal_id) REFERENCES goals(id) ON DELETE CASCADE
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

    await db.execute('''
      CREATE TABLE planner_books(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id INTEGER NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        date_added TEXT NOT NULL,
        FOREIGN KEY(book_id) REFERENCES books(id) ON DELETE CASCADE
      )
    ''');

    await _createIndexes(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (kDebugMode) {
      print("Database upgrade called from version $oldVersion to $newVersion");
    }

    if (oldVersion < 2) {
      // Add new columns to books
      await db.execute('ALTER TABLE books ADD COLUMN isbn TEXT');
      await db.execute('ALTER TABLE books ADD COLUMN user_review TEXT');
      await db.execute('ALTER TABLE books ADD COLUMN duration_minutes INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE books ADD COLUMN cover_path TEXT');

      // Create shelves table and seed system shelves
      await db.execute('''
        CREATE TABLE IF NOT EXISTS shelves(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          is_system INTEGER NOT NULL DEFAULT 0,
          sort_order INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await db.insert('shelves', {'name': 'Currently Reading', 'is_system': 1, 'sort_order': 0});
      await db.insert('shelves', {'name': 'Want to Read',      'is_system': 1, 'sort_order': 1});
      await db.insert('shelves', {'name': 'Finished',          'is_system': 1, 'sort_order': 2});
      await db.insert('shelves', {'name': 'Unfinished',        'is_system': 1, 'sort_order': 3});

      // Back up sessions and book_tags before rebuilding books.
      // PRAGMA foreign_keys is ignored inside a transaction (which sqflite uses
      // for onUpgrade), so DROP TABLE books would cascade-delete all sessions
      // and book_tags. Backing them up first avoids the data loss.
      await db.execute('CREATE TABLE sessions_backup AS SELECT * FROM sessions');
      await db.execute('CREATE TABLE book_tags_backup AS SELECT * FROM book_tags');
      await db.execute('DROP TABLE sessions');
      await db.execute('DROP TABLE book_tags');

      // Rebuild books table to add shelf_id
      await db.execute('''
        CREATE TABLE books_new(
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
          isbn TEXT,
          user_review TEXT,
          duration_minutes INTEGER DEFAULT 0,
          shelf_id INTEGER NOT NULL DEFAULT 2,
          cover_path TEXT,
          FOREIGN KEY(book_type_id) REFERENCES book_types(id),
          FOREIGN KEY(shelf_id) REFERENCES shelves(id)
        )
      ''');

      // Backfill shelf from legacy is_completed / date_started flags
      // 1=Currently Reading, 2=Want to Read, 3=Finished, 4=Unfinished
      await db.execute('''
        INSERT INTO books_new
          SELECT
            b.id, b.title, b.author, b.word_count, b.page_count,
            b.rating, b.is_completed, b.is_favorite, b.book_type_id,
            b.date_added, b.date_started, b.date_finished,
            b.isbn, b.user_review, b.duration_minutes,
            CASE
              WHEN b.is_completed = 1 THEN 3
              WHEN b.date_started IS NOT NULL THEN 1
              ELSE 2
            END,
            b.cover_path
          FROM books b
      ''');

      await db.execute('DROP TABLE books');
      await db.execute('ALTER TABLE books_new RENAME TO books');

      // Restore sessions (backup predates notes column so we can't SELECT *)
      await db.execute('''
        CREATE TABLE sessions(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          book_id INTEGER,
          pages_read INTEGER,
          duration_minutes INTEGER,
          date DATETIME,
          notes TEXT,
          FOREIGN KEY(book_id) REFERENCES books(id) ON DELETE CASCADE
        )
      ''');
      await db.execute(
          'INSERT INTO sessions(id, book_id, pages_read, duration_minutes, date) '
          'SELECT id, book_id, pages_read, duration_minutes, date FROM sessions_backup');
      await db.execute('DROP TABLE sessions_backup');

      // Restore book_tags
      await db.execute('''
        CREATE TABLE book_tags(
          book_id INTEGER,
          tag_id INTEGER,
          PRIMARY KEY (book_id, tag_id),
          FOREIGN KEY(book_id) REFERENCES books(id) ON DELETE CASCADE,
          FOREIGN KEY(tag_id) REFERENCES tags(id) ON DELETE CASCADE
        )
      ''');
      await db.execute('INSERT INTO book_tags SELECT * FROM book_tags_backup');
      await db.execute('DROP TABLE book_tags_backup');

      // Create planner list
      await db.execute('''
        CREATE TABLE IF NOT EXISTS planner_books(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          book_id INTEGER NOT NULL,
          sort_order INTEGER NOT NULL DEFAULT 0,
          date_added TEXT NOT NULL,
          FOREIGN KEY(book_id) REFERENCES books(id) ON DELETE CASCADE
        )
      ''');
    }

    if (oldVersion < 3) {
      await db.execute('ALTER TABLE sessions ADD COLUMN notes TEXT');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS goals(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          metric TEXT NOT NULL,
          period TEXT NOT NULL,
          target INTEGER NOT NULL,
          created_at TEXT NOT NULL,
          UNIQUE(metric, period)
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS goal_target_changes(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          goal_id INTEGER NOT NULL,
          target INTEGER NOT NULL,
          effective_from TEXT NOT NULL,
          FOREIGN KEY(goal_id) REFERENCES goals(id) ON DELETE CASCADE
        )
      ''');
    }

    if (oldVersion < 4) {
      // Backfill date_finished for any books marked complete without a finish date.
      // Use date_added as the best available approximation.
      await db.execute('''
        UPDATE books SET date_finished = date_added
        WHERE is_completed = 1 AND date_finished IS NULL
      ''');

      // Drop is_completed — date_finished IS NOT NULL is the single source of truth.
      await db.execute('ALTER TABLE books DROP COLUMN is_completed');
    }

    if (oldVersion < 5) {
      await db.execute('ALTER TABLE books ADD COLUMN open_library_key TEXT');
    }

    if (oldVersion < 6) {
      // Repair: an earlier _onCreate omitted open_library_key, so databases
      // first created AT v5 (fresh installs) lack the column while upgraded
      // databases have it. _onUpgrade isn't called for a same-version install,
      // so those broken DBs can only be fixed by a later version bump. Add the
      // column only if missing so this is safe whichever state the DB is in.
      final cols = await db.rawQuery('PRAGMA table_info(books)');
      final hasOpenLibraryKey =
          cols.any((c) => c['name'] == 'open_library_key');
      if (!hasOpenLibraryKey) {
        await db.execute('ALTER TABLE books ADD COLUMN open_library_key TEXT');
      }
    }

    if (oldVersion < 7) {
      // Existing covers were all cropped to 2:3, so portrait is the correct
      // backfill for every one of them.
      await db.execute(
        'ALTER TABLE books ADD COLUMN cover_shape INTEGER NOT NULL DEFAULT 0',
      );
    }

    if (oldVersion < 8) {
      // Audiobooks only — nothing to backfill, every existing row starts null.
      await db.execute('ALTER TABLE books ADD COLUMN narrator TEXT');
    }

    if (oldVersion < 9) {
      // Series. Nothing to backfill here — titles like "Legendary (Caraval #2)"
      // are offered for linking from the library, never rewritten silently.
      // Guarded like v6, so a database that somehow has them already is fine.
      await db.execute(_createSeriesTable.replaceFirst(
          'CREATE TABLE', 'CREATE TABLE IF NOT EXISTS'));
      final cols = await db.rawQuery('PRAGMA table_info(books)');
      if (!cols.any((c) => c['name'] == 'series_id')) {
        await db.execute('ALTER TABLE books ADD COLUMN series_id INTEGER '
            'REFERENCES series(id) ON DELETE SET NULL');
      }
      if (!cols.any((c) => c['name'] == 'series_position')) {
        await db.execute('ALTER TABLE books ADD COLUMN series_position REAL');
      }
    }

    if (oldVersion < 10) {
      // Placeholders for books in a series the reader doesn't have yet.
      await db.execute(_createSeriesPlaceholdersTable.replaceFirst(
          'CREATE TABLE', 'CREATE TABLE IF NOT EXISTS'));
    }

    if (oldVersion < 11) {
      await _createIndexes(db);
    }

    if (oldVersion < 12) {
      // The pages a session started and stopped on. Nothing to backfill —
      // older sessions only ever held a count, and keep it.
      final cols = await db.rawQuery('PRAGMA table_info(sessions)');
      if (!cols.any((c) => c['name'] == 'start_page')) {
        await db.execute('ALTER TABLE sessions ADD COLUMN start_page INTEGER');
      }
      if (!cols.any((c) => c['name'] == 'end_page')) {
        await db.execute('ALTER TABLE sessions ADD COLUMN end_page INTEGER');
      }
    }

    if (oldVersion < 13) {
      // The times an audiobook session started and stopped on. Nothing to
      // backfill — older sessions only ever held a duration.
      final cols = await db.rawQuery('PRAGMA table_info(sessions)');
      for (final name in ['start_position', 'end_position']) {
        if (!cols.any((c) => c['name'] == name)) {
          await db.execute('ALTER TABLE sessions ADD COLUMN $name INTEGER');
        }
      }
    }
  }

  /// Lookup indexes for the columns queries join, filter and sort on. Without
  /// one SQLite reads the whole table to find matching rows — including on
  /// every book delete, which has to find that book's sessions, tags and
  /// planner entry to cascade to.
  ///
  /// Columns with only a handful of values (shelf, book type) are left out:
  /// an index that still matches a quarter of the table saves nothing.
  static const _indexes = [
    'CREATE INDEX IF NOT EXISTS idx_sessions_book_id ON sessions(book_id)',
    'CREATE INDEX IF NOT EXISTS idx_sessions_date ON sessions(date)',
    'CREATE INDEX IF NOT EXISTS idx_books_series_id ON books(series_id)',
    'CREATE INDEX IF NOT EXISTS idx_books_date_finished ON books(date_finished)',
    // The primary key (book_id, tag_id) already serves lookups by book.
    'CREATE INDEX IF NOT EXISTS idx_book_tags_tag_id ON book_tags(tag_id)',
    'CREATE INDEX IF NOT EXISTS idx_planner_books_book_id ON planner_books(book_id)',
    'CREATE INDEX IF NOT EXISTS idx_goal_target_changes_goal '
        'ON goal_target_changes(goal_id, effective_from)',
  ];

  Future<void> _createIndexes(Database db) async {
    for (final sql in _indexes) {
      await db.execute(sql);
    }
  }

  /// Names are unique ignoring case, so "caraval" and "Caraval" are one series.
  static const _createSeriesTable = '''
    CREATE TABLE series(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL UNIQUE COLLATE NOCASE
    )
  ''';

  /// A number in a series held for a book the reader doesn't have — one not
  /// out yet, or not bought. Never a book: it stays out of the library, the
  /// shelves and every stat. One per number.
  static const _createSeriesPlaceholdersTable = '''
    CREATE TABLE series_placeholders(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      series_id INTEGER NOT NULL REFERENCES series(id) ON DELETE CASCADE,
      position REAL NOT NULL,
      title TEXT,
      UNIQUE(series_id, position)
    )
  ''';

  Future<void> printDatabaseVersion() async {
    final db = await database;
    final version = await db.getVersion();
    if (kDebugMode) {
      print('Current database version: $version');
    }
  }
}