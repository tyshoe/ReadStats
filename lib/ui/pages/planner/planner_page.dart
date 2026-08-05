import 'package:flutter/material.dart';
import '/data/models/planner_book.dart';
import '/data/repositories/planner_repository.dart';
import '/data/database/database_helper.dart';
import '/ui/pages/library/widgets/random_book_picker.dart';
import '/ui/widgets/app_snackbar.dart';
import 'widgets/planner_book_card.dart';
import 'widgets/planner_book_sheet.dart';

class PlannerPage extends StatefulWidget {
  const PlannerPage({super.key});

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

  // Refreshes the list without toggling [_isLoading], so the full-screen
  // spinner only ever shows on the initial load — not on every add/delete.
  Future<void> _loadBooks() async {
    final books = await _repository.getPlannerBooks();
    if (!mounted) return;
    setState(() {
      _books = books;
      _isLoading = false;
    });
  }

  Future<void> _addBook() async {
    final wantToReadBooks = await _repository.getWantToReadBooks();
    if (!mounted) return;
    final existingIds = _books.map((b) => b.bookId).toSet();
    await showPlannerBookSheet(
      context: context,
      wantToReadBooks: wantToReadBooks,
      existingBookIds: existingIds,
      onAdd: (book) async {
        await _repository.addPlannerBook(book);
        await _loadBooks();
      },
      onRandomPick: _rollRandomBook,
    );
  }

  /// Rolls the reel over the books the sheet had left, once the sheet itself
  /// has closed — so the reel plays over the planner and lands the new book
  /// straight into the visible list. Shuffling past or closing adds nothing.
  Future<void> _rollRandomBook(List<Map<String, dynamic>> pool) async {
    final count = pool.length;
    final picked = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (_) => RandomBookPicker(
        books: pool,
        scopeLabel: 'Want to Read · $count ${count == 1 ? 'book' : 'books'}',
        confirmLabel: 'Add to planner',
        footerNote: 'Shuffle again to skip this pick, or close to add nothing.',
      ),
    );
    if (picked == null || !mounted) return;

    await _repository.addPlannerBook(plannerEntryFor(picked));
    await _loadBooks();
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
    final ids = Set<int>.from(_selectedIds);
    setState(() {
      _books.removeWhere((b) => ids.contains(b.id));
      _selectedIds.clear();
    });
    for (final id in ids) {
      await _repository.deletePlannerBook(id);
    }
  }

  Future<void> _deleteBook(PlannerBook book) async {
    // Remove from the list synchronously so a swipe-dismissed item never
    // lingers in the tree (Dismissible asserts on this), then persist.
    setState(() => _books.removeWhere((b) => b.id == book.id));
    await _repository.deletePlannerBook(book.id!);
  }

  /// Randomises the reading order, with an undo — a shuffle throws away a
  /// hand-arranged list, so it can't be a one-way door.
  Future<void> _shuffleBooks() async {
    if (_books.length < 2) return;

    final previous = List<PlannerBook>.from(_books);
    final shuffled = List<PlannerBook>.from(_books);
    // A two-book list comes back unchanged half the time, which reads as a
    // dead button — keep rolling until the order actually moves.
    do {
      shuffled.shuffle();
    } while (_isSameOrder(shuffled, previous));

    setState(() => _books = shuffled);
    await _repository.reorderBooks(_books);

    AppSnackbar.show(
      'Planner shuffled',
      actionLabel: 'Undo',
      onAction: () => _restoreOrder(previous),
    );
  }

  bool _isSameOrder(List<PlannerBook> a, List<PlannerBook> b) {
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  Future<void> _restoreOrder(List<PlannerBook> order) async {
    if (!mounted) return;
    // Drop anything deleted since the shuffle, so undo can't resurrect a row.
    final liveIds = _books.map((b) => b.id).toSet();
    final restored = order.where((b) => liveIds.contains(b.id)).toList();

    setState(() => _books = restored);
    await _repository.reorderBooks(restored);
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final book = _books.removeAt(oldIndex);
      _books.insert(newIndex, book);
    });
    await _repository.reorderBooks(_books);
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
          backgroundColor: theme.colorScheme.surfaceContainer,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: _selectionMode
              ? IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: _clearSelection,
                )
              : null,
          title: Text(_selectionMode
              ? '${_selectedIds.length} selected'
              : 'Reading Planner'),
          actions: [
            // Nothing to shuffle below two books.
            if (!_selectionMode && _books.length > 1)
              IconButton(
                icon: const Icon(Icons.shuffle_rounded),
                tooltip: 'Shuffle order',
                onPressed: _shuffleBooks,
              ),
          ],
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
                      proxyDecorator: (child, _, _) => child,
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
                          onDismissed: () => _deleteBook(book),
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

class _PlannerItem extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dismissible(
      key: ValueKey(book.id),
      direction: selectionMode
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
      onDismissed: (_) => onDismissed(),
      child: PlannerBookCard(
        book: book,
        index: index,
        isSelected: isSelected,
        onTap: onTap,
        onLongPress: onLongPress,
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
