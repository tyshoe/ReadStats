import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:read_stats/ui/widgets/field_decoration.dart';

/// The book form's rating — stars, or a 0–5 number, by the reader's rating
/// style — with the favorite heart beside it.
///
/// Not rated and rated 0 stars are different answers, so they look
/// different: no rating shows outlined stars and "Not rated"; 0 stars shows
/// solid grey ones and "0 stars". Clear takes a rating back to none — 0 is
/// reached by tapping the first star again, or sliding left past it.
class RatingFavoriteRow extends StatelessWidget {
  final bool useStars;

  /// Null when the book hasn't been rated; 0 when it's been given no stars.
  final double? rating;

  /// Holds the number when [useStars] is off.
  final TextEditingController ratingController;
  final ValueChanged<double?> onRatingChanged;
  final bool isFavorite;
  final VoidCallback onFavoriteToggled;

  const RatingFavoriteRow({
    super.key,
    required this.useStars,
    required this.rating,
    required this.ratingController,
    required this.onRatingChanged,
    required this.isFavorite,
    required this.onFavoriteToggled,
  });

  static const _gold = Color(0xFFFBCB04);

  /// "Not rated", "0 stars", "1 star", "4.5 stars".
  static String describe(double? rating) {
    if (rating == null) return 'Not rated';
    final number = rating == rating.roundToDouble()
        ? rating.toInt().toString()
        : rating.toString();
    return '$number ${rating == 1 ? 'star' : 'stars'}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (useStars) _starsHeading(theme),
        Row(
          children: [
            Expanded(child: useStars ? _stars(theme) : _numberField(theme)),
            const SizedBox(width: 16),
            IconButton(
              icon: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                color: isFavorite
                    ? Colors.red
                    : theme.colorScheme.onSurfaceVariant,
                size: 32,
              ),
              onPressed: onFavoriteToggled,
            ),
          ],
        ),
      ],
    );
  }

  /// "Rating · Not rated", or the rating in words with Clear beside it. A
  /// fixed height, so the stars don't jump when Clear comes and goes.
  Widget _starsHeading(ThemeData theme) {
    final colors = theme.colorScheme;
    final rated = rating != null;
    return SizedBox(
      height: 36,
      child: Row(
        children: [
          Text('Rating', style: theme.textTheme.bodyMedium),
          Text(
            '  ·  ${describe(rating)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: rated ? colors.onSurface : colors.onSurfaceVariant,
              fontWeight: rated ? FontWeight.w600 : null,
            ),
          ),
          const Spacer(),
          if (rated)
            TextButton(
              onPressed: () => onRatingChanged(null),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: const Text('Clear'),
            ),
        ],
      ),
    );
  }

  Widget _stars(ThemeData theme) {
    final colors = theme.colorScheme;
    final rated = rating != null;
    return RatingBar.builder(
      initialRating: rating ?? 0,
      minRating: 0,
      direction: Axis.horizontal,
      allowHalfRating: true,
      itemCount: 5,
      itemSize: 32,
      itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
      // The bar paints every star it hasn't filled in this colour, over
      // whatever icon it's given: outlines while there's no rating, solid
      // stars once there is one — so 0 stars reads as an answer.
      unratedColor: rated
          ? colors.onSurfaceVariant.withValues(alpha: 0.35)
          : colors.onSurfaceVariant.withValues(alpha: 0.7),
      itemBuilder: (context, _) => Icon(
        rated ? Icons.star_rounded : Icons.star_border_rounded,
        color: _gold,
      ),
      glow: false,
      onRatingUpdate: onRatingChanged,
    );
  }

  Widget _numberField(ThemeData theme) {
    return TextField(
      controller: ratingController,
      decoration: filledFieldDecoration(theme).copyWith(
        labelText: 'Rating',
        // Empty is no rating; 0 is a rating of no stars.
        hintText: 'Not rated — or 0 to 5',
        suffixIcon: ratingController.text.isNotEmpty
            ? IconButton(
                tooltip: 'Clear rating',
                icon: const Icon(Icons.clear),
                onPressed: () {
                  ratingController.clear();
                  onRatingChanged(null);
                },
              )
            : null,
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d{0,1}(\.\d{0,2})?$')),
      ],
      onChanged: (value) {
        if (value.isEmpty) {
          onRatingChanged(null);
          return;
        }
        final parsed = double.tryParse(value);
        if (parsed == null) return;
        if (parsed > 5.0) {
          ratingController.text = '5.00';
          ratingController.selection = TextSelection.fromPosition(
            const TextPosition(offset: 4),
          );
          onRatingChanged(5.0);
        } else {
          onRatingChanged(parsed);
        }
      },
      onTapOutside: (event) {
        FocusManager.instance.primaryFocus?.unfocus();
      },
    );
  }
}
