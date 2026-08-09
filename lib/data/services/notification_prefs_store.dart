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
  static const _lastSentKey = 'notificationLastSent';
  static const _permissionAskedKey = 'notificationPermissionAsked';

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

  /// When each type was last handed to the OS, keyed by type.
  ///
  /// This is bookkeeping rather than a setting, so it stays out of [prefs] and
  /// gets its own storage key. It records the moment a reminder was *scheduled
  /// for*, which is the closest thing available to a delivery time — the plugin
  /// never reports back that a notification actually fired. A time still in the
  /// future therefore means "armed", and one in the past means "delivered".
  final Map<NotificationType, DateTime> _lastSent = {};

  DateTime? lastSentAt(NotificationType type) => _lastSent[type];

  /// Records [at], or forgets the entry when [at] is null — which is what
  /// cancelling a pending occurrence calls for, since the recorded time then
  /// refers to a notification that will never arrive.
  Future<void> setSentAt(NotificationType type, DateTime? at) async {
    if (at == null) {
      if (_lastSent.remove(type) == null) return;
    } else {
      _lastSent[type] = at;
    }
    final sharedPrefs = await SharedPreferences.getInstance();
    await sharedPrefs.setString(
      _lastSentKey,
      jsonEncode({
        for (final entry in _lastSent.entries)
          entry.key.id: entry.value.toIso8601String(),
      }),
    );
  }

  /// Whether the OS permission prompt has been put in front of the reader.
  ///
  /// The prompt is one-shot on both platforms — Android stops showing it after
  /// a couple of dismissals and iOS after the first — so it is spent once and
  /// never asked for again. From then on the settings page's banner is the only
  /// route back, and it sends the reader to system settings instead.
  bool _permissionAsked = false;

  bool get permissionAsked => _permissionAsked;

  Future<void> markPermissionAsked() async {
    if (_permissionAsked) return;
    _permissionAsked = true;
    final sharedPrefs = await SharedPreferences.getInstance();
    await sharedPrefs.setBool(_permissionAskedKey, true);
  }

  Future<void> load() async {
    final sharedPrefs = await SharedPreferences.getInstance();
    _permissionAsked = sharedPrefs.getBool(_permissionAskedKey) ?? false;
    _loadLastSent(sharedPrefs.getString(_lastSentKey));

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

  /// Losing this map only costs one extra reminder, so anything unparseable is
  /// dropped without complaint.
  void _loadLastSent(String? raw) {
    if (raw == null || raw.isEmpty) return;
    try {
      (jsonDecode(raw) as Map<String, dynamic>).forEach((id, value) {
        final type = NotificationType.fromId(id);
        final at = DateTime.tryParse(value?.toString() ?? '');
        if (type != null && at != null) _lastSent[type] = at;
      });
    } catch (_) {
      // Keep whatever parsed before the failure.
    }
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
