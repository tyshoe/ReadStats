import '/data/database/database_helper.dart';
import '/data/models/planner_book.dart';
import '/data/services/cover_service.dart';

class PlannerRepository {
  final DatabaseHelper _databaseHelper;

  PlannerRepository(this._databaseHelper);

  Future<int> addPlannerBook(PlannerBook book) async {
    return await _databaseHelper.insertPlannerBook(book.toMap());
  }

  Future<List<PlannerBook>> getPlannerBooks() async {
    final maps = await _databaseHelper.getPlannerBooks();
    final books = <PlannerBook>[];
    for (final m in maps) {
      final book = PlannerBook.fromMap(m);
      books.add(book.copyWith(coverPath: await _resolveCover(book.coverPath)));
    }
    return books;
  }

  /// Books currently on the "Want to Read" shelf — the source for the
  /// add-to-planner picker. Loaded fresh so the picker reflects the live
  /// library rather than a snapshot captured at navigation time.
  Future<List<Map<String, dynamic>>> getWantToReadBooks() async {
    final maps = await _databaseHelper.getBooks(
      shelfId: DatabaseHelper.shelfWantToRead,
    );
    final books = <Map<String, dynamic>>[];
    for (final m in maps) {
      final resolved = await _resolveCover(m['cover_path'] as String?);
      books.add({...m, 'cover_path': resolved});
    }
    return books;
  }

  /// Cover values are stored as bare filenames ("42.jpg") and must be resolved
  /// to a current absolute path before use in [Image.file]. Returns null when
  /// there is no cover. Mirrors the resolution done at app load.
  Future<String?> _resolveCover(String? storedPath) async {
    if (storedPath == null) return null;
    return CoverService.resolveFullPath(storedPath);
  }

  Future<int> deletePlannerBook(int id) async {
    return await _databaseHelper.deletePlannerBook(id);
  }

  /// Persists the new order after a drag-and-drop reorder.
  /// [books] should be the list in its new display order.
  Future<void> reorderBooks(List<PlannerBook> books) async {
    final reindexed = [
      for (int i = 0; i < books.length; i++)
        books[i].copyWith(sortOrder: i),
    ];
    await _databaseHelper.updatePlannerSortOrders(reindexed.map((b) => b.toMap()).toList());
  }
}
