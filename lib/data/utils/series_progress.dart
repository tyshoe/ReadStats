import '../database/database_helper.dart';

/// Where one number of a series stands for the reader.
enum SeriesSlotState { finished, reading, unfinished, toRead, missing }

/// One number in a series: the books the reader has at that number (often
/// one; a paperback and an audiobook of the same book make two), or none.
class SeriesSlot {
  final double position;
  final List<Map<String, dynamic>> books;
  final SeriesSlotState state;

  /// A number held for a book the reader doesn't have yet — `id`, `title`.
  /// Only on missing slots: a book at the same number takes its place.
  final Map<String, dynamic>? placeholder;

  const SeriesSlot(this.position, this.books, this.state, {this.placeholder});

  bool get isMissing => books.isEmpty;

  /// Missing, but held by a placeholder.
  bool get isPlanned => books.isEmpty && placeholder != null;

  /// The placeholder's title, if it has one.
  String? get plannedTitle => placeholder?['title'] as String?;

  /// The copy to open — the one furthest along.
  Map<String, dynamic>? get book => books.isEmpty ? null : books.first;
}

/// A series as the reader has it: every number from 1 to the highest they
/// own (gaps included), what state each is in, and what comes next.
///
/// Built from the books in one series. Shared by the Library's series rows,
/// the Series page and the book detail strip, so all three agree.
class SeriesProgress {
  final int seriesId;
  final String name;
  final List<SeriesSlot> slots;

  /// Books with no number. Counted, but not placed in the strip.
  final List<Map<String, dynamic>> unnumbered;

  SeriesProgress._(this.seriesId, this.name, this.slots, this.unnumbered);

  /// [placeholders] are rows of `series_placeholders`: numbers held for
  /// books not in the library. They count toward the series, unread.
  factory SeriesProgress.from(
    int seriesId,
    List<Map<String, dynamic>> books, {
    List<Map<String, dynamic>> placeholders = const [],
  }) {
    final name = books
            .map((b) => b['series_name'] as String?)
            .firstWhere((n) => n != null && n.isNotEmpty, orElse: () => null) ??
        'Series';

    final byPosition = <double, List<Map<String, dynamic>>>{};
    final unnumbered = <Map<String, dynamic>>[];
    for (final b in books) {
      final p = (b['series_position'] as num?)?.toDouble();
      if (p == null) {
        unnumbered.add(b);
      } else {
        byPosition.putIfAbsent(p, () => []).add(b);
      }
    }

    final planned = <double, Map<String, dynamic>>{
      for (final p in placeholders)
        if ((p['position'] as num?) != null)
          (p['position'] as num).toDouble(): p,
    };

    // Whole numbers up to the highest one owned or planned, so a gap shows
    // as a gap; in-between numbers (a #1.5 novella) only when they're there.
    final positions = <double>{...byPosition.keys, ...planned.keys};
    if (positions.isNotEmpty) {
      final top = positions.reduce((a, b) => a > b ? a : b).floor();
      for (var i = 1; i <= top; i++) {
        positions.add(i.toDouble());
      }
    }
    final ordered = positions.toList()..sort();

    final slots = [
      for (final p in ordered)
        _slot(p, byPosition[p] ?? const [], planned[p]),
    ];
    return SeriesProgress._(seriesId, name, slots, unnumbered);
  }

  static SeriesSlot _slot(double position, List<Map<String, dynamic>> books,
      Map<String, dynamic>? placeholder) {
    if (books.isEmpty) {
      return SeriesSlot(position, const [], SeriesSlotState.missing,
          placeholder: placeholder);
    }
    final sorted = [...books]..sort((a, b) => _rank(a).compareTo(_rank(b)));
    return SeriesSlot(position, sorted, _stateOf(sorted.first));
  }

  /// Furthest along first: finished, reading, unfinished, to read.
  static int _rank(Map<String, dynamic> b) => switch (_stateOf(b)) {
        SeriesSlotState.finished => 0,
        SeriesSlotState.reading => 1,
        SeriesSlotState.unfinished => 2,
        _ => 3,
      };

  static SeriesSlotState _stateOf(Map<String, dynamic> b) =>
      switch (b['shelf_id'] as int?) {
        DatabaseHelper.shelfFinished => SeriesSlotState.finished,
        DatabaseHelper.shelfCurrentlyReading => SeriesSlotState.reading,
        DatabaseHelper.shelfUnfinished => SeriesSlotState.unfinished,
        _ => SeriesSlotState.toRead,
      };

  /// Numbers in the strip plus unnumbered books.
  int get total => slots.length + unnumbered.length;

  int get read =>
      slots.where((s) => s.state == SeriesSlotState.finished).length +
      unnumbered
          .where((b) => _stateOf(b) == SeriesSlotState.finished)
          .length;

  bool get isComplete => total > 0 && read == total;

  /// Every book the reader owns, in reading order.
  List<Map<String, dynamic>> get books => [
        for (final s in slots) ...s.books,
        ...unnumbered,
      ];

  /// What to read next: the book in progress if there is one, otherwise the
  /// first number not yet read — owned or missing.
  SeriesSlot? get nextUp {
    for (final s in slots) {
      if (s.state == SeriesSlotState.reading) return s;
    }
    for (final s in slots) {
      if (s.state == SeriesSlotState.toRead ||
          s.state == SeriesSlotState.missing) {
        return s;
      }
    }
    return null;
  }

  /// The number a new book most likely takes: the first open gap, or one
  /// past the end.
  double get nextFreeNumber {
    for (final s in slots) {
      if (s.isMissing && !s.isPlanned) return s.position;
    }
    if (slots.isEmpty) return 1;
    return slots.last.position.floorToDouble() + 1;
  }

  /// The most common author, for a series written by one person.
  String? get author {
    final counts = <String, int>{};
    for (final b in books) {
      final a = (b['author'] as String?)?.trim();
      if (a != null && a.isNotEmpty) counts[a] = (counts[a] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;
    return counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
  }

  /// "Book 3", or "Book 1.5" for an in-between number.
  static String label(double position) => 'Book ${formatNumber(position)}';

  static String formatNumber(double position) =>
      position == position.roundToDouble()
          ? position.toInt().toString()
          : position.toString();

  /// Groups [books] by series. Books without one are left out.
  static Map<int, List<Map<String, dynamic>>> bySeries(
    Iterable<Map<String, dynamic>> books,
  ) {
    final map = <int, List<Map<String, dynamic>>>{};
    for (final b in books) {
      final id = b['series_id'] as int?;
      if (id != null) map.putIfAbsent(id, () => []).add(b);
    }
    return map;
  }
}
