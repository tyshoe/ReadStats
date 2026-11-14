part of 'database_helper.dart';

/// Shelves.
extension ShelfQueries on DatabaseHelper {
  Future<List<Map<String, dynamic>>> getShelves() async {
    final db = await database;
    return await db.query('shelves', orderBy: 'sort_order ASC');
  }

  Future<int> insertShelf(Map<String, dynamic> shelf) async {
    final db = await database;
    final id = await db.insert('shelves', shelf);
    DatabaseHelper.booksChanged.notify();
    return id;
  }

  Future<int> updateShelf(Map<String, dynamic> shelf) async {
    final db = await database;
    final result = await db.update(
      'shelves',
      shelf,
      where: 'id = ?',
      whereArgs: [shelf['id']],
    );
    DatabaseHelper.booksChanged.notify();
    return result;
  }

  /// Only non-system shelves can be deleted. Books on a deleted shelf
  /// are moved to "Want to Read" (id = 2).
  Future<void> deleteShelf(int shelfId) async {
    final db = await database;
    final rows = await db.query('shelves',
        where: 'id = ?', whereArgs: [shelfId], limit: 1);
    if (rows.isEmpty || rows.first['is_system'] == 1) return;

    const fallbackId = DatabaseHelper.shelfWantToRead;

    await db.update('books', {'shelf_id': fallbackId},
        where: 'shelf_id = ?', whereArgs: [shelfId]);
    await db.delete('shelves', where: 'id = ?', whereArgs: [shelfId]);
    DatabaseHelper.booksChanged.notify();
  }

  Future<void> updateShelfSortOrders(List<Map<String, dynamic>> shelves) async {
    final db = await database;
    final batch = db.batch();
    for (final shelf in shelves) {
      batch.update(
        'shelves',
        {'sort_order': shelf['sort_order']},
        where: 'id = ?',
        whereArgs: [shelf['id']],
      );
    }
    await batch.commit(noResult: true);
    DatabaseHelper.booksChanged.notify();
  }
}
