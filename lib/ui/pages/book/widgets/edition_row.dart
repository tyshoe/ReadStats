import 'package:flutter/material.dart';
import 'package:read_stats/data/services/book_search_service.dart';

/// Which edition of the book this is, and the way to pick another: a
/// search finds the book, not the reader's copy of it.
class EditionRow extends StatelessWidget {
  final BookEdition? edition;
  final VoidCallback onTap;

  const EditionRow({super.key, required this.edition, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final edition = this.edition;
    final muted = theme.colorScheme.onSurfaceVariant;
    final String label;
    if (edition == null) {
      label = 'Choose the one you own';
    } else if (edition.summary.isNotEmpty) {
      label = edition.summary;
    } else if (edition.isbn != null) {
      label = 'ISBN ${edition.isbn}';
    } else {
      label = edition.title.isEmpty ? 'Chosen' : edition.title;
    }
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            children: [
              Icon(Icons.auto_stories, size: 20, color: muted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Edition',
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: edition == null ? muted : null,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: muted),
            ],
          ),
        ),
      ),
    );
  }
}
