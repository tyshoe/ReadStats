import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import '/data/repositories/book_repository.dart';
import '/viewmodels/SettingsViewModel.dart';

void showRateBookDialog({
  required BuildContext context,
  required String bookTitle,
  required void Function(double rating, String? review) onRate,
  required VoidCallback onSkip,
  required bool useStarRating,
  double initialRating = 0.0,
  String? initialReview,
  String? author,
  String? coverPath,
  Color? accentColor,
}) {
  final theme = Theme.of(context);
  final textColor = theme.textTheme.bodyMedium?.color ?? Colors.black;
  final surface = theme.colorScheme.surface;
  final accent = accentColor ?? theme.colorScheme.primary;

  showDialog(
    context: context,
    builder: (context) {
      double rating = initialRating;
      bool hasRated = initialRating > 0;
      final TextEditingController ratingController = TextEditingController();
      final TextEditingController reviewController = TextEditingController(text: initialReview ?? '');

      if (initialRating > 0) {
        ratingController.text = initialRating.toStringAsFixed(2);
      }

      return StatefulBuilder(
        builder: (context, setState) {
          final hasCover = coverPath != null && coverPath.isNotEmpty;

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            backgroundColor: surface,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Rate & Review',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Cover + title/author
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (hasCover) ...[
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.35),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(
                                File(coverPath!),
                                width: 100,
                                height: 148,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                bookTitle,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (author != null && author.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  author,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: textColor.withOpacity(0.55),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Rating widget
                    useStarRating
                        ? Column(
                            children: [
                              Center(
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
                                    setState(() {
                                      rating = newRating;
                                      hasRated = true;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                hasRated
                                    ? '${rating % 1 == 0 ? rating.toInt() : rating} / 5'
                                    : 'Tap to rate',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: textColor.withOpacity(0.5),
                                ),
                              ),
                            ],
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

                    const SizedBox(height: 16),

                    TextField(
                      controller: reviewController,
                      decoration: InputDecoration(
                        labelText: 'Review (optional)',
                        hintText: 'What did you think?',
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest,
                        border: UnderlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: UnderlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                        alignLabelWithHint: true,
                      ),
                      minLines: 3,
                      maxLines: null,
                      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                    ),

                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: TextButton(
                              onPressed: () {
                                ratingController.dispose();
                                reviewController.dispose();
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
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: accent,
                                foregroundColor: theme.colorScheme.onPrimary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: () {
                                final review = reviewController.text.trim().isEmpty
                                    ? null
                                    : reviewController.text.trim();
                                ratingController.dispose();
                                reviewController.dispose();
                                Navigator.pop(context);
                                onRate(rating, review);
                              },
                              child: const Text(
                                'Save',
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

Future<void> showRatingDialogForBook({
  required BuildContext context,
  required Map<String, dynamic> book,
  required BookRepository bookRepository,
  required SettingsViewModel settingsViewModel,
}) async {
  final completer = Completer<void>();

  showRateBookDialog(
    context: context,
    bookTitle: book['title'],
    author: book['author'] as String?,
    coverPath: book['cover_path'] as String?,
    accentColor: settingsViewModel.accentColorNotifier.value,
    onRate: (rating, review) async {
      try {
        await bookRepository.updateBookRating(book['id'], rating, review: review);
      } catch (_) {
      } finally {
        completer.complete();
      }
    },
    onSkip: () => completer.complete(),
    useStarRating: settingsViewModel.defaultRatingStyleNotifier.value == 0,
  );

  return completer.future;
}

