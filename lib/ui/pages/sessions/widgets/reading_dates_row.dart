import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '/data/database/database_helper.dart';

/// A book's Started and Finished dates as a session page edits them, and
/// what the "Move to shelf" choice does to them.
///
/// Reading and Unfinished fill an empty start date, Finished fills both.
/// A shelf tap only fills dates that are empty, and moving to another shelf
/// takes back what an earlier tap filled. Dates the book came with, or that
/// the reader picked, are never wiped by a shelf; the × on the field is how a
/// date gets cleared on purpose. Kept that way so every date a book has had
/// can move into its read history when rereads arrive.
///
/// The one exception is Reading, which drops the finish date: a book being
/// read isn't finished. (With rereads, Reading on a finished book becomes
/// starting a new read instead.)
class ReadingDates {
  // As loaded, to tell which dates the save should write.
  DateTime? _loadedStarted;
  DateTime? _loadedFinished;

  // The book's dates plus the reader's own picks — what shelf taps build on.
  DateTime? _ownStarted;
  DateTime? _ownFinished;

  /// What the fields show.
  DateTime? started;
  DateTime? finished;

  void load(DateTime? started, DateTime? finished) {
    _loadedStarted = _ownStarted = this.started = started;
    _loadedFinished = _ownFinished = this.finished = finished;
  }

  /// Applies [shelfId]'s dates on top of the book's own, filling empty ones
  /// with [day].
  void selectShelf(int shelfId, DateTime day) {
    started = _ownStarted;
    finished = _ownFinished;
    if (shelfId == DatabaseHelper.shelfFinished) {
      started ??= day;
      finished ??= day;
    } else if (shelfId == DatabaseHelper.shelfCurrentlyReading) {
      started ??= day;
      finished = null;
    } else if (shelfId == DatabaseHelper.shelfUnfinished) {
      // Logging a session means the book was started, even if it's being
      // abandoned in the same breath.
      started ??= day;
    }
  }

  /// The session moved to [day]: dates a shelf filled in move with it.
  void moveSessionDay(DateTime day) {
    if (_ownStarted == null && started != null) started = day;
    if (_ownFinished == null && finished != null) finished = day;
  }

  void pickStarted(DateTime date) {
    _ownStarted = started = date;
    // A finish date before the new start can't be true any more.
    if (finished != null && finished!.isBefore(date)) {
      _ownFinished = finished = null;
    }
  }

  void pickFinished(DateTime date) => _ownFinished = finished = date;

  void clearStarted() => _ownStarted = started = null;

  void clearFinished() => _ownFinished = finished = null;

  /// The dates that differ from what was loaded, keyed by column, for
  /// `BookRepository.updateReadingDates`. Untouched dates are left out so a
  /// stale copy of the book can't overwrite one this page never changed.
  Map<String, String?> get changes => {
        if (started != _loadedStarted)
          'date_started': started?.toIso8601String(),
        if (finished != _loadedFinished)
          'date_finished': finished?.toIso8601String(),
      };
}

/// A read-only field that opens a picker — dates and times both behave this
/// way, and a TextFormField would need a throwaway controller each build.
class PickerField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  /// Shown in place of [icon] when set, to empty the field.
  final VoidCallback? onClear;

  const PickerField({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (onClear != null)
                // Sized to the icon it replaces, so a date appearing or being
                // cleared doesn't change the field's height.
                SizedBox(
                  width: 20,
                  height: 20,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.clear),
                    color: theme.colorScheme.onSurfaceVariant,
                    onPressed: onClear,
                  ),
                )
              else
                Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// The book's own Started and Finished dates, as both session pages show
/// them under "Move to shelf".
class ReadingDatesRow extends StatelessWidget {
  final DateTime? started;
  final DateTime? finished;
  final VoidCallback onPickStarted;
  final VoidCallback onPickFinished;
  final VoidCallback onClearStarted;
  final VoidCallback onClearFinished;

  const ReadingDatesRow({
    super.key,
    required this.started,
    required this.finished,
    required this.onPickStarted,
    required this.onPickFinished,
    required this.onClearStarted,
    required this.onClearFinished,
  });

  static String _format(DateTime? date) =>
      date == null ? 'Not set' : DateFormat('MMM d, y').format(date);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("This book's reading dates",
            style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: PickerField(
                label: 'Started',
                value: _format(started),
                icon: Icons.calendar_today,
                onTap: onPickStarted,
                onClear: started == null ? null : onClearStarted,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: PickerField(
                label: 'Finished',
                value: _format(finished),
                icon: Icons.event_available,
                onTap: onPickFinished,
                onClear: finished == null ? null : onClearFinished,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Opens a picker for one of a book's reading dates. Bounded by each other and
/// by today: a book can't be finished before it was started, or on a day that
/// hasn't come.
Future<DateTime?> pickReadingDate(
  BuildContext context, {
  required bool isStart,
  required DateTime? started,
  required DateTime? finished,
  required DateTime fallback,
}) {
  final today = DateTime.now();
  return showDatePicker(
    context: context,
    initialDate: (isStart ? started : finished) ?? fallback,
    firstDate: isStart ? DateTime(1900) : started ?? DateTime(1900),
    lastDate: DateTime(today.year, today.month, today.day),
  );
}
