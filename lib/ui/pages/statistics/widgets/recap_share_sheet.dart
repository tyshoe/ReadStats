import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:carousel_slider/carousel_slider.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '/data/models/monthly_recap.dart';
import '/data/services/gallery_save_service.dart';
import '/ui/pages/library/widgets/book_share_card.dart' show CheckerboardBackground;
import '/ui/widgets/share_action.dart';
import 'recap_share_card.dart';

/// How much of the sheet's width a card takes, and the gap either side of it.
/// The card's own width decides how wide its cover grid cells are, so the slot
/// height is worked out from the same two numbers.
const double _kViewportFraction = 0.85;
const double _kCardGutter = 8;

const double _kCheckerSquareSize = 22;

/// Which colour scheme the card is drawn in. Same three choices the book share
/// sheet offers, so a reader who has shared a book already knows this sheet.
enum _RecapCardTheme { light, dark, transparent }

/// The share sheet for one month's recap: swipe between card styles, pick a
/// theme, then save to the gallery or hand the image to the system share sheet.
///
/// Cover paths are passed in already resolved to absolute paths — this sheet
/// draws them and never touches storage itself.
Future<void> showRecapShareSheet({
  required BuildContext context,
  required MonthlyRecap recap,
  String? coverPath,
  int? coverShape,
}) {
  final theme = Theme.of(context);
  final styles = RecapShareCard.stylesFor(recap);

  Future<Uint8List?> captureKey(GlobalKey key) async {
    final boundary =
        key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    // 3x, so the card is sharp when it lands in a feed rather than being
    // upscaled from the phone's own layout size.
    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<bool> saveImage(GlobalKey key) async {
    try {
      final bytes = await captureKey(key);
      if (bytes == null) return false;
      return saveImageToGallery(
        bytes,
        name: 'recap_${recap.key}_${DateTime.now().millisecondsSinceEpoch}',
      );
    } catch (e) {
      return false;
    }
  }

  Future<bool> shareImage(GlobalKey key) async {
    try {
      final bytes = await captureKey(key);
      if (bytes == null) return false;
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/recap_${recap.key}.png';
      await File(path).writeAsBytes(bytes);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path)],
          text: 'My ${recap.monthLabel} in books.',
        ),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      final keys = [for (final _ in styles) GlobalKey()];
      final carouselController = CarouselSliderController();
      final appIsDark = Theme.of(context).brightness == Brightness.dark;

      // The cover grid divides up the card's width, so how tall the tallest
      // card comes out depends on how wide the sheet is.
      final cardWidth =
          MediaQuery.sizeOf(context).width * _kViewportFraction -
              _kCardGutter * 2;
      final cardHeight = RecapShareCard.slotHeightFor(recap, cardWidth);

      var currentPage = 0;
      var isSaving = false;
      var isSharing = false;
      var saveSuccess = false;
      String? actionError;
      var selectedTheme =
          appIsDark ? _RecapCardTheme.dark : _RecapCardTheme.light;
      final hasCover = coverPath != null && coverPath.isNotEmpty;
      var useCoverBackground = true;

      return StatefulBuilder(
        builder: (context, setState) {
          final isTransparent = selectedTheme == _RecapCardTheme.transparent;
          final isDark = selectedTheme == _RecapCardTheme.dark;

          Widget buildCard(GlobalKey key, RecapCardStyle style) {
            final card = RecapShareCard(
              recap: recap,
              coverPath: coverPath,
              coverShape: coverShape,
              headerColor: theme.colorScheme.primary,
              useCoverBackground: useCoverBackground,
              isTransparent: isTransparent,
              isDark: isDark,
              style: style,
            );

            final repaint = RepaintBoundary(key: key, child: card);
            // The checkerboard sits outside the boundary so it never lands in
            // the captured PNG — it is there to show transparency, not to be
            // part of the card.
            final inner = isTransparent
                ? Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: const CheckerboardBackground(
                              squareSize: _kCheckerSquareSize),
                        ),
                      ),
                      repaint,
                    ],
                  )
                : repaint;
            // Scrollable rather than clipped: the slot is sized to fit, but a
            // long title or a font with taller metrics must degrade to a card
            // the reader can scroll. The captured image is unaffected either
            // way, since it comes from the boundary's own full layout.
            // `heightFactor` is what keeps the align from expanding — inside a
            // scroll view its height is unbounded, and an [Align] with no
            // factor takes all of it.
            return SizedBox(
              height: cardHeight,
              child: SingleChildScrollView(
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: 1,
                  child: inner,
                ),
              ),
            );
          }

          final sheetBg =
              appIsDark ? const Color(0xFF1E1E1E) : const Color(0xFFE8E8E8);
          return Container(
            decoration: BoxDecoration(
              color: sheetBg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Container(
                      height: 4,
                      width: 40,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  CarouselSlider(
                    carouselController: carouselController,
                    options: CarouselOptions(
                      height: cardHeight + 20,
                      enlargeCenterPage: false,
                      viewportFraction: _kViewportFraction,
                      enableInfiniteScroll: false,
                      onPageChanged: (index, _) =>
                          setState(() => currentPage = index),
                      padEnds: true,
                    ),
                    items: [
                      for (var i = 0; i < styles.length; i++)
                        ClipRect(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: _kCardGutter),
                            child: buildCard(keys[i], styles[i]),
                          ),
                        ),
                    ],
                  ),
                  // A month with nothing finished has only the summary to
                  // offer, and a lone dot over the name of the only card is
                  // furniture for a choice the reader hasn't got.
                  if (styles.length > 1) ...[
                    const SizedBox(height: 4),
                    AnimatedSmoothIndicator(
                      activeIndex: currentPage,
                      count: styles.length,
                      effect: WormEffect(
                        dotHeight: 7,
                        dotWidth: 7,
                        activeDotColor: theme.colorScheme.primary,
                        dotColor:
                            theme.colorScheme.onSurface.withValues(alpha: 0.25),
                      ),
                      onDotClicked: (index) =>
                          carouselController.animateToPage(index),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      RecapShareCard.labelFor(styles[currentPage]),
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                  if (isTransparent) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Saves as PNG with transparency',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        const Spacer(),
                        _ThemeCircle(
                          selected: selectedTheme == _RecapCardTheme.dark,
                          onTap: () => setState(
                              () => selectedTheme = _RecapCardTheme.dark),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Color(0xFF121212),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        _ThemeCircle(
                          selected: selectedTheme == _RecapCardTheme.light,
                          onTap: () => setState(
                              () => selectedTheme = _RecapCardTheme.light),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        _ThemeCircle(
                          selected: selectedTheme == _RecapCardTheme.transparent,
                          onTap: () => setState(() =>
                              selectedTheme = _RecapCardTheme.transparent),
                          child: const ClipOval(
                              child: CheckerboardBackground(squareSize: 12)),
                        ),
                        Expanded(
                          child: hasCover
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
                                                .colorScheme.onPrimaryContainer
                                            : theme
                                                .colorScheme.onSurfaceVariant,
                                      ),
                                      label: const Text('Cover'),
                                      selected: useCoverBackground,
                                      onSelected: (v) =>
                                          setState(() => useCoverBackground = v),
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
                                                .colorScheme.onPrimaryContainer
                                            : theme
                                                .colorScheme.onSurfaceVariant,
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
                              style: theme.textTheme.labelSmall
                                  ?.copyWith(color: theme.colorScheme.error),
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
                                final success = await saveImage(keys[currentPage]);
                                if (success) {
                                  setState(() {
                                    isSaving = false;
                                    saveSuccess = true;
                                  });
                                  Future.delayed(
                                      const Duration(milliseconds: 1400), () {
                                    if (context.mounted) Navigator.pop(context);
                                  });
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
                                final success =
                                    await shareImage(keys[currentPage]);
                                setState(() {
                                  isSharing = false;
                                  if (!success) {
                                    actionError =
                                        'Failed to share. Please try again.';
                                  }
                                });
                              },
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

/// One of the three theme swatches, ringed when selected.
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
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withValues(alpha: 0.25),
            width: selected ? 2 : 1,
          ),
        ),
        child: child,
      ),
    );
  }
}

