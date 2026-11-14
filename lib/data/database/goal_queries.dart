part of 'database_helper.dart';

/// Goals, their target history and progress.
extension GoalQueries on DatabaseHelper {
  /// Delete all goals and their target-change history. goal_target_changes
  /// cascades from goals, but we clear it explicitly so the wipe doesn't rely
  /// on foreign_keys being enabled.
  Future<void> deleteAllGoals() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('goal_target_changes');
      await txn.delete('goals');
    });
  }

  Future<int> insertGoal(Map<String, dynamic> goal) async {
    final db = await database;
    return await db.insert('goals', goal);
  }

  Future<List<Map<String, dynamic>>> getGoals() async {
    final db = await database;
    return await db.query('goals', orderBy: 'id ASC');
  }

  Future<int> updateGoalTarget(int goalId, int newTarget) async {
    final db = await database;
    return await db.update(
      'goals',
      {'target': newTarget},
      where: 'id = ?',
      whereArgs: [goalId],
    );
  }

  Future<int> deleteGoal(int id) async {
    final db = await database;
    return await db.delete('goals', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insertGoalTargetChange(Map<String, dynamic> change) async {
    final db = await database;
    return await db.insert('goal_target_changes', change);
  }

  /// Every target change across all goals, for the backup.
  Future<List<Map<String, dynamic>>> getAllGoalTargetChanges() async {
    final db = await database;
    return await db.query('goal_target_changes',
        orderBy: 'goal_id ASC, effective_from ASC, id ASC');
  }

  /// Restores goals and their target history from a backup, returning how many
  /// goals were added.
  ///
  /// Goals get fresh ids and their changes are re-pointed at them. A goal the
  /// device already has for the same metric and period is left as it is,
  /// history and all — there can only be one per pair.
  Future<int> restoreGoals(
    List<Map<String, dynamic>> goals,
    List<Map<String, dynamic>> changes,
  ) async {
    final db = await database;
    return db.transaction((txn) async {
      final idMap = <int, int>{};
      for (final g in goals) {
        final existing = await txn.query(
          'goals',
          columns: ['id'],
          where: 'metric = ? AND period = ?',
          whereArgs: [g['metric'], g['period']],
          limit: 1,
        );
        if (existing.isNotEmpty) continue;
        idMap[g['id'] as int] = await txn.insert('goals', {
          'metric': g['metric'],
          'period': g['period'],
          'target': g['target'],
          'created_at': g['created_at'],
        });
      }
      for (final c in changes) {
        final goalId = idMap[c['goal_id']];
        if (goalId == null) continue;
        await txn.insert('goal_target_changes', {
          'goal_id': goalId,
          'target': c['target'],
          'effective_from': c['effective_from'],
        });
      }
      return idMap.length;
    });
  }

  /// Every target [goalId] has had, oldest first.
  Future<List<Map<String, dynamic>>> getGoalTargetChanges(int goalId) async {
    final db = await database;
    return await db.query(
      'goal_target_changes',
      where: 'goal_id = ?',
      whereArgs: [goalId],
      orderBy: 'effective_from ASC, id ASC',
    );
  }

  Future<int?> getTargetForPeriod(int goalId, String periodStart) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT target FROM goal_target_changes
      WHERE goal_id = ? AND effective_from <= ?
      ORDER BY effective_from DESC, id DESC
      LIMIT 1
    ''', [goalId, periodStart]);
    if (result.isEmpty) return null;
    return result.first['target'] as int?;
  }

  Future<int> getProgressForPeriod({
    required String metric,
    required String periodStart,
    required String periodEnd,
  }) async {
    final db = await database;

    if (metric == 'books_finished') {
      final result = await db.rawQuery('''
        SELECT COUNT(*) as count FROM books
        WHERE date_finished IS NOT NULL
          AND DATE(date_finished) >= ?
          AND DATE(date_finished) <= ?
      ''', [periodStart, periodEnd]);
      return (result.first['count'] as int?) ?? 0;
    } else if (metric == 'sessions') {
      final result = await db.rawQuery('''
        SELECT COUNT(*) as count FROM sessions
        WHERE DATE(date) >= ? AND DATE(date) <= ?
      ''', [periodStart, periodEnd]);
      return (result.first['count'] as int?) ?? 0;
    } else if (metric == 'pages_read') {
      final result = await db.rawQuery('''
        SELECT COALESCE(SUM(pages_read), 0) as total FROM sessions
        WHERE DATE(date) >= ? AND DATE(date) <= ?
      ''', [periodStart, periodEnd]);
      return (result.first['total'] as int?) ?? 0;
    } else {
      // time_reading
      final result = await db.rawQuery('''
        SELECT COALESCE(SUM(duration_minutes), 0) as total FROM sessions
        WHERE DATE(date) >= ? AND DATE(date) <= ?
      ''', [periodStart, periodEnd]);
      return (result.first['total'] as int?) ?? 0;
    }
  }
}
