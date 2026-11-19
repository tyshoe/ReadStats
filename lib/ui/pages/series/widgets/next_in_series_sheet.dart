import 'package:flutter/material.dart';
import 'package:read_stats/data/models/shelf.dart';
import 'package:read_stats/data/repositories/book_repository.dart';
import 'package:read_stats/data/repositories/planner_repository.dart';
import 'package:read_stats/data/repositories/series_repository.dart';
import 'package:read_stats/data/services/cover_service.dart';
import 'package:read_stats/data/utils/series_title.dart';
import 'package:read_stats/ui/pages/book_search/book_search_sheet.dart';
import 'package:read_stats/ui/pages/sessions/widgets/rate_book_dialog.dart';
import 'package:read_stats/ui/settings_view_model.dart';
import 'package:read_stats/ui/widgets/app_snackbar.dart';
import 'package:read_stats/ui/widgets/book_cover.dart';

/// Everything that follows finishing a book: rate it, then — if it's part of
/// a series — see what comes next. Every "finished" path calls this, so the
/// series prompt can't be skipped by finishing from a different screen.
Future<void> afterFinishingBook({
  required BuildContext context,
  required Map<String, dynamic> book,
  required BookRepository bookRepository,
  required SettingsViewModel settingsViewModel,
}) async {
  await showRatingDialogForBook(
    context: context,
    book: book,
    bookRepository: bookRepository,
    settingsViewModel: settingsViewModel,
  );
  if (!context.mounted) return;
  await showNextInSeries(
    context: context,
    finishedBookId: book['id'] as int,
    bookRepository: bookRepository,
    settingsViewModel: settingsViewModel,
  );
}

/// Opens book search for a number missing from a series, with the series and
/// number already filled into whatever book the reader picks.
Future<void> addMissingSeriesBook({
  required BuildContext context,
  required SettingsViewModel settingsViewModel,
  required String seriesName,
  required double position,
  String? author,
  /// The book's title when it's known — a placeholder's — searched for in
  /// place of the series name.
  String? title,
}) {
  final what = title?.trim().isNotEmpty == true ? title!.trim() : seriesName;
  return Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => BookSearchSheet(
      settingsViewModel: settingsViewModel,
      // The app reloads on any book write, so nothing to refresh by hand.
      onSave: (_) {},
      initialQuery: [what, ?author].join(' '),
      initialSeriesName: seriesName,
      initialSeriesPosition: position,
    ),
  ));
}

/// What to offer after a series book is finished.
sealed class _Suggestion {}

/// The next unread book the reader already owns.
class _NextBook extends _Suggestion {
  final Map<String, dynamic> book;
  _NextBook(this.book);
}

/// The next number isn't in the library.
class _MissingNumber extends _Suggestion {
  final double position;
  _MissingNumber(this.position);
}

/// Every book they have in the series is read.
class _AllRead extends _Suggestion {
  final int count;
  _AllRead(this.count);
}

bool _isUnread(Map<String, dynamic> b) {
  final shelf = b['shelf_id'] as int?;
  return shelf == Shelf.wantToRead ||
      shelf == Shelf.currentlyReading;
}

double? _position(Map<String, dynamic> b) =>
    (b['series_position'] as num?)?.toDouble();

/// Walks forward from the finished book: a missing whole number before the
/// next owned book is the gap to fill; otherwise the first unread book ahead.
/// Read out of order? Falls back to any unread book in the series.
_Suggestion? _suggest(Map<String, dynamic> finished, List<Map<String, dynamic>> books) {
  final others = books.where((b) => b['id'] != finished['id']).toList();
  final from = _position(finished);

  if (from != null) {
    var cursor = from;
    final ahead = others.where((b) => (_position(b) ?? -1) > from).toList()
      ..sort((a, b) => _position(a)!.compareTo(_position(b)!));
    for (final b in ahead) {
      final p = _position(b)!;
      // A whole number skipped between where we are and this book.
      if (p >= cursor.floor() + 2) return _MissingNumber(cursor.floor() + 1.0);
      if (_isUnread(b)) return _NextBook(b);
      cursor = p;
    }
  }

  final unread = others.where(_isUnread).toList();
  if (unread.isNotEmpty) return _NextBook(unread.first);

  final allRead = books.every((b) => b['shelf_id'] == Shelf.finished);
  if (allRead && books.length > 1) return _AllRead(books.length);
  return null;
}

