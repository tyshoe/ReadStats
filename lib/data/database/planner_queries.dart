part of 'database_helper.dart';

/// The reading planner.
extension PlannerQueries on DatabaseHelper {
  Future<bool> isInPlanner(int bookId) async {
    final db = await database;
    final rows = await db.query('planner_books',
        columns: ['id'], where: 'book_id = ?', whereArgs: [bookId], limit: 1);
    return rows.isNotEmpty;
  }

  Future<int> insertPlannerBook(Map<String, dynamic> plannerBook) async {
    final db = await database;
    // Append after the current last item. MAX+1 (not COUNT) so a gap left by a
    // deleted row can't collide with an existing sort_order.
    final result =
        await db.rawQuery('SELECT MAX(sort_order) as max_order FROM planner_books');
    final maxOrder = result.first['max_order'] as int?;
    final sortOrder = maxOrder == null ? 0 : maxOrder + 1;
    return await db.insert('planner_books', {
      'book_id': plannerBook['book_id'],
      'sort_order': sortOrder,
      'date_added': plannerBook['date_added'],
    });
  }

  Future<List<Map<String, dynamic>>> getPlannerBooks() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT t.id, t.book_id, t.sort_order, t.date_added,
             b.title, b.author, b.cover_path, b.cover_shape, b.page_count,
             b.book_type_id, b.duration_minutes
      FROM planner_books t
      INNER JOIN books b ON t.book_id = b.id
      ORDER BY t.sort_order ASC
    ''');
  }

  Future<int> deletePlannerBook(int id) async {
    final db = await database;
    return await db.delete('planner_books', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updatePlannerSortOrders(List<Map<String, dynamic>> books) async {
    final db = await database;
    final batch = db.batch();
    for (final book in books) {
      batch.update(
        'planner_books',
        {'sort_order': book['sort_order']},
        where: 'id = ?',
        whereArgs: [book['id']],
      );
    }
    await batch.commit(noResult: true);
  }
}
