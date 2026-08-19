/// The kinds of reminder the app can send. Each one is configured
/// independently — the reader can run a nightly reading nudge without ever
/// hearing about goals, or the reverse.
///
/// [id] is persisted, so renaming an enum value is safe but changing its id
/// silently resets that type's settings.
enum NotificationType {
  /// "Time to read" at a chosen time on chosen days. Copy never changes, so
  /// this one is scheduled as a repeating weekly notification and left alone.
  /// Needs no description — the label says all there is to say.
  dailyReminder(
    id: 'daily_reminder',
    label: 'Daily reading reminder',
  ),

  /// How the current goal periods are tracking. Copy depends on live progress,
  /// so it is re-scheduled whenever the numbers move.
  goalCheckIn(
    id: 'goal_check_in',
    label: 'Goal check-in',
    description: 'How your reading goals are tracking',
  ),

  /// Sent only when the week is closing and no session has been logged yet.
  /// Configured by how much notice to give rather than by weekday — picking a
  /// day for this means working out which day the week happens to end on.
  streakAtRisk(
    id: 'streak_at_risk',
    label: 'Streak at risk',
    description: "When your week streak is about to break",
  ),

  /// A book left mid-read for a while. Configured by a day threshold rather
  /// than a weekly schedule.
  staleBook(
    id: 'stale_book',
    label: 'Forgotten book',
    description: "When a book you're reading goes untouched",
  ),

  /// The month just gone, summarised. Fires on the 1st, so the only thing left
  /// to configure is what time of day it arrives.
  monthlyRecap(
    id: 'monthly_recap',
    label: 'Monthly recap',
    description: 'When last month\'s recap is ready',
  );

  const NotificationType({
    required this.id,
    required this.label,
    this.description,
  });

  /// Stable key used in storage and to derive platform notification ids.
  final String id;
  final String label;

  /// Only for types whose trigger isn't obvious from the label — a reminder
  /// that explains itself doesn't need a second line repeating it.
  final String? description;

  /// True when the schedule is a time plus a set of weekdays. The others don't
  /// hang off the week — [streakAtRisk] fires relative to the end of the
  /// reader's week and [staleBook] relative to a book's last session, so both
  /// are configured with a day count, and [monthlyRecap] lands on a fixed day
  /// of the month with nothing to choose but the time.
  bool get usesWeekdaySchedule =>
      this == NotificationType.dailyReminder ||
      this == NotificationType.goalCheckIn;

  /// Fires once a month, on the 1st. The date is fixed — a recap that arrived
  /// mid-month would be summarising a month the reader is still living in.
  bool get usesMonthlySchedule => this == NotificationType.monthlyRecap;

  /// Label for the day-count control, on the types that have one.
  String get thresholdLabel => switch (this) {
        NotificationType.streakAtRisk => 'Notice',
        NotificationType.staleBook => 'Untouched for',
        _ => '',
      };

  List<int> get thresholdOptions => switch (this) {
        NotificationType.streakAtRisk => kStreakNoticeOptions,
        NotificationType.staleBook => kStaleBookThresholdOptions,
        _ => const <int>[],
      };

  String thresholdDisplay(int days) => switch (this) {
        NotificationType.streakAtRisk =>
          '$days ${days == 1 ? 'day' : 'days'} left',
        _ => '$days days',
      };

  /// A second line under the control, for when the number alone doesn't say
  /// what it works out to on the calendar.
  String? thresholdHint(int days) => switch (this) {
        NotificationType.streakAtRisk =>
          'Arrives on ${kWeekdayNames[streakNoticeWeekday(days) - 1]}',
        _ => null,
      };

  static NotificationType? fromId(String id) {
    for (final type in NotificationType.values) {
      if (type.id == id) return type;
    }
    return null;
  }
}

/// The week in the order it is shown, Sunday first.
///
/// The values are `DateTime.monday`..`DateTime.sunday` (1–7), which is also
/// what `TZDateTime.weekday` returns — so no conversion is ever needed between
/// what is stored here and what scheduling compares against. Only the order of
/// this list is Sunday-first; the numbers keep their normal meaning.
const List<int> kAllWeekdays = <int>[
  DateTime.sunday,
  DateTime.monday,
  DateTime.tuesday,
  DateTime.wednesday,
  DateTime.thursday,
  DateTime.friday,
  DateTime.saturday,
];

/// Day thresholds offered for [NotificationType.staleBook]. A free-form number
/// field would invite values — 1 day, 200 days — that make the reminder either
/// constant or useless, so the choice is a fixed ladder instead.
const List<int> kStaleBookThresholdOptions = <int>[3, 5, 7, 10, 14, 21, 30];

/// How much notice [NotificationType.streakAtRisk] can give, in days left in
/// the week — 1 being the last day. Stops at six: seven would put the warning
/// on the first day of the week, before there is anything to warn about.
const List<int> kStreakNoticeOptions = <int>[1, 2, 3, 4, 5, 6];

