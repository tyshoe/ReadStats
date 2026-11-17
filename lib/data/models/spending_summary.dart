import '../database/database_helper.dart';

/// One book the reader has put a price on.
class PricedBook {
  final int id;
  final String title;
  final String author;
  final int? bookTypeId;
  final String? coverPath;
  final int? coverShape;

  /// When it joined the library, which is when its price counts as spent.
  final DateTime bought;
  final double paid;

  const PricedBook({
    required this.id,
    required this.title,
    required this.author,
    required this.bookTypeId,
    required this.coverPath,
    required this.coverShape,
    required this.bought,
    required this.paid,
  });
}

/// A slice of the spending — a year, a format, a shelf.
class SpendingGroup<K> {
  final K key;
  final int books;
  final double spent;

  const SpendingGroup(this.key, this.books, this.spent);
}

/// Everything spent up to one day.
class SpendingPoint {
  final DateTime date;
  final double spent;

  const SpendingPoint(this.date, this.spent);
}

/// Where a priced book stands with the reader, for [SpendingSummary.byStatus].
enum ReadStatus {
  read('Read'),
  reading('Reading'),
  unread('Unread'),
  setAside('Set aside'),
  other('Other shelves');

  final String label;
  const ReadStatus(this.label);

  static ReadStatus ofShelf(int? shelfId) => switch (shelfId) {
        DatabaseHelper.shelfFinished => read,
        DatabaseHelper.shelfCurrentlyReading => reading,
        DatabaseHelper.shelfWantToRead => unread,
        DatabaseHelper.shelfUnfinished => setAside,
        _ => other,
      };
}

/// What the reader's books cost, worked out from the price on each one.
///
/// Only books with a price count; the rest of the library is left out of
/// every figure rather than counted as free. A book's price is spent on the
/// day it was added — the app doesn't keep a purchase date of its own.
class SpendingSummary {
  /// Books with a price, dearest first.
  final List<PricedBook> books;

  /// Books in the library with no price.
  final int unpriced;

  final double spent;

  /// Spent on books added this calendar year, and how many.
  final double spentThisYear;
  final int boughtThisYear;

  /// Hours logged on the priced books, for [perHour].
  final double hoursRead;

  /// Newest year first.
  final List<SpendingGroup<int>> byYear;

  /// Most spent first; the key is a `book_type_id`.
  final List<SpendingGroup<int?>> byFormat;

  /// In [ReadStatus] order, without the empty ones.
  final List<SpendingGroup<ReadStatus>> byStatus;

  /// The running total, oldest first, ending today.
  final List<SpendingPoint> timeline;

  const SpendingSummary({
    required this.books,
    required this.unpriced,
    required this.spent,
    required this.spentThisYear,
    required this.boughtThisYear,
    required this.hoursRead,
    required this.byYear,
    required this.byFormat,
    required this.byStatus,
    required this.timeline,
  });

  bool get isEmpty => books.isEmpty;

  double get perBook => books.isEmpty ? 0 : spent / books.length;

  /// What an hour of reading has cost: everything spent over every hour
  /// logged on those books. Null until there is an hour to divide by.
  double? get perHour => hoursRead < 1 ? null : spent / hoursRead;

  /// [bookRows] and [sessionRows] are rows as the app holds them.
  factory SpendingSummary.from(
    List<Map<String, dynamic>> bookRows,
    List<Map<String, dynamic>> sessionRows, {
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();

    final books = <PricedBook>[];
    final status = <int, ReadStatus>{};
    var unpriced = 0;
    for (final row in bookRows) {
      final paid = (row['price_paid'] as num?)?.toDouble();
      if (paid == null) {
        unpriced++;
        continue;
      }
      final id = row['id'] as int;
      status[id] = ReadStatus.ofShelf(row['shelf_id'] as int?);
      books.add(PricedBook(
        id: id,
        title: (row['title'] ?? '').toString(),
        author: (row['author'] ?? '').toString(),
        bookTypeId: row['book_type_id'] as int?,
        coverPath: row['cover_path'] as String?,
        coverShape: row['cover_shape'] as int?,
        bought: DateTime.tryParse(row['date_added']?.toString() ?? '') ?? today,
        paid: paid,
      ));
    }
    books.sort((a, b) => b.paid.compareTo(a.paid));

    var minutes = 0;
    for (final s in sessionRows) {
      if (status.containsKey(s['book_id'])) {
        minutes += (s['duration_minutes'] as num?)?.toInt() ?? 0;
      }
    }

    var spent = 0.0, spentThisYear = 0.0;
    var boughtThisYear = 0;
    final years = <int, (int, double)>{};
    final formats = <int?, (int, double)>{};
    final statuses = <ReadStatus, (int, double)>{};
    (int, double) add((int, double)? to, double paid) =>
        ((to?.$1 ?? 0) + 1, (to?.$2 ?? 0) + paid);

    for (final b in books) {
      spent += b.paid;
      if (b.bought.year == today.year) {
        spentThisYear += b.paid;
        boughtThisYear++;
      }
      years[b.bought.year] = add(years[b.bought.year], b.paid);
      formats[b.bookTypeId] = add(formats[b.bookTypeId], b.paid);
      final s = status[b.id]!;
      statuses[s] = add(statuses[s], b.paid);
    }

    return SpendingSummary(
      books: books,
      unpriced: unpriced,
      spent: spent,
      spentThisYear: spentThisYear,
      boughtThisYear: boughtThisYear,
      hoursRead: minutes / 60,
      byYear: [
        for (final e in years.entries)
          SpendingGroup(e.key, e.value.$1, e.value.$2),
      ]..sort((a, b) => b.key.compareTo(a.key)),
      byFormat: [
        for (final e in formats.entries)
          SpendingGroup(e.key, e.value.$1, e.value.$2),
      ]..sort((a, b) => b.spent.compareTo(a.spent)),
      byStatus: [
        for (final s in ReadStatus.values)
          if (statuses[s] != null)
            SpendingGroup(s, statuses[s]!.$1, statuses[s]!.$2),
      ],
      timeline: _timeline(books, today),
    );
  }

  /// The running total at up to [_maxPoints] evenly spaced days from the
  /// first book to today.
  static const _maxPoints = 60;

  static List<SpendingPoint> _timeline(List<PricedBook> books, DateTime today) {
    if (books.isEmpty) return const [];
    DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);

    final end = day(today);
    var start = end;
    for (final b in books) {
      final d = day(b.bought);
      if (d.isBefore(start)) start = d;
    }
    final span = end.difference(start).inDays;
    if (span <= 0) return const [];

    final step = (span / _maxPoints).ceil().clamp(1, span);
    final days = <DateTime>[
      for (var offset = 0; offset < span; offset += step)
        DateTime(start.year, start.month, start.day + offset),
      end,
    ];

    return [
      for (final d in days)
        () {
          // Through the end of the day, so a book counts on the day it came.
          final until = DateTime(d.year, d.month, d.day + 1);
          var spent = 0.0;
          for (final b in books) {
            if (b.bought.isBefore(until)) spent += b.paid;
          }
          return SpendingPoint(d, spent);
        }(),
    ];
  }
}
