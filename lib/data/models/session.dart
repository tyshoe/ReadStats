class Session {
  final int? id;
  final int bookId;
  final int pagesRead;
  final int hours;
  final int minutes;
  final String date;

  Session({
    this.id,
    required this.bookId,
    required this.pagesRead,
    required this.hours,
    required this.minutes,
    required this.date,
  });

  // Convert a Session object to a Map for database operations
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'book_id': bookId,
      'pages_read': pagesRead,
      'hours': hours,
      'minutes': minutes,
      'date': date,
    };
  }

  // Factory constructor to create a Session from a Map (e.g., from database)
  factory Session.fromMap(Map<String, dynamic> map) {
    return Session(
      id: map['id'],
      bookId: map['book_id'],
      pagesRead: map['pages_read'],
      hours: map['hours'],
      minutes: map['minutes'],
      date: map['date'],
    );
  }
}
