import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'session_progress_bar.dart';

/// Where an audiobook session started and stopped, as the session form and
/// the post-timer page edit it.
///
/// Recorded as the two times the player showed, in whichever direction the
/// reader's app counts: time left, which runs down, or time played, which
/// runs up. Either way the gap between them is what was listened to, and the
/// time one session stops on is the time the next one starts on — so only
/// the stop time is left to type.
///
/// The times are kept as typed. A session that starts on a larger time than
/// it stops on was logged by time left.
///
/// A bare duration stays available for sittings logged from memory, and is
/// what sessions from before the times were kept hold.
class SessionPosition {
  final fromHours = TextEditingController();
  final fromMinutes = TextEditingController();
  final toHours = TextEditingController();
  final toMinutes = TextEditingController();

  /// Start and stop times, or just how long the session was.
  bool byRange = true;

  /// Time left, counting down, or time played, counting up.
  bool countsDown = true;

  /// Minutes logged for the book in sessions before and after this one, for
  /// placing a session in the book when it has no times to go by.
  int minutesBefore = 0;
  int minutesAfter = 0;

  /// The book's length in minutes, when it has one.
  int? bookMinutes;

  /// True once the start holds something the reader typed, which a later
  /// [suggestStart] must not overwrite.
  bool _fromTouched = false;

  /// Whether the start on screen was filled in from the last session (true),
  /// is the start of the book (false), or was typed (null).
  bool? startIsLastStop;

  /// Whether the start time's fields are open. It is usually filled in
  /// already, so it sits as a line of text until the reader asks to change
  /// it.
  bool editingStart = false;

  /// The start time in the fields, if there is one.
  int? get startTime => _from;

  /// Loads a saved session for editing.
  void load({int? startPosition, int? endPosition}) {
    byRange = startPosition != null && endPosition != null;
    if (startPosition == null || endPosition == null) return;
    countsDown = startPosition >= endPosition;
    _write(fromHours, fromMinutes, startPosition);
    _write(toHours, toMinutes, endPosition);
    _fromTouched = true;
  }

  /// Offers where this session starts, unless the reader already typed their
  /// own: the time the last session stopped on ([lastStop]), or the start of
  /// the book when there is none or it was listened to its end. [countsDown]
  /// is the direction the last session was logged in, and [byDuration]
  /// whether it was logged as a bare duration instead.
  void suggestStart({
    int? lastStop,
    required bool countsDown,
    bool byDuration = false,
  }) {
    if (_fromTouched) return;
    byRange = !byDuration;
    this.countsDown = countsDown;
    final total = bookMinutes ?? 0;
    final finished = lastStop != null &&
        (countsDown ? lastStop == 0 : total > 0 && lastStop >= total);
    if (lastStop != null && !finished) {
      _write(fromHours, fromMinutes, lastStop);
      startIsLastStop = true;
    } else if (!countsDown) {
      _write(fromHours, fromMinutes, 0);
      startIsLastStop = false;
    } else if (total > 0) {
      _write(fromHours, fromMinutes, total);
      startIsLastStop = false;
    } else {
      // Time left at the start of a book of unknown length: can't be guessed.
      fromHours.clear();
      fromMinutes.clear();
      startIsLastStop = null;
    }
  }

  /// Forgets everything typed, for a form that moves to another book.
  void clear() {
    for (final c in [fromHours, fromMinutes, toHours, toMinutes]) {
      c.clear();
    }
    _fromTouched = false;
    startIsLastStop = null;
    editingStart = false;
  }

  void markStartTyped() {
    _fromTouched = true;
    startIsLastStop = null;
  }

  /// Switches between time left and time played. With the book's length
  /// known, what is already in the fields is carried across.
  void flip() {
    final total = bookMinutes ?? 0;
    if (total > 0) {
      final from = _from, to = _to;
      if (from != null) {
        _write(fromHours, fromMinutes, (total - from).clamp(0, total));
      }
      if (to != null) _write(toHours, toMinutes, (total - to).clamp(0, total));
    } else if (!_fromTouched) {
      fromHours.clear();
      fromMinutes.clear();
      startIsLastStop = null;
    }
    countsDown = !countsDown;
  }

  /// Logs by the player's times, in the direction given.
  void useTimes({required bool countsDown}) {
    if (this.countsDown != countsDown) flip();
    byRange = true;
  }