/// Indexed by `DateTime.monday`..`DateTime.sunday` minus one.
const List<String> kWeekdayNames = <String>[
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// The weekday a streak warning with [daysLeft] to spare lands on.
///
/// Streak weeks are Monday-aligned — see `ReadingStats.weekOrdinal`, which this
/// has to agree with — so the week runs out at the end of Sunday. One day left
/// is therefore Sunday itself, and each extra day of notice steps back from
/// there: five days left is Wednesday.
int streakNoticeWeekday(int daysLeft) =>
    DateTime.sunday + 1 - daysLeft.clamp(1, 7);

/// Where [weekday] falls in the displayed week. Used to sort stored days so
/// they read Sunday-first everywhere, rather than in numeric order — which
/// would put Sunday, as 7, last.
int _weekOrder(int weekday) => kAllWeekdays.indexOf(weekday);

/// One reminder's settings. Every type stores the same shape even where a field
/// doesn't apply to it — the day-count types keep a time of day (when to send)
/// but ignore [weekdays], and the weekday-scheduled types ignore
/// [thresholdDays]. Carrying the unused field costs nothing and keeps storage
/// uniform.
class NotificationPref {
  final bool enabled;
  final int hour;
  final int minute;

  /// Days this fires on, as `DateTime.monday`..`DateTime.sunday`. De-duplicated
  /// and put in week order (Sunday first) by the constructor, so display never
  /// depends on the order the reader happened to tap them in.
  final List<int> weekdays;

  /// The day count for the types configured by one: days of silence before
  /// [NotificationType.staleBook] fires, or days left in the week when
  /// [NotificationType.streakAtRisk] should warn. Unused by the rest.
  final int thresholdDays;

  NotificationPref({
    required this.enabled,
    required this.hour,
    required this.minute,
    required List<int> weekdays,
    this.thresholdDays = 5,
  }) : weekdays = List.unmodifiable(weekdays.toSet().toList()
          ..sort((a, b) => _weekOrder(a).compareTo(_weekOrder(b))));

  /// Sensible starting point per type, used until the reader changes anything.
  ///
  /// [NotificationType.streakAtRisk] is the one that starts on. It is the only
  /// reminder that is purely protective — it fires solely when something the
  /// reader has already built is about to be lost, and never otherwise, so it
  /// can't become background noise. The rest are opted into.
  factory NotificationPref.defaultsFor(NotificationType type) =>
      switch (type) {
        // Evening, when reading actually happens.
        NotificationType.dailyReminder => NotificationPref(
            enabled: false,
            hour: 20,
            minute: 0,
            weekdays: kAllWeekdays,
          ),
        // Sunday evening, with the week's numbers all but final.
        NotificationType.goalCheckIn => NotificationPref(
            enabled: false,
            hour: 18,
            minute: 0,
            weekdays: const [DateTime.sunday],
          ),
        // The last day of the week, but in the morning: this one asks for a
        // reading session before midnight, so it has to leave a whole day to
        // find the time. An evening warning about a deadline a few hours out is
        // one the reader can only fail.
        NotificationType.streakAtRisk => NotificationPref(
            enabled: true,
            hour: 9,
            minute: 0,
            weekdays: kAllWeekdays,
            thresholdDays: 1,
          ),
        // A week of silence: long enough that an ordinary busy stretch doesn't
        // trip it, short enough to catch a book before it is truly abandoned.
        NotificationType.staleBook => NotificationPref(
            enabled: false,
            hour: 19,
            minute: 0,
            weekdays: kAllWeekdays,
            thresholdDays: 7,
          ),
        // On by default, and the only opted-out-of one that is. A recap is the
        // point of the feature rather than a nudge on top of it: it arrives at
        // most once a month, says nothing at all when the month was empty, and
        // a reader who never hears the first one would never know the recap
        // exists. Morning on the 1st, while the month just gone still feels
        // recent.
        NotificationType.monthlyRecap => NotificationPref(
            enabled: true,
            hour: 9,
            minute: 0,
            weekdays: kAllWeekdays,
          ),
      };

  NotificationPref copyWith({
    bool? enabled,
    int? hour,
    int? minute,
    List<int>? weekdays,
    int? thresholdDays,
  }) =>
      NotificationPref(
        enabled: enabled ?? this.enabled,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
        weekdays: weekdays ?? this.weekdays,
        thresholdDays: thresholdDays ?? this.thresholdDays,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'hour': hour,
        'minute': minute,
        'weekdays': weekdays,
        'thresholdDays': thresholdDays,
      };

  /// Rebuilds from stored JSON, falling back to the type's defaults field by
  /// field. A pref written by an older version simply picks up defaults for
  /// anything it didn't have.
  factory NotificationPref.fromJson(
    Map<String, dynamic> json,
    NotificationType type,
  ) {
    final defaults = NotificationPref.defaultsFor(type);
    final rawDays = json['weekdays'];
    return NotificationPref(
      enabled: json['enabled'] as bool? ?? defaults.enabled,
      hour: (json['hour'] as num?)?.toInt().clamp(0, 23) ?? defaults.hour,
      minute: (json['minute'] as num?)?.toInt().clamp(0, 59) ?? defaults.minute,
      weekdays: rawDays is List
          ? rawDays
              .map((d) => (d as num).toInt())
              .where((d) => d >= DateTime.monday && d <= DateTime.sunday)
              .toList()
          : defaults.weekdays,
      thresholdDays:
          (json['thresholdDays'] as num?)?.toInt().clamp(1, 90) ??
              defaults.thresholdDays,
    );
  }

  /// A reminder with every day switched off would never fire, so it counts as
  /// off regardless of the toggle. [staleBook] ignores weekdays entirely.
  bool isActiveFor(NotificationType type) =>
      enabled && (!type.usesWeekdaySchedule || weekdays.isNotEmpty);
}
