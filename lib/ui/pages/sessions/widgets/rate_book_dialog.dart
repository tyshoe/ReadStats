import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

void showRateBookDialog({
  required BuildContext context,
  required String bookTitle,
  required ValueChanged<double> onRate,
  required VoidCallback onSkip,
  required bool useStarRating,
  double initialRating = 0.0,
  Color? accentColor,
}) {
  final theme = Theme.of(context);
  final textColor = theme.textTheme.bodyMedium?.color ?? Colors.black;
  final surface = theme.colorScheme.surface;
  final accent = accentColor ?? theme.colorScheme.primary;

  showDialog(
    context: context,
    builder: (context) {
      // Move state management inside the builder
      double rating = initialRating;
      final TextEditingController ratingController = TextEditingController();

      // Initialize the controller if we have an initial rating
      if (initialRating > 0) {
        ratingController.text = initialRating.toStringAsFixed(2);
      }

      return StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            backgroundColor: surface,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Rate this book',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Centered rating component
                  useStarRating
                      ? Center(
                          child: RatingBar.builder(
                            initialRating: rating,
                            minRating: 0,
                            direction: Axis.horizontal,
                            allowHalfRating: true,
                            itemCount: 5,
                            itemSize: 40,
                            itemPadding: const EdgeInsets.symmetric(horizontal: 6.0),
                            itemBuilder: (context, _) => const Icon(
                              Icons.star,
                              color: Colors.amber,
                            ),
                            glow: false,
                            onRatingUpdate: (newRating) {
                              setState(() => rating = newRating);
                            },
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: TextField(
                            textAlign: TextAlign.center,
                            controller: ratingController,
                            decoration: InputDecoration(
                              labelText: 'Rating',
                              hintText: 'Enter rating (0–5)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              suffixIcon: ratingController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        setState(() {
                                          rating = 0;
                                          ratingController.clear();
                                        });
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
                                setState(() => rating = 0);
                              } else {
                                final parsed = double.tryParse(value);
                                if (parsed != null) {
                                  if (parsed > 5.0) {
                                    rating = 5.0;
                                    ratingController.text = '5.00';
                                    ratingController.selection = TextSelection.fromPosition(
                                      const TextPosition(offset: 4),
                                    );
                                  } else {
                                    rating = parsed;
                                  }
                                  setState(() {});
                                }
                              }
                            },
                            onTapOutside: (event) {
                              FocusManager.instance.primaryFocus?.unfocus();
                            },
                          ),
                        ),

                  const SizedBox(height: 24),

                  // Buttons with more space and centered
                  Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: TextButton(
                            onPressed: () {
                              ratingController.dispose(); // Dispose here
                              Navigator.pop(context);
                              onSkip();
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Skip',
                              style: TextStyle(
                                color: textColor.withOpacity(0.7),
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () {
                              ratingController.dispose(); // Dispose here
                              Navigator.pop(context);
                              onRate(rating);
                            },
                            child: const Text(
                              'Save',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
