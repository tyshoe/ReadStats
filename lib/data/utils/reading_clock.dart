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
  if (hour >= 5 && hour < 12) return 0; // 5am – 11:59am
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
