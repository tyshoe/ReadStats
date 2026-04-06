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

  Future<List<Book>> getBooks({int yearFilter = 0, int? shelfId}) async {
    final booksMap = await _databaseHelper.getBooks(
      yearFilter: yearFilter,
      shelfId: shelfId,
    );
    return booksMap.map((map) => Book.fromMap(map)).toList();
  }

  Future<int> updateBook(Book book) async {
    return await _databaseHelper.updateBook(book.toMap());
  }

  Future<int> deleteBook(int id) async {
    return await _databaseHelper.deleteBook(id);
  }

  Future<void> deleteBooksBatch(List<int> ids) async {
    await _databaseHelper.deleteBooksBatch(ids);
  }

  Future<void> updateCoverPath(int bookId, String? path) async {
    await _databaseHelper.updateCoverPath(bookId, path);
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
        int? finishedShelfId,
      }) async {
    final updates = <String, dynamic>{};

    if (isFirstSession) {
      updates['date_started'] = sessionDate.toIso8601String();
    }

    if (isFinalSession) {
      updates['date_finished'] = sessionDate.toIso8601String();
      updates['is_completed'] = 1;
      // Move to Finished shelf if caller provides its id, otherwise look it up
      if (finishedShelfId != null) {
        updates['shelf_id'] = finishedShelfId;
      }
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

  Future<List<String>> getAuthorSuggestions(String query) async {
    return await _databaseHelper.getAuthorSuggestions(query);
  }

  Future<void> toggleFavoriteStatus(int bookId, bool isFavorite) async {
    await _databaseHelper.updateBookFavoriteStatus(bookId, isFavorite ? 1 : 0);
  }

  Future<void> updateBookShelf(int bookId, int shelfId) async {
    await _databaseHelper.updateBookShelf(bookId, shelfId);
  }

  Future<List<Map<String, dynamic>>> getBookCountsPerType() async {
    return await _databaseHelper.getBookCountsPerType();
  }

  Future<List<Map<String, dynamic>>> getBookCountsPerShelf() async {
    return await _databaseHelper.getBookCountsPerShelf();
  }

  // --- Shelf passthrough ---

  Future<List<Map<String, dynamic>>> getShelves() async {
    return await _databaseHelper.getShelves();
  }

  Future<int> insertShelf(Map<String, dynamic> shelf) async {
    return await _databaseHelper.insertShelf(shelf);
  }

  Future<int> updateShelf(Map<String, dynamic> shelf) async {
    return await _databaseHelper.updateShelf(shelf);
  }

  Future<void> deleteShelf(int shelfId) async {
    await _databaseHelper.deleteShelf(shelfId);
  }

  Future<void> updateShelfSortOrders(List<Map<String, dynamic>> shelves) async {
    await _databaseHelper.updateShelfSortOrders(shelves);
  }
}