import 'package:read_stats/data/models/book_type.dart';
import 'package:read_stats/data/models/shelf.dart';

/// A filter on one measure of a book — its rating, its page count, or an
/// audiobook's listening time in minutes. One shape for all three, so they
/// behave alike: a range whose open ends mean "no limit", or else only the
/// books with no value at all.
class MeasureRange {
  /// Inclusive bounds; null is open.
  final num? min;
  final num? max;

  /// Only books without a value: unrated, no page count, no listening time.
  final bool missing;

  const MeasureRange({this.min, this.max, this.missing = false});

  static const any = MeasureRange();

  /// Whether this narrows anything. With both ends open and [missing] off,
  /// every book passes — those without a value too.
  bool get isActive => missing || min != null || max != null;

  /// Whether a book whose value is [value] passes. Null is "no value",
  /// which only [missing] lets through once a range is set. Zero is a value
  /// here — a book rated 0 stars has been rated, unlike one with no rating
  /// — so measures where zero means "not known" (a page count of 0) pass
  /// null instead; see [known].
  bool matches(num? value) {
    if (missing) return value == null;
    if (min == null && max == null) return true;
    return value != null &&
        (min == null || value >= min!) &&
        (max == null || value <= max!);
  }

  /// [value] where zero or less stands for "not known" — a page count or a
  /// listening time — as null.
  static num? known(Object? value) =>
      value is num && value > 0 ? value : null;

  @override
  bool operator ==(Object other) =>
      other is MeasureRange &&
      other.min == min &&
      other.max == max &&
      other.missing == missing;

  @override
  int get hashCode => Object.hash(min, max, missing);
}

/// What narrows the Library's list: the shelf chip and every option in the
/// sort & filter sheet. An empty list or `false` means "don't filter on it".
class LibraryFilter {
  /// Format names as the filter sheet shows them ("Paperback", …).
  final List<String> bookTypes;
  final bool favoritesOnly;
  final bool reviewedOnly;
  final int? shelfId;
  final bool seriesOnly;

  /// 'all', 'with' or 'without' a cover.
  final String coverFilter;
  final List<String> finishedYears;
  final List<String> tags;

  /// How [tags] combine: 'any', 'all' or 'exclude'.
  final String tagMode;

  /// Stars, half stars included.
  final MeasureRange rating;

  /// Page count — print books and ebooks. See [apply] for how this and
  /// [listening] share out the formats.
  final MeasureRange pages;

  /// Listening time in minutes — audiobooks.
  final MeasureRange listening;

  const LibraryFilter({
    required this.bookTypes,
    required this.favoritesOnly,
    required this.reviewedOnly,
    required this.shelfId,
    required this.seriesOnly,
    required this.coverFilter,
    required this.finishedYears,
    required this.tags,
    required this.tagMode,
    this.rating = MeasureRange.any,
    this.pages = MeasureRange.any,
    this.listening = MeasureRange.any,
  });

  /// Roughly how many print pages an hour of narration covers — for putting
  /// audiobooks among print books when sorting by length.
  static const double pagesPerListeningHour = 32;

  static int _minutesOf(Map<String, dynamic> book) =>
      (book['duration_minutes'] as num?)?.toInt() ?? 0;

  static int _pagesOf(Map<String, dynamic> book) =>
      (book['page_count'] as num?)?.toInt() ?? 0;

  /// A book's length in pages, an audiobook's listening time turned into
  /// pages, so every format sorts by length on one scale. An audiobook with
  /// no listening time falls back to a page count if it has one (some
  /// imports carry the print edition's). Null when unknown.
  static double? pageLengthOf(Map<String, dynamic> book) {
    final minutes = _minutesOf(book);
    if (book['book_type_id'] == BookType.audiobook && minutes > 0) {
      return minutes / 60 * pagesPerListeningHour;
    }
    final pages = _pagesOf(book);
    return pages > 0 ? pages.toDouble() : null;
  }

  /// The sort a shelf starts with until the reader picks another: the order
  /// it's naturally read in, newest first. Unfinished books keep the day
  /// they were started but no finish, so they go by that.
  static (String, bool) defaultSort(int? shelfId) => switch (shelfId) {
        Shelf.finished => ('Date finished', false),
        Shelf.currentlyReading || Shelf.unfinished => ('Date started', false),
        _ => ('Date added', false),
      };

  static const Map<int, String> bookTypeNames = {
    1: "Paperback",
    2: "Hardback",
    3: "eBook",
    4: "Audiobook",
  };

