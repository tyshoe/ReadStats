import 'package:read_stats/data/database/database_helper.dart';
import 'package:read_stats/data/models/tag.dart';

class Book {
  int? id;
  String title;
  String author;
  int wordCount;
  int pageCount;
  double? rating;
  bool isFavorite;
  int bookTypeId;
  final String dateAdded;
  final String? dateStarted;
  final String? dateFinished;
  List<Tag> tags;
  String? isbn;
  String? userReview;
  int durationMinutes;
  int shelfId;
  String? coverPath;
  // Denormalized from JOIN — populated when loaded from DB, not written back
  final String? shelfName;

  Book({
    this.id,
    required this.title,
    required this.author,
    required this.wordCount,
    required this.pageCount,
    required this.rating,
    required this.isFavorite,
    required this.bookTypeId,
    required this.dateAdded,
    this.dateStarted,
    this.dateFinished,
    this.tags = const [],
    this.isbn,
    this.userReview,
    this.durationMinutes = 0,
    this.shelfId = DatabaseHelper.shelfWantToRead,
    this.coverPath,
    this.shelfName,
  });

  /// Convert to Map for database writes.
  /// shelfKey / shelfName are read-only JOIN fields — excluded from writes.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'word_count': wordCount,
      'page_count': pageCount,
      'rating': rating,
      'is_favorite': isFavorite ? 1 : 0,
      'book_type_id': bookTypeId,
      'date_added': dateAdded,
      'date_started': dateStarted,
      'date_finished': dateFinished,
      'isbn': isbn,
      'user_review': userReview,
      'duration_minutes': durationMinutes,
      'shelf_id': shelfId,
      'cover_path': coverPath,
      // tags stored separately in book_tags
    };
  }

  factory Book.fromMap(Map<String, dynamic> map) {
    return Book(
      id: map['id'],
      title: map['title'] ?? '',
      author: map['author'] ?? '',
      wordCount: (map['word_count'] as int?) ?? 0,
      pageCount: (map['page_count'] as int?) ?? 0,
      rating: map['rating'] != null ? (map['rating'] as num).toDouble() : null,
      isFavorite: (map['is_favorite'] as int?) == 1,
      bookTypeId: (map['book_type_id'] as int?) ?? 1,
      dateAdded: map['date_added'] ?? DateTime.now().toIso8601String(),
      dateStarted: map['date_started'],
      dateFinished: map['date_finished'],
      isbn: map['isbn'],
      userReview: map['user_review'],
      durationMinutes: (map['duration_minutes'] as int?) ?? 0,
      shelfId: (map['shelf_id'] as int?) ?? DatabaseHelper.shelfWantToRead,
      coverPath: map['cover_path'] as String?,
      shelfName: map['shelf_name'] as String?,
    );
  }

  bool get isFinished => dateFinished != null;

  void addTag(Tag tag) => tags.add(tag);
  void removeTag(Tag tag) => tags.remove(tag);
  bool hasTag(Tag tag) => tags.any((t) => t.id == tag.id);

  @override
  String toString() => 'Book(id: $id, title: $title, shelfId: $shelfId, tags: ${tags.length})';
}