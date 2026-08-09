import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/notification_pref.dart';
import 'notification_prefs_store.dart';

/// Schedules and cancels the app's local reminders.
///
/// Everything is local — there is no server, and nothing about the reader's
/// library ever leaves the device. Reminders are scheduled *inexactly*
/// (`inexactAllowWhileIdle`): exact alarms would need `SCHEDULE_EXACT_ALARM`
/// and a Play Store justification, which a reading nudge doesn't warrant. The
/// cost is that Android may fire a reminder a few minutes late.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// The types whose scheduling is actually implemented. The enum also declares
  /// the types still to come, so extending this set is all that's needed to
  /// surface them — the settings UI reads from here rather than from
  /// [NotificationType.values], so an unimplemented type can never be switched
  /// on and then silently do nothing.
  static const Set<NotificationType> supportedTypes = {
    NotificationType.dailyReminder,
  };

  /// Android refuses to raise the importance of a channel that already exists —
  /// `createNotificationChannel` on a known id is silently ignored, since only
  /// the reader is allowed to change it after the fact. Moving from default to
  /// high importance therefore means a new id and deleting the old one, which
  /// is what [_legacyChannelId] is for.
  static const _channelId = 'reading_reminders_v2';
  static const _legacyChannelId = 'reading_reminders';
  static const _channelName = 'Reading reminders';
  static const _channelDescription =
      'Scheduled nudges to keep your reading habit going';

  /// Notification ids are grouped per type so a type can be re-scheduled
  /// without touching the others. The daily reminder claims one id per weekday
  /// ([_dailyReminderBase] + 1..7); later types take the ranges above it.
  static const _dailyReminderBase = 100;

  bool _initialized = false;

  /// Set up timezones and the platform plugin. Safe to call more than once.
  ///
  /// Never throws: a device that refuses to report its timezone, or a platform
  /// channel that isn't ready, must not stop the app from launching. The
  /// service simply stays uninitialized and every later call no-ops.
  Future<void> init() async {
    if (_initialized) return;
    try {
      tz_data.initializeTimeZones();
      // Scheduling is done in the device's own zone, so a reminder set for
      // 8pm stays at 8pm after the reader flies somewhere else.
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier));

      await _plugin.initialize(
        settings: const InitializationSettings(
          // The launcher foreground is a white-on-transparent silhouette,
          // which is what Android expects for a status bar icon — the full
          // colour launcher icon would render as a grey block.
          android: AndroidInitializationSettings('@drawable/ic_launcher_foreground'),
          // Permission is requested when the reader enables their first
          // reminder, not on the launch that installs the update.
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );

      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      // Left behind by the first release, which used default importance.
      await android?.deleteNotificationChannel(channelId: _legacyChannelId);
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          // High, so the reminder arrives as a heads-up banner rather than a
          // silent line in the shade. At default importance a reminder that is
          // also running late is very easy to miss entirely, which reads as the
          // notification never having been sent.
          importance: Importance.high,
        ),
      );

      _initialized = true;
    } catch (e) {
      debugPrint('NotificationService init failed: $e');
    }
  }

  /// Whether the OS will currently deliver notifications for this app.
  Future<bool> hasPermission() async {
    if (!_initialized) return false;
    if (Platform.isAndroid) {
      final enabled = await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.areNotificationsEnabled();
      return enabled ?? false;
    }
    final options = await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.checkPermissions();
    return options?.isAlertEnabled ?? false;
  }

  /// Prompt for permission. Called when the reader switches on their first
  /// reminder — the point at which the request has obvious context — rather
  /// than at launch.
  ///
  /// Returns false if the reader declines, or if the OS has already been asked
  /// and refused (in which case the prompt no longer appears and the caller
  /// should send them to system settings).
  Future<bool> requestPermission() async {
    if (!_initialized) return false;
    if (Platform.isAndroid) {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      return granted ?? false;
    }
    final granted = await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    return granted ?? false;
  }

  /// Opens the system notification settings for this app, for when permission
  /// was denied permanently and the in-app prompt no longer does anything.
  Future<void> openSystemSettings() async {
    if (!_initialized) return;
    try {
      await _plugin.openAppNotificationSettings();
    } catch (e) {
      debugPrint('Could not open notification settings: $e');
    }
  }

  /// Rebuild every scheduled reminder from the current prefs.
  ///
  /// Cheap enough to call liberally — on launch, and after any change that
  /// could affect what a reminder would say. Each type is cancelled and
  /// re-scheduled wholesale rather than diffed, so there is no way for a stale
  /// alarm to survive a settings change.
  Future<void> rescheduleAll() async {
    if (!_initialized) return;
    final store = NotificationPrefsStore.instance;
    // Permission can be revoked from system settings at any time. Scheduling
    // against a revoked permission silently does nothing, so skip the work.
    if (!await hasPermission()) {
      await cancelAll();
      return;
    }
    await _scheduleDailyReminder(store.of(NotificationType.dailyReminder));
  }

  Future<void> cancelAll() async {
    if (!_initialized) return;
    await _plugin.cancelAll();
  }

  // ── Daily reading reminder ─────────────────────────────────────────────────

  /// The pool the daily reminder draws its body from.
  ///
  /// Facts rather than encouragement, because the text is frozen when the
  /// notification is scheduled and never revisited. That rules out anything
  /// about the reader — "pick up where you left off" is wrong for someone
  /// between books — and anything about the time of day, since the reader
  /// chooses when this arrives. A fact is true whoever reads it and whenever it
  /// lands, which is exactly what a frozen string has to be.
  ///
  /// Kept short: Android shows roughly one line before collapsing, so the point
  /// has to land in the first sixty characters or so. Claims are hedged to what
  /// the underlying research actually supports — the longevity finding is
  /// observational, so it says readers *outlived*, not that reading extends
  /// life. Arithmetic ones (pages per day) are exact by construction.
  static const List<String> _dailyReminderFacts = [
    '20 pages a day is about 25 books a year.',
    'Book readers outlived non-readers by about two years in a Yale study.',
    'The median American reader finishes five books a year.',
    "There are more public libraries in the US than McDonald's.",
    'Adults read about 240 words a minute.',
    'Children read to daily hear 1.4 million more words by age five.',
    'Around three in four US adults read a book last year.',
    '20 minutes of reading a day adds up to 1.8 million words a year.',
    'Readers aged 18 to 29 read more books than any other adult age group.',
    'Nearly every US public library now lends ebooks and audiobooks.',
    'Ten pages a day is still a dozen books a year.',
    'US print book sales hit their highest level on record in 2021.',
    'Iceland publishes more books per person than any other country.',
    'Audiobooks have grown by double digits nearly every year for a decade.',
    'A book a week from ages 20 to 80 is roughly 3,000 books.',
    'Independent bookstores have been opening again since 2020.',
    'How much you read predicts your vocabulary, over and above IQ.',
    'Icelanders exchange books on Christmas Eve and read them that night.',
  ];

  /// The only reminder whose text doesn't depend on live data, so it is
  /// scheduled as a repeating weekly notification per selected day — it keeps
  /// firing without the app, including across reboots, which the boot receiver
  /// in the manifest handles. The types that quote live numbers can't do this;
  /// they will be scheduled one occurrence at a time.
  ///
  /// A repeat would otherwise show one fixed body forever, so every reschedule
  /// deals a fresh hand from a shuffled pool — and [rescheduleAll] runs on each
  /// launch, so simply opening the app turns the facts over. Dealing from a
  /// shuffle rather than picking per slot guarantees the days in one batch are
  /// all different from each other.
  ///
  /// Not keyed to the date: the same day resolves to the same date all day, so
  /// a reader adjusting the time to test would see one fact over and over.
  ///
  /// Never opening the app degrades to the same weekly line repeating, since
  /// the plugin re-arms a repeat with the body it was given. Late and repetitive
  /// beats silent.
  Future<void> _scheduleDailyReminder(NotificationPref pref) async {
    for (final weekday in kAllWeekdays) {
      await _plugin.cancel(id: _dailyReminderBase + weekday);
    }
    if (!pref.isActiveFor(NotificationType.dailyReminder)) return;

    // More facts than there are days in a week, so no two slots collide.
    final pool = _dailyReminderFacts.toList()..shuffle();
    var slot = 0;
    for (final weekday in pref.weekdays) {
      final scheduledDate = _nextInstanceOf(weekday, pref.hour, pref.minute);
      final fact = pool[slot++ % pool.length];
      await _plugin.zonedSchedule(
        id: _dailyReminderBase + weekday,
        // The nudge lives in the title, since the body is a fact and states no
        // intent of its own. Kept constant so the reminder has one recognisable
        // shape in the tray.
        title: 'Time to read',
        body: fact,
        scheduledDate: scheduledDate,
        notificationDetails: _details(fact),
        // Inexact: Android may deliver this up to an hour after the set time,
        // and defer it further under Doze or app standby. Accepted rather than
        // requesting an exact-alarm permission, which needs a Play Store
        // declaration and a trip to system settings for precision a reading
        // nudge doesn't need.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  /// [body] is repeated as big-text style so Android shows the whole line when
  /// the shade is expanded. Without it a fact longer than the collapsed width
  /// is simply truncated, and these are written to end on the point.
  NotificationDetails _details(String body) => NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          // Matches the channel. Importance governs behaviour on Android 8+;
          // priority is what older versions read, so both are set.
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(body),
        ),
        iOS: const DarwinNotificationDetails(),
      );

  /// The next moment matching [weekday] at [hour]:[minute] in the device's zone.
  ///
  /// Days are stepped by rebuilding the date rather than adding a 24-hour
  /// [Duration], because a DST boundary makes a calendar day 23 or 25 hours
  /// long — adding a fixed day would drift an 8pm reminder to 7pm or 9pm.
  static tz.TZDateTime _nextInstanceOf(int weekday, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    // Today's slot having already passed means the first candidate is tomorrow.
    if (!scheduled.isAfter(now)) scheduled = _nextDay(scheduled, hour, minute);
    while (scheduled.weekday != weekday) {
      scheduled = _nextDay(scheduled, hour, minute);
    }
    return scheduled;
  }

  // Day overflow is normalised by the TZDateTime constructor, so month and
  // year ends need no special handling.
  static tz.TZDateTime _nextDay(tz.TZDateTime from, int hour, int minute) =>
      tz.TZDateTime(tz.local, from.year, from.month, from.day + 1, hour, minute);
}