  /// The books that pass every filter, in the order given. [tagsByBook] holds
  /// each book's tag names by book id.
  List<Map<String, dynamic>> apply(
    List<Map<String, dynamic>> books,
    Map<int, List<String>> tagsByBook,
  ) {
    final selectedTypeIds = bookTypes
        .map(
          (type) => bookTypeNames.entries
              .firstWhere(
                (entry) => entry.value == type,
                orElse: () => const MapEntry(-1, ''),
              )
              .key,
        )
        .where((id) => id != -1)
        .toList();

    return books.where((book) {
      final typeMatch =
          selectedTypeIds.isEmpty ||
          (book['book_type_id'] != null &&
              selectedTypeIds.contains(book['book_type_id']));

      final favoriteMatch =
          !favoritesOnly ||
          (book['is_favorite'] != null && book['is_favorite'] == 1);

      final reviewedMatch =
          !reviewedOnly ||
          (book['user_review'] != null &&
              (book['user_review'] as String).trim().isNotEmpty);

      final shelfMatch =
          shelfId == null || (book['shelf_id'] as int?) == shelfId;

      final seriesMatch = !seriesOnly || book['series_id'] != null;

      final hasCover = (book['cover_path'] as String?)?.isNotEmpty ?? false;
      final coverMatch = switch (coverFilter) {
        'with' => hasCover,
        'without' => !hasCover,
        _ => true,
      };

      bool yearMatch = finishedYears.isEmpty;
      if (!yearMatch && book['date_finished'] != null) {
        final date = DateTime.tryParse(book['date_finished'].toString());
        yearMatch = date != null && finishedYears.contains('${date.year}');
      }

      bool tagMatch = tags.isEmpty;
      if (!tagMatch) {
        final bookTags = tagsByBook[book['id'] as int] ?? const [];
        tagMatch = switch (tagMode) {
          'all' => tags.every(bookTags.contains),
          'exclude' => !tags.any(bookTags.contains),
          _ => tags.any(bookTags.contains),
        };
      }

      // Null is no rating; 0 is a rating of no stars.
      final ratingMatch = rating.matches(book['rating'] as num?);

      // Pages say nothing about an audiobook, and listening time nothing
      // about print, so each kind is judged by its own measure. With only
      // one set, the other kind drops out — asking for 300+ pages is asking
      // about books that have pages. With both set, either kind can match.
      final isAudio = book['book_type_id'] == BookType.audiobook;
      final lengthMatch = !(pages.isActive || listening.isActive) ||
          (isAudio
              ? listening.isActive &&
                  listening.matches(MeasureRange.known(book['duration_minutes']))
              : pages.isActive &&
                  pages.matches(MeasureRange.known(book['page_count'])));

      return typeMatch &&
          favoriteMatch &&
          reviewedMatch &&
          shelfMatch &&
          seriesMatch &&
          coverMatch &&
          yearMatch &&
          tagMatch &&
          ratingMatch &&
          lengthMatch;
    }).toList();
  }

  /// [books] sorted by [option] ('Title', 'Author', 'Rating', 'Pages',
  /// 'Date started', 'Date finished' or 'Date added'), with the pinned ones
  /// first in the order they came.
  ///
  /// Books missing the sorted value — unrated, no page count, never finished —
  /// go last whichever way the sort runs, and ties fall back to title, so the
  /// order never shuffles between loads.
  static List<Map<String, dynamic>> sort(
    List<Map<String, dynamic>> books,
    String option,
    bool ascending,
    Set<int> pinnedIds,
  ) {
    final pinned = books.where((b) => pinnedIds.contains(b['id'])).toList();
    final unpinned = books.where((b) => !pinnedIds.contains(b['id'])).toList();

    // The value each book is sorted by, worked out once rather than on every
    // comparison. Null when the book doesn't have one.
    Comparable<dynamic>? keyOf(Map<String, dynamic> b) {
      DateTime? date(String key) => DateTime.tryParse(b[key] as String? ?? '');
      num? positive(String key) {
        final v = b[key] as num?;
        return v == null || v <= 0 ? null : v;
      }

      final Object? key = switch (option) {
        'Title' => titleSortKey(b['title'] as String?),
        'Author' => (b['author'] as String? ?? '').trim().toLowerCase(),
        'Rating' => positive('rating'),
        // Audiobooks by listening time, on the same scale as pages.
        'Pages' => pageLengthOf(b),
        'Date started' => date('date_started'),
        'Date finished' => date('date_finished'),
        'Date added' => date('date_added'),
        _ => null,
      };
      if (key is String && key.isEmpty) return null;
      return key as Comparable<dynamic>?;
    }

    final keys = {for (final b in unpinned) b['id']: keyOf(b)};
    final titles = {
      for (final b in unpinned) b['id']: titleSortKey(b['title'] as String?),
    };

    unpinned.sort((a, b) {
      final ka = keys[a['id']];
      final kb = keys[b['id']];
      if (ka == null || kb == null) {
        if (ka != kb) return ka == null ? 1 : -1;
      } else {
        final c = ka.compareTo(kb);
        if (c != 0) return ascending ? c : -c;
      }
      return titles[a['id']]!.compareTo(titles[b['id']]!);
    });

    return [...pinned, ...unpinned];
  }

  static final _leadingArticle = RegExp(r'^(the|a|an)\s+');

  /// A title as it files on a shelf: lower case, with a leading "The", "A"
  /// or "An" set aside, so "The Road" sits under R.
  static String titleSortKey(String? title) {
    final t = (title ?? '').trim().toLowerCase();
    final stripped = t.replaceFirst(_leadingArticle, '');
    return stripped.isEmpty ? t : stripped;
  }

  /// Every year a book was finished in, newest first.
  static List<String> finishedYearsOf(List<Map<String, dynamic>> books) {
    final years = <String>{
      for (final book in books)
        if (book['date_finished'] case final String finished)
          if (DateTime.tryParse(finished) case final date?) '${date.year}',
    };
    return years.toList()..sort((a, b) => b.compareTo(a));
  }
}
