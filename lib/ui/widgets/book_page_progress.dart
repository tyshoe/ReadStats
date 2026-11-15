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
    final theme = Theme.of(context);
    final page = _page ?? 0;
    final total = widget.pageCount ?? 0;
    if (_pagesRead <= 0 || total <= 0) return const SizedBox.shrink();

    final fraction = (_pagesRead / total).clamp(0.0, 1.0);
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
              valueColor: AlwaysStoppedAnimation<Color>(widget.color),
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Expanded(
                child: Text(
                  page > 0 ? 'On page $page' : '$_pagesRead pages read',
                  style: style,
                ),
              ),
              Text(
                '$_pagesRead of $total pages · ${(fraction * 100).round()}%',
                style: style,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