  /// Logs a bare duration. The times stay in their fields, unsaved, in case
  /// the reader switches back.
  void useDuration() => byRange = false;

  static void _write(
      TextEditingController hours, TextEditingController minutes, int value) {
    hours.text = '${value ~/ 60}';
    minutes.text = '${value % 60}';
  }

  static int? _read(TextEditingController hours, TextEditingController minutes) {
    if (hours.text.isEmpty && minutes.text.isEmpty) return null;
    return (int.tryParse(hours.text) ?? 0) * 60 +
        (int.tryParse(minutes.text) ?? 0);
  }

  int? get _from => _read(fromHours, fromMinutes);
  int? get _to => _read(toHours, toMinutes);

  /// True when both times are in and run the wrong way for the direction.
  bool get isBackwards {
    final from = _from, to = _to;
    if (!byRange || from == null || to == null) return false;
    return countsDown ? to > from : to < from;
  }

  /// The times to store, or null where one is missing or they run backwards.
  int? get startPosition =>
      byRange && _to != null && !isBackwards ? _from : null;
  int? get endPosition =>
      byRange && _from != null && !isBackwards ? _to : null;

  /// Minutes of the book this session covered.
  int? get minutes {
    final start = startPosition, end = endPosition;
    return start == null || end == null ? null : (end - start).abs();
  }

  /// Whether this session listens the book to its end: no time left, or as
  /// much played as the book is long.
  bool get reachesEnd {
    final end = endPosition;
    final total = bookMinutes ?? 0;
    if (end == null) return false;
    return countsDown ? end == 0 : total > 0 && end >= total;
  }

  /// Where the session sits in the book, for the bar. Taken from the start
  /// time when there is one, which says exactly how much came before;
  /// otherwise from the minutes other sessions logged. [durationMinutes] is
  /// the session's length where the times don't give one.
  ({int before, int session, int after}) placeInBook(int durationMinutes) {
    final total = bookMinutes ?? 0;
    final from = _from;
    final session = minutes ?? durationMinutes;
    if (byRange && from != null && total > 0) {
      final played = countsDown ? total - from : from;
      return (before: played.clamp(0, total), session: session, after: 0);
    }
    return (before: minutesBefore, session: session, after: minutesAfter);
  }

  void dispose() {
    for (final c in [fromHours, fromMinutes, toHours, toMinutes]) {
      c.dispose();
    }
  }
}

/// `1h 5m`, `45m`, `2h`.
String formatPositionMinutes(int minutes) {
  final h = minutes ~/ 60, m = minutes % 60;
  if (h > 0 && m > 0) return '${h}h ${m}m';
  return h > 0 ? '${h}h' : '${m}m';
}

/// A stored session's two times as one line: `6h 12m → 5h 40m left`, or
/// `5h 40m → 6h 12m` for time played. Null without both.
String? formatPositionRange(int? start, int? end) {
  if (start == null || end == null) return null;
  final range =
      '${formatPositionMinutes(start)} → ${formatPositionMinutes(end)}';
  return start > end ? '$range left' : range;
}

/// Where an audiobook session stopped, as the one thing to type: the time
/// the player shows. The start, already filled in from the last session, is
/// a line of text above it with a way to edit it, and how the session is
/// logged — time left, time played, or a bare duration — is a menu beside
/// the heading. For a book with a length, a bar below places the session in
/// the book.
class SessionPositionField extends StatelessWidget {
  final SessionPosition position;

  /// The session's length as the page has it, for the bar when the times
  /// here don't give one.
  final int durationMinutes;

  /// The page's own fields for the session's length, when it has them to
  /// offer: shown in place of the times when logging a bare duration.
  final Widget? lengthFields;

  /// Called after anything changes, so the page can rebuild and react.
  final VoidCallback onChanged;

