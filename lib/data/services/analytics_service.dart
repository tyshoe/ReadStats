import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:read_stats/data/models/book_type.dart';
import 'package:read_stats/firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Anonymous usage counts (Firebase Analytics) and crash reports
/// (Crashlytics), behind the reader's "Share usage statistics" switch.
///
/// Every event goes through a named method here, so nothing the reader typed —
/// titles, authors, notes, tags — can ever be sent: only event names, formats
/// and small counts.
///
/// Silent no-op when:
/// - Firebase isn't configured yet (`lib/firebase_options.dart` is a stub),
/// - the reader turned sharing off,
/// - it's a debug build (so emulator testing doesn't count as real use; run
///   `flutter run --profile` to see events in Firebase DebugView).
///
/// Collection is also off in the Android manifest, so nothing leaves the
/// device before [init] has read the reader's choice.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  static const _prefKey = 'shareUsageStats';
  static const _demoKey = 'libraryIsDemo';

  /// The reader's choice. On unless they turned it off.
  final ValueNotifier<bool> enabledNotifier = ValueNotifier(true);

  bool _ready = false;

  /// Whether the library is the generated demo one, kept across launches so
  /// `demo_library` can be sent even if sharing was off when it was loaded.
  bool _demoLibrary = false;

  bool get _sending => _ready && enabledNotifier.value && !kDebugMode;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    enabledNotifier.value = prefs.getBool(_prefKey) ?? true;
    _demoLibrary = prefs.getBool(_demoKey) ?? false;
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Analytics disabled: $e');
      return;
    }
    _ready = true;

    if (!kDebugMode) {
      // Crashlytics skips these on its own while collection is off.
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    }
    await _applyCollection();
  }

  Future<void> setEnabled(bool enabled) async {
    enabledNotifier.value = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, enabled);
    await _applyCollection();
  }

  Future<void> _applyCollection() async {
    if (!_ready) return;
    final on = enabledNotifier.value && !kDebugMode;
    try {
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(on);
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(on);
      // With collection off, Crashlytics still keeps crash reports on the
      // device and would upload them once it's turned back on. Crashes from
      // while the reader had opted out are dropped instead.
      if (!on) await FirebaseCrashlytics.instance.deleteUnsentReports();
    } catch (e) {
      if (kDebugMode) debugPrint('Analytics toggle failed: $e');
    }
  }

  void _log(String name, [Map<String, Object>? params]) {
    if (!_sending) return;
    unawaited(
      FirebaseAnalytics.instance
          .logEvent(name: name, parameters: params)
          .catchError((_) {}),
    );
  }

  static String _format(int? bookTypeId) => switch (bookTypeId) {
        BookType.paperback => 'paperback',
        BookType.hardback => 'hardback',
        BookType.ebook => 'ebook',
        BookType.audiobook => 'audiobook',
        _ => 'unknown',
      };

  // ── Events ────────────────────────────────────────────────────────────────

  /// A main tab or full-screen page was opened.
  void screen(String name) {
    if (!_sending) return;
    unawaited(
      FirebaseAnalytics.instance
          .logScreenView(screenName: name)
          .catchError((_) {}),
    );
  }

  /// [method]: `form` (typed or picked from search) or `scan` (bulk scanner).
  void bookAdded({required String method, int? bookTypeId}) =>
      _log('book_added', {'method': method, 'format': _format(bookTypeId)});

  void bookFinished({int? bookTypeId}) =>
      _log('book_finished', {'format': _format(bookTypeId)});

  /// [method]: `timer` or `manual`.
  void sessionLogged({required String method, int? bookTypeId}) => _log(
        'session_logged',
        {'method': method, 'format': _format(bookTypeId)},
      );

  void timerStarted() => _log('timer_started');

  void goalCreated({required String metric, required String period}) {
    _log('goal_created', {'metric': metric, 'period': period});
    setHasGoal(true);
  }

  /// [source]: `backup`, `goodreads`, `bookmory` or `demo`. Also decides
  /// `demo_library`: a demo load makes the library the demo one, any other
  /// import brings in real books.
  void dataImported(String source) {
    _log('data_imported', {'source': source});
    unawaited(setDemoLibrary(source == 'demo'));
  }

  void backupExported() => _log('backup_exported');

  void wrappedOpened() => _log('wrapped_opened');

  void recapOpened() => _log('recap_opened');

  /// [content]: `book_card`, `recap`, `wrapped` or `library_list`.
  void shared(String content) => _log('content_shared', {'content': content});

  void onboardingFinished() => _log('onboarding_finished');

  // ── User properties ───────────────────────────────────────────────────────

  void _setProperty(String name, String value) {
    if (!_sending) return;
    unawaited(
      FirebaseAnalytics.instance
          .setUserProperty(name: name, value: value)
          .catchError((_) {}),
    );
  }

  /// Describes the library each time the books load:
  /// - `library_size` in steps of 25 ("1-24", "25-49", … "975-999",
  ///   "1000+"), so the dashboard can split users by it without an exact count;
  /// - `main_format`: `physical`, `ebook` or `audiobook` when more than half
  ///   the books are that format, else `mixed` (`none` when empty);
  /// - `demo_library`: `true` while it's the generated demo library.
  void setLibrary(List<Map<String, dynamic>> books) {
    if (!_sending) return;
    final count = books.length;
    final low = count ~/ 25 * 25;
    _setProperty('library_size', switch (count) {
      0 => '0',
      >= 1000 => '1000+',
      _ => '${low == 0 ? 1 : low}-${low + 24}',
    });

    var physical = 0, ebook = 0, audiobook = 0;
    for (final book in books) {
      switch (book['book_type_id']) {
        case BookType.paperback || BookType.hardback:
          physical++;
        case BookType.ebook:
          ebook++;
        case BookType.audiobook:
          audiobook++;
      }
    }
    _setProperty('main_format', switch (count) {
      0 => 'none',
      _ when physical * 2 > count => 'physical',
      _ when ebook * 2 > count => 'ebook',
      _ when audiobook * 2 > count => 'audiobook',
      _ => 'mixed',
    });

    _setProperty('demo_library', '$_demoLibrary');
  }

  /// Remembered whether or not sharing is on, so the property is right once
  /// it is.
  Future<void> setDemoLibrary(bool demo) async {
    _demoLibrary = demo;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_demoKey, demo);
    _setProperty('demo_library', '$demo');
  }

  void setHasGoal(bool hasGoal) => _setProperty('has_goal', '$hasGoal');

  /// Sessions logged, in widening ranges ("1-9", "10-24", … "500-999",
  /// "1000+"): the gap between a first week and a habit matters more than
  /// one between 600 and 700.
  void setSessionCount(int sessions) => _setProperty(
        'session_count',
        switch (sessions) {
          0 => '0',
          < 10 => '1-9',
          < 25 => '10-24',
          < 50 => '25-49',
          < 100 => '50-99',
          < 250 => '100-249',
          < 500 => '250-499',
          < 1000 => '500-999',
          _ => '1000+',
        },
      );
}
