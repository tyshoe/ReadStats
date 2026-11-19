import 'package:read_stats/data/models/cover_shape.dart';
import 'package:read_stats/data/models/shelf.dart';
import 'package:read_stats/data/models/tag.dart';

class Book {
  int? id;
  String title;
  String author;
  int? wordCount;
  int? pageCount;
  double? rating;
  bool isFavorite;
  int bookTypeId;
  final String dateAdded;
  final String? dateStarted;
  final String? dateFinished;
  List<Tag> tags;
  String? isbn;
  String? userReview;
  int? durationMinutes;
  int shelfId;
  String? coverPath;
  /// How the cover is framed — see CoverShape.portrait/Square.
  int coverShape;
  String? openLibraryKey;
  /// Who reads the audiobook. Null for every other format, and kept rather
  /// than cleared if the format changes, so a mistapped format loses nothing.
  String? narrator;
  /// The series this book belongs to, and where it falls — a double so a
  /// novella can sit at 1.5. Both null for standalones.
  int? seriesId;
  double? seriesPosition;
  /// What the reader paid for this copy, in their own currency. Optional,
  /// and only entered by those who track their spending.
  double? pricePaid;
  /// When this copy was bought. Null means "when it was added", which is
  /// what spending counts from in that case.
  String? datePurchased;
  // Denormalized from JOIN — populated when loaded from DB, not written back
  final String? shelfName;
  /// Joined series name on reads. Also carries a name to resolve into
  /// [seriesId] before insert (imports, demo data); never written itself.
  final String? seriesName;

  Book({
    this.id,
    required this.title,
    required this.author,
    this.wordCount,
    this.pageCount,
    required this.rating,
    required this.isFavorite,
    required this.bookTypeId,
    required this.dateAdded,
    this.dateStarted,
    this.dateFinished,
    this.tags = const [],
    this.isbn,
    this.userReview,
    this.durationMinutes,
    this.shelfId = Shelf.wantToRead,
    this.coverPath,
    this.coverShape = CoverShape.portrait,
    this.openLibraryKey,
    this.narrator,
    this.seriesId,
    this.seriesPosition,
    this.pricePaid,
    this.datePurchased,
    this.shelfName,
    this.seriesName,
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
      'cover_shape': coverShape,
      'open_library_key': openLibraryKey,
      'narrator': narrator,
      'series_id': seriesId,
      'series_position': seriesPosition,
      'price_paid': pricePaid,
      'date_purchased': datePurchased,
      // tags stored separately in book_tags
    };
  }

  factory Book.fromMap(Map<String, dynamic> map) {
    return Book(
      id: map['id'],
      title: map['title'] ?? '',
      author: map['author'] ?? '',
      wordCount: map['word_count'] as int?,
      pageCount: map['page_count'] as int?,
      rating: map['rating'] != null ? (map['rating'] as num).toDouble() : null,
      isFavorite: (map['is_favorite'] as int?) == 1,
      bookTypeId: (map['book_type_id'] as int?) ?? 1,
      dateAdded: map['date_added'] ?? DateTime.now().toIso8601String(),
      dateStarted: map['date_started'],
      dateFinished: map['date_finished'],
      isbn: map['isbn'],
      userReview: map['user_review'],
      durationMinutes: map['duration_minutes'] as int?,
      shelfId: (map['shelf_id'] as int?) ?? Shelf.wantToRead,
      coverPath: map['cover_path'] as String?,
      coverShape:
          (map['cover_shape'] as int?) ?? CoverShape.portrait,
      openLibraryKey: map['open_library_key'] as String?,
      narrator: map['narrator'] as String?,
      seriesId: map['series_id'] as int?,
      seriesPosition: (map['series_position'] as num?)?.toDouble(),
      pricePaid: (map['price_paid'] as num?)?.toDouble(),
      datePurchased: map['date_purchased'] as String?,
      shelfName: map['shelf_name'] as String?,
      seriesName: map['series_name'] as String?,
    );
  }

  bool get isFinished => dateFinished != null;

  @override
  String toString() => 'Book(id: $id, title: $title, shelfId: $shelfId, tags: ${tags.length})';
}
