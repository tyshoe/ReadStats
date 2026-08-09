import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/notification_pref.dart';

/// Persists one [NotificationPref] per [NotificationType].
///
/// Kept out of `SettingsViewModel`, which is strictly one scalar per key with a
/// matching getter/setter pair — this is a nested map and would not fit that
/// shape. Stored as a single JSON blob under one key so adding a type later
/// doesn't leave orphaned keys behind.
///
/// Deliberately excluded from backup export: reminders are a property of the
/// device that shows them, not of the reading history being carried across.
class NotificationPrefsStore {
  static const _key = 'notificationPrefs';

  NotificationPrefsStore._();

  static final NotificationPrefsStore instance = NotificationPrefsStore._();

  /// Every type is always present, so listeners never have to handle a missing
  /// entry. Seeded with defaults until [load] completes.
  final ValueNotifier<Map<NotificationType, NotificationPref>> prefs =
      ValueNotifier(_defaults());

  static Map<NotificationType, NotificationPref> _defaults() => {
        for (final type in NotificationType.values)
          type: NotificationPref.defaultsFor(type),
      };

  NotificationPref of(NotificationType type) => prefs.value[type]!;

  /// True when at least one reminder is switched on — used to decide whether
  /// the permission state is worth surfacing to the reader.
  bool get anyEnabled =>
      prefs.value.entries.any((e) => e.value.isActiveFor(e.key));

  Future<void> load() async {
    final sharedPrefs = await SharedPreferences.getInstance();
    final raw = sharedPrefs.getString(_key);
    if (raw == null || raw.isEmpty) return;

    // A corrupt or hand-edited blob falls back to defaults rather than throwing
    // during startup — losing reminder settings is recoverable, failing to
    // launch is not.
    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    final loaded = _defaults();
    decoded.forEach((id, value) {
      final type = NotificationType.fromId(id);
      if (type == null || value is! Map<String, dynamic>) return;
      loaded[type] = NotificationPref.fromJson(value, type);
    });
    prefs.value = loaded;
  }

  Future<void> update(NotificationType type, NotificationPref pref) async {
    // Replace the map rather than mutating it — ValueNotifier compares by
    // identity, so an in-place edit would not notify.
    prefs.value = {...prefs.value, type: pref};
    await _persist();
  }

  Future<void> _persist() async {
    final sharedPrefs = await SharedPreferences.getInstance();
    await sharedPrefs.setString(
      _key,
      jsonEncode({
        for (final entry in prefs.value.entries)
          entry.key.id: entry.value.toJson(),
      }),
    );
  }
}
