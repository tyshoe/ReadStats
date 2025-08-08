class BookTag {
  final int bookId;
  final int tagId;

  BookTag({
    required this.bookId,
    required this.tagId,
  });

  // Creates a copy of the book-tag with updated fields
  BookTag copyWith({
    int? bookId,
    int? tagId,
  }) {
    return BookTag(
      bookId: bookId ?? this.bookId,
      tagId: tagId ?? this.tagId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'book_id': bookId,
      'tag_id': tagId,
    };
  }

  factory BookTag.fromMap(Map<String, dynamic> map) {
    return BookTag(
      bookId: map['book_id'],
      tagId: map['tag_id'],
    );
  }

  @override
  String toString() => 'BookTag(bookId: $bookId, tagId: $tagId)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is BookTag &&
              runtimeType == other.runtimeType &&
              bookId == other.bookId &&
              tagId == other.tagId;

  @override
  int get hashCode => bookId.hashCode ^ tagId.hashCode;
}