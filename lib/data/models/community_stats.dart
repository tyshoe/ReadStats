/// App-wide totals shown on the Settings support card, summed once a day by
/// `.github/scripts/community_stats.py` over installs active in the last 90
/// days that share usage statistics. See `LibrarySnapshotService`.
class CommunityStats {
  /// Installs with a real (non-demo, non-empty) library.
  final int readers;

  /// Books in those libraries right now.
  final int booksTracked;

  /// Whole hours across those installs' logged reading sessions.
  final int hoursRead;

  const CommunityStats({
    required this.readers,
    required this.booksTracked,
    required this.hoursRead,
  });

  /// Null unless every count is present and non-negative, so a broken or
  /// half-written file shows nothing rather than a wrong number.
  static CommunityStats? fromJson(Object? json) {
    if (json is! Map) return null;
    int? count(String key) {
      final value = json[key];
      return value is int && value >= 0 ? value : null;
    }

    final readers = count('readers');
    final booksTracked = count('books_tracked');
    final hoursRead = count('hours_read');
    if (readers == null || booksTracked == null || hoursRead == null) {
      return null;
    }
    return CommunityStats(
      readers: readers,
      booksTracked: booksTracked,
      hoursRead: hoursRead,
    );
  }
}
