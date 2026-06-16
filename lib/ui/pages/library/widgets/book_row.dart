import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

class BookRow extends StatelessWidget {
  final Map<String, dynamic> book;
  final VoidCallback onTap;
  final bool showStars;
  final List<String> tags;
  final bool isSelected;
  final Color selectionColor;
  final bool isPinned;

  const BookRow({
    super.key,
    required this.book,
    required this.onTap,
    required this.showStars,
    this.tags = const [],
    this.isSelected = false,
    this.selectionColor = Colors.blue,
    this.isPinned = false,
  });

  static const Color _starColor = Color(0xFFFBCB04);
  static const double _coverWidth = 70;
  static const double _coverHeight = 110;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rating = (book['rating'] as num?)?.toDouble();
    final hasRating = rating != null && rating > 0;
    final coverPath = book['cover_path'] as String?;
    final mutedColor = theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      color: isSelected
          ? selectionColor.withValues(alpha: 0.45)
          : theme.cardTheme.color,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover only when one exists — no placeholder otherwise.
              if (coverPath != null) ...[
                _buildCover(coverPath),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title + corner badges
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            book['title'],
                            style: theme.textTheme.bodyLarge,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isPinned)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Icon(Icons.push_pin,
                                size: 16,
                                color: theme.iconTheme.color?.withValues(alpha: 0.6)),
                          ),
                        if (book['is_favorite'] == 1)
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child:
                                Icon(Icons.favorite, size: 16, color: Colors.red),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      book['author'],
                      style:
                          theme.textTheme.bodyMedium?.copyWith(color: mutedColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (hasRating) ...[
                      const SizedBox(height: 8),
                      _buildRating(theme, rating),
                    ],
                    const SizedBox(height: 8),
                    if (tags.isNotEmpty)
                      _buildTags(theme)
                    else
                      const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCover(String path) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.file(
        File(path),
        width: _coverWidth,
        height: _coverHeight,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildRating(ThemeData theme, double rating) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          rating.toStringAsFixed(1),
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        SizedBox(width: showStars ? 6 : 4),
        // Star preference → 5 stars; numeric → single star
        if (showStars)
          RatingBarIndicator(
            rating: rating,
            itemCount: 5,
            itemSize: 18,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (context, _) =>
                const Icon(Icons.star_rounded, color: _starColor),
          )
        else
          const Icon(Icons.star_rounded, size: 14, color: _starColor),
      ],
    );
    return FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: row);
  }

  Widget _buildTags(ThemeData theme) {
    final shown = tags.take(3).toList();
    final extra = tags.length - shown.length;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4, right: 6),
          child: Icon(Icons.sell, size: 16, color: theme.colorScheme.onSecondaryContainer),
        ),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tag in shown) _tagChip(theme, tag),
              if (extra > 0) _tagChip(theme, '+$extra'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tagChip(ThemeData theme, String label) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Text(
        label,
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.onSecondaryContainer),
      ),
    );
  }
}
