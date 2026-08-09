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

  /// True when the schedule is a time plus a set of weekdays. [staleBook] is
  /// the exception — it fires relative to a book's last session, so it is
  /// configured with a day threshold instead.
  bool get usesWeekdaySchedule => this != NotificationType.staleBook;

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

/// Where [weekday] falls in the displayed week. Used to sort stored days so
/// they read Sunday-first everywhere, rather than in numeric order — which
/// would put Sunday, as 7, last.
int _weekOrder(int weekday) => kAllWeekdays.indexOf(weekday);

/// One reminder's settings. Every type stores the same shape even where a field
/// doesn't apply to it — [staleBook] keeps a time of day (when to send) but
/// ignores [weekdays], and the weekday-scheduled types ignore [thresholdDays].
/// Carrying the unused field costs nothing and keeps storage uniform.
class NotificationPref {
  final bool enabled;
  final int hour;
  final int minute;

  /// Days this fires on, as `DateTime.monday`..`DateTime.sunday`. De-duplicated
  /// and put in week order (Sunday first) by the constructor, so display never
  /// depends on the order the reader happened to tap them in.
  final List<int> weekdays;

  /// Days of silence before [staleBook] fires. Unused by other types.
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
  /// All start disabled — notifications are opted into, never sprung on the
  /// reader by an app update.
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
        // Sunday evening too, but early enough that there is still time to read
        // something and save the streak.
        NotificationType.streakAtRisk => NotificationPref(
            enabled: false,
            hour: 17,
            minute: 0,
            weekdays: const [DateTime.sunday],
          ),
        NotificationType.staleBook => NotificationPref(
            enabled: false,
            hour: 19,
            minute: 0,
            weekdays: kAllWeekdays,
            thresholdDays: 5,
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
