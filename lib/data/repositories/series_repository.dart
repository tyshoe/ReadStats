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

  /// Placeholders in a series, in order.
  Future<List<Map<String, dynamic>>> placeholdersIn(int seriesId) =>
      _db.getSeriesPlaceholders(seriesId);

  /// Every placeholder with its series' name — for backups.
  Future<List<Map<String, dynamic>>> allPlaceholderRows() =>
      _db.getAllSeriesPlaceholders();

  /// Every placeholder by series id — for the Library's series rows.
  Future<Map<int, List<Map<String, dynamic>>>> allPlaceholders() async {
    final map = <int, List<Map<String, dynamic>>>{};
    for (final r in await _db.getAllSeriesPlaceholders()) {
      map.putIfAbsent(r['series_id'] as int, () => []).add(r);
    }
    return map;
  }

  Future<void> savePlaceholder(int seriesId, double position, String? title) =>
      _db.saveSeriesPlaceholder(seriesId, position, _clean(title));

  Future<void> updatePlaceholder(
          int id, int seriesId, double position, String? title) =>
      _db.updateSeriesPlaceholder(id, seriesId, position, _clean(title));

  /// New numbers for several placeholders in one go, by id.
  Future<void> repositionPlaceholders(Map<int, double> positionsById) =>
      _db.repositionSeriesPlaceholders(positionsById);

  Future<void> deletePlaceholders(List<int> ids) =>
      _db.deleteSeriesPlaceholders(ids);

  /// Placeholders from a backup or the demo, by series name — ids are local.
  /// Rows: `series_name`, `position`, `title`.
  Future<int> restorePlaceholders(List<Map<String, dynamic>> rows) async {
    var count = 0;
    for (final r in rows) {
      final name = (r['series_name'] as String?)?.trim();
      final position = (r['position'] as num?)?.toDouble();
      if (name == null || name.isEmpty || position == null) continue;
      await _db.saveSeriesPlaceholder(
          await idFor(name), position, _clean(r['title'] as String?));
      count++;
    }
    return count;
  }

  static String? _clean(String? title) {
    final t = title?.trim();
    return t == null || t.isEmpty ? null : t;
  }

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
