import 'package:read_stats/data/models/tag.dart';

class Book {
  int? id; // Nullable because it's auto-generated
  String title;
  String author;
  int wordCount;
  int pageCount;
  double? rating;
  bool isCompleted;
  bool isFavorite;
  int bookTypeId;
  final String dateAdded;
  final String? dateStarted;
  final String? dateFinished;
  List<Tag> tags;

  Book({
    this.id,
    required this.title,
    required this.author,
    required this.wordCount,
    required this.pageCount,
    required this.rating,
    required this.isCompleted,
    required this.isFavorite,
    required this.bookTypeId,
    required this.dateAdded,
    this.dateStarted,
    this.dateFinished,
    this.tags = const [], // Initialize empty list by default
  });

  // Convert a Book object into a Map for database operations
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'word_count': wordCount,
      'page_count': pageCount,
      'rating': rating,
      'is_completed': isCompleted ? 1 : 0,
      'is_favorite': isFavorite ? 1 : 0,
      'book_type_id': bookTypeId,
      'date_added': dateAdded,
      'date_started': dateStarted,
      'date_finished': dateFinished,
      // Note: tags are not included here as they're stored separately
    };
  }

  // Create a Book object from a Map (retrieved from database)
  factory Book.fromMap(Map<String, dynamic> map) {
    return Book(
      id: map['id'],
      title: map['title'] ?? '', // Ensure non-null string
      author: map['author'] ?? '', // Ensure non-null string
      wordCount: (map['word_count'] as int?) ?? 0,
      pageCount: (map['page_count'] as int?) ?? 0,
      rating: map['rating'] != null ? double.tryParse(map['rating'].toString()) : null,
      isCompleted: (map['is_completed'] as int?) == 1,
      isFavorite: (map['is_favorite'] as int?) == 1,
      bookTypeId: (map['book_type_id'] as int?) ?? 1, // Default value
      dateAdded: map['date_added'] ?? DateTime.now().toIso8601String(),
      dateStarted: map['date_started'],
      dateFinished: map['date_finished']
    );
  }

  // Helper method to add a tag
  void addTag(Tag tag) {
    tags.add(tag);
  }

  // Helper method to remove a tag
  void removeTag(Tag tag) {
    tags.remove(tag);
  }

  // Helper method to check if book has a specific tag
  bool hasTag(Tag tag) {
    return tags.any((t) => t.id == tag.id);
  }

  @override
  String toString() {
    return 'Book(id: $id, title: $title, tags: ${tags.length})';
  }
}