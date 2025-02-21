import '../models/session.dart'; // Import your Session model
import '../database/database_helper.dart';

class SessionRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  // Add a session to the database
  Future<int> addSession(Session session) async {
    return await _databaseHelper.insertSession(session.toMap());
  }

  // Fetch all sessions with book details
  Future<List<Session>> getSessions() async {
    final sessionsMap = await _databaseHelper.getSessionsWithBooks();
    return sessionsMap.map((map) => Session.fromMap(map)).toList();
  }

  // Update an existing session
  Future<int> updateSession(Session session) async {
    return await _databaseHelper.updateSession(session.toMap());
  }

  // Delete a session from the database
  Future<int> deleteSession(int id) async {
    return await _databaseHelper.deleteSession(id);
  }

  // Fetch all sessions related to a specific book
  Future<List<Session>> getSessionsByBookId(int bookId) async {
    final sessionsMap = await _databaseHelper.getSessionsByBookId(bookId);
    return sessionsMap.map((map) => Session.fromMap(map)).toList();
  }

  // Get complete stats for a specific book
  Future<Map<String, dynamic>> getCompleteBookStats(int bookId) async {
    return await _databaseHelper.getCompleteBookStats(bookId);
  }
}
