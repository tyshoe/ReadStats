part of 'database_helper.dart';

/// Tags and the book–tag links.
extension TagQueries on DatabaseHelper {
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

  Future<List<Tag>> getAllTagsWithCount() async {
    final db = await database;

    final result = await db.rawQuery('''
    SELECT t.id, t.name, t.color, COUNT(bt.book_id) as bookCount
    FROM tags t
    LEFT JOIN book_tags bt ON t.id = bt.tag_id
    GROUP BY t.id
    ORDER BY COUNT(bt.book_id) COLLATE NOCASE DESC
  ''');

    return result.map((row) => Tag.fromMap(row)).toList();
  }
}
