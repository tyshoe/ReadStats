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

  Future<List<Book>> getBooks() async {
    final booksData = await _databaseHelper.getBooks();
    return booksData.map((book) => Book.fromMap(book)).toList();
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

  Future<List<int>> getBookYears() async {
    return await _databaseHelper.getBookYears();
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
}

