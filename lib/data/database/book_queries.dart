part of 'database_helper.dart';

/// Books: reads, writes and the lookups the book form uses.
extension BookQueries on DatabaseHelper {
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
    DatabaseHelper.booksChanged.notify();
    if (kDebugMode) {
      print('Batch book insert complete. ${books.length} books added.');
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

  Future<Map<String, dynamic>?> getBookById(int bookId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT b.*, s.name as shelf_name, se.name as series_name
      FROM books b
      LEFT JOIN shelves s ON b.shelf_id = s.id
      LEFT JOIN series se ON b.series_id = se.id
      WHERE b.id = ?
    ''', [bookId]);

    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }

  Future<int> insertBook(Map<String, dynamic> book) async {
    final db = await database;
    final id = await db.insert('books', book);
    DatabaseHelper.booksChanged.notify();
    return id;
  }

  Future<List<Map<String, dynamic>>> getBooks({int yearFilter = 0, int? shelfId}) async {
    try {
      final db = await database;

      final List<String> conditions = [];
      final List<dynamic> arguments = [];

      if (yearFilter != 0) {
        conditions.add("strftime('%Y', b.date_finished) = ?");
        arguments.add(yearFilter.toString());
      }

      if (shelfId != null) {
        conditions.add('b.shelf_id = ?');
        arguments.add(shelfId);
      }

      String query = '''
        SELECT b.*, s.name as shelf_name, se.name as series_name
        FROM books b
        LEFT JOIN shelves s ON b.shelf_id = s.id
        LEFT JOIN series se ON b.series_id = se.id
      ''';

      if (conditions.isNotEmpty) {
        query += ' WHERE ${conditions.join(' AND ')}';
      }
      query += ' ORDER BY b.date_finished DESC';

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
    final result = await db.update(
      'books',
      book,
      where: 'id = ?',
      whereArgs: [book['id']],
    );
    // Finished books don't belong in the reading planner.
    if (book['shelf_id'] == Shelf.finished) {
      await db.delete('planner_books',
          where: 'book_id = ?', whereArgs: [book['id']]);
    }
    DatabaseHelper.booksChanged.notify();
    return result;
  }

  Future<int> updateBookPartial(int id, Map<String, dynamic> updates) async {
    final db = await database;
    final result = await db.update(
      'books',
      updates,
      where: 'id = ?',
      whereArgs: [id],
    );
    // Finished books don't belong in the reading planner.
    if (updates['shelf_id'] == Shelf.finished) {
      await db.delete('planner_books', where: 'book_id = ?', whereArgs: [id]);
    }
    DatabaseHelper.booksChanged.notify();
    return result;
  }

  Future<int> deleteBook(int id) async {
    final db = await database;
    final result = await db.delete(
      'books',
      where: 'id = ?',
      whereArgs: [id],
    );
    DatabaseHelper.booksChanged.notify();
    return result;
  }

  Future<void> updateCoverPath(int bookId, String? path) async {
    final db = await database;
    await db.update(
      'books',
      {'cover_path': path},
      where: 'id = ?',
      whereArgs: [bookId],
    );
    DatabaseHelper.booksChanged.notify();
  }

  Future<void> deleteBooksBatch(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    final placeholders = ids.map((_) => '?').join(', ');
    await db.rawDelete(
      'DELETE FROM books WHERE id IN ($placeholders)',
      ids,
    );
    DatabaseHelper.booksChanged.notify();
  }

  Future<int> deleteAllBooks() async {
    final db = await database;
    final result = await db.delete('books');
    // Series exist only through their books.
    await db.delete('series_placeholders');
    await db.delete('series');
    DatabaseHelper.booksChanged.notify();
    return result;
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

  /// Narrators on the reader's books whose name contains [query], names
  /// starting with it first. The column can hold a comma-separated cast, so
  /// each name is offered on its own.
  Future<List<String>> getNarratorSuggestions(String query) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT DISTINCT narrator FROM books WHERE narrator LIKE ?',
      ['%$query%'],
    );
    final q = query.toLowerCase();
    final names = <String>{
      for (final row in rows)
        for (final name in (row['narrator'] as String).split(','))
          if (name.trim().toLowerCase().contains(q)) name.trim(),
    }.toList();
    int rank(String n) => n.toLowerCase().startsWith(q) ? 0 : 1;
    names.sort((a, b) {
      final byRank = rank(a).compareTo(rank(b));
      return byRank != 0
          ? byRank
          : a.toLowerCase().compareTo(b.toLowerCase());
    });
    return names.take(5).toList();
  }

  Future<void> updateBookFavoriteStatus(int bookId, int isFavorite) async {
    final db = await database;
    await db.update(
      'books',
      {'is_favorite': isFavorite},
      where: 'id = ?',
      whereArgs: [bookId],
    );
    DatabaseHelper.booksChanged.notify();
  }

  /// Writes the rating and review the user just entered. [review] is written
  /// even when null — that's how a review gets cleared, and the dialog sends
  /// null for an empty box.
  Future<void> updateBookRating(int bookId, double rating, {String? review}) async {
    final db = await database;
    await db.update(
      'books',
      {'rating': rating, 'user_review': review},
      where: 'id = ?',
      whereArgs: [bookId],
    );
    DatabaseHelper.booksChanged.notify();
  }

  Future<void> updateBookShelf(int bookId, int shelfId) async {
    final db = await database;
    await db.update(
      'books',
      {'shelf_id': shelfId},
      where: 'id = ?',
      whereArgs: [bookId],
    );
    // Finished books don't belong in the reading planner.
    if (shelfId == Shelf.finished) {
      await db
          .delete('planner_books', where: 'book_id = ?', whereArgs: [bookId]);
    }
    DatabaseHelper.booksChanged.notify();
  }
}
