import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:carousel_slider/carousel_slider.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:read_stats/data/services/gallery_save_service.dart';
import 'package:read_stats/ui/pages/book/widgets/book_share_card.dart';
import 'package:read_stats/ui/widgets/share_action.dart';
import 'package:share_plus/share_plus.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

/// The share-card carousel for a book: four card styles in three themes, to
/// save to the gallery or share as an image.
class BookShareSheet {
  /// [dateRange] is "Started …", "Finished …" or the two dates, as the cards
  /// print it.
  static void show(
    BuildContext context,
    Map<String, dynamic> book,
    Map<String, dynamic> stats,
    int ratingStyle,
    String dateRange,
  ) => _showShareModal(context, book, stats, ratingStyle, dateRange);

  static void _showShareModal(
    BuildContext context,
    Map<String, dynamic> book,
    Map<String, dynamic> stats,
    int ratingStyle,
    String? dateRangeString,
  ) {
    final theme = Theme.of(context);

    Future<Uint8List?> captureKey(GlobalKey key) async {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    }

    Future<bool> saveImage(GlobalKey key) async {
      final imageBytes = await captureKey(key);
      if (imageBytes == null) return false;
      return saveImageToGallery(
        imageBytes,
        name:
            'book_share_${book['id']}_'
            '${DateTime.now().millisecondsSinceEpoch}',
      );
    }

    Future<bool> shareImage(GlobalKey key) async {
      try {
        final imageBytes = await captureKey(key);
        if (imageBytes == null) return false;
        final directory = await getTemporaryDirectory();
        final imagePath = '${directory.path}/book_share_${book['id']}.png';
        await File(imagePath).writeAsBytes(imageBytes);
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(imagePath)],
            text:
                'Just finished "${book['title']}" — here are my reading stats!',
          ),
        );
        return true;
      } catch (e) {
        return false;
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final GlobalKey coverKey = GlobalKey();
        final GlobalKey coverMinimalKey = GlobalKey();
        final GlobalKey dominantKey = GlobalKey();
        final GlobalKey reviewKey = GlobalKey();
        final CarouselSliderController carouselController =
            CarouselSliderController();
        int currentPage = 0;
        bool isSaving = false;
        bool isSharing = false;
        bool saveSuccess = false;
        String? actionError;
        final appIsDark = Theme.of(context).brightness == Brightness.dark;
        _ShareCardTheme selectedTheme = appIsDark
            ? _ShareCardTheme.dark
            : _ShareCardTheme.light;

        final args = (
          title: book['title'] as String,
          author: book['author'] as String,
          rating: (book['rating'] as num?)?.toDouble() ?? 0.0,
          totalPages: (stats['total_pages'] as num?)?.toInt() ?? 0,
          wordCount: (book['word_count'] as int?) ?? 0,
          daysToComplete: _calculateDaysToComplete(
            book['date_started'],
            book['date_finished'],
          ),
          pagesPerMinute:
              (stats['pages_per_minute'] as num?)?.toDouble() ?? 0.0,
          wordsPerMinute:
              (stats['words_per_minute'] as num?)?.toDouble() ?? 0.0,
          totalTime: (stats['total_time'] as num?)?.toInt() ?? 0,
          sessionCount: (stats['session_count'] as num?)?.toInt() ?? 0,
          dateRangeString: dateRangeString,
          userReview: book['user_review'] as String?,
          bookTypeName: _bookTypeName(book['book_type_id'] as int?),
        );

        final hasCoverImage = book['cover_path'] != null;
        bool useCoverBackground = true;

        return StatefulBuilder(
          builder: (context, setState) {
            final isTransparent = selectedTheme == _ShareCardTheme.transparent;
            final isDark = selectedTheme == _ShareCardTheme.dark;

            Widget buildCard(GlobalKey key, ShareCardStyle style) {
              final card = BookShareCard(
                title: args.title,
                author: args.author,
                rating: args.rating,
                totalPages: args.totalPages,
                wordCount: args.wordCount,
                daysToComplete: args.daysToComplete,
                pagesPerMinute: args.pagesPerMinute,
                wordsPerMinute: args.wordsPerMinute,
                totalTime: args.totalTime,
                sessionCount: args.sessionCount,
                dateRangeString: args.dateRangeString,
                userReview: args.userReview,
                bookTypeName: args.bookTypeName,
                headerColor: theme.colorScheme.primary,
                useCoverBackground: useCoverBackground,
                isTransparent: isTransparent,
                isDark: isDark,
                initialCoverPath: book['cover_path'] as String?,
                coverShape: book['cover_shape'] as int?,
                style: style,
              );

              final repaint = RepaintBoundary(key: key, child: card);
              final inner = isTransparent
                  ? Stack(
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: const CheckerboardBackground(
                              squareSize: _kCheckerSquareSize,
                            ),
                          ),
                        ),
                        repaint,
                      ],
                    )
                  : repaint;
              return SizedBox(
                height: _kCardHeight,
                child: Align(alignment: Alignment.topCenter, child: inner),
              );
            }

            final sheetBg = appIsDark
                ? const Color(0xFF1E1E1E)
                : const Color(0xFFE8E8E8);
            return Container(
              decoration: BoxDecoration(
                color: sheetBg,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Container(
                      height: 4,
                      width: 40,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.3,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  CarouselSlider(
                    carouselController: carouselController,
                    options: CarouselOptions(
                      height: 420,
                      enlargeCenterPage: false,
                      viewportFraction: 0.85,
                      enableInfiniteScroll: false,
                      onPageChanged: (index, _) =>
                          setState(() => currentPage = index),
                      padEnds: true,
                    ),
                    items: [
                      ClipRect(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: buildCard(coverKey, ShareCardStyle.cover),
                        ),
                      ),
                      ClipRect(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: buildCard(
                            coverMinimalKey,
                            ShareCardStyle.coverMinimal,
                          ),
                        ),
                      ),
                      ClipRect(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: buildCard(
                            dominantKey,
                            ShareCardStyle.coverDominant,
                          ),
                        ),
                      ),
                      ClipRect(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: buildCard(reviewKey, ShareCardStyle.review),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),
                  AnimatedSmoothIndicator(
                    activeIndex: currentPage,
                    count: 4,
                    effect: WormEffect(
                      dotHeight: 7,
                      dotWidth: 7,
                      activeDotColor: theme.colorScheme.primary,
                      dotColor: theme.colorScheme.onSurface.withValues(
                        alpha: 0.25,
                      ),
                    ),
                    onDotClicked: (index) =>
                        carouselController.animateToPage(index),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    const [
                      'Cover',
                      'Cover Simple',
                      'Poster',
                      'Review',
                    ][currentPage],
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (isTransparent) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Saves as PNG with transparency',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),

                  // Theme selector — circles centered, cover toggle in right spacer
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        const Spacer(),
                        _ThemeCircle(
                          selected: selectedTheme == _ShareCardTheme.dark,
                          onTap: () => setState(
                            () => selectedTheme = _ShareCardTheme.dark,
                          ),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Color(0xFF121212),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        _ThemeCircle(
                          selected: selectedTheme == _ShareCardTheme.light,
                          onTap: () => setState(
                            () => selectedTheme = _ShareCardTheme.light,
                          ),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        _ThemeCircle(
                          selected:
                              selectedTheme == _ShareCardTheme.transparent,
                          onTap: () => setState(
                            () => selectedTheme = _ShareCardTheme.transparent,
                          ),
                          child: ClipOval(
                            child: CheckerboardBackground(squareSize: 12),
                          ),
                        ),
                        Expanded(
                          child: hasCoverImage
                              ? FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 16),
                                    child: FilterChip(
                                      avatar: Icon(
                                        Icons.image_outlined,
                                        size: 14,
                                        color: useCoverBackground
                                            ? theme
                                                  .colorScheme
                                                  .onPrimaryContainer
                                            : theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                      ),
                                      label: const Text('Cover'),
                                      selected: useCoverBackground,
                                      onSelected: (v) => setState(
                                        () => useCoverBackground = v,
                                      ),
                                      showCheckmark: false,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      visualDensity: VisualDensity.compact,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        side: BorderSide(
                                          color: useCoverBackground
                                              ? Colors.transparent
                                              : theme.colorScheme.outline,
                                        ),
                                      ),
                                      selectedColor:
                                          theme.colorScheme.primaryContainer,
                                      labelStyle: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: useCoverBackground
                                                ? theme
                                                      .colorScheme
                                                      .onPrimaryContainer
                                                : theme
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                )
                              : const SizedBox(),
                        ),
                      ],
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    child: actionError != null
                        ? Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              actionError!,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.error,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),

                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ShareAction(
                        icon: FluentIcons.arrow_download_16_filled,
                        label: 'Save',
                        theme: theme,
                        isLoading: isSaving,
                        isSuccess: saveSuccess,
                        onTap: isSaving || isSharing || saveSuccess
                            ? null
                            : () async {
                                setState(() {
                                  isSaving = true;
                                  actionError = null;
                                });
                                final key = [
                                  coverKey,
                                  coverMinimalKey,
                                  dominantKey,
                                  reviewKey,
                                ][currentPage];
                                final success = await saveImage(key);
                                if (success) {
                                  setState(() {
                                    isSaving = false;
                                    saveSuccess = true;
                                  });
                                  Future.delayed(
                                    const Duration(milliseconds: 1400),
                                    () {
                                      if (context.mounted) {
                                        Navigator.pop(context);
                                      }
                                    },
                                  );
                                } else {
                                  setState(() {
                                    isSaving = false;
                                    actionError =
                                        'Failed to save. Please try again.';
                                  });
                                }
                              },
                      ),
                      ShareAction(
                        icon: FluentIcons.share_16_filled,
                        label: 'Share',
                        theme: theme,
                        isLoading: isSharing,
                        onTap: isSaving || isSharing || saveSuccess
                            ? null
                            : () async {
                                setState(() {
                                  isSharing = true;
                                  actionError = null;
                                });
                                final key = [
                                  coverKey,
                                  coverMinimalKey,
                                  dominantKey,
                                  reviewKey,
                                ][currentPage];
                                final success = await shareImage(key);
                                if (!success) {
                                  setState(() {
                                    isSharing = false;
                                    actionError =
                                        'Failed to share. Please try again.';
                                  });
                                } else {
                                  setState(() => isSharing = false);
                                }
                              },
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static String? _bookTypeName(int? id) {
    return switch (id) {
      1 => 'Paperback',
      2 => 'Hardback',
      3 => 'eBook',
      4 => 'Audiobook',
      _ => null,
    };
  }

  static int _calculateDaysToComplete(String? startDate, String? finishDate) {
    if (startDate != null && finishDate != null) {
      DateTime startDateTime = DateTime.parse(startDate);
      DateTime finishDateTime = DateTime.parse(finishDate);
      int days = finishDateTime.difference(startDateTime).inDays;
      int adjustedDays = days == 0 ? 1 : days;
      return adjustedDays;
    }
    return 0;
  }
}

enum _ShareCardTheme { light, dark, transparent }

const double _kCheckerSquareSize = 22;
const double _kCardHeight = 370;

class _ThemeCircle extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  const _ThemeCircle({
    required this.selected,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected
              ? primary
              : Theme.of(context).colorScheme.outlineVariant,
        ),
        padding: const EdgeInsets.all(3),
        child: ClipOval(child: child),
      ),
    );
  }
}
