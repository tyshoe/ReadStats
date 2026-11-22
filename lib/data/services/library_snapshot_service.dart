import 'dart:async';
import 'dart:convert';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:read_stats/data/services/analytics_service.dart';
import 'package:read_stats/firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps this install's entry in the community totals on the Settings support
/// card: one Firestore document, `installs/{anonymous uid}`, holding only
/// `books` (library size), `minutes` (time across all logged sessions, the
/// same total the Stats page shows),
/// `updated` (set by the server) and `expires` (90 days on, after which the
/// daily GitHub job deletes it).
///
/// The totals count current libraries, not events, so they can't drift: the
/// daily GitHub job (`.github/scripts/community_stats.py`) sums documents
/// updated in the last 90 days. Reinstalls and abandoned phones drop out on
/// their own once their document goes stale.
///
/// What it sends follows the "Share usage statistics" switch:
/// - on, with real books: the two numbers, when they change (after a short
///   pause, so a bulk edit is one write) and at least weekly so the entry
///   stays fresh;
/// - off, an empty library, or the demo library: the document is deleted —
///   switching sharing off removes this install from the totals.
/// Debug builds never send, like analytics. `firestore.rules` caps the
/// numbers and lets an install touch only its own document.
///
/// The uid comes from Firebase anonymous sign-in: a random id with no profile
/// behind it, signed in only once sharing is on. App Check tokens go with
/// every write so Firestore can be set to accept only the real app.
class LibrarySnapshotService {
  LibrarySnapshotService._();
  static final LibrarySnapshotService instance = LibrarySnapshotService._();

  /// What was last written: "books/minutes", or "0/0" for no document.
  static const _sentKey = 'snapshotSent';
  static const _sentAtKey = 'snapshotSentAt';

  static const _debounce = Duration(seconds: 30);
  static const _heartbeat = Duration(days: 7);

  int _books = 0;
  int _minutes = 0;
  bool _booksLoaded = false;
  bool _sessionsLoaded = false;
  Timer? _timer;
  bool _flushing = false;
  bool _appCheckActive = false;

  /// Starts following the sharing switch. Call once, after analytics init.
  void init() {
    AnalyticsService.instance.enabledNotifier.addListener(_schedule);
  }

  /// Called with the library each time the books load.
  void updateBooks(List<Map<String, dynamic>> books) {
    _books = books.length;
    _booksLoaded = true;
    _schedule();
  }

  /// Called with every session each time the sessions load.
  void updateSessions(List<Map<String, dynamic>> sessions) {
    var minutes = 0;
    for (final session in sessions) {
      final value = session['duration_minutes'];
      if (value is num) minutes += value.toInt();
    }
    _minutes = minutes;
    _sessionsLoaded = true;
    _schedule();
  }

  void _schedule() {
    if (!_booksLoaded || !_sessionsLoaded) return;
    _timer?.cancel();
    _timer = Timer(_debounce, _flush);
  }

  Future<void> _flush() async {
    final analytics = AnalyticsService.instance;
    if (kDebugMode || !analytics.firebaseReady || _flushing) return;
    _flushing = true;
    try {
      final share = analytics.enabledNotifier.value &&
          !analytics.demoLibrary &&
          _books > 0;
      final want = share
          ? (books: _books, minutes: _minutes)
          : (books: 0, minutes: 0);
      final wantKey = '${want.books}/${want.minutes}';

      final prefs = await SharedPreferences.getInstance();
      final sent = prefs.getString(_sentKey) ?? '0/0';
      final sentAt = DateTime.fromMillisecondsSinceEpoch(
          prefs.getInt(_sentAtKey) ?? 0);
      final fresh = DateTime.now().difference(sentAt) < _heartbeat;
      if (wantKey == sent && (want.books == 0 || fresh)) return;

      // Nothing to delete if nothing was ever written: don't sign in for it.
      if (want.books == 0 && sent == '0/0') return;

      final ok = await _commit(want.books == 0 ? null : want);
      if (!ok) return; // Retried on the next load or switch change.
      await prefs.setString(_sentKey, wantKey);
      await prefs.setInt(_sentAtKey, DateTime.now().millisecondsSinceEpoch);
      if (!kReleaseMode) debugPrint('Library snapshot sent: $wantKey');
    } catch (e) {
      if (!kReleaseMode) debugPrint('Library snapshot failed: $e');
    } finally {
      _flushing = false;
    }
  }

  /// Writes [counts] to this install's document, or deletes it when null.
  Future<bool> _commit(({int books, int minutes})? counts) async {
    // First, so the anonymous sign-in is attested too, not just the write.
    final appCheck = await _appCheckToken();
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser ?? (await auth.signInAnonymously()).user;
    if (user == null) return false;

    final project = DefaultFirebaseOptions.currentPlatform.projectId;
    final root = 'projects/$project/databases/(default)/documents';
    final name = '$root/installs/${user.uid}';
    final write = counts == null
        ? {'delete': name}
        : {
            'update': {
              'name': name,
              'fields': {
                'books': {'integerValue': '${counts.books}'},
                'minutes': {'integerValue': '${counts.minutes}'},
                // The daily GitHub job deletes the document after this, so an
                // install that stops sending doesn't linger.
                'expires': {
                  'timestampValue': DateTime.now()
                      .toUtc()
                      .add(const Duration(days: 90))
                      .toIso8601String(),
                },
              },
            },
            'updateTransforms': [
              {'fieldPath': 'updated', 'setToServerValue': 'REQUEST_TIME'},
            ],
          };

    final response = await http
        .post(
          Uri.parse('https://firestore.googleapis.com/v1/$root:commit'),
          headers: {
            'Authorization': 'Bearer ${await user.getIdToken()}',
            'Content-Type': 'application/json',
            'X-Firebase-AppCheck': ?appCheck,
          },
          body: jsonEncode({
            'writes': [write],
          }),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200 && !kReleaseMode) {
      debugPrint('Library snapshot rejected: ${response.body}');
    }
    return response.statusCode == 200;
  }

  /// Play Integrity / DeviceCheck proof that this is the real app. Started
  /// only here — once sharing is on — and without background refreshes.
  /// Null when it can't be had (an emulator, say); Firestore accepts that
  /// until App Check is enforced.
  Future<String?> _appCheckToken() async {
    try {
      if (!_appCheckActive) {
        await FirebaseAppCheck.instance.activate(
          providerAndroid: const AndroidPlayIntegrityProvider(),
          providerApple: const AppleDeviceCheckProvider(),
        );
        await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(false);
        _appCheckActive = true;
      }
      return await FirebaseAppCheck.instance.getToken();
    } catch (e) {
      if (!kReleaseMode) debugPrint('App Check unavailable: $e');
      return null;
    }
  }
}
