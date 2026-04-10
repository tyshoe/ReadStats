import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SessionsCalendar extends StatelessWidget {
  final DateTime start;
  final DateTime end;
  final List<Map<String, dynamic>> sessions;
  final bool isCurrentMonth;

  const SessionsCalendar({
    super.key,
    required this.start,
    required this.end,
    required this.sessions,
    this.isCurrentMonth = false,
  });

  DateTime _weekStart(DateTime date) {
    final utc = DateTime.utc(date.year, date.month, date.day);
    return DateTime.utc(utc.year, utc.month, utc.day - (utc.weekday % 7));
  }

  // Returns a map of week-start ISO string -> streak count for every streak run end.
  Map<String, int> _streakEndCounts() {
    if (sessions.isEmpty) return {};

    final weekStarts = sessions
        .map((s) => _weekStart(DateTime.parse(s['date'])))
        .toSet()
        .toList()
      ..sort();

    final Map<String, int> result = {};
    int run = 1;
    for (int i = 1; i < weekStarts.length; i++) {
      if (weekStarts[i].difference(weekStarts[i - 1]).inDays == 7) {
        run++;
      } else {
        result[weekStarts[i - 1].toIso8601String()] = run;
        run = 1;
      }
    }
    result[weekStarts.last.toIso8601String()] = run;
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final readDates = sessions
        .map((s) => DateTime.parse(s['date']).toIso8601String().substring(0, 10))
        .toSet();

    final today = DateTime.now();
    final todayStr = today.toIso8601String().substring(0, 10);

    final todayUtc = DateTime.utc(today.year, today.month, today.day);
    final currentWeekStartUtc = DateTime.utc(
        todayUtc.year, todayUtc.month, todayUtc.day - (todayUtc.weekday % 7));

    final streakEnds = _streakEndCounts();

    // The active streak is the most recent run whose last week is within
    // 1 week of today (current or last week). Anything older is historical.
    String? activeStreakKey;
    Set<String> activeStreakWeeks = {};
    if (sessions.isNotEmpty) {
      final lastWeek = sessions
          .map((s) => _weekStart(DateTime.parse(s['date'])))
          .reduce((a, b) => a.isAfter(b) ? a : b);
      if (currentWeekStartUtc.difference(lastWeek).inDays <= 7) {
        activeStreakKey = lastWeek.toIso8601String();
        // Walk back through all weeks in the active streak
        final count = streakEnds[activeStreakKey] ?? 0;
        var w = lastWeek;
        for (int i = 0; i < count; i++) {
          activeStreakWeeks.add(w.toIso8601String());
          w = DateTime.utc(w.year, w.month, w.day - 7);
        }
      }
    }

    // Map every session week → its run's end key, for pill grouping across all runs
    final Map<String, String> weekToRunEnd = {};
    for (final entry in streakEnds.entries) {
      var w = DateTime.parse(entry.key);
      for (int i = 0; i < entry.value; i++) {
        weekToRunEnd[w.toIso8601String()] = entry.key;
        w = DateTime.utc(w.year, w.month, w.day - 7);
      }
    }

    // Align start/end to week boundaries (Sunday-start).
    // Use UTC to avoid DST issues (e.g. US DST ends on the first Sunday of
    // November, making local day arithmetic skip/repeat a date).
    final startUtc = DateTime.utc(start.year, start.month, start.day);
    final endUtc = DateTime.utc(end.year, end.month, end.day);
    DateTime gridStart = startUtc.subtract(Duration(days: startUtc.weekday % 7));
    DateTime gridEnd = endUtc.add(Duration(days: 6 - (endUtc.weekday % 7)));

    List<Widget> rows = [];
    DateTime current = gridStart;

    int totalDays = gridEnd.difference(gridStart).inDays + 1;
    int totalWeeks = (totalDays / 7).ceil();

    for (int week = 0; week < totalWeeks; week++) {
      final weekStartDate = current;
      List<Widget> days = [];

      for (int day = 0; day < 7; day++) {
        final dateStr = current.toIso8601String().substring(0, 10);
        final isRead = readDates.contains(dateStr);
        final isToday = dateStr == todayStr;
        final isFuture = current.isAfter(today);

        bool isOutsideCurrentMonth = isCurrentMonth &&
            (current.month != startUtc.month || current.year != startUtc.year);

        Color textColor;
        if (isOutsideCurrentMonth) {
          textColor = colorScheme.onSurface.withOpacity(0.3);
        } else if (isToday && isRead) {
          textColor = colorScheme.onPrimary;
        } else if (isRead) {
          textColor = colorScheme.primary;
        } else if (isToday && !isRead) {
          textColor = colorScheme.primary;
        } else if (!isFuture) {
          textColor = colorScheme.onSurface.withOpacity(0.6);
        } else {
          textColor = colorScheme.onSurface;
        }

        Color? bgColor;
        BoxBorder? border;
        if (isToday && isRead && !isOutsideCurrentMonth) {
          bgColor = colorScheme.primary;
        } else if (isRead && !isOutsideCurrentMonth) {
          bgColor = colorScheme.primary.withOpacity(0.3);
        } else if (isRead && isOutsideCurrentMonth) {
          bgColor = colorScheme.onSurface.withOpacity(0.06);
        } else if (isToday && !isRead && !isOutsideCurrentMonth) {
          border = Border.all(color: colorScheme.primary, width: 1.5);
        }

        days.add(
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: bgColor ?? Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: border,
              ),
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                DateFormat('d').format(current),
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.normal, color: textColor),
              ),
            ),
          ),
        );

        current = current.add(const Duration(days: 1));
      }

      // Week indicator
      final weekStartUtc = _weekStart(weekStartDate);
      final weekKey = weekStartUtc.toIso8601String();
      final streakCount = streakEnds[weekKey];
      final myRunEnd = weekToRunEnd[weekKey];
      final isInActiveStreak = activeStreakWeeks.contains(weekKey);

      final prevWeekKey = DateTime.utc(weekStartUtc.year, weekStartUtc.month, weekStartUtc.day - 7).toIso8601String();
      final nextWeekKey = DateTime.utc(weekStartUtc.year, weekStartUtc.month, weekStartUtc.day + 7).toIso8601String();
      // Round the pill cap where this run starts or ends
      final pillTopRounded = weekToRunEnd[prevWeekKey] != myRunEnd;
      final pillBottomRounded = weekToRunEnd[nextWeekKey] != myRunEnd;

      Widget indicator;
      if (myRunEnd != null) {
        final dotColor = isInActiveStreak
            ? colorScheme.primary
            : colorScheme.onSurface.withOpacity(0.35);
        final pillColor = isInActiveStreak
            ? colorScheme.primary.withOpacity(0.15)
            : colorScheme.onSurface.withOpacity(0.1);

        Widget inner;
        if (streakCount != null) {
          inner = Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.whatshot, color: dotColor, size: 16),
              Text('$streakCount', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: dotColor)),
            ],
          );
        } else {
          inner = Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
          );
        }

        indicator = SizedBox(
          width: 36,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: Container(
                  width: 26,
                  decoration: BoxDecoration(
                    color: pillColor,
                    borderRadius: BorderRadius.vertical(
                      top: pillTopRounded ? const Radius.circular(13) : Radius.zero,
                      bottom: pillBottomRounded ? const Radius.circular(13) : Radius.zero,
                    ),
                  ),
                ),
              ),
              Center(child: inner),
            ],
          ),
        );
      } else {
        indicator = SizedBox(
          width: 36,
          child: Center(
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: colorScheme.onSurface.withOpacity(0.25),
                  width: 1.5,
                ),
              ),
            ),
          ),
        );
      }

      rows.add(IntrinsicHeight(child: Row(children: [...days, indicator])));
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              children: [
                ...['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((day) => Expanded(
                      child: Center(
                        child: Text(
                          day,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                    )),
                const SizedBox(width: 36),
              ],
            ),
          ),
          ...rows,
        ],
      ),
    );
  }
}
