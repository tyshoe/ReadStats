import 'package:flutter/material.dart';

/// The stack of buttons shown while books are selected: delete, pin, add
/// to series and tag.
class SelectionActions extends StatelessWidget {
  final Color accentColor;
  final VoidCallback onDelete;
  final VoidCallback onPin;
  final VoidCallback onAddToSeries;
  final VoidCallback onTag;

  const SelectionActions({
    super.key,
    required this.accentColor,
    required this.onDelete,
    required this.onPin,
    required this.onAddToSeries,
    required this.onTag,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          heroTag: 'delete',
          backgroundColor: cs.error,
          onPressed: onDelete,
          child: Icon(Icons.delete, color: cs.onPrimary),
        ),
        const SizedBox(height: 16),
        FloatingActionButton(
          heroTag: 'pin',
          backgroundColor: accentColor,
          onPressed: onPin,
          child: Icon(Icons.push_pin, color: cs.onPrimary),
        ),
        const SizedBox(height: 16),
        FloatingActionButton(
          heroTag: 'series',
          backgroundColor: accentColor,
          onPressed: onAddToSeries,
          tooltip: 'Add to series',
          child: Icon(Icons.collections_bookmark, color: cs.onPrimary),
        ),
        const SizedBox(height: 16),
        FloatingActionButton(
          heroTag: 'tag',
          backgroundColor: accentColor,
          onPressed: onTag,
          child: Icon(Icons.sell, color: cs.onPrimary),
        ),
      ],
    );
  }
}

/// Asks before deleting [count] books and their sessions. True to delete.
Future<bool> confirmDeleteBooks(BuildContext context, int count) async {
  final bookWord = count == 1 ? 'book' : 'books';
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Delete $count $bookWord?'),
      content: const Text(
        'This will also delete all sessions for these books. This action cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(
            'Delete',
            style: TextStyle(color: Theme.of(ctx).colorScheme.error),
          ),
        ),
      ],
    ),
  );
  return confirmed == true;
}
