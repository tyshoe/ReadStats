import 'package:flutter/material.dart';
import '/ui/widgets/book_cover.dart';
import '/ui/widgets/book_type.dart';

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
Future<Map<String, dynamic>?> showBookPickerSheet({
  required BuildContext context,
  required List<Map<String, dynamic>> books,
  required String title,
  String emptyMessage = 'No books available',
  String searchEmptyMessage = 'No books found',
  Future<bool> Function(Map<String, dynamic>)? onSelect,
  void Function(List<Map<String, dynamic>>)? onRandomPick,
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
    ),
  );
}

class _BookPickerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> books;
  final String title;
  final String emptyMessage;
  final String searchEmptyMessage;
  final Future<bool> Function(Map<String, dynamic>)? onSelect;
  final void Function(List<Map<String, dynamic>>)? onRandomPick;

  const _BookPickerSheet({
    required this.books,
    required this.title,
    required this.emptyMessage,
    required this.searchEmptyMessage,
    this.onSelect,
    this.onRandomPick,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxHeight = MediaQuery.of(context).size.height * 0.75;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search title or author...',
                prefixIcon: Icon(Icons.search_rounded),
                border: OutlineInputBorder(),
                isDense: true,
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
                    child: ListView.separated(
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                      itemBuilder: (_, i) {
                        final book = _filtered[i];
                        final coverPath = book['cover_path'] as String?;
                        final author = book['author'] as String?;
                        // Two copies of one title — paperback and audiobook —
                        // are identical rows without this.
                        final (typeIcon, typeLabel) =
                            bookTypeDetails(book['book_type_id'] as int?);
                        return ListTile(
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
                          trailing: Column(
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
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          onTap: () => _onTap(book),
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
