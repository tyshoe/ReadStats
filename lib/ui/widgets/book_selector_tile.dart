import 'package:flutter/material.dart';
import 'book_cover.dart';
import 'book_type.dart';

/// The row that stands for "the book this session is about".
///
/// The reading timer and the session form ask the same question and open the
/// same picker, so they show the same control: cover, title, author, and the
/// book's type on its own line — a reader can own one title twice, on paper and
/// as audio, and only the type tells the two copies apart.
///
/// [onTap] of null makes the tile inert, for the one case where the book can't
/// be changed: editing a session that already belongs to a book.
class BookSelectorTile extends StatelessWidget {
  final Map<String, dynamic>? book;

  /// Shown in place of a title when [book] is null.
  final String placeholder;
  final VoidCallback? onTap;
  final IconData trailingIcon;

  const BookSelectorTile({
    super.key,
    required this.book,
    required this.placeholder,
    required this.onTap,
    this.trailingIcon = Icons.unfold_more,
  });

  static const double _coverWidth = 42;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final book = this.book;
    final coverPath = book?['cover_path'] as String?;
    final author = book?['author'] as String?;
    final muted = theme.colorScheme.onSurface.withAlpha(140);

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              // No cover, no stand-in — an empty frame reads as a broken image.
              if (coverPath != null && coverPath.isNotEmpty) ...[
                BookCover(
                  path: coverPath,
                  shape: book!['cover_shape'] as int?,
                  width: _coverWidth,
                  borderRadius: 4,
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      book?['title'] as String? ?? placeholder,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: book != null
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: book != null
                            ? theme.colorScheme.onSurface
                            : muted,
                      ),
                    ),
                    if (author?.isNotEmpty == true) ...[
                      const SizedBox(height: 2),
                      Text(
                        author!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: muted,
                        ),
                      ),
                    ],
                    if (book != null) ...[
                      const SizedBox(height: 6),
                      _typeBadge(theme, book['book_type_id'] as int?),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                trailingIcon,
                size: 20,
                color: theme.colorScheme.onSurface.withAlpha(100),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeBadge(ThemeData theme, int? bookTypeId) {
    final (icon, label) = bookTypeDetails(bookTypeId);
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 2, 8, 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

}