  const SessionPositionField({
    super.key,
    required this.position,
    required this.onChanged,
    this.durationMinutes = 0,
    this.lengthFields,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final total = position.bookMinutes ?? 0;
    final place = position.placeInBook(durationMinutes);
    final byRange = position.byRange;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                byRange ? 'Place in the book' : 'Session length',
                style: theme.textTheme.titleSmall,
              ),
            ),
            _buildModeMenu(theme),
          ],
        ),
        const SizedBox(height: 8),
        if (byRange) ...[
          _buildStart(theme, muted),
          Text('Stopped at', style: muted),
          const SizedBox(height: 6),
          _fields(theme, position.toHours, position.toMinutes,
              onChanged: onChanged),
          _buildResult(theme, muted),
        ] else if (lengthFields != null)
          lengthFields!
        else
          Text('Saving how long the session was, not where you stopped.',
              style: muted),
        if (total > 0) ...[
          const SizedBox(height: 16),
          SessionProgressBar(
            total: total,
            before: place.before,
            session: place.session,
            after: place.after,
            beforeLabel: 'Listened before',
            format: formatPositionMinutes,
          ),
        ],
      ],
    );
  }

  /// How the session is logged. Chosen once and then carried from session to
  /// session, so it is a quiet menu and not a control of its own.
  Widget _buildModeMenu(ThemeData theme) {
    const labels = ['Time left', 'Time played', 'Duration'];
    final current = !position.byRange ? 2 : position.countsDown ? 0 : 1;
    final color = theme.colorScheme.primary;
    return PopupMenuButton<int>(
      initialValue: current,
      tooltip: 'How to log this session',
      onSelected: (picked) {
        if (picked == 2) {
          position.useDuration();
        } else {
          position.useTimes(countsDown: picked == 0);
        }
        onChanged();
      },
      itemBuilder: (_) => [
        for (var i = 0; i < labels.length; i++)
          PopupMenuItem(value: i, child: Text(labels[i])),
      ],
      child: Padding(
        padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              labels[current],
              style: theme.textTheme.labelLarge?.copyWith(color: color),
            ),
            Icon(Icons.arrow_drop_down, size: 20, color: color),
          ],
        ),
      ),
    );
  }

  /// The start time: a line of text when it is filled in, its fields when it
  /// is missing, wrong, or being changed.
  Widget _buildStart(ThemeData theme, TextStyle? muted) {
    final start = position.startTime;
    final button = TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      visualDensity: VisualDensity.compact,
    );
    if (start == null || position.editingStart || position.isBackwards) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Started at', style: muted),
            const SizedBox(height: 6),
            _fields(
              theme,
              position.fromHours,
              position.fromMinutes,
              onChanged: () {
                position.markStartTyped();
                onChanged();
              },
            ),
          ],
        ),
      );
    }

    final from = position.countsDown
        ? 'Started at ${formatPositionMinutes(start)} left'
        : 'Started at ${formatPositionMinutes(start)}';
    final why = switch (position.startIsLastStop) {
      true => ' · where you left off',
      false => ' · the beginning',
      null => '',
    };
    return Row(
      children: [
        Expanded(child: Text('$from$why', style: muted)),
        TextButton(
          style: button,
          onPressed: () {
            position.editingStart = true;
            onChanged();
          },
          child: const Text('Edit start'),
        ),
      ],
    );
  }

  /// What the times add up to, or what's wrong with them.
  Widget _buildResult(ThemeData theme, TextStyle? muted) {
    if (position.isBackwards) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          position.countsDown
              ? 'Time left where you stopped is more than where you started'
              : 'Where you stopped is before where you started',
          style: muted?.copyWith(color: theme.colorScheme.error),
        ),
      );
    }
    final minutes = position.minutes;
    if (minutes == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        '${formatPositionMinutes(minutes)} listened',
        style:
            theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _fields(
    ThemeData theme,
    TextEditingController hours,
    TextEditingController minutes, {
    required VoidCallback onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: _field(theme, hours, 'Hours', onChanged: onChanged),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _field(
            theme,
            minutes,
            'Minutes',
            // Overflow belongs in the hours field.
            clampTo: 59,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _field(
    ThemeData theme,
    TextEditingController controller,
    String label, {
    int? clampTo,
    required VoidCallback onChanged,
  }) {
    UnderlineInputBorder border() => UnderlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        );
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(3),
      ],
      onChanged: (value) {
        if (clampTo != null && (int.tryParse(value) ?? 0) > clampTo) {
          controller.text = '$clampTo';
        }
        onChanged();
      },
      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest,
        border: border(),
        enabledBorder: border(),
        focusedBorder: border(),
        contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      ),
    );
  }
}
