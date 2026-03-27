import 'package:flutter/material.dart';
import '/data/models/planner_book.dart';

/// Shows a bottom sheet to pick a Want to Read book to add to the planner.
/// [wantToReadBooks] should already be filtered to shelf = Want to Read.
/// [existingBookIds] are excluded from the list (already in planner).
/// Returns the new [PlannerBook] to add, or null if cancelled.
Future<PlannerBook?> showPlannerBookSheet({
  required BuildContext context,
  required List<Map<String, dynamic>> wantToReadBooks,
  required Set<int> existingBookIds,
}) {
  return showModalBottomSheet<PlannerBook>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _PlannerPickerSheet(
      wantToReadBooks: wantToReadBooks,
      existingBookIds: existingBookIds,
    ),
  );
}

class _PlannerPickerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> wantToReadBooks;
  final Set<int> existingBookIds;

  const _PlannerPickerSheet({
    required this.wantToReadBooks,
    required this.existingBookIds,
  });

  @override
  State<_PlannerPickerSheet> createState() => _PlannerPickerSheetState();
}

class _PlannerPickerSheetState extends State<_PlannerPickerSheet> {
  final _searchController = TextEditingController();
  late List<Map<String, dynamic>> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = _available;
    _searchController.addListener(_filter);
  }

  List<Map<String, dynamic>> get _available => widget.wantToReadBooks
      .where((b) => !widget.existingBookIds.contains(b['id'] as int))
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

  void _pick(Map<String, dynamic> book) {
    final entry = PlannerBook(
      bookId: book['id'] as int,
      sortOrder: 0,
      dateAdded: DateTime.now().toIso8601String(),
      bookTitle: book['title'] as String? ?? '',
      bookAuthor: book['author'] as String? ?? '',
    );
    Navigator.of(context).pop(entry);
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
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                  visualDensity: VisualDensity.compact,
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
                : ListView.builder(
                    controller: scrollController,
                    itemCount: _filtered.length,
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
