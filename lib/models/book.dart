class Book {
  int? id; // Nullable because it's auto-generated
  String title;
  String author;
  int wordCount;
  double rating;
  bool isCompleted;

  Book({
    this.id,
    required this.title,
    required this.author,
    required this.wordCount,
    required this.rating,
    required this.isCompleted,
  });

  // Convert a Book object into a Map for database operations
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'word_count': wordCount,
      'rating': rating,
      'is_completed': isCompleted ? 1 : 0, // SQLite doesn't support bool, use 1 & 0
    };
  }

  // Create a Book object from a Map (retrieved from database)
  factory Book.fromMap(Map<String, dynamic> map) {
    return Book(
      id: map['id'],
      title: map['title'],
      author: map['author'],
      wordCount: map['word_count'],
      rating: map['rating'].toDouble(),
      isCompleted: map['is_completed'] == 1, // Convert 1 & 0 back to bool
    );
  }
}
