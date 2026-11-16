import 'package:flutter/material.dart';

import '/data/database/database_helper.dart';
import '/data/repositories/session_repository.dart';

/// Where the reader is in a book: the page they're on, and how much of the
/// book's length they have read, with a thin bar.
///
/// The two are separate figures. The page is where the last session stopped
/// — see [SessionRepository.getLastPage] — while progress is pages read
/// against the book's page count, which is its length and not the number on
/// its last page. Both follow new sessions as they are saved. Draws nothing
/// for a book with no page count, or one not started.
class BookPageProgress extends StatefulWidget {
  final int bookId;
  final int? pageCount;
  final SessionRepository sessionRepository;
  final Color color;

  const BookPageProgress({
    super.key,
    required this.bookId,
    required this.pageCount,
    required this.sessionRepository,
    required this.color,
  });

  @override
  State<BookPageProgress> createState() => _BookPageProgressState();
}

class _BookPageProgressState extends State<BookPageProgress> {
  int? _page;
  int _pagesRead = 0;

  @override
  void initState() {
    super.initState();
    DatabaseHelper.sessionsChanged.addListener(_load);
    _load();
  }

  @override
  void didUpdateWidget(covariant BookPageProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bookId != widget.bookId) {
      _page = null;
      _pagesRead = 0;
      _load();
    }
  }

  @override
  void dispose() {
    DatabaseHelper.sessionsChanged.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final bookId = widget.bookId;
    // Far enough ahead to take in a session saved this instant.
    final ahead = DateTime.now().add(const Duration(days: 1));
    final last = await widget.sessionRepository.getLastPage(bookId, ahead);
    final around = await widget.sessionRepository.getPagesAround(bookId, ahead);
    if (!mounted || bookId != widget.bookId) return;
    setState(() {
      _page = last?.page;
      _pagesRead = around.pagesBefore;
    });
  }

  @override
  Widget build(BuildContext context) {
    final page = _page ?? 0;
    final total = widget.pageCount ?? 0;
    if (_pagesRead <= 0 || total <= 0) return const SizedBox.shrink();

    final fraction = (_pagesRead / total).clamp(0.0, 1.0);
    return _ProgressLine(
      fraction: fraction,
      color: widget.color,
      place: page > 0 ? 'On page $page' : '$_pagesRead pages read',
      amount: '$_pagesRead of $total pages · ${(fraction * 100).round()}%',
    );
  }
}

/// [BookPageProgress] for an audiobook: the time the player is on, and how
/// much of the book's length has been listened to, with the same thin bar.
///
/// The place is worked out as the session form does — the time the last
/// session with times stopped on, moved on by what later sessions logged as
/// a bare duration; see [SessionRepository.getLastPosition] — and shown the
/// way the reader logs it, as time left or time played. Draws nothing for a
/// book with no length, or one not started.
class BookAudioProgress extends StatefulWidget {
  final int bookId;
  final int? bookMinutes;
  final SessionRepository sessionRepository;
  final Color color;

  const BookAudioProgress({
    super.key,
    required this.bookId,
    required this.bookMinutes,
    required this.sessionRepository,
    required this.color,
  });

  @override
  State<BookAudioProgress> createState() => _BookAudioProgressState();
}

class _BookAudioProgressState extends State<BookAudioProgress> {
  int? _lastStop;
  int _minutesSince = 0;
  bool _countsDown = true;

  @override
  void initState() {
    super.initState();
    DatabaseHelper.sessionsChanged.addListener(_load);
    _load();
  }

  @override
  void didUpdateWidget(covariant BookAudioProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bookId != widget.bookId) {
      _lastStop = null;
      _minutesSince = 0;
      _load();
    }
  }

  @override
  void dispose() {
    DatabaseHelper.sessionsChanged.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final bookId = widget.bookId;
    // Far enough ahead to take in a session saved this instant.
    final ahead = DateTime.now().add(const Duration(days: 1));
    final last = await widget.sessionRepository.getLastPosition(bookId, ahead);
    if (!mounted || bookId != widget.bookId) return;
    setState(() {
      _lastStop = last.lastStop;
      _minutesSince = last.minutesSince;
      _countsDown = last.countsDown;
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.bookMinutes ?? 0;
    if (total <= 0) return const SizedBox.shrink();

    final lastStop = _lastStop;
    final int played;
    if (lastStop == null) {
      played = _minutesSince;
    } else if (_countsDown) {
      played = total - (lastStop - _minutesSince);
    } else {
      played = lastStop + _minutesSince;
    }
    final listened = played.clamp(0, total);
    if (listened <= 0) return const SizedBox.shrink();

    final fraction = listened / total;
    return _ProgressLine(
      fraction: fraction,
      color: widget.color,
      place: _countsDown
          ? '${_formatMinutes(total - listened)} left'
          : 'At ${_formatMinutes(listened)}',
      amount: '${_formatMinutes(listened)} of ${_formatMinutes(total)}'
          ' · ${(fraction * 100).round()}%',
    );
  }
}

/// `1h 5m`, `45m`, `2h`.
String _formatMinutes(int minutes) {
  final h = minutes ~/ 60, m = minutes % 60;
  if (h > 0 && m > 0) return '${h}h ${m}m';
  return h > 0 ? '${h}h' : '${m}m';
}

/// The bar, with where the reader is under its left end and how much of the
/// book that comes to under its right.
class _ProgressLine extends StatelessWidget {
  final double fraction;
  final Color color;
  final String place;
  final String amount;

  const _ProgressLine({
    required this.fraction,
    required this.color,
    required this.place,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurface.withAlpha(160),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 10, left: 2, right: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 5,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Expanded(child: Text(place, style: style)),
              Text(amount, style: style),
            ],
          ),
        ],
      ),
    );
  }
}
