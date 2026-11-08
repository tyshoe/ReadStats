import '../database/database_helper.dart';
import '../models/book.dart';

class SeriesRepository {
  final DatabaseHelper _db;

  SeriesRepository(this._db);

  /// The id for the series called [name], creating it on first use.
  Future<int> idFor(String name) => _db.seriesIdFor(name);

  /// Series that have books, A–Z.
  Future<List<String>> names() => _db.getSeriesNames();

  /// Highest number in the series called [name], ignoring [excludeBookIds].
  Future<double?> maxPosition(String name,
          {List<int> excludeBookIds = const []}) =>
      _db.getSeriesMaxPosition(name, excludeBookIds: excludeBookIds);

  /// The books in a series, in reading order.
  Future<List<Map<String, dynamic>>> booksIn(int seriesId) =>
      _db.getBooksInSeries(seriesId);

  /// Links books in one batch — see [DatabaseHelper.linkBooksToSeries].
  Future<void> link(List<Map<String, dynamic>> updates) =>
      _db.linkBooksToSeries(updates);

  /// Fills in [Book.seriesId] for books that arrived with only a series name
  /// (imports, demo data), creating series as needed.
  Future<void> resolveNames(List<Book> books) async {
    final ids = <String, int>{};
    for (final book in books) {
      final name = book.seriesName?.trim();
      if (name == null || name.isEmpty || book.seriesId != null) continue;
      book.seriesId = ids[name.toLowerCase()] ??= await idFor(name);
    }
  }
}
