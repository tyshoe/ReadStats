/// Where a session's start time lands: which day of the week, and which part
/// of the day.
///
/// Shared by the Statistics habit charts so the weekday strip and the clock
/// strip can never disagree about when evening starts or what to call a Tuesday.
library;

/// The parts of a day, in the order they are charted. Night wraps midnight, so
/// the four together cover the clock.
const List<String> kDaypartLabels = ['Morning', 'Afternoon', 'Evening', 'Night'];

/// The daypart indexes, for iterating in chart order.
const List<int> kDaypartOrder = [0, 1, 2, 3];

/// Index into [kDaypartLabels] for an hour of the day.
int daypartOf(int hour) {
  if (hour < 5) return 3; //              the small hours are still Night
  if (hour < 12) return 0; //             5am – 11:59am
  if (hour < 17) return 1; //             12pm – 4:59pm
  if (hour < 22) return 2; //             5pm – 9:59pm
  return 3; //                            10pm – 4:59am
}

/// Keyed by DateTime.monday..sunday.
const Map<int, String> kWeekdayShort = {
  DateTime.monday: 'Mon',
  DateTime.tuesday: 'Tue',
  DateTime.wednesday: 'Wed',
  DateTime.thursday: 'Thu',
  DateTime.friday: 'Fri',
  DateTime.saturday: 'Sat',
  DateTime.sunday: 'Sun',
};

const Map<int, String> kWeekdayFull = {
  DateTime.monday: 'Monday',
  DateTime.tuesday: 'Tuesday',
  DateTime.wednesday: 'Wednesday',
  DateTime.thursday: 'Thursday',
  DateTime.friday: 'Friday',
  DateTime.saturday: 'Saturday',
  DateTime.sunday: 'Sunday',
};

/// A session timed at exactly midnight carries a date that arrived without a
/// time — an import of someone else's export, floored to 00:00 by DateUtils.
/// The day is real, but the hour is not, so only the clock-face figures skip it.
bool hasRealClockTime(DateTime at) => at.hour != 0 || at.minute != 0;

/// The hour a reading day starts for the habit charts. Matches where Night
/// ends in [daypartOf], so a sitting that runs past midnight stays whole on
/// the night it began instead of being cut in two at 12am.
const int kReadingDayStartHour = 5;

/// The weekday (DateTime.monday..sunday) a session counts toward: the small
/// hours belong to the night before. A session with no real clock time stays
/// on its own date.
int readingWeekday(DateTime at) =>
    hasRealClockTime(at) && at.hour < kReadingDayStartHour
        ? at.subtract(const Duration(days: 1)).weekday
        : at.weekday;

/// Minutes from the start of the reading day to [at].
int readingDayMinute(DateTime at) =>
    ((at.hour - kReadingDayStartHour + 24) % 24) * 60 + at.minute;

/// The clock hour (0–23) an hour slot of the reading day covers.
int clockHourOfSlot(int slot) => (slot + kReadingDayStartHour) % 24;

/// An empty week of hour slots: seven rows indexed by weekday − 1
/// (DateTime.monday first), each twenty-four slots from
/// [kReadingDayStartHour].
List<List<int>> emptyClockGrid() =>
    List.generate(7, (_) => List<int>.filled(24, 0));

/// Adds a session to a clock grid. [minuteGrid] gets its minutes spread over
/// the hours it actually covered; [sessionGrid] gets one count in the hour it
/// started. Reading that would run past the end of the reading day is dropped.
void addToClockGrids(
  DateTime at,
  int minutes, {
  required List<List<int>> minuteGrid,
  required List<List<int>> sessionGrid,
}) {
  final row = readingWeekday(at) - 1;
  var cursor = readingDayMinute(at);
  sessionGrid[row][cursor ~/ 60] += 1;
  var left = minutes;
  while (left > 0 && cursor < 24 * 60) {
    final room = 60 - cursor % 60;
    final take = left < room ? left : room;
    minuteGrid[row][cursor ~/ 60] += take;
    cursor += take;
    left -= take;
  }
}

/// Totals for each part of the day across a clock grid, keyed by index into
/// [kDaypartLabels].
Map<int, int> daypartTotalsOf(List<List<int>> grid) {
  final totals = <int, int>{};
  for (final row in grid) {
    for (var slot = 0; slot < row.length; slot++) {
      final part = daypartOf(clockHourOfSlot(slot));
      totals[part] = (totals[part] ?? 0) + row[slot];
    }
  }
  return totals;
}

/// The fullest bucket of [totals], or null when nothing is logged. Ties go to
/// whichever key comes first in [order], so the answer is stable.
int? peakBucket(Map<int, int> totals, List<int> order) {
  int? best;
  for (final key in order) {
    final value = totals[key] ?? 0;
    if (value > 0 && (best == null || value > (totals[best] ?? 0))) best = key;
  }
  return best;
}
