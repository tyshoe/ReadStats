class PlannerBook {
  final int? id;
  final int bookId;
  final int sortOrder;
  final String dateAdded;
  // Populated from JOIN with books table — not stored in planner_books
  final String bookTitle;
  final String bookAuthor;
  final int pageCount;
  final int bookTypeId;
  final int durationMinutes;

  const PlannerBook({
    this.id,
    required this.bookId,
    required this.sortOrder,
    required this.dateAdded,
    required this.bookTitle,
    required this.bookAuthor,
    this.pageCount = 0,
    this.bookTypeId = 0,
    this.durationMinutes = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'book_id': bookId,
      'sort_order': sortOrder,
      'date_added': dateAdded,
    };
  }

  factory PlannerBook.fromMap(Map<String, dynamic> map) {
    return PlannerBook(
      id: map['id'] as int?,
      bookId: map['book_id'] as int,
      sortOrder: map['sort_order'] as int? ?? 0,
      dateAdded: map['date_added'] as String? ?? DateTime.now().toIso8601String(),
      bookTitle: map['title'] as String? ?? '',
      bookAuthor: map['author'] as String? ?? '',
      pageCount: map['page_count'] as int? ?? 0,
      bookTypeId: map['book_type_id'] as int? ?? 0,
      durationMinutes: map['duration_minutes'] as int? ?? 0,
    );
  }

  PlannerBook copyWith({
    int? id,
    int? bookId,
    int? sortOrder,
    String? dateAdded,
    String? bookTitle,
    String? bookAuthor,
    int? pageCount,
    int? bookTypeId,
    int? durationMinutes,
  }) {
    return PlannerBook(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      sortOrder: sortOrder ?? this.sortOrder,
      dateAdded: dateAdded ?? this.dateAdded,
      bookTitle: bookTitle ?? this.bookTitle,
      bookAuthor: bookAuthor ?? this.bookAuthor,
      pageCount: pageCount ?? this.pageCount,
      bookTypeId: bookTypeId ?? this.bookTypeId,
      durationMinutes: durationMinutes ?? this.durationMinutes,
    );
  }
}
