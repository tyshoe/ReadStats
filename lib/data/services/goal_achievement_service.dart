import 'dart:convert';

import 'package:read_stats/data/models/goal.dart';
import 'package:read_stats/data/repositories/goal_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A reading goal the reader has just met for its current period.
class GoalAchievement {
  final Goal goal;
  final PeriodProgress progress;

  /// Periods met in a row, ending with this one.
  final int streak;

  const GoalAchievement(this.goal, this.progress, this.streak);
}

/// Decides which goals have *just* been met, for the celebration screen.
///
/// The reader's goals (weekly sessions, yearly books...) — not the badge
/// ladders, which [MilestoneService] handles. Only the current period is ever
/// celebrated: an edit that meets a past week's goal shows up in the Profile
/// activity feed instead, which replays the whole history.
///
/// Remembers, per goal, the last period it was met (or seen met) in, so each
/// goal is celebrated at most once per period. That covers deleting and
/// re-adding the session that met it, and raising the target after it was
/// met. A goal created already met for its period isn't celebrated either —
/// [adopt] records it as met when it's created.
class GoalAchievementService {
  static const _snapshotKey = 'goalMetPeriods';
  static const _seededKey = 'goalMetPeriodsSeeded';

  /// Stored for a goal seen but not yet met this period.
  static const _notMet = '';

  static bool _resyncPending = false;
  static bool _bulkInProgress = false;

  /// See [MilestoneService.beginBulkChange], which calls these.
  static void beginBulkChange() => _bulkInProgress = true;

  static void endBulkChange() {
    _bulkInProgress = false;
    _resyncPending = true;
  }

  /// Records a new [goal] as it stands now, so it's celebrated when it's next
  /// met rather than when it's first seen.
  static Future<void> adopt(Goal goal, PeriodProgress progress) async {
    final prefs = await SharedPreferences.getInstance();
    final snapshot = _read(prefs) ?? {};
    snapshot['${goal.id}'] = _stateOf(progress);
    await _write(prefs, snapshot);
  }

  /// The goals met since the last check, at most one per goal.
  ///
  /// Returns empty on the first ever call, and after a bulk change: those
  /// adopt the current state instead, so a restore or the first run after this
  /// shipped doesn't celebrate goals the reader met long ago.
  static Future<List<GoalAchievement>> check(GoalRepository repo) async {
    if (_bulkInProgress) return const [];
    final prefs = await SharedPreferences.getInstance();
    final goals = await repo.getGoals();
    final progress = {
      for (final g in goals) g.id!: await repo.getCurrentProgress(g),
    };
    final current = {
      for (final g in goals) '${g.id}': _stateOf(progress[g.id]!),
    };

    final snapshot = _read(prefs);
    if (!(prefs.getBool(_seededKey) ?? false) ||
        _resyncPending ||
        snapshot == null) {
      _resyncPending = false;
      await _write(prefs, current);
      await prefs.setBool(_seededKey, true);
      return const [];
    }

    final achievements = <GoalAchievement>[];
    final merged = <String, String>{};
    for (final goal in goals) {
      final key = '${goal.id}';
      final p = progress[goal.id]!;
      final was = snapshot[key];
      // A goal this service has never seen — adopted, not celebrated, since
      // there's no telling when it was met.
      if (was == null) {
        merged[key] = current[key]!;
        continue;
      }
      if (p.met && was != _periodKey(p)) {
        achievements.add(
          GoalAchievement(goal, p, await _streak(repo, goal)),
        );
        merged[key] = _periodKey(p);
      } else {
        merged[key] = was;
      }
    }

    // Built from the current goals, so this also drops deleted ones. Runs on
    // every reload, so skip the write when nothing moved.
    if (jsonEncode(merged) != jsonEncode(snapshot)) {
      await _write(prefs, merged);
    }
    return achievements;
  }

  /// Periods met in a row up to and including the current one.
  static Future<int> _streak(GoalRepository repo, Goal goal) async {
    final history = await repo.getHistory(goal);
    var streak = 0;
    for (final p in history.reversed) {
      if (!p.met) break;
      streak++;
    }
    return streak == 0 ? 1 : streak;
  }

  static String _stateOf(PeriodProgress p) => p.met ? _periodKey(p) : _notMet;

  static String _periodKey(PeriodProgress p) =>
      p.periodStart.toIso8601String().substring(0, 10);

  static Map<String, String>? _read(SharedPreferences prefs) {
    final raw = prefs.getString(_snapshotKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v as String));
    } catch (_) {
      return null;
    }
  }

  static Future<void> _write(SharedPreferences prefs, Map<String, String> map) =>
      prefs.setString(_snapshotKey, jsonEncode(map));
}
