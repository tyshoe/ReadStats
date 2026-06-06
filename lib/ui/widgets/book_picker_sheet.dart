import 'dart:io';
import 'package:flutter/material.dart';

/// Shows a bottom sheet for picking a book from a list.
///
/// Default (single-select) behaviour: tapping a book pops the sheet and the
/// returned Future resolves to that book map.
///
/// Multi-select behaviour: supply [onSelect]. It is called with the tapped
/// book and should return `true` to remove the book from the visible list and
/// keep the sheet open, or `false` to close the sheet immediately.
Future<Map<String, dynamic>?> showBookPickerSheet({
  required BuildContext context,
  required List<Map<String, dynamic>> books,
  required String title,
  String emptyMessage = 'No books available',
  String searchEmptyMessage = 'No books found',
  Future<bool> Function(Map<String, dynamic>)? onSelect,
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
    ),
  );
}

class _BookPickerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> books;
  final String title;
  final String emptyMessage;
  final String searchEmptyMessage;
  final Future<bool> Function(Map<String, dynamic>)? onSelect;

  const _BookPickerSheet({
    required this.books,
    required this.title,
    required this.emptyMessage,
    required this.searchEmptyMessage,
    this.onSelect,
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
            child: Text(
              widget.title,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
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
          const SizedBox(height: 8),
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
                        return ListTile(
                          leading: coverPath != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: Image.file(
                                    File(coverPath),
                                    width: 36,
                                    height: 50,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const SizedBox(width: 36),
                                  ),
                                )
                              : null,
                          title: Text(
                            book['title'] as String? ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: (book['author'] as String?)?.isNotEmpty == true
                              ? Text(
                                  'by ${book['author']}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : null,
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
