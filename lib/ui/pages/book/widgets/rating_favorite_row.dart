import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:read_stats/ui/widgets/field_decoration.dart';

/// The book form's rating — stars, or a 0–5 number, by the reader's rating
/// style — with the favorite heart beside it.
class RatingFavoriteRow extends StatelessWidget {
  final bool useStars;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (useStars) Text('Rating', style: theme.textTheme.bodyMedium),
        Row(
          children: [
            Expanded(child: useStars ? _stars() : _numberField(theme)),
            const SizedBox(width: 16),
            IconButton(
              icon: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                color: isFavorite
                    ? Colors.red
                    : theme.colorScheme.onSurface.withAlpha(153),
                size: 32,
              ),
              onPressed: onFavoriteToggled,
            ),
          ],
        ),
      ],
    );
  }

  Widget _stars() {
    return RatingBar.builder(
      initialRating: rating ?? 0,
      minRating: 0,
      direction: Axis.horizontal,
      allowHalfRating: true,
      itemCount: 5,
      itemSize: 32,
      itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
      itemBuilder: (context, _) =>
          const Icon(Icons.star_rounded, color: Color(0xFFFBCB04)),
      glow: false,
      onRatingUpdate: onRatingChanged,
    );
  }

  Widget _numberField(ThemeData theme) {
    return TextField(
      controller: ratingController,
      decoration: filledFieldDecoration(theme).copyWith(
        labelText: 'Rating',
        hintText: 'Enter rating (0–5)',
        suffixIcon: ratingController.text.isNotEmpty
            ? IconButton(
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
