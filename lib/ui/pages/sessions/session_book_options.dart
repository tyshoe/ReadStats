import '/data/database/database_helper.dart';

// Currently Reading first, then To Read, Unfinished, and — though it never
// reaches the list — Finished last.
const Map<int, int> _shelfOrder = {
  DatabaseHelper.shelfCurrentlyReading: 0,
  DatabaseHelper.shelfWantToRead: 1,
  DatabaseHelper.shelfUnfinished: 2,
  DatabaseHelper.shelfFinished: 3,
};

/// The books on offer when logging a session, in the order every session
/// picker shows them: shelf first, then title.
///
/// Finished books are closed to new sessions, so they're dropped. Every entry
/// point into the picker runs its list through here — the timer and the
/// session form open the same sheet, and it should hold the same books
/// whichever one opened it.
List<Map<String, dynamic>> sessionBookOptions(
  List<Map<String, dynamic>> books,
) {
  final options = books
      .where((b) => DatabaseHelper.acceptsSessions(b['shelf_id'] as int?))
      .toList();
  options.sort((a, b) {
    final shelfA = _shelfOrder[a['shelf_id'] as int? ?? 0] ?? 99;
    final shelfB = _shelfOrder[b['shelf_id'] as int? ?? 0] ?? 99;
    if (shelfA != shelfB) return shelfA.compareTo(shelfB);
    final titleA = (a['title'] as String? ?? '').toLowerCase();
    final titleB = (b['title'] as String? ?? '').toLowerCase();
    return titleA.compareTo(titleB);
  });
  return options;
}
