import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/tag.dart';
import '../models/book_tag.dart';

class TagRepository {
  final DatabaseHelper _databaseHelper;

  TagRepository(this._databaseHelper);

  Future<int> createTag(Tag tag) async {
    final db = await _databaseHelper.database;
    try {
      return await db.insert('tags', tag.toMap());
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw TagAlreadyExistsException(tag.name);
      }
      rethrow;
    }
  }

  Future<List<Tag>> getAllTags() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('tags');
    return List.generate(maps.length, (i) => Tag.fromMap(maps[i]));
  }

  Future<int> updateTag(Tag tag) async {
    final db = await _databaseHelper.database;
    return await db.update(
      'tags',
      tag.toMap(),
      where: 'id = ?',
      whereArgs: [tag.id],
    );
  }

  Future<int> deleteTag(int id) async {
    final db = await _databaseHelper.database;
    return await db.delete(
      'tags',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Tag>> getTagsForBook(int bookId) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT tags.* FROM tags
      INNER JOIN book_tags ON tags.id = book_tags.tag_id
      WHERE book_tags.book_id = ?
    ''', [bookId]);
    return List.generate(maps.length, (i) => Tag.fromMap(maps[i]));
  }

  Future<bool> isTagAssignedToBook(int bookId, int tagId) async {
    final db = await _databaseHelper.database;
    final result = await db.query(
      'book_tags',
      where: 'book_id = ? AND tag_id = ?',
      whereArgs: [bookId, tagId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<void> addTagToBook(int bookId, int tagId) async {
    final db = await _databaseHelper.database;

    // First check if the relationship already exists
    final alreadyAssigned = await isTagAssignedToBook(bookId, tagId);
    if (alreadyAssigned) {
      return; // Silently skip if already exists
    }

    try {
      await db.insert(
        'book_tags',
        {'book_id': bookId, 'tag_id': tagId},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    } on DatabaseException catch (e) {
      if (!e.isUniqueConstraintError()) {
        rethrow; // Only rethrow if it's not a unique constraint error
      }
    }
  }

  Future<int> removeTagFromBook(int bookId, int tagId) async {
    final db = await _databaseHelper.database;
    return await db.delete(
      'book_tags',
      where: 'book_id = ? AND tag_id = ?',
      whereArgs: [bookId, tagId],
    );
  }

  Future<List<Tag>> searchTags(String query) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'tags',
      where: 'name LIKE ?',
      whereArgs: ['%$query%'],
    );
    return List.generate(maps.length, (i) => Tag.fromMap(maps[i]));
  }

  // In TagRepository
  Future<List<BookTag>> getAllBookTags() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> results = await db.rawQuery('''
    SELECT book_id, tag_id 
    FROM book_tags
  ''');

    return results.map((row) => BookTag(
      bookId: row['book_id'] as int,
      tagId: row['tag_id'] as int,
    )).toList();
  }
}

extension DatabaseExceptionExtensions on DatabaseException {
  bool isUniqueConstraintError() {
    return toString().contains('SQLITE_CONSTRAINT') &&
        (toString().contains('UNIQUE') || toString().contains('PRIMARY KEY'));
  }
}

class TagAlreadyExistsException implements Exception {
  final String tagName;

  TagAlreadyExistsException(this.tagName);

  @override
  String toString() => 'Tag "$tagName" already exists';
}