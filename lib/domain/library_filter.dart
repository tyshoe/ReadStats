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
  });

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

      return typeMatch &&
          favoriteMatch &&
          reviewedMatch &&
          shelfMatch &&
          seriesMatch &&
          coverMatch &&
          yearMatch &&
          tagMatch;
    }).toList();
  }

  /// [books] sorted by [option] ('Title', 'Author', 'Rating', 'Pages',
  /// 'Date started', 'Date finished' or 'Date added'), with the pinned ones
  /// first in the order they came.
  static List<Map<String, dynamic>> sort(
    List<Map<String, dynamic>> books,
    String option,
    bool ascending,
    Set<int> pinnedIds,
  ) {
    final pinned = books.where((b) => pinnedIds.contains(b['id'])).toList();
    final unpinned = books.where((b) => !pinnedIds.contains(b['id'])).toList();

    DateTime date(Map<String, dynamic> b, String key) =>
        b[key] != null ? DateTime.tryParse(b[key]) ?? DateTime(0) : DateTime(0);

    unpinned.sort((a, b) {
      final int comparison = switch (option) {
        'Title' => (a['title'] ?? '').compareTo(b['title'] ?? ''),
        'Author' => (a['author'] ?? '').compareTo(b['author'] ?? ''),
        'Rating' => (a['rating'] ?? 0.0).toDouble().compareTo(
          (b['rating'] ?? 0.0).toDouble(),
        ),
        'Pages' => (a['page_count'] ?? 0).toInt().compareTo(
          (b['page_count'] ?? 0).toInt(),
        ),
        'Date started' => date(
          a,
          'date_started',
        ).compareTo(date(b, 'date_started')),
        'Date finished' => date(
          a,
          'date_finished',
        ).compareTo(date(b, 'date_finished')),
        'Date added' => date(a, 'date_added').compareTo(date(b, 'date_added')),
        _ => 0,
      };
      return ascending ? comparison : -comparison;
    });

    return [...pinned, ...unpinned];
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
