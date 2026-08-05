import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '/ui/pages/profile/badges.dart';
import '/ui/pages/profile/reading_stats.dart';

/// A badge tier the reader has just crossed for the first time.
class MilestoneUnlock {
  final ReadingGoal goal;
  final GoalTier tier;

  const MilestoneUnlock(this.goal, this.tier);
}

/// Decides which milestones are *new*.
///
/// Badges carry no earned state of their own — [ReadingGoal.achievedIndex]
/// derives them from [ReadingStats] every time. "New" therefore only exists
/// relative to a stored snapshot of the highest tier index reached per goal.
///
/// The snapshot only ever ratchets upward. Deleting a book lowers the metric
/// behind a badge, and without the ratchet re-adding it would celebrate the
/// same milestone a second time.
class MilestoneService {
  static const _snapshotKey = 'milestoneSnapshot';
  static const _seededKey = 'milestoneSnapshotSeeded';

  static bool _resyncPending = false;
  static bool _bulkInProgress = false;

  /// Bracket a bulk data change — backup restore, CSV import, full wipe — where
  /// the jump isn't something the reader just did at the desk.
  ///
  /// This has to be a span, not a one-shot flag. A restore wipes before it
  /// inserts, and each write broadcasts, so a check lands on the empty library
  /// in between. A one-shot flag would be spent adopting that empty state, and
  /// the next check would diff a full library against zero and celebrate every
  /// medal at once. Checks are suppressed until [endBulkChange], which then
  /// adopts the finished state.
  static void beginBulkChange() => _bulkInProgress = true;

  static void endBulkChange() {
    _bulkInProgress = false;
    _resyncPending = true;
  }

  /// Diff [stats] against the snapshot and return the newly earned tier of each
  /// goal that advanced — at most one per goal, the highest reached. Ordered
  /// lowest tier first, so a night that moves several goals builds toward its
  /// best medal.
  ///
  /// Returns empty on the first ever call: that run seeds the snapshot, so
  /// readers who already earned medals before this shipped aren't buried in
  /// sixty of them at once.
  static Future<List<MilestoneUnlock>> check(ReadingStats stats) async {
    if (_bulkInProgress) return const [];
    final prefs = await SharedPreferences.getInstance();
    final current = {for (final g in kGoals) g.id: g.achievedIndex(stats)};

    if (!(prefs.getBool(_seededKey) ?? false) || _resyncPending) {
      _resyncPending = false;
      await _write(prefs, current);
      await prefs.setBool(_seededKey, true);
      return const [];
    }

    final snapshot = _read(prefs);
    if (snapshot == null) {
      // Seeded, but the snapshot is gone or unreadable. Diffing against nothing
      // would replay every tier the reader already holds, so adopt instead.
      await _write(prefs, current);
      return const [];
    }

    final unlocks = <MilestoneUnlock>[];
    final merged = <String, int>{};
    for (final goal in kGoals) {
      final was = snapshot[goal.id] ?? -1;
      final now = current[goal.id]!;
      // Only the tier landed on, never the ones passed through. A single long
      // session can clear Bronze and Silver at once, and there is one medal per
      // goal showing the highest tier — celebrating Bronze first would present
      // a medal that is already out of date by the time it's dismissed.
      if (now > was) unlocks.add(MilestoneUnlock(goal, goal.tiers[now]));
      merged[goal.id] = now > was ? now : was;
    }

    if (unlocks.isEmpty) return const [];
    await _write(prefs, merged);
    unlocks.sort((a, b) => a.tier.tier.index.compareTo(b.tier.tier.index));
    return unlocks;
  }

  /// The stored snapshot, or null if there isn't a readable one — which the
  /// caller treats as "adopt current state", not "nothing earned yet".
  static Map<String, int>? _read(SharedPreferences prefs) {
    final raw = prefs.getString(_snapshotKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      return null;
    }
  }

  static Future<void> _write(SharedPreferences prefs, Map<String, int> map) =>
      prefs.setString(_snapshotKey, jsonEncode(map));
}