/// Shows what comes next after [finishedBookId], if it's in a series. Quiet
/// for standalones and for series with nothing useful to suggest.
Future<void> showNextInSeries({
  required BuildContext context,
  required int finishedBookId,
  required BookRepository bookRepository,
  required SettingsViewModel settingsViewModel,
}) async {
  final planner = PlannerRepository();
  final finished = await bookRepository.getBookById(finishedBookId);
  final seriesId = finished?['series_id'] as int?;
  if (finished == null || seriesId == null) return;

  final books = await SeriesRepository().booksIn(seriesId);
  final suggestion = _suggest(finished, books);
  if (suggestion == null) return;

  Map<String, dynamic>? next;
  var inPlanner = false;
  if (suggestion is _NextBook) {
    next = Map<String, dynamic>.from(suggestion.book);
    final cover = next['cover_path'] as String?;
    if (cover != null && cover.isNotEmpty) {
      next['cover_path'] = await CoverService.resolveFullPath(cover);
    }
    inPlanner = await planner.isInPlanner(next['id'] as int);
  }
  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _NextInSeriesSheet(
      hostContext: context,
      finished: finished,
      suggestion: suggestion,
      next: next,
      inPlanner: inPlanner,
      bookRepository: bookRepository,
      settingsViewModel: settingsViewModel,
    ),
  );
}

class _NextInSeriesSheet extends StatelessWidget {
  /// The screen under the sheet — where book search opens once it closes.
  final BuildContext hostContext;
  final Map<String, dynamic> finished;
  final _Suggestion suggestion;
  final Map<String, dynamic>? next;
  final bool inPlanner;
  final BookRepository bookRepository;
  final SettingsViewModel settingsViewModel;

  const _NextInSeriesSheet({
    required this.hostContext,
    required this.finished,
    required this.suggestion,
    required this.next,
    required this.inPlanner,
    required this.bookRepository,
    required this.settingsViewModel,
  });

  String get _series => finished['series_name'] as String? ?? 'this series';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final from = _position(finished);

    final (title, subtitle) = switch (suggestion) {
      _NextBook() => (
          'Next in $_series',
          from == null
              ? 'Keep the series going'
              : 'You finished #${SeriesTitle.formatPosition(from)}',
        ),
      _MissingNumber(:final position) => (
          'Next in $_series',
          '#${SeriesTitle.formatPosition(position)} isn\'t in your library yet',
        ),
      _AllRead(:final count) => (
          'Series caught up',
          'You\'ve read all $count $_series books you have',
        ),
    };

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Handle bar ────────────────────────────────────────────────────
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: muted.withAlpha(80),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Header ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleLarge),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // ── Body ──────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: switch (suggestion) {
              _NextBook() => _buildNextBook(context, theme),
              _MissingNumber(:final position) =>
                _buildMissing(context, theme, position),
              _AllRead() => _buildAllRead(context, theme),
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNextBook(BuildContext context, ThemeData theme) {
    final book = next!;
    final muted = theme.colorScheme.onSurfaceVariant;
    final cover = book['cover_path'] as String?;
    final position = _position(book);
    final shelf = book['shelf_id'] as int?;
    final reading = shelf == Shelf.currentlyReading;

    Future<void> startReading() async {
      await bookRepository.updateBookShelf(
          book['id'] as int, Shelf.currentlyReading);
      if (!context.mounted) return;
      Navigator.pop(context);
      AppSnackbar.show('${book['title']} is on Currently Reading');
    }

    Future<void> addToPlanner() async {
      await PlannerRepository()
          .addBookById(book['id'] as int);
      if (!context.mounted) return;
      Navigator.pop(context);
      AppSnackbar.show('${book['title']} added to your planner');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (cover != null && cover.isNotEmpty) ...[
              BookCover(
                path: cover,
                shape: book['cover_shape'] as int?,
                width: 56,
                borderRadius: 6,
              ),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (position != null)
                    Text(
                      '#${SeriesTitle.formatPosition(position)}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  Text(
                    book['title'] as String? ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    book['author'] as String? ?? '',
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                  if (reading) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Already on Currently Reading',
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (reading)
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          )
        else ...[
          FilledButton(
            onPressed: startReading,
            child: const Text('Start reading'),
          ),
          if (!inPlanner) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: addToPlanner,
              child: const Text('Add to planner'),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildMissing(BuildContext context, ThemeData theme, double position) {
    final number = SeriesTitle.formatPosition(position);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.collections_bookmark,
                size: 32, color: theme.colorScheme.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Find #$number and it joins $_series at the right place.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () async {
            Navigator.pop(context);
            if (!hostContext.mounted) return;
            await addMissingSeriesBook(
              context: hostContext,
              settingsViewModel: settingsViewModel,
              seriesName: _series,
              position: position,
              author: finished['author'] as String?,
            );
          },
          child: Text('Find #$number'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Not now'),
        ),
      ],
    );
  }

  Widget _buildAllRead(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.verified, size: 32, color: theme.colorScheme.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'If more come out, add them to $_series and they\'ll show up here.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
