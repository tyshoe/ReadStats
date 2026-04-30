enum GoalMetric {
  booksFinished,
  timeReading,
  pagesRead,
  sessions;

  String get dbValue => switch (this) {
        GoalMetric.booksFinished => 'books_finished',
        GoalMetric.timeReading => 'time_reading',
        GoalMetric.pagesRead => 'pages_read',
        GoalMetric.sessions => 'sessions',
      };

  String get label => switch (this) {
        GoalMetric.booksFinished => 'Books Finished',
        GoalMetric.timeReading => 'Time Reading',
        GoalMetric.pagesRead => 'Pages Read',
        GoalMetric.sessions => 'Sessions',
      };

  String unitLabel(int value) => switch (this) {
        GoalMetric.booksFinished => '$value ${value == 1 ? 'book' : 'books'}',
        GoalMetric.timeReading => _formatMinutes(value),
        GoalMetric.pagesRead => '$value ${value == 1 ? 'page' : 'pages'}',
        GoalMetric.sessions => '$value ${value == 1 ? 'session' : 'sessions'}',
      };

  /// Display value for goal cards — time keeps its format, others show number only.
  String cardDisplay(int value) => switch (this) {
        GoalMetric.timeReading => _formatMinutes(value),
        _ => '$value',
      };

  static String _formatMinutes(int minutes) {
    if (minutes < 60) return '$minutes\u00A0min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h\u00A0${m}m';
  }

  static GoalMetric fromDb(String value) => switch (value) {
        'books_finished' => GoalMetric.booksFinished,
        'time_reading' => GoalMetric.timeReading,
        'pages_read' => GoalMetric.pagesRead,
        _ => GoalMetric.sessions,
      };
}

enum GoalPeriod {
  weekly,
  monthly,
  yearly;

  String get dbValue => name;

  String get label => switch (this) {
        GoalPeriod.weekly => 'Weekly',
        GoalPeriod.monthly => 'Monthly',
        GoalPeriod.yearly => 'Yearly',
      };

  static GoalPeriod fromDb(String value) => switch (value) {
        'weekly' => GoalPeriod.weekly,
        'monthly' => GoalPeriod.monthly,
        _ => GoalPeriod.yearly,
      };
}

class Goal {
  final int? id;
  final GoalMetric metric;
  final GoalPeriod period;
  final int target;
  final String createdAt;

  const Goal({
    this.id,
    required this.metric,
    required this.period,
    required this.target,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'metric': metric.dbValue,
        'period': period.dbValue,
        'target': target,
        'created_at': createdAt,
      };

  factory Goal.fromMap(Map<String, dynamic> map) => Goal(
        id: map['id'] as int?,
        metric: GoalMetric.fromDb(map['metric'] as String),
        period: GoalPeriod.fromDb(map['period'] as String),
        target: map['target'] as int,
        createdAt: map['created_at'] as String,
      );

  Goal copyWith({int? target}) => Goal(
        id: id,
        metric: metric,
        period: period,
        target: target ?? this.target,
        createdAt: createdAt,
      );
}

class PeriodProgress {
  final DateTime periodStart;
  final DateTime periodEnd;
  final int target;
  final int actual;
  /// False for periods before the goal was created — actual is shown but no target.
  final bool hasGoal;

  const PeriodProgress({
    required this.periodStart,
    required this.periodEnd,
    required this.target,
    required this.actual,
    this.hasGoal = true,
  });

  double get ratio =>
      hasGoal && target > 0 ? (actual / target).clamp(0.0, 1.0) : 0.0;
  bool get met => hasGoal && actual >= target;
}
