import 'package:flutter/material.dart';
import 'package:read_stats/ui/widgets/book_cover.dart';
import 'package:read_stats/ui/widgets/book_type.dart';

/// Shows a bottom sheet for picking a book from a list.
///
/// Default (single-select) behaviour: tapping a book pops the sheet and the
/// returned Future resolves to that book map.
///
/// Multi-select behaviour: supply [onSelect]. It is called with the tapped
/// book and should return `true` to remove the book from the visible list and
/// keep the sheet open, or `false` to close the sheet immediately.
///
/// Supply [onRandomPick] to add a "Surprise me" header action. The sheet closes
/// and hands the still-available books to the callback, which owns the pick
/// from there — so its UI takes over the screen instead of stacking on the
/// sheet. The sheet's own Future completes with null in that case.
///
/// Supply [groupOf] to split the list under headings — a label and an icon
/// for each book. A heading is shown wherever the label changes, so [books]
/// should already be sorted by it.
Future<Map<String, dynamic>?> showBookPickerSheet({
  required BuildContext context,
  required List<Map<String, dynamic>> books,
  required String title,
  String emptyMessage = 'No books available',
  String searchEmptyMessage = 'No books found',
  Future<bool> Function(Map<String, dynamic>)? onSelect,
  void Function(List<Map<String, dynamic>>)? onRandomPick,
  BookGroup? Function(Map<String, dynamic>)? groupOf,
}) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _BookPickerSheet(
      books: books,
      title: title,
      emptyMessage: emptyMessage,
      searchEmptyMessage: searchEmptyMessage,
      onSelect: onSelect,
      onRandomPick: onRandomPick,
      groupOf: groupOf,
    ),
  );
}

/// A heading in a grouped picker list.
typedef BookGroup = ({String label, IconData icon});

/// A heading row: its group and how many of the visible books it holds.
typedef _GroupHeader = ({BookGroup group, int count});

class _BookPickerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> books;
  final String title;
  final String emptyMessage;
  final String searchEmptyMessage;
  final Future<bool> Function(Map<String, dynamic>)? onSelect;
  final void Function(List<Map<String, dynamic>>)? onRandomPick;
  final BookGroup? Function(Map<String, dynamic>)? groupOf;

  const _BookPickerSheet({
    required this.books,
    required this.title,
    required this.emptyMessage,
    required this.searchEmptyMessage,
    this.onSelect,
    this.onRandomPick,
    this.groupOf,
  });

  @override
  State<_BookPickerSheet> createState() => _BookPickerSheetState();
}

class _BookPickerSheetState extends State<_BookPickerSheet> {
  final _searchController = TextEditingController();
  late List<Map<String, dynamic>> _available;
  late List<Map<String, dynamic>> _filtered;

  @override
  void initState() {
    super.initState();
    _available = List.of(widget.books);
    _filtered = _available;
    _searchController.addListener(_filter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filter() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _available
          : _available.where((b) {
              final title = (b['title'] as String? ?? '').toLowerCase();
              final author = (b['author'] as String? ?? '').toLowerCase();
              return title.contains(q) || author.contains(q);
            }).toList();
    });
  }

  /// Hands the pool off to the caller and closes the sheet first, so whatever
  /// the caller shows isn't stacked on top of it. The pool is everything still
  /// available, not just what the search box has narrowed to.
  void _onRandomPick() {
    final pool = List.of(_available);
    Navigator.pop(context);
    widget.onRandomPick!(pool);
  }

  Future<void> _onTap(Map<String, dynamic> book) async {
    if (widget.onSelect != null) {
      final removeFromList = await widget.onSelect!(book);
      if (!mounted) return;
      if (removeFromList) {
        setState(() {
          _available.remove(book);
          _filter();
        });
      } else {
        Navigator.pop(context, book);
      }
    } else {
      Navigator.pop(context, book);
    }
  }

  /// The visible books, with a heading before each group when grouping is on.
  List<Object> _rows() {
    final groupOf = widget.groupOf;
    if (groupOf == null) return _filtered;
    final groups = [for (final book in _filtered) groupOf(book)];
    final counts = <String, int>{};
    for (final g in groups) {
      if (g != null) counts[g.label] = (counts[g.label] ?? 0) + 1;
    }
    final rows = <Object>[];
    String? current;
    for (var i = 0; i < _filtered.length; i++) {
      final group = groups[i];
      if (group != null && group.label != current) {
        rows.add((group: group, count: counts[group.label]!));
      }
      current = group?.label;
      rows.add(_filtered[i]);
    }
    return rows;
  }

  /// The shelf's icon and name in the accent colour, so it stands apart from
  /// the book rows without competing with them.
  Widget _groupHeader(ThemeData theme, _GroupHeader header) {
    final accent = theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Row(
        children: [
          Icon(header.group.icon, size: 16, color: accent),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              header.group.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                color: accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${header.count}',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxHeight = MediaQuery.of(context).size.height * 0.75;
    final rows = _rows();

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle, header and search follow the bulk tag sheet, like the
          // app's other sheets.
          // ── Handle bar ──────────────────────────────────────────────────
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

          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title, style: theme.textTheme.titleLarge),
                      Text(
                        '${_available.length} '
                        '${_available.length == 1 ? 'book' : 'books'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // Only offered while there is something left to pick from.
                if (widget.onRandomPick != null && _available.isNotEmpty)
                  FilledButton.tonalIcon(
                    onPressed: _onRandomPick,
                    icon: const Icon(Icons.shuffle, size: 18),
                    label: const Text('Surprise me'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ),
          // ── Search ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search title or author…',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _available.isEmpty
                            ? widget.emptyMessage
                            : widget.searchEmptyMessage,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : Scrollbar(
                    thumbVisibility: true,
                    child: ListView.builder(
                      itemCount: rows.length,
                      itemBuilder: (_, i) {
                        final row = rows[i];
                        if (row is _GroupHeader) return _groupHeader(theme, row);
                        final book = row as Map<String, dynamic>;
                        final coverPath = book['cover_path'] as String?;
                        final author = book['author'] as String?;
                        // Two copies of one title — paperback and audiobook —
                        // are identical rows without this.
                        final (typeIcon, typeLabel) =
                            bookTypeDetails(book['book_type_id'] as int?);
                        final tile = ListTile(
                          leading: coverPath != null
                              ? BookCover(
                                  path: coverPath,
                                  shape: book['cover_shape'] as int?,
                                  width: 36,
                                  borderRadius: 3,
                                )
                              : null,
                          title: Text(
                            book['title'] as String? ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: author?.isNotEmpty == true
                              ? Text(
                                  'by $author',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : null,
                          // One width for every format, so the icons and
                          // labels share a centre line down the list — sized
                          // to its own label, "eBook" sat further right than
                          // the longer names.
                          trailing: SizedBox(
                            width: 60,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  typeIcon,
                                  size: 16,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  typeLabel,
                                  maxLines: 1,
                                  softWrap: false,
                                  overflow: TextOverflow.visible,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          onTap: () => _onTap(book),
                        );
                        // A divider between books, but not under a heading.
                        if (i == 0 || rows[i - 1] is _GroupHeader) return tile;
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Divider(
                              height: 1,
                              indent: 16,
                              endIndent: 16,
                              color: theme.colorScheme.outlineVariant
                                  .withValues(alpha: 0.5),
                            ),
                            tile,
                          ],
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
