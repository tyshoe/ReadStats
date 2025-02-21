import '../../models/book.dart';
import '../../database/database_helper.dart';

class BookRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  Future<int> addBook(Book book) async {
    return await _databaseHelper.insertBook(book.toMap());
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

  Future<Map<String, dynamic>?> getBookById(int bookId) async {
    return await _databaseHelper.getBookById(bookId);
  }

  Future<Map<String, dynamic>> getBookStats(int bookId) async {
    return await _databaseHelper.getBookStats(bookId);
  }
}
