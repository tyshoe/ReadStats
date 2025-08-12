import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SessionsCalendar extends StatelessWidget {
  final DateTime start;
  final DateTime end;
  final List<Map<String, dynamic>> sessions;
  final bool isCurrentMonth; // <-- new

  const SessionsCalendar({
    super.key,
    required this.start,
    required this.end,
    required this.sessions,
    this.isCurrentMonth = false, // default false for 30-day mode
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final readDates = sessions
        .map((s) => DateTime.parse(s['date']).toIso8601String().substring(0, 10))
        .toSet();

    // Align start/end to week boundaries
    DateTime gridStart = start.subtract(Duration(days: start.weekday % 7));
    DateTime gridEnd = end.add(Duration(days: 6 - (end.weekday % 7)));

    List<Widget> rows = [];
    DateTime current = gridStart;

    int totalDays = gridEnd.difference(gridStart).inDays + 1;
    int totalWeeks = (totalDays / 7).ceil();

    for (int week = 0; week < totalWeeks; week++) {
      List<Widget> days = [];

      for (int day = 0; day < 7; day++) {
        final dateStr = current.toIso8601String().substring(0, 10);
        final isRead = readDates.contains(dateStr);
        final isToday = current.year == DateTime.now().year &&
            current.month == DateTime.now().month &&
            current.day == DateTime.now().day;
        final isFuture = current.isAfter(DateTime.now());

        bool isOutsideCurrentMonth = isCurrentMonth &&
            (current.month != start.month || current.year != start.year);

        // Styling logic
        Color textColor;
        if (isOutsideCurrentMonth) {
          textColor = colorScheme.onSurface.withOpacity(0.3); // greyed out
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
              child: Column(
                children: [
                  Text(
                    DateFormat('d').format(current),
                    style: TextStyle(
                      fontWeight: FontWeight.normal,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        current = current.add(const Duration(days: 1));
      }
      rows.add(Row(children: days));
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
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((day) {
                return Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          ...rows,
        ],
      ),
    );
  }
}