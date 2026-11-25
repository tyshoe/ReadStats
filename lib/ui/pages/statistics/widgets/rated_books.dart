import 'package:flutter/material.dart';
import 'package:read_stats/data/models/cover_shape.dart';
import 'package:read_stats/ui/widgets/book_cover.dart';
import 'package:read_stats/ui/widgets/book_picker_sheet.dart';

/// A rating as the reader gave it: "5", "4.5".
String formatRating(double rating) => rating == rating.roundToDouble()
    ? rating.toInt().toString()
    : rating.toStringAsFixed(1);

double ratingOf(Map<String, dynamic> book) =>
    (book['rating'] as num?)?.toDouble() ?? 0;

/// Lists [books] — all of one rating, or one star bucket of the histogram —
/// and hands back the one tapped. Split under a heading per exact rating when
/// the bucket holds more than one ("5★" and "4.5★" both round to five stars).
Future<Map<String, dynamic>?> showRatedBooksSheet({
  required BuildContext context,
  required String title,
  required List<Map<String, dynamic>> books,
}) {
  final sorted = books.toList()
    ..sort((a, b) {
      final r = ratingOf(b).compareTo(ratingOf(a));
      if (r != 0) return r;
      return (b['date_finished'] as String? ?? '')
          .compareTo(a['date_finished'] as String? ?? '');
    });
  final mixed = sorted.map(ratingOf).toSet().length > 1;
  return showBookPickerSheet(
    context: context,
    books: sorted,
    title: title,
    groupOf: mixed
        ? (b) => (label: '${formatRating(ratingOf(b))}★', icon: Icons.star)
        : null,
  );
}

/// The books at the top or bottom of the reader's ratings. Ties are the norm —
/// most readers have a shelf of five-star books — so it shows how many share
/// the rating and a fan of their covers, rather than one of them at random.
class RatedBooksCard extends StatelessWidget {
  final String title;
  final double rating;

  /// Newest finished first; the first three are the ones fanned out.
  final List<Map<String, dynamic>> books;
  final VoidCallback onTap;

  const RatedBooksCard({
    super.key,
    required this.title,
    required this.rating,
    required this.books,
    required this.onTap,
  });

  static const double _coverWidth = 40;
  static const double _overlap = 16;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface;
    final single = books.length == 1;
    final subtitle =
        single ? books.first['title'] as String? ?? '' : '${books.length} books';
    final fan = books.take(3).toList();

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: muted.withAlpha(153))),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(formatRating(rating),
                            style: theme.textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 2),
                        const Icon(Icons.star_rounded,
                            size: 18, color: Color(0xFFFBCB04)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: muted.withAlpha(179)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: _coverWidth + _overlap * (fan.length - 1),
                height: _coverWidth / CoverShape.aspectRatio(null),
                child: Stack(
                  alignment: Alignment.bottomLeft,
                  children: [
                    // Back to front, so the newest sits on top at the left.
                    for (var i = fan.length - 1; i >= 0; i--)
                      Positioned(
                        left: i * _overlap,
                        bottom: 0,
                        child: _Cover(book: fan[i], width: _coverWidth),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  final Map<String, dynamic> book;
  final double width;

  const _Cover({required this.book, required this.width});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final path = book['cover_path'] as String?;
    final shape = book['cover_shape'] as int?;
    final height = width / CoverShape.aspectRatio(shape);
    // A thin ring in the card's colour keeps overlapping covers apart.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
            color: theme.cardTheme.color ??
                theme.colorScheme.surfaceContainerLow,
            width: 1.5),
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      child: path != null && path.isNotEmpty
          ? BookCover(path: path, shape: shape, width: width, borderRadius: 4)
          : SizedBox(
              width: width,
              height: height,
              child: Icon(Icons.menu_book,
                  size: 18, color: theme.colorScheme.onSurfaceVariant),
            ),
    );
  }
}
