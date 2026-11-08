import 'package:flutter/material.dart';

import '/data/database/database_helper.dart';
import '/data/repositories/series_repository.dart';
import '/data/utils/series_title.dart';

/// A book whose title names a series it isn't linked to yet.
class _Found {
  final Map<String, dynamic> book;
  final SeriesTitle parsed;
  bool selected = true;
  _Found(this.book, this.parsed);
}

/// Books in [books] whose titles name a series ("Legendary (Caraval #2)") and
/// that aren't in a series yet. Empty when there's nothing to offer.
List<Map<String, dynamic>> booksWithSeriesInTitle(
        List<Map<String, dynamic>> books) =>
    [
      for (final b in books)
        if (b['series_id'] == null &&
            SeriesTitle.parse(b['title'] as String? ?? '') != null)
          b,
    ];

/// Reviews series found in titles and links the ones the reader keeps.
/// Nothing changes until they tap Link. Returns how many books were linked.
Future<int?> showSeriesDetectSheet({
  required BuildContext context,
  required List<Map<String, dynamic>> books,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _SeriesDetectSheet(books: books),
  );
}

class _SeriesDetectSheet extends StatefulWidget {
  final List<Map<String, dynamic>> books;
  const _SeriesDetectSheet({required this.books});

  @override
  State<_SeriesDetectSheet> createState() => _SeriesDetectSheetState();
}

class _SeriesDetectSheetState extends State<_SeriesDetectSheet> {
  late final List<_Found> _found;
  bool _stripTitles = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _found = [
      for (final b in booksWithSeriesInTitle(widget.books))
        _Found(b, SeriesTitle.parse(b['title'] as String)!),
    ]..sort((a, b) {
        final bySeries = a.parsed.series
            .toLowerCase()
            .compareTo(b.parsed.series.toLowerCase());
        return bySeries != 0
            ? bySeries
            : a.parsed.position.compareTo(b.parsed.position);
      });
  }

  int get _selectedCount => _found.where((f) => f.selected).length;

  Future<void> _link() async {
    final chosen = _found.where((f) => f.selected).toList();
    if (chosen.isEmpty) {
      Navigator.pop(context, 0);
      return;
    }
    setState(() => _saving = true);
    final repo = SeriesRepository(DatabaseHelper());
    final ids = <String, int>{};
    final updates = <Map<String, dynamic>>[];
    for (final f in chosen) {
      final key = f.parsed.series.toLowerCase();
      final seriesId = ids[key] ??= await repo.idFor(f.parsed.series);
      updates.add({
        'id': f.book['id'],
        if (_stripTitles) 'title': f.parsed.title,
        'series_id': seriesId,
        'series_position': f.parsed.position,
      });
    }
    await repo.link(updates);
    if (mounted) Navigator.pop(context, chosen.length);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final seriesCount =
        _found.map((f) => f.parsed.series.toLowerCase()).toSet().length;
    final muted = theme.colorScheme.onSurfaceVariant;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Handle bar ──────────────────────────────────────────────────────
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: muted.withAlpha(80),
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
                    Text('Link Series', style: theme.textTheme.titleLarge),
                    Text(
                      '${_found.length} ${_found.length == 1 ? 'book' : 'books'}'
                      ' in $seriesCount ${seriesCount == 1 ? 'series' : 'series'}',
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: _saving || _selectedCount == 0 ? null : _link,
                style: FilledButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                ),
                child: Text('Link ($_selectedCount)'),
              ),
            ],
          ),
        ),
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          title: const Text('Remove series from titles'),
          subtitle: Text(
            _stripTitles
                ? '"Legendary (Caraval #2)" becomes "Legendary"'
                : 'Titles stay as they are',
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
          value: _stripTitles,
          onChanged: (v) => setState(() => _stripTitles = v),
        ),
        const Divider(height: 1),

        // ── Books ───────────────────────────────────────────────────────────
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.55,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              for (final f in _found)
                CheckboxListTile(
                  value: f.selected,
                  onChanged: (v) => setState(() => f.selected = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    _stripTitles ? f.parsed.title : f.book['title'] as String,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${f.parsed.series} #${SeriesTitle.formatPosition(f.parsed.position)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: MediaQuery.paddingOf(context).bottom + 8),
      ],
    );
  }
}
