import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '/ui/pages/profile/reading_stats.dart';
import '../database/database_helper.dart';
import '../models/goal.dart';
import '../models/notification_pref.dart';
import '../repositories/goal_repository.dart';
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

  /// The types whose scheduling is actually implemented. The settings UI reads
  /// from here rather than from [NotificationType.values], so a type declared
  /// but not yet scheduled can never be switched on and then silently do
  /// nothing.
  static const Set<NotificationType> supportedTypes = {
    NotificationType.dailyReminder,
    NotificationType.goalCheckIn,
    NotificationType.streakAtRisk,
    NotificationType.staleBook,
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
  /// ([_dailyReminderBase] + 1..7); the data-driven types only ever have a
  /// single occurrence pending, so one id each is enough.
  static const _dailyReminderBase = 100;
  static const _goalCheckInId = 200;
  static const _streakAtRiskId = 300;
  static const _staleBookId = 400;

  /// Goals beyond this many are summarised as a count. Android's expanded
  /// notification has room for a handful of lines, not a full list.
  static const _maxGoalLines = 4;

  bool _initialized = false;

  /// Needed by the goal check-in, which reads targets and period progress
  /// straight from the database. Null until [configure] runs.
  GoalRepository? _goalRepository;

  /// The book and session rows the app already keeps in memory, pushed here by
  /// [updateData]. Null until the first load completes — the data-driven
  /// reminders are left untouched until then rather than being cancelled and
  /// re-added a moment later.
  List<Map<String, dynamic>>? _books;
  List<Map<String, dynamic>>? _sessions;

  Timer? _refreshDebounce;
  bool _rescheduling = false;
  bool _rescheduleQueued = false;

  /// Wire up the repositories the data-driven reminders read from. Called once
  /// at startup, before [init].
  void configure({required GoalRepository goalRepository}) {
    _goalRepository = goalRepository;
  }

  /// Hand over the current library, then re-schedule.
  ///
  /// Called on every books/sessions reload, so a session logged an hour before
  /// a check-in is reflected in what it says. Debounced because books and
  /// sessions land separately and a single save can touch both.
  void updateData({
    required List<Map<String, dynamic>> books,
    required List<Map<String, dynamic>> sessions,
  }) {
    _books = books;
    _sessions = sessions;
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(seconds: 1), rescheduleAll);
  }

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
          // Never asked here — initialising the plugin should not put a system
          // dialog on screen. See [ensurePermissionRequested], which asks once
          // the app has something on screen to justify it.
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

  /// Ask for permission once, from outside the settings page.
  ///
  /// [NotificationType.streakAtRisk] ships switched on, and a reminder nobody
  /// opted into never reaches the settings page that would otherwise do the
  /// asking — so without this, the one default-on reminder would silently never
  /// arrive on Android 13+ and iOS, where notifications start denied.
  ///
  /// Called at the end of onboarding for new installs and on the first launch
  /// after updating for everyone else. Both routes are safe to call repeatedly:
  /// the prompt is spent at most once.
  Future<void> ensurePermissionRequested() async {
    if (!_initialized) return;
    final store = NotificationPrefsStore.instance;
    if (store.permissionAsked) return;
    // Nothing switched on means there is nothing to ask for yet — a reader who
    // turned the defaults off should not be prompted for reminders they have
    // already declined.
    if (!store.anyEnabled) return;

    if (await hasPermission()) {
      // Already granted, which is the norm on Android 12 and below where the
      // grant comes with the install. Recorded so that revoking it later can't
      // produce a prompt out of nowhere on some unrelated launch.
      await store.markPermissionAsked();
      return;
    }

    await requestPermission();
    // Granted or not, what is scheduled has to be brought in line: nothing can
    // have been armed while permission was missing.
    await rescheduleAll();
  }

  /// Prompt for permission, and record that the prompt has been spent.
  ///
  /// Returns false if the reader declines, or if the OS has already been asked
  /// and refused (in which case the prompt no longer appears and the caller
  /// should send them to system settings).
  Future<bool> requestPermission() async {
    if (!_initialized) return false;
    // Marked up front: the OS counts the prompt whatever the reader answers,
    // and an early return below must not leave it looking unspent.
    await NotificationPrefsStore.instance.markPermissionAsked();
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
    // Launch and the first data load both trigger a reschedule, and the two
    // overlap. Running them concurrently would interleave one pass's cancels
    // with another's schedules, leaving a reminder cancelled until something
    // else happened to trigger a third pass.
    if (_rescheduling) {
      _rescheduleQueued = true;
      return;
    }
    _rescheduling = true;
    try {
      do {
        _rescheduleQueued = false;
        await _reschedule();
      } while (_rescheduleQueued);
    } finally {
      _rescheduling = false;
    }
  }

  Future<void> _reschedule() async {
    final store = NotificationPrefsStore.instance;
    // Permission can be revoked from system settings at any time. Scheduling
    // against a revoked permission silently does nothing, so skip the work.
    if (!await hasPermission()) {
      await cancelAll();
      return;
    }
    await _scheduleDailyReminder(store.of(NotificationType.dailyReminder));

    // The rest quote live numbers and can't be worked out without the library.
    // At launch this pass runs before the first load, so they are left as they
    // were until [updateData] triggers the pass that can do them justice.
    if (_books == null || _sessions == null) return;
    await _scheduleGoalCheckIn(store.of(NotificationType.goalCheckIn));
    await _scheduleStreakAtRisk(store.of(NotificationType.streakAtRisk));
    await _scheduleStaleBook(store.of(NotificationType.staleBook));
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

  // ── Data-driven reminders ──────────────────────────────────────────────────
  //
  // Unlike the daily reminder, these three quote the reader's actual numbers,
  // so they can't be armed as a repeat — the plugin would re-fire whatever text
  // it was first given, forever. Each schedules its *next* occurrence only, and
  // every fact in it is worked out as of that future moment rather than as of
  // now: progress for the period the check-in lands in, staleness measured to
  // the evening it would arrive.
  //
  // That makes a single pending occurrence correct even if it was armed days
  // earlier, because the only things that move these numbers — a session, a
  // finished book, a new goal — all happen with the app open, and every one of
  // them triggers a reschedule. The occurrence after next is left unscheduled
  // until the app is next opened; a reader who never opens it has no streak to
  // protect and no progress to report anyway.

  /// A summary of where each goal stands, or nothing at all when there are no
  /// goals — a check-in with no numbers in it is just noise.
  Future<void> _scheduleGoalCheckIn(NotificationPref pref) async {
    await _plugin.cancel(id: _goalCheckInId);
    if (!pref.isActiveFor(NotificationType.goalCheckIn)) return;
    final repo = _goalRepository;
    if (repo == null) return;

    final scheduledDate = _nextSelectedOccurrence(pref);
    if (scheduledDate == null) return;

    final goals = await repo.getGoals();
    if (goals.isEmpty) return;

    final lines = <String>[];
    var allMet = true;
    for (final goal in goals) {
      final progress = await repo.getProgressAt(goal, scheduledDate);
      if (!progress.met) allMet = false;
      if (lines.length < _maxGoalLines) lines.add(_goalLine(goal, progress));
    }
    if (goals.length > _maxGoalLines) {
      lines.add('and ${goals.length - _maxGoalLines} more');
    }

    final body = lines.join('\n');
    await _plugin.zonedSchedule(
      id: _goalCheckInId,
      // Leading with the outcome, so a reader who only sees the title still
      // learns something.
      title: allMet ? 'Goals met' : 'Goal check-in',
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: _details(body),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// "Weekly pages read: 120 of 200", with a tick once it's in the bag.
  static String _goalLine(Goal goal, PeriodProgress progress) {
    final line = '${goal.period.label} ${goal.metric.label.toLowerCase()}: '
        '${goal.metric.cardDisplay(progress.actual)} of '
        '${goal.metric.cardDisplay(progress.target)}';
    return progress.met ? '$line ✓' : line;
  }

  /// Only scheduled when the week it would land in has no session yet *and*
  /// there is a run of earlier weeks to lose. Both are judged against the
  /// scheduled week, which for a future week means "no session logged so far" —
  /// and logging one reschedules this away.
  ///
  /// The day is derived rather than picked: the reader says how much notice
  /// they want and [streakNoticeWeekday] works out which day that is, so the
  /// setting can't drift out of step with where the week actually ends.
  Future<void> _scheduleStreakAtRisk(NotificationPref pref) async {
    await _plugin.cancel(id: _streakAtRiskId);
    if (!pref.isActiveFor(NotificationType.streakAtRisk)) return;

    final scheduledDate = _nextInstanceOf(
      streakNoticeWeekday(pref.thresholdDays),
      pref.hour,
      pref.minute,
    );

    final weeks = <int>{};
    for (final session in _sessions!) {
      final date = _asDate(session['date']);
      if (date != null) weeks.add(ReadingStats.weekOrdinal(date));
    }

    // Already read this week — there is nothing at risk.
    final fireWeek = ReadingStats.weekOrdinal(scheduledDate);
    if (weeks.contains(fireWeek)) return;

    // Weeks running up to, but not including, the one the reminder lands in.
    var streak = 0;
    for (var week = fireWeek - 1; weeks.contains(week); week--) {
      streak++;
    }
    if (streak == 0) return;

    // The notice setting counts the day the reminder arrives on, so one day
    // left means it lands on the last day of the week.
    final deadline = switch (pref.thresholdDays) {
      1 => 'today',
      2 => 'by tomorrow',
      final days => 'in the next $days days',
    };
    final body = '$streak ${streak == 1 ? 'week' : 'weeks'} in a row. '
        'Log a session $deadline to keep it going.';

    await _plugin.zonedSchedule(
      id: _streakAtRiskId,
      title: 'Streak at risk',
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: _details(body),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// A book on the Currently Reading shelf that hasn't been touched in a while.
  ///
  /// This one has no weekday picker — it's driven by the book, not the
  /// calendar, so it checks daily at the chosen time. To stop that becoming a
  /// nightly nag about a book the reader has quietly given up on, a nudge is
  /// followed by another threshold's worth of silence: set to seven days, an
  /// ignored reminder comes back in seven, not tomorrow.
  Future<void> _scheduleStaleBook(NotificationPref pref) async {
    await _plugin.cancel(id: _staleBookId);

    // The cancel above dropped whatever was pending, so a recorded time still
    // in the future no longer refers to anything and must not start a cooldown.
    // It is written again below only if this pass actually arms something —
    // otherwise a reminder that was cancelled because the book got picked back
    // up would go on suppressing the next one for a full threshold.
    final store = NotificationPrefsStore.instance;
    final lastSent = store.lastSentAt(NotificationType.staleBook);
    if (lastSent != null && lastSent.isAfter(DateTime.now())) {
      await store.setSentAt(NotificationType.staleBook, null);
    }

    if (!pref.isActiveFor(NotificationType.staleBook)) return;

    final scheduledDate = _nextDailyInstance(pref.hour, pref.minute);
    if (lastSent != null &&
        lastSent.isBefore(DateTime.now()) &&
        scheduledDate.difference(lastSent).inDays < pref.thresholdDays) {
      return;
    }

    // Most recent session per book. A book that has never had one falls back to
    // when the reader started it, then to when it was added — otherwise a book
    // shelved as Currently Reading and never opened could never go stale.
    final lastRead = <int, DateTime>{};
    for (final session in _sessions!) {
      final date = _asDate(session['date']);
      if (date == null) continue;
      final bookId = _asInt(session['book_id']);
      final previous = lastRead[bookId];
      if (previous == null || date.isAfter(previous)) lastRead[bookId] = date;
    }

    String? staleTitle;
    var staleDays = 0;
    var staleCount = 0;
    for (final book in _books!) {
      if (_asInt(book['shelf_id']) != DatabaseHelper.shelfCurrentlyReading) {
        continue;
      }
      final last = lastRead[_asInt(book['id'])] ??
          _asDate(book['date_started']) ??
          _asDate(book['date_added']);
      if (last == null) continue;
      final days = _daysBetween(last, scheduledDate);
      if (days < pref.thresholdDays) continue;
      staleCount++;
      // The most neglected book leads — it's the one the reader is least likely
      // to have front of mind.
      if (staleTitle == null || days > staleDays) {
        staleDays = days;
        staleTitle = book['title']?.toString();
      }
    }
    if (staleTitle == null || staleTitle.isEmpty) return;

    final others = staleCount - 1;
    final body = StringBuffer('“$staleTitle” has gone $staleDays days '
        'without a session.');
    if (others > 0) {
      body.write(' Plus $others other ${others == 1 ? 'book' : 'books'}.');
    }

    await _plugin.zonedSchedule(
      id: _staleBookId,
      title: 'Still reading?',
      body: body.toString(),
      scheduledDate: scheduledDate,
      notificationDetails: _details(body.toString()),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
    await store.setSentAt(NotificationType.staleBook, scheduledDate);
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
    var scheduled = _nextDailyInstance(hour, minute);
    while (scheduled.weekday != weekday) {
      scheduled = _nextDay(scheduled, hour, minute);
    }
    return scheduled;
  }

  /// Today at [hour]:[minute], or tomorrow if that has already gone by.
  static tz.TZDateTime _nextDailyInstance(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    final scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    return scheduled.isAfter(now) ? scheduled : _nextDay(scheduled, hour, minute);
  }

  /// The soonest of the days [pref] has selected, for the types that schedule
  /// one occurrence at a time. Null only when no day is selected, which
  /// [NotificationPref.isActiveFor] already treats as switched off.
  static tz.TZDateTime? _nextSelectedOccurrence(NotificationPref pref) {
    tz.TZDateTime? soonest;
    for (final weekday in pref.weekdays) {
      final candidate = _nextInstanceOf(weekday, pref.hour, pref.minute);
      if (soonest == null || candidate.isBefore(soonest)) soonest = candidate;
    }
    return soonest;
  }

  // Day overflow is normalised by the TZDateTime constructor, so month and
  // year ends need no special handling.
  static tz.TZDateTime _nextDay(tz.TZDateTime from, int hour, int minute) =>
      tz.TZDateTime(tz.local, from.year, from.month, from.day + 1, hour, minute);

  /// Whole calendar days from [from] to [to], counted in UTC so a daylight
  /// saving change can't turn a five-day gap into four days and 23 hours.
  static int _daysBetween(DateTime from, DateTime to) =>
      DateTime.utc(to.year, to.month, to.day)
          .difference(DateTime.utc(from.year, from.month, from.day))
          .inDays;

  // Session and book rows come from SQLite as ints or strings depending on the
  // column and the writer, so both are parsed defensively — the same approach
  // ReadingStats takes with the very same maps.
  static int _asInt(dynamic value) =>
      value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;

  static DateTime? _asDate(dynamic value) {
    final text = value?.toString();
    if (text == null || text.isEmpty) return null;
    return DateTime.tryParse(text);
  }
}
