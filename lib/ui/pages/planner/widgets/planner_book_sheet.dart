import 'package:flutter/material.dart';
import '/data/models/planner_book.dart';

/// Shows a bottom sheet to pick Want to Read books to add to the planner.
/// [wantToReadBooks] should already be filtered to shelf = Want to Read.
/// [existingBookIds] are excluded from the list (already in planner).
/// [onAdd] is called immediately each time a book is tapped; the sheet stays open.
Future<void> showPlannerBookSheet({
  required BuildContext context,
  required List<Map<String, dynamic>> wantToReadBooks,
  required Set<int> existingBookIds,
  required Future<void> Function(PlannerBook) onAdd,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _PlannerPickerSheet(
      wantToReadBooks: wantToReadBooks,
      existingBookIds: existingBookIds,
      onAdd: onAdd,
    ),
  );
}

class _PlannerPickerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> wantToReadBooks;
  final Set<int> existingBookIds;
  final Future<void> Function(PlannerBook) onAdd;

  const _PlannerPickerSheet({
    required this.wantToReadBooks,
    required this.existingBookIds,
    required this.onAdd,
  });

  @override
  State<_PlannerPickerSheet> createState() => _PlannerPickerSheetState();
}

class _PlannerPickerSheetState extends State<_PlannerPickerSheet> {
  final _searchController = TextEditingController();
  final _addedIds = <int>{};
  late List<Map<String, dynamic>> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = _available;
    _searchController.addListener(_filter);
  }

  List<Map<String, dynamic>> get _available => widget.wantToReadBooks
      .where((b) {
        final id = b['id'] as int;
        return !widget.existingBookIds.contains(id) && !_addedIds.contains(id);
      })
      .toList();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filter() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filtered = _available.where((b) {
        final title = (b['title'] as String? ?? '').toLowerCase();
        final author = (b['author'] as String? ?? '').toLowerCase();
        return title.contains(q) || author.contains(q);
      }).toList();
    });
  }

  Future<void> _pick(Map<String, dynamic> book) async {
    final id = book['id'] as int;
    final entry = PlannerBook(
      bookId: id,
      sortOrder: 0,
      dateAdded: DateTime.now().toIso8601String(),
      bookTitle: book['title'] as String? ?? '',
      bookAuthor: book['author'] as String? ?? '',
    );
    await widget.onAdd(entry);
    if (!mounted) return;
    setState(() {
      _addedIds.add(id);
      _filter();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollController) => Column(
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
                    'Add to Planner',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              autofocus: false,
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
                    child: Text(
                      _available.isEmpty
                          ? 'All Want to Read books are already in your planner'
                          : 'No books found',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.separated(
                    controller: scrollController,
                    itemCount: _filtered.length,
                    separatorBuilder: (context, i) => Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                    itemBuilder: (_, index) {
                      final book = _filtered[index];
                      return ListTile(
                        title: Text(
                          book['title'] as String? ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          'by ${book['author'] as String? ?? ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => _pick(book),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
