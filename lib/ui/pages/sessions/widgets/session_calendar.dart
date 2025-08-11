import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SessionsCalendar extends StatelessWidget {
  final DateTime start;
  final DateTime end;
  final List<Map<String, dynamic>> sessions;

  const SessionsCalendar({
    super.key,
    required this.start,
    required this.end,
    required this.sessions,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final readDates = sessions
        .map((s) => DateTime.parse(s['date']).toIso8601String().substring(0, 10))
        .toSet();

    List<Widget> rows = [];
    DateTime current = start;

    // Calculate total number of weeks in range
    int totalDays = end.difference(start).inDays + 1;
    int totalWeeks = (totalDays / 7).ceil();

    for (int week = 0; week < totalWeeks; week++) {
      List<Widget> days = [];

      for (int day = 0; day < 7; day++) {
        final dateStr = current.toIso8601String().substring(0, 10);
        final isRead = readDates.contains(dateStr);
        final isToday = current.day == DateTime.now().day &&
            current.month == DateTime.now().month &&
            current.year == DateTime.now().year;
        final isFuture = current.isAfter(DateTime.now());

        // Decide text color adaptively
        Color textColor;
        if (isToday && isRead) {
          textColor = colorScheme.onPrimary; // Today with session
        } else if (isRead) {
          textColor = colorScheme.primary; // Past with session
        } else if (isToday && !isRead) {
          textColor = colorScheme.primary; // Today no session
        } else if (!isFuture) {
          textColor = colorScheme.onSurface.withOpacity(0.6); // Past faded
        } else {
          textColor = colorScheme.onSurface; // Future dark
        }

        days.add(
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isToday && isRead
                    ? colorScheme.primary
                    : isRead
                    ? colorScheme.primary.withOpacity(0.3)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: isToday && !isRead
                    ? Border.all(color: colorScheme.primary, width: 1.5)
                    : null,
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
