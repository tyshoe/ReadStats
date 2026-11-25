import 'package:flutter/foundation.dart';
import 'package:read_stats/domain/monthly_recap.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers which monthly recap the reader has already opened.
///
/// One value — the newest month whose recap has been seen, as `yyyyMM` — so the
/// Statistics tab can mark a finished month as new without the reader having to
/// rely on catching the notification. Kept out of `SettingsViewModel` because
/// it is bookkeeping rather than a preference: nothing in Settings sets it, and
/// it should not travel with a settings backup.
///
/// Also holds the book each year's Wrapped was told to name book of the year.
/// That one is the reader's own choice rather than bookkeeping, so it does
/// travel with a backup — by book id, which a restore keeps.
class RecapStore {
  static const _key = 'lastSeenRecapMonth';

  RecapStore._();

  static final RecapStore instance = RecapStore._();

  /// 0 until something has been seen, which reads as "every month is new" —
  /// correct for a fresh install, where the first finished month should be
  /// announced.
  final ValueNotifier<int> lastSeenMonth = ValueNotifier(0);

  static const _wrappedKey = 'lastSeenWrappedYear';

  /// The newest year whose Wrapped has been opened. 0 until one has.
  final ValueNotifier<int> lastSeenWrappedYear = ValueNotifier(0);

  static const _picksKey = 'wrappedBookOfYearPicks';

  /// Book of the year as the reader chose it, by year. Stored as `year:id`
  /// strings.
  Map<int, int> _bookOfYearPicks = const {};

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    lastSeenMonth.value = prefs.getInt(_key) ?? 0;
    lastSeenWrappedYear.value = prefs.getInt(_wrappedKey) ?? 0;
    _bookOfYearPicks = {
      for (final entry in prefs.getStringList(_picksKey) ?? const <String>[])
        if (_parsePick(entry) case final pick?) pick.$1: pick.$2,
    };
  }

  static (int, int)? _parsePick(String entry) {
    final parts = entry.split(':');
    if (parts.length != 2) return null;
    final y = int.tryParse(parts[0]);
    final i = int.tryParse(parts[1]);
    return y == null || i == null ? null : (y, i);
  }

  /// The book the reader named [year]'s book of the year, if they did.
  int? bookOfYearPick(int year) => _bookOfYearPicks[year];

  /// Every year's chosen book, for a backup.
  Map<int, int> get bookOfYearPicks => Map.unmodifiable(_bookOfYearPicks);

  /// Names [bookId] [year]'s book of the year.
  Future<void> setBookOfYearPick(int year, int bookId) =>
      replaceBookOfYearPicks({..._bookOfYearPicks, year: bookId});

  /// Replaces every year's choice at once — a restore's, or none when the
  /// books they pointed at are gone.
  Future<void> replaceBookOfYearPicks(Map<int, int> picks) async {
    final prefs = await SharedPreferences.getInstance();
    if (picks.isEmpty) {
      await prefs.remove(_picksKey);
    } else {
      await prefs.setStringList(
          _picksKey, [for (final e in picks.entries) '${e.key}:${e.value}']);
    }
    _bookOfYearPicks = Map.of(picks);
  }

  /// Records that [year]'s Wrapped has been opened. Forward-only, for the same
  /// reason as [markSeen].
  Future<void> markWrappedSeen(int year) async {
    if (year <= lastSeenWrappedYear.value) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_wrappedKey, year);
    lastSeenWrappedYear.value = year;
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
