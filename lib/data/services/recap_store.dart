import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/monthly_recap.dart';

/// Remembers which monthly recap the reader has already opened.
///
/// One value — the newest month whose recap has been seen, as `yyyyMM` — so the
/// Statistics tab can mark a finished month as new without the reader having to
/// rely on catching the notification. Kept out of `SettingsViewModel` because
/// it is bookkeeping rather than a preference: nothing in Settings sets it, and
/// it should not travel with a settings backup.
class RecapStore {
  static const _key = 'lastSeenRecapMonth';

  RecapStore._();

  static final RecapStore instance = RecapStore._();

  /// 0 until something has been seen, which reads as "every month is new" —
  /// correct for a fresh install, where the first finished month should be
  /// announced.
  final ValueNotifier<int> lastSeenMonth = ValueNotifier(0);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    lastSeenMonth.value = prefs.getInt(_key) ?? 0;
  }

  /// Records that [year]/[month]'s recap has been opened. Only ever moves
  /// forward — opening an old month back in the history must not make the
  /// newest one look unseen again.
  ///
  /// Written before the notifier is updated, so listeners are told once the
  /// value is durable — and, just as importantly, from a later microtask. The
  /// recap page marks the month seen as it builds, and notifying synchronously
  /// from there would rebuild the Statistics page in the middle of a build.
  Future<void> markSeen(int year, int month) async {
    final key = MonthlyRecap.monthKey(year, month);
    if (key <= lastSeenMonth.value) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, key);
    lastSeenMonth.value = key;
  }
}
