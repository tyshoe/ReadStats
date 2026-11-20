import 'package:flutter/material.dart';

/// The library with no books at all: Carl, asking for one.
class EmptyLibrary extends StatelessWidget {
  const EmptyLibrary({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/images/carl.png', width: 100, height: 100),
          const SizedBox(height: 16),
          Text(
            'Carl is hungry, add a book to your library',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

/// Books exist, but none are showing: why, by what's narrowing the list.
class NoMatchingBooks extends StatelessWidget {
  final bool searching;

  /// Only a shelf is selected — no search, no other filter — so the shelf
  /// itself is empty.
  final bool shelfEmpty;

  const NoMatchingBooks({
    super.key,
    required this.searching,
    required this.shelfEmpty,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final IconData icon = searching
        ? Icons.search_off_rounded
        : shelfEmpty
        ? Icons.library_books_outlined
        : Icons.filter_list_off_rounded;
    final String message = searching
        ? 'No books match your search.'
        : shelfEmpty
        ? 'No books on this shelf yet.'
        : 'No books match the active filters.';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            message,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
