import '/data/database/database_helper.dart';
import '/data/models/planner_book.dart';

class PlannerRepository {
  final DatabaseHelper _databaseHelper;

  PlannerRepository(this._databaseHelper);

  Future<int> addPlannerBook(PlannerBook book) async {
    return await _databaseHelper.insertPlannerBook(book.toMap());
  }

  Future<List<PlannerBook>> getPlannerBooks() async {
    final maps = await _databaseHelper.getPlannerBooks();
    return maps.map((m) => PlannerBook.fromMap(m)).toList();
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
