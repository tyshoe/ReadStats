import 'package:flutter/material.dart';
import '/data/models/planner_book.dart';
import '/data/repositories/planner_repository.dart';
import '/data/database/database_helper.dart';
import 'widgets/planner_book_card.dart';
import 'widgets/planner_book_sheet.dart';

class PlannerPage extends StatefulWidget {
  final List<Map<String, dynamic>> wantToReadBooks;

  const PlannerPage({super.key, this.wantToReadBooks = const []});

  @override
  State<PlannerPage> createState() => _PlannerPageState();
}

class _PlannerPageState extends State<PlannerPage> {
  late final PlannerRepository _repository;
  List<PlannerBook> _books = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _repository = PlannerRepository(DatabaseHelper());
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    setState(() => _isLoading = true);
    final books = await _repository.getPlannerBooks();
    if (mounted) {
      setState(() {
        _books = books;
        _isLoading = false;
      });
    }
  }

  Future<void> _addBook() async {
    final existingIds = _books.map((b) => b.bookId).toSet();
    final result = await showPlannerBookSheet(
      context: context,
      wantToReadBooks: widget.wantToReadBooks,
      existingBookIds: existingIds,
    );
    if (result == null) return;
    await _repository.addPlannerBook(result);
    await _loadBooks();
  }

  Future<bool> _confirmDelete(PlannerBook book) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove from Planner?'),
        content: Text('Remove "${book.bookTitle}" from your reading planner?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _deleteBook(PlannerBook book) async {
    final confirm = await _confirmDelete(book);
    if (!confirm) return;
    await _repository.deletePlannerBook(book.id!);
    await _loadBooks();
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final book = _books.removeAt(oldIndex);
      _books.insert(newIndex, book);
    });
    _repository.reorderBooks(_books);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reading Planner'),
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _books.isEmpty
              ? _EmptyState(onAdd: _addBook)
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.only(top: 4, bottom: 80),
                    itemCount: _books.length,
                    onReorder: _onReorder,
                    buildDefaultDragHandles: false,
                    itemBuilder: (_, index) {
                      final book = _books[index];
                      return Dismissible(
                        key: ValueKey(book.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.delete_outline,
                              color: theme.colorScheme.onErrorContainer),
                        ),
                        confirmDismiss: (_) => _confirmDelete(book),
                        onDismissed: (_) {},
                        child: PlannerBookCard(
                          key: ValueKey('card_${book.id}'),
                          book: book,
                          index: index + 1,
                          onDelete: () => _deleteBook(book),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addBook,
        tooltip: 'Add to Planner',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.menu_book_rounded,
            size: 64,
            color: theme.colorScheme.outlineVariant,
          ),
          const SizedBox(height: 16),
          Text('Your planner is empty', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Add books from your Want to Read shelf\nto plan your reading order',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add your first book'),
          ),
        ],
      ),
    );
  }
}
