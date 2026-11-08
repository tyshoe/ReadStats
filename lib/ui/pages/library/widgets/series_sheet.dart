import 'package:flutter/material.dart';

import '/data/database/database_helper.dart';
import '/data/repositories/series_repository.dart';
import '/data/services/cover_service.dart';
import '/data/utils/series_title.dart';
import '/ui/widgets/book_cover.dart';
import '/viewmodels/SettingsViewModel.dart';
import 'next_in_series_sheet.dart';

/// Every book in a series, in order, opened from a book's detail sheet.
///
/// Returns the book the reader tapped (cover path resolved, ready for the
/// detail sheet), or null if they closed it.
///
/// With [settingsViewModel], numbers missing from the series can be tapped to
/// find and add that book; the list refreshes when the reader comes back.
Future<Map<String, dynamic>?> showSeriesSheet({
  required BuildContext context,
  required int seriesId,
  required int currentBookId,
  SettingsViewModel? settingsViewModel,
}) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _SeriesSheet(
      seriesId: seriesId,
      currentBookId: currentBookId,
      settingsViewModel: settingsViewModel,
    ),
  );
}

/// One row: a book, or a numbered gap the reader doesn't have.
class _Entry {
  final Map<String, dynamic>? book;
  final double? position;
  const _Entry(this.book, this.position);
}

class _SeriesSheet extends StatefulWidget {
  final int seriesId;
  final int currentBookId;
  final SettingsViewModel? settingsViewModel;

  const _SeriesSheet({
    required this.seriesId,
    required this.currentBookId,
    this.settingsViewModel,
  });

  @override
  State<_SeriesSheet> createState() => _SeriesSheetState();
}

class _SeriesSheetState extends State<_SeriesSheet> {
  List<Map<String, dynamic>>? _books;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await SeriesRepository(DatabaseHelper()).booksIn(widget.seriesId);
    final books = <Map<String, dynamic>>[];
    for (final row in rows) {
      final book = Map<String, dynamic>.from(row);
      final cover = book['cover_path'] as String?;
      if (cover != null && cover.isNotEmpty) {
        book['cover_path'] = await CoverService.resolveFullPath(cover);
      }
      books.add(book);
    }
    if (mounted) setState(() => _books = books);
  }

  /// Books in order, with whole-number gaps filled in up to the highest
  /// number — "#2 isn't in your library" is worth knowing.
  List<_Entry> _entries(List<Map<String, dynamic>> books) {
    final numbered = <double, Map<String, dynamic>>{};
    final unnumbered = <Map<String, dynamic>>[];
    for (final b in books) {
      final p = (b['series_position'] as num?)?.toDouble();
      if (p == null || numbered.containsKey(p)) {
        unnumbered.add(b);
      } else {
        numbered[p] = b;
      }
    }

    final entries = <_Entry>[];
    if (numbered.isNotEmpty) {
      final max = numbered.keys.reduce((a, b) => a > b ? a : b).floor();
      final positions = {
        ...numbered.keys,
        for (var i = 1; i <= max; i++) i.toDouble(),
      }.toList()
        ..sort();
      for (final p in positions) {
        entries.add(_Entry(numbered[p], p));
      }
    }
    entries.addAll(unnumbered.map((b) => _Entry(b, null)));
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final books = _books;
    final name = books != null && books.isNotEmpty
        ? books.first['series_name'] as String? ?? 'Series'
        : 'Series';
    final finished = books
            ?.where((b) => b['shelf_id'] == DatabaseHelper.shelfFinished)
            .length ??
        0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Handle bar ──────────────────────────────────────────────────────
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurfaceVariant.withAlpha(80),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),

        // ── Header ──────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: theme.textTheme.titleLarge),
                    if (books != null)
                      Text(
                        '${books.length} ${books.length == 1 ? 'book' : 'books'}'
                        ' · $finished read',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Divider(height: 1),

        // ── Books ───────────────────────────────────────────────────────────
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.6,
          ),
          child: books == null
              ? const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              : ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    for (final e in _entries(books)) _buildRow(theme, e),
                  ],
                ),
        ),
        SizedBox(height: MediaQuery.paddingOf(context).bottom + 8),
      ],
    );
  }

  Widget _buildRow(ThemeData theme, _Entry e) {
    final muted = theme.colorScheme.onSurfaceVariant;
    final number = e.position == null
        ? '–'
        : SeriesTitle.formatPosition(e.position!);
    final book = e.book;

    if (book == null) {
      final settings = widget.settingsViewModel;
      final books = _books ?? const [];
      return ListTile(
        leading: _NumberBadge(number: number, faded: true),
        title: Text(
          'Not in your library',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: muted,
            fontStyle: FontStyle.italic,
          ),
        ),
        trailing: settings == null || e.position == null
            ? null
            : Icon(Icons.add_circle, color: theme.colorScheme.primary),
        onTap: settings == null || e.position == null || books.isEmpty
            ? null
            : () async {
                await addMissingSeriesBook(
                  context: context,
                  settingsViewModel: settings,
                  seriesName: books.first['series_name'] as String,
                  position: e.position!,
                  author: books.first['author'] as String?,
                );
                // Back from adding — show the book if it landed here.
                if (mounted) _load();
              },
      );
    }

    final isCurrent = book['id'] == widget.currentBookId;
    final cover = book['cover_path'] as String?;

    return Material(
      color: isCurrent
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.45)
          : Colors.transparent,
      child: ListTile(
        onTap: isCurrent ? null : () => Navigator.pop(context, book),
        leading: _NumberBadge(number: number),
        title: Text(
          book['title'] as String? ?? '',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          isCurrent ? 'Viewing now' : _shelfLabel(book['shelf_id'] as int?),
          style: theme.textTheme.bodySmall?.copyWith(color: muted),
        ),
        trailing: cover != null && cover.isNotEmpty
            ? BookCover(
                path: cover,
                shape: book['cover_shape'] as int?,
                width: 32,
                borderRadius: 4,
              )
            : null,
      ),
    );
  }

  static String _shelfLabel(int? shelfId) => switch (shelfId) {
        DatabaseHelper.shelfFinished => 'Finished',
        DatabaseHelper.shelfCurrentlyReading => 'Reading',
        DatabaseHelper.shelfUnfinished => 'Set aside',
        _ => 'Want to read',
      };
}

class _NumberBadge extends StatelessWidget {
  final String number;
  final bool faded;

  const _NumberBadge({required this.number, this.faded = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: faded
            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
            : theme.colorScheme.secondaryContainer,
        shape: BoxShape.circle,
      ),
      child: Text(
        '#$number',
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: faded
              ? theme.colorScheme.onSurfaceVariant
              : theme.colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}
