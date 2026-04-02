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
  final Set<int> _selectedIds = {};

  bool get _selectionMode => _selectedIds.isNotEmpty;

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
    await showPlannerBookSheet(
      context: context,
      wantToReadBooks: widget.wantToReadBooks,
      existingBookIds: existingIds,
      onAdd: (book) async {
        await _repository.addPlannerBook(book);
        await _loadBooks();
      },
    );
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _clearSelection() => setState(() => _selectedIds.clear());

  Future<void> _deleteSelected() async {
    for (final id in _selectedIds) {
      await _repository.deletePlannerBook(id);
    }
    _selectedIds.clear();
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

    return PopScope(
      canPop: !_selectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _clearSelection();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: theme.scaffoldBackgroundColor,
          leading: _selectionMode
              ? IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: _clearSelection,
                )
              : null,
          title: Text(_selectionMode
              ? '${_selectedIds.length} selected'
              : 'Reading Planner'),
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
                      proxyDecorator: (child, _, __) => child,
                      itemBuilder: (_, index) {
                        final book = _books[index];
                        final isSelected = _selectedIds.contains(book.id);
                        return _PlannerItem(
                          key: ValueKey(book.id),
                          book: book,
                          index: index + 1,
                          selectionMode: _selectionMode,
                          isSelected: isSelected,
                          onLongPress: () => _toggleSelection(book.id!),
                          onTap: _selectionMode
                              ? () => _toggleSelection(book.id!)
                              : null,
                          onDismissed: () async {
                            await _repository.deletePlannerBook(book.id!);
                            await _loadBooks();
                          },
                        );
                      },
                    ),
                  ),
        floatingActionButton: _selectionMode
            ? FloatingActionButton(
                onPressed: _deleteSelected,
                backgroundColor: theme.colorScheme.error,
                child: Icon(Icons.delete, color: theme.colorScheme.onPrimary),
              )
            : FloatingActionButton(
                onPressed: _addBook,
                tooltip: 'Add to Planner',
                child: const Icon(Icons.add),
              ),
      ),
    );
  }
}

class _PlannerItem extends StatefulWidget {
  final PlannerBook book;
  final int index;
  final bool selectionMode;
  final bool isSelected;
  final VoidCallback onLongPress;
  final VoidCallback? onTap;
  final Future<void> Function() onDismissed;

  const _PlannerItem({
    super.key,
    required this.book,
    required this.index,
    required this.selectionMode,
    required this.isSelected,
    required this.onLongPress,
    required this.onTap,
    required this.onDismissed,
  });

  @override
  State<_PlannerItem> createState() => _PlannerItemState();
}

class _PlannerItemState extends State<_PlannerItem> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dismissible(
            key: ValueKey(widget.book.id),
            direction: widget.selectionMode
                ? DismissDirection.none
                : DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.error,
                borderRadius:
                    const BorderRadius.horizontal(right: Radius.circular(12)),
              ),
              child: Icon(
                Icons.playlist_remove_rounded,
                size: 32,
                color: theme.colorScheme.onPrimary,
              ),
            ),
            onDismissed: (_) => widget.onDismissed(),
            child: PlannerBookCard(
              key: ValueKey('card_${widget.book.id}'),
              book: widget.book,
              index: widget.index,
              isSelected: widget.isSelected,
              onTap: widget.onTap,
              onLongPress: widget.onLongPress,
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
        ],
      ),
    );
  }
}
