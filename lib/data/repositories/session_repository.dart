import '../models/session.dart';
import '../database/database_helper.dart';

class SessionRepository {
  final DatabaseHelper _databaseHelper;

  SessionRepository(this._databaseHelper);

  Future<int> addSession(Session session) async {
    return await _databaseHelper.insertSession(session.toMap());
  }

  Future<List<Session>> getSessions() async {
    final sessionsMap = await _databaseHelper.getSessionsWithBooks();
    print('Session Repo, getSession: $sessionsMap');
    return sessionsMap.map((map) => Session.fromMap(map)).toList();
  }

  Future<List<Session>> getSessionsByYear(int year) async {
    final sessionsMap = await _databaseHelper.getSessionsWithBooksByYear(year);
    print('Session Repo, getSessionByYear: $sessionsMap');
    return sessionsMap.map((map) => Session.fromMap(map)).toList();
  }

  Future<List<int>> getValidYears() async {
    return await _databaseHelper.getValidYears();
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
