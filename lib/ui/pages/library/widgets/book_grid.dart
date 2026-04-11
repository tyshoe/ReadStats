import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';

class BookGridItem extends StatelessWidget {
  final Map<String, dynamic> book;
  final VoidCallback onTap;
  final bool isPinned;
  final bool isSelected;
  final bool selectionMode;
  final Color selectionColor;

  const BookGridItem({
    super.key,
    required this.book,
    required this.onTap,
    this.isPinned = false,
    this.isSelected = false,
    this.selectionMode = false,
    this.selectionColor = Colors.blue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasCover = book['cover_path'] != null;
    final blurSelected = selectionMode && isSelected && hasCover;

    return Card(
      elevation: 0,
      color: hasCover ? null : (isSelected ? selectionColor.withOpacity(0.45) : theme.cardTheme.color),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: isSelected
            ? BorderSide(color: selectionColor, width: 3)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Cover image or text placeholder
                  if (hasCover)
                    Image.file(
                      File(book['cover_path'] as String),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (_, __, ___) => _textPlaceholder(theme, book),
                    )
                  else
                    _textPlaceholder(theme, book),

                  // Blur + dim overlay for selected books in selection mode
                  if (blurSelected)
                    Positioned.fill(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: .8, sigmaY: .8),
                        child: Container(color: Colors.black.withOpacity(0.35)),
                      ),
                    ),

                  // Checkmark overlay for selected books with covers
                  if (isSelected && hasCover)
                    const Positioned.fill(
                      child: Center(
                        child: Icon(Icons.check_circle, color: Colors.white, size: 32),
                      ),
                    ),

                  if (!blurSelected)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (isPinned)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: _BadgePill(
                                child: Icon(
                                  Icons.push_pin,
                                  size: 16,
                                  color: theme.iconTheme.color?.withAlpha(153),
                                ),
                              ),
                            ),
                          if (book['is_favorite'] == 1)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: _BadgePill(
                                child: Icon(
                                  Icons.favorite,
                                  size: 16,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _textPlaceholder(ThemeData theme, Map<String, dynamic> book) {
  return Container(
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          book['title'],
          style: theme.textTheme.bodyMedium,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
        const Spacer(),
        Text(
          book['author'],
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.textTheme.bodySmall?.color?.withAlpha(153),
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );
}

class _BadgePill extends StatelessWidget {
  final Widget child;
  const _BadgePill({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(child: child);
  }
}
