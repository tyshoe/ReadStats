import '../models/session.dart';
import '../database/database_helper.dart';

class SessionRepository {
  final DatabaseHelper _databaseHelper;

  SessionRepository(this._databaseHelper);

  Future<int> addSession(Session session) async {
    return await _databaseHelper.insertSession(session.toMap());
  }

  Future<void> addSessionsBatch(List<Session> sessions) async {
    await _databaseHelper.addSessionsBatch(sessions);
  }

  Future<List<Session>> getSessions({int yearFilter = 0}) async {
    final sessionsMap = await _databaseHelper.getSessionsWithBooks(yearFilter: yearFilter);
    return sessionsMap.map((map) => Session.fromMap(map)).toList();
  }

  /// Sessions as raw rows, each with its book's title.
  Future<List<Map<String, dynamic>>> getSessionRows({int yearFilter = 0}) =>
      _databaseHelper.getSessionsWithBooks(yearFilter: yearFilter);

  /// One book's sessions as raw rows.
  Future<List<Map<String, dynamic>>> getSessionRowsByBookId(int bookId) =>
      _databaseHelper.getSessionsByBookId(bookId);

  /// The page the reader had reached in a book before [before] — where the
  /// next session starts. See [SessionQueries.getLastPage].
  Future<({int page, bool exact})?> getLastPage(int bookId, DateTime before) =>
      _databaseHelper.getLastPage(bookId, before.toIso8601String());

  /// Pages logged for a book before and after [date], and whether any
  /// session follows it. See [SessionQueries.getPagesAround].
  Future<({int pagesBefore, int pagesAfter, bool hasLater})> getPagesAround(
          int bookId, DateTime date,
          {int? excludeId}) =>
      _databaseHelper.getPagesAround(bookId, date.toIso8601String(),
          excludeId: excludeId);

  Future<List<int>> getSessionYears() async {
    return await _databaseHelper.getSessionYears();
  }

  Future<int> updateSession(Session session) async {
    return await _databaseHelper.updateSession(session.toMap());
  }

  Future<int> deleteSession(int id) async {
    return await _databaseHelper.deleteSession(id);
  }

  Future<List<Session>> getSessionsByBookId(int bookId) async {
    final sessionsMap = await _databaseHelper.getSessionsByBookId(bookId);
    return sessionsMap.map((map) => Session.fromMap(map)).toList();
  }

  Future<Map<String, dynamic>> getCompleteBookStats(int bookId) async {
    return await _databaseHelper.getCompleteBookStats(bookId);
  }
}
