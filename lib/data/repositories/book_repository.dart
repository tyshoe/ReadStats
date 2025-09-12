import '/data/models/book.dart';
import '/data/database/database_helper.dart';

class BookRepository {
  final DatabaseHelper _databaseHelper;

  BookRepository(this._databaseHelper);

  Future<int> addBook(Book book) async {
    return await _databaseHelper.insertBook(book.toMap());
  }

  Future<void> addBooksBatch(List<Book> books) async {
    await _databaseHelper.addBooksBatch(books);
  }

  // Future<List<Book>> getBooks() async {
  //   final booksData = await _databaseHelper.getBooks();
  //   return booksData.map((book) => Book.fromMap(book)).toList();
  // }

  Future<List<Book>> getBooks({int yearFilter = 0}) async {
    final booksMap = await _databaseHelper.getBooks(yearFilter: yearFilter);
    return booksMap.map((map) => Book.fromMap(map)).toList();
  }

  Future<int> updateBook(Book book) async {
    return await _databaseHelper.updateBook(book.toMap());
  }

  Future<int> deleteBook(int id) async {
    return await _databaseHelper.deleteBook(id);
  }

  Future<int> deleteAllBooks() async {
    return await _databaseHelper.deleteAllBooks();
  }

  Future<Map<String, dynamic>?> getBookById(int bookId) async {
    return await _databaseHelper.getBookById(bookId);
  }

  Future<Map<String, dynamic>> getBookStats(int bookId) async {
    return await _databaseHelper.getBookStats(bookId);
  }

  Future<Map<String, dynamic>> getAllBookStats(int yearFilter) async {
    return await _databaseHelper.getAllBookStats(yearFilter);
  }

  Future<Map<double, int>> getRatingDistribution({int selectedYear = 0}) {
    return _databaseHelper.getRatingDistribution(selectedYear: selectedYear);
  }

  Future<List<int>> getBookYears() async {
    return await _databaseHelper.getBookYears();
  }

  Future<void> updateBookRating(int bookId, double rating) async {
    await _databaseHelper.updateBookRating(bookId, rating);
  }

  Future<void> updateBookDates(
    int bookId, {
    required bool isFirstSession,
    required bool isFinalSession,
    required DateTime sessionDate,
  }) async {
    final updates = <String, dynamic>{};

    if (isFirstSession) {
      updates['date_started'] = sessionDate.toIso8601String();
    }

    if (isFinalSession) {
      updates['date_finished'] = sessionDate.toIso8601String();
      updates['is_completed'] = 1;
    }

    if (updates.isNotEmpty) {
      await _databaseHelper.updateBookPartial(bookId, updates);
    }
  }

  Future<bool> doesBookExist(String title, String author, {int? excludeId}) async {
    final books = await _databaseHelper.getBooksByTitleAndAuthor(title, author);
    if (excludeId != null) {
      return books.any((book) => book['id'] != excludeId);
    }
    return books.isNotEmpty;
  }

  // Add to BookRepository class
  Future<List<String>> getAuthorSuggestions(String query) async {
    return await _databaseHelper.getAuthorSuggestions(query);
  }

  // In your BookRepository class
  Future<void> toggleFavoriteStatus(int bookId, bool isFavorite) async {
    await _databaseHelper.updateBookFavoriteStatus(bookId, isFavorite ? 1 : 0);
  }
}
