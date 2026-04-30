import '../database/database_helper.dart';
import '../models/goal.dart';

class GoalRepository {
  final DatabaseHelper _db;

  GoalRepository(this._db);

  Future<List<Goal>> getGoals() async {
    final rows = await _db.getGoals();
    return rows.map(Goal.fromMap).toList();
  }

  Future<Goal> createGoal(GoalMetric metric, GoalPeriod period, int target) async {
    final now = DateTime.now();
    final createdAt = now.toIso8601String();
    final effectiveFrom = _periodStart(period, now);

    final map = {
      'metric': metric.dbValue,
      'period': period.dbValue,
      'target': target,
      'created_at': createdAt,
    };
    final id = await _db.insertGoal(map);

    await _db.insertGoalTargetChange({
      'goal_id': id,
      'target': target,
      'effective_from': effectiveFrom,
    });

    return Goal(
      id: id,
      metric: metric,
      period: period,
      target: target,
      createdAt: createdAt,
    );
  }

  Future<void> updateTarget(Goal goal, int newTarget) async {
    final effectiveFrom = _periodStart(goal.period, DateTime.now());
    await _db.updateGoalTarget(goal.id!, newTarget);
    await _db.insertGoalTargetChange({
      'goal_id': goal.id,
      'target': newTarget,
      'effective_from': effectiveFrom,
    });
  }

  Future<void> deleteGoal(int id) async {
    await _db.deleteGoal(id);
  }

  Future<PeriodProgress> getCurrentProgress(Goal goal) async {
    final now = DateTime.now();
    final start = _periodStart(goal.period, now);
    final end = _periodEnd(goal.period, now);
    final target = await _db.getTargetForPeriod(goal.id!, start) ?? goal.target;
    final actual = await _db.getProgressForPeriod(
      metric: goal.metric.dbValue,
      periodStart: start,
      periodEnd: end,
    );
    return PeriodProgress(
      periodStart: DateTime.parse(start),
      periodEnd: DateTime.parse(end),
      target: target,
      actual: actual,
    );
  }

  Future<List<PeriodProgress>> getHistory(Goal goal) async {
    final createdAt = DateTime.parse(goal.createdAt);
    final now = DateTime.now();
    // Always go back the full display window so pre-goal actuals are visible.
    final windowStart = _historyWindowStart(goal.period, now);
    final periods = _generatePeriods(goal.period, windowStart, now);
    // The period that contains createdAt — goal exists from here onward.
    final goalPeriodStart = DateTime.parse(_periodStart(goal.period, createdAt));
    final history = <PeriodProgress>[];

    for (final range in periods) {
      final start = _dateToIso(range.$1);
      final end = _dateToIso(range.$2);
      final hasGoal = !range.$1.isBefore(goalPeriodStart);
      final target = hasGoal
          ? (await _db.getTargetForPeriod(goal.id!, start) ?? goal.target)
          : 0;
      final actual = await _db.getProgressForPeriod(
        metric: goal.metric.dbValue,
        periodStart: start,
        periodEnd: end,
      );
      history.add(PeriodProgress(
        periodStart: range.$1,
        periodEnd: range.$2,
        target: target,
        actual: actual,
        hasGoal: hasGoal,
      ));
    }

    return history;
  }

  DateTime _historyWindowStart(GoalPeriod period, DateTime now) {
    switch (period) {
      case GoalPeriod.weekly:
        // Current week start (Sunday) minus 11 weeks = 12 weeks total.
        final weekStart = now.subtract(Duration(days: now.weekday % 7));
        final d = weekStart.subtract(const Duration(days: 77));
        return DateTime(d.year, d.month, d.day);
      case GoalPeriod.monthly:
        // 5 months before current = 6 months total.
        int year = now.year;
        int month = now.month - 5;
        while (month <= 0) {
          month += 12;
          year--;
        }
        return DateTime(year, month, 1);
      case GoalPeriod.yearly:
        return DateTime(now.year - 4, 1, 1);
    }
  }

  // --- period helpers ---

  String _periodStart(GoalPeriod period, DateTime date) {
    final d = switch (period) {
      GoalPeriod.weekly => date.subtract(Duration(days: date.weekday % 7)),
      GoalPeriod.monthly => DateTime(date.year, date.month, 1),
      GoalPeriod.yearly => DateTime(date.year, 1, 1),
    };
    return _dateToIso(DateTime(d.year, d.month, d.day));
  }

  String _periodEnd(GoalPeriod period, DateTime date) {
    final d = switch (period) {
      GoalPeriod.weekly => date.add(Duration(days: 6 - date.weekday % 7)),
      GoalPeriod.monthly => DateTime(date.year, date.month + 1, 0),
      GoalPeriod.yearly => DateTime(date.year, 12, 31),
    };
    return _dateToIso(DateTime(d.year, d.month, d.day));
  }

  String _dateToIso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  List<(DateTime, DateTime)> _generatePeriods(
      GoalPeriod period, DateTime createdAt, DateTime now) {
    final periods = <(DateTime, DateTime)>[];

    DateTime cursor = switch (period) {
      GoalPeriod.weekly =>
        createdAt.subtract(Duration(days: createdAt.weekday % 7)),
      GoalPeriod.monthly => DateTime(createdAt.year, createdAt.month, 1),
      GoalPeriod.yearly => DateTime(createdAt.year, 1, 1),
    };
    cursor = DateTime(cursor.year, cursor.month, cursor.day);

    final currentStart = DateTime.parse(_periodStart(period, now));

    while (!cursor.isAfter(currentStart)) {
      final end = switch (period) {
        GoalPeriod.weekly => DateTime(cursor.year, cursor.month, cursor.day + 6),
        GoalPeriod.monthly => DateTime(cursor.year, cursor.month + 1, 0),
        GoalPeriod.yearly => DateTime(cursor.year, 12, 31),
      };
      periods.add((cursor, end));
      cursor = switch (period) {
        GoalPeriod.weekly => DateTime(cursor.year, cursor.month, cursor.day + 7),
        GoalPeriod.monthly => DateTime(cursor.year, cursor.month + 1, 1),
        GoalPeriod.yearly => DateTime(cursor.year + 1, 1, 1),
      };
    }

    return periods.reversed.toList(); // most recent first
  }
}
