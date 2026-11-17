part of 'database_helper.dart';

/// Aggregates for Statistics and the book detail sheet.
extension StatsQueries on DatabaseHelper {
  Future<Map<String, dynamic>> getBookStats(int bookId) async {
    final db = await database;
    final result = await db.rawQuery('''
    SELECT 
      COUNT(sessions.id) AS session_count, 
      SUM(sessions.pages_read) AS total_pages,
      SUM(sessions.duration_minutes) AS total_time,  -- Converts time to duration_minutes
      SUM(sessions.pages_read) * 1.0 / SUM(sessions.duration_minutes) AS pages_per_minute,
      CASE 
        WHEN books.page_count IS NOT NULL AND books.page_count > 0 
        THEN (books.word_count * (SUM(sessions.pages_read) * 1.0 / books.page_count)) * 1.0 / SUM(sessions.duration_minutes)
        ELSE books.word_count * 1.0 / SUM(sessions.duration_minutes)
      END AS words_per_minute,
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
        books.date_finished IS NOT NULL
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
      (SELECT cover_path FROM books WHERE id = (SELECT book_id FROM MaxRating)) AS highest_rating_cover_path,
      (SELECT cover_shape FROM books WHERE id = (SELECT book_id FROM MaxRating)) AS highest_rating_cover_shape,
      (SELECT book_id FROM MinRating) AS lowest_rating_book_id,
      (SELECT book_title FROM MinRating) AS lowest_rating_book_title,
      (SELECT cover_path FROM books WHERE id = (SELECT book_id FROM MinRating)) AS lowest_rating_cover_path,
      (SELECT cover_shape FROM books WHERE id = (SELECT book_id FROM MinRating)) AS lowest_rating_cover_shape,
      (SELECT book_id FROM MaxPages) AS highest_pages_book_id,
      (SELECT book_title FROM MaxPages) AS highest_pages_book_title,
      (SELECT cover_path FROM books WHERE id = (SELECT book_id FROM MaxPages)) AS highest_pages_cover_path,
      (SELECT cover_shape FROM books WHERE id = (SELECT book_id FROM MaxPages)) AS highest_pages_cover_shape,
      (SELECT book_id FROM MinPages) AS lowest_pages_book_id,
      (SELECT book_title FROM MinPages) AS lowest_pages_book_title,
      (SELECT cover_path FROM books WHERE id = (SELECT book_id FROM MinPages)) AS lowest_pages_cover_path,
      (SELECT cover_shape FROM books WHERE id = (SELECT book_id FROM MinPages)) AS lowest_pages_cover_shape,
      (SELECT book_id FROM SlowestRead) AS slowest_read_book_id,
      (SELECT book_title FROM SlowestRead) AS slowest_read_book_title,
      (SELECT cover_path FROM books WHERE id = (SELECT book_id FROM SlowestRead)) AS slowest_read_cover_path,
      (SELECT cover_shape FROM books WHERE id = (SELECT book_id FROM SlowestRead)) AS slowest_read_cover_shape,
      (SELECT book_id FROM FastestRead) AS fastest_read_book_id,
      (SELECT book_title FROM FastestRead) AS fastest_read_book_title,
      (SELECT cover_path FROM books WHERE id = (SELECT book_id FROM FastestRead)) AS fastest_read_cover_path,
      (SELECT cover_shape FROM books WHERE id = (SELECT book_id FROM FastestRead)) AS fastest_read_cover_shape
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
    WHERE date_finished IS NOT NULL
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

  Future<List<Map<String, dynamic>>> getBookCountsPerType() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT bt.name, COUNT(b.id) as book_count
      FROM book_types bt
      LEFT JOIN books b ON b.book_type_id = bt.id
      GROUP BY bt.id
      ORDER BY bt.id ASC
    ''');
  }

  Future<List<Map<String, dynamic>>> getBookCountsPerShelf() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT s.name, COUNT(b.id) as book_count
      FROM shelves s
      LEFT JOIN books b ON b.shelf_id = s.id
      GROUP BY s.id
      ORDER BY s.sort_order ASC
    ''');
  }
}
