class Session {
  final int? id;
  final int bookId;
  final int? pagesRead;
  final int? durationMinutes;
  final String date;
  final String? notes;

  /// The pages the session started and stopped on, bookmark style, so
  /// [pagesRead] is the gap between them. Null on sessions logged as a bare
  /// count, and on everything from before page numbers were kept.
  final int? startPage;
  final int? endPage;

  Session({
    this.id,
    required this.bookId,
    required this.pagesRead,
    required this.durationMinutes,
    required this.date,
    this.notes,
    this.startPage,
    this.endPage,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'book_id': bookId,
      'pages_read': pagesRead,
      'duration_minutes': durationMinutes,
      'date': date,
      'notes': notes,
      'start_page': startPage,
      'end_page': endPage,
    };
  }

  factory Session.fromMap(Map<String, dynamic> map) {
    return Session(
      id: map['id'],
      bookId: map['book_id'],
      pagesRead: map['pages_read'],
      durationMinutes: map['duration_minutes'],
      date: map['date'],
      notes: map['notes'] as String?,
      startPage: map['start_page'] as int?,
      endPage: map['end_page'] as int?,
    );
  }
}
