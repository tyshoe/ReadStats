import 'package:flutter/material.dart';
import '/data/models/planner_book.dart';
import '/ui/widgets/book_picker_sheet.dart';

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
  final available = wantToReadBooks
      .where((b) => !existingBookIds.contains(b['id'] as int))
      .toList();

  return showBookPickerSheet(
    context: context,
    books: available,
    title: 'Add to Planner',
    emptyMessage: 'All Want to Read books are already in your planner',
    searchEmptyMessage: 'No books found',
    onSelect: (book) async {
      final entry = PlannerBook(
        bookId: book['id'] as int,
        sortOrder: 0,
        dateAdded: DateTime.now().toIso8601String(),
        bookTitle: book['title'] as String? ?? '',
        bookAuthor: book['author'] as String? ?? '',
      );
      await onAdd(entry);
      return true; // remove from list, keep sheet open
    },
  );
}
