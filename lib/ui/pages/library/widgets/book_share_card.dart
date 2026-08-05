import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'dart:io';
import 'dart:ui' as ui;
import '/data/database/database_helper.dart';

enum ShareCardStyle { cover, coverMinimal, coverDominant, review }

class BookShareCard extends StatefulWidget {
  final String title;
  final String author;
  final double rating;
  final int totalPages;
  final int wordCount;
  final int daysToComplete;
  final double pagesPerMinute;
  final double wordsPerMinute;
  final int totalTime;
  final int sessionCount;
  final String? dateRangeString;
  final String? userReview;
  final String? bookTypeName;
  final Color? headerColor;
  final bool useCoverBackground;
  final bool isTransparent;
  final bool isDark;
  final String? initialCoverPath;
  final int? coverShape;
  final ShareCardStyle style;

  const BookShareCard({
    super.key,
    required this.title,
    required this.author,
    required this.rating,
    required this.totalPages,
    this.wordCount = 0,
    required this.daysToComplete,
    required this.pagesPerMinute,
    required this.wordsPerMinute,
    required this.totalTime,
    required this.sessionCount,
    required this.dateRangeString,
    this.headerColor,
    this.useCoverBackground = true,
    this.userReview,
    this.bookTypeName,
    this.isTransparent = false,
    this.isDark = false,
    this.initialCoverPath,
    this.coverShape,
    this.style = ShareCardStyle.cover,
  });

  @override
  State<BookShareCard> createState() => _BookShareCardState();
}

class _BookShareCardState extends State<BookShareCard> {
  File? _coverImage;

  static const Color _starYellow = Color(0xFFFBCB04);
  static const double _coverImageHeight = 130;

  @override
  void initState() {
    super.initState();
    if (widget.initialCoverPath != null) {
      _coverImage = File(widget.initialCoverPath!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Gradient headerGradient;
    final Color headerStartColor;
    final Color bodyBg;
    final Color bodyPrimary;
    final Color bodySecondary;
    final Color dividerColor;

    if (widget.isTransparent) {
      headerGradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.black.withValues(alpha: 0.62),
          Colors.black.withValues(alpha: 0.44),
        ],
      );
      headerStartColor = Colors.black;
      bodyBg = Colors.black.withValues(alpha: 0.28);
      bodyPrimary = Colors.white;
      bodySecondary = Colors.white.withValues(alpha: 0.58);
      dividerColor = Colors.white.withValues(alpha: 0.12);
    } else if (widget.isDark) {
      final base = widget.headerColor ?? const Color(0xFF2C2C2C);
      headerStartColor = Color.lerp(base, Colors.black, 0.3)!;
      headerGradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [headerStartColor, Color.lerp(base, Colors.black, 0.65)!],
      );
      bodyBg = const Color(0xFF141414);
      bodyPrimary = Colors.white;
      bodySecondary = Colors.white.withValues(alpha: 0.52);
      dividerColor = Colors.white.withValues(alpha: 0.10);
    } else {
      final base = widget.headerColor ?? const Color(0xFF484848);
      headerStartColor = base;
      headerGradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [base, Color.lerp(base, Colors.black, 0.40)!],
      );
      bodyBg = Colors.white;
      bodyPrimary = const Color(0xFF111827);
      bodySecondary = const Color(0xFF6B7280);
      dividerColor = const Color(0xFFE9EAEC);
    }
    final headerFg = ThemeData.estimateBrightnessForColor(headerStartColor) == Brightness.light
        ? Colors.black
        : Colors.white;

    switch (widget.style) {
      case ShareCardStyle.cover:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(headerGradient, headerFg),
            _buildBody(bodyBg, bodyPrimary, bodySecondary, dividerColor),
          ],
        );
      case ShareCardStyle.coverMinimal:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(headerGradient, headerFg, showWords: false),
            _buildBody(bodyBg, bodyPrimary, bodySecondary, dividerColor,
                minimal: true),
          ],
        );
      case ShareCardStyle.coverDominant:
        return _buildCoverDominantCard(headerGradient);
      case ShareCardStyle.review:
        return _buildReviewCard(headerGradient, headerFg, bodyBg, bodyPrimary, bodySecondary, dividerColor);
    }
  }

  // ── Header ───────────────────────────────────────────────────────────

  Widget _buildHeader(Gradient gradient, Color fg, {bool showWords = true}) {
    const radius = BorderRadius.vertical(top: Radius.circular(20));
    // Don't use blurred cover in transparent mode — would look opaque against a see-through body
    final hasCover = _coverImage != null && !widget.isTransparent && widget.useCoverBackground;
    // Blurred cover is always dark, so fg is always white when cover is present
    final effectiveFg = hasCover ? Colors.white : fg;
    return ClipRRect(
      borderRadius: radius,
      child: Stack(
        children: [
          if (hasCover) ...[
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                child: Image.file(_coverImage!, fit: BoxFit.cover),
              ),
            ),
            Positioned.fill(
              child: Container(color: Colors.black.withValues(alpha: 0.45)),
            ),
          ] else
            Positioned.fill(
              child: Container(decoration: BoxDecoration(gradient: gradient)),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
            child: _coverImage != null
                ? _buildHeaderWithCover(effectiveFg, showWords: showWords)
                : _buildHeaderMinimal(effectiveFg, showWords: showWords),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderWithCover(Color fg, {bool showWords = true}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Reserve the cover's 130px-tall slot whether or not it's shown, so the
        // header height stays identical when toggling. When hidden, the spacer is
        // zero-width so the text reflows to the left edge.
        if (widget.useCoverBackground) ...[
          _buildCoverImage(),
          const SizedBox(width: 16),
        ] else
          const SizedBox(height: _coverImageHeight),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              Text(
                widget.title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: fg,
                  height: 1.25,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 5),
              Text(
                widget.author,
                style: TextStyle(
                  fontSize: 12,
                  color: fg.withValues(alpha: 0.75),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              _buildRatingRow(fg),
              const SizedBox(height: 8),
              _buildSubLine(fg, showWords: showWords),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderMinimal(Color fg, {bool showWords = true}) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: fg,
                  height: 1.2,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                widget.author,
                style: TextStyle(
                  fontSize: 13,
                  color: fg.withValues(alpha: 0.75),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              _buildRatingRow(fg),
              const SizedBox(height: 8),
              _buildSubLine(fg, showWords: showWords),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRatingRow(Color fg, {bool stacked = false}) {
    if (stacked) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            widget.rating.toStringAsFixed(1),
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: fg, height: 1),
          ),
          const SizedBox(height: 2),
          RatingBarIndicator(
            rating: widget.rating,
            itemBuilder: (context, _) => const Icon(Icons.star_rounded, color: _starYellow),
            itemCount: 5,
            itemSize: 26,
            physics: const NeverScrollableScrollPhysics(),
          ),
        ],
      );
    }
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.rating.toStringAsFixed(1),
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: fg),
        ),
        const SizedBox(width: 8),
        RatingBarIndicator(
          rating: widget.rating,
          itemBuilder: (context, _) => const Icon(Icons.star_rounded, color: _starYellow),
          itemCount: 5,
          itemSize: 26,
          physics: const NeverScrollableScrollPhysics(),
        ),
      ],
    );
    return FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: row);
  }

  Widget _buildSubLine(Color fg, {bool showWords = true}) {
    final style = TextStyle(
      fontSize: 11,
      color: fg.withValues(alpha: 0.65),
      fontWeight: FontWeight.w500,
    );

    final countParts = <String>[];
    if (widget.totalPages > 0) countParts.add('${widget.totalPages} pages');
    if (showWords && widget.wordCount > 0) countParts.add('${_formatNumber(widget.wordCount)} words');

    final hasType = widget.bookTypeName != null;
    final hasCounts = countParts.isNotEmpty;

    if (!hasType && !hasCounts) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasType)
          Text(widget.bookTypeName!, style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
        if (hasType && hasCounts) const SizedBox(height: 2),
        if (hasCounts)
          Text(countParts.join('  ·  '), style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }

  String _formatNumber(int n) {
    return n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }

  Widget _buildCoverImage() {
    // Height is fixed either way so the header keeps its size (see the slot
    // reserved in _buildHeaderWithCover); only the width follows the shape.
    final width = widget.coverShape == DatabaseHelper.coverShapeSquare
        ? _coverImageHeight
        : 90.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.file(_coverImage!,
          width: width, height: _coverImageHeight, fit: BoxFit.cover),
    );
  }

  // ── Body ─────────────────────────────────────────────────────────────

  Widget _buildBody(Color bg, Color primary, Color secondary, Color divider,
      {bool minimal = false}) {
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeroStats(primary, secondary),
          if (!minimal && _hasSecondaryStats) ...[
            const SizedBox(height: 14),
            _buildThinDivider(divider),
            const SizedBox(height: 12),
            _buildSpeedRow(secondary),
          ],
          if (!minimal && _hasReview) ...[
            const SizedBox(height: 12),
            _buildQuote(widget.userReview!.trim(),
                color: secondary, fontSize: 12, maxLines: 3),
          ],
          const SizedBox(height: 14),
          _buildThinDivider(divider),
          const SizedBox(height: 10),
          _buildFooter(secondary),
        ],
      ),
    );
  }

  // ── Cover-dominant card ───────────────────────────────────────────────

  Widget _buildCoverDominantCard(Gradient gradient) {
    final hasCover = _coverImage != null && widget.useCoverBackground;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 370,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasCover)
              Image.file(_coverImage!, fit: BoxFit.cover)
            else
              Container(decoration: BoxDecoration(gradient: gradient)),
            // Subtle uniform veil so bright covers don't overpower the text
            if (hasCover)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.18),
                ),
              ),
            // Focused scrim behind the bottom text content
            Positioned(
              left: 0, right: 0, bottom: 0, height: 220,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.4, 1.0],
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.75),
                      Colors.black.withValues(alpha: 0.97),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.author,
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.75)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    _buildRatingRow(Colors.white),
                    const SizedBox(height: 6),
                    _buildDominantStatsRow(),
                    const SizedBox(height: 8),
                    _buildFooter(Colors.white.withValues(alpha: 0.55), forceLight: true),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDominantStatsRow() {
    final parts = <String>[];
    if (widget.totalTime > 0) parts.add(_formatTime(widget.totalTime));
    if (widget.daysToComplete > 0) parts.add('${widget.daysToComplete} days');
    if (widget.sessionCount > 0) parts.add('${widget.sessionCount} sessions');
    if (parts.isEmpty) return const SizedBox.shrink();
    return Text(
      parts.join('  ·  '),
      style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Colors.white.withValues(alpha: 0.85)),
    );
  }

  // ── Quote card ────────────────────────────────────────────────────────

  Widget _buildReviewCard(Gradient headerGradient, Color headerFg, Color bodyBg,
      Color bodyPrimary, Color bodySecondary, Color dividerColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildCompactHeader(headerGradient, headerFg),
        Container(
          decoration: BoxDecoration(
            color: bodyBg,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_hasReview)
                _buildQuote(
                  widget.userReview!.trim(),
                  color: bodyPrimary,
                  fontSize: 15,
                  maxLines: 7,
                )
              else
                Text(
                  'No review written for this book.',
                  style: TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: bodySecondary,
                    height: 1.6,
                  ),
                ),
              const SizedBox(height: 18),
              Divider(height: 1, thickness: 1, color: dividerColor),
              const SizedBox(height: 10),
              _buildFooter(bodySecondary),
            ],
          ),
        ),
      ],
    );
  }

  // ── Shared compact header (review card) ─────────────────────────────

  Widget _buildCompactHeader(Gradient gradient, Color fg,
      {bool showSubLine = false}) {
    const radius = BorderRadius.vertical(top: Radius.circular(20));
    final hasCover = _coverImage != null && !widget.isTransparent && widget.useCoverBackground;
    final effectiveFg = hasCover ? Colors.white : fg;
    return ClipRRect(
      borderRadius: radius,
      child: Stack(
        children: [
          if (hasCover) ...[
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                child: Image.file(_coverImage!, fit: BoxFit.cover),
              ),
            ),
            Positioned.fill(
              child: Container(color: Colors.black.withValues(alpha: 0.45)),
            ),
          ] else
            Positioned.fill(
              child: Container(decoration: BoxDecoration(gradient: gradient)),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: effectiveFg,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.author,
                        style: TextStyle(fontSize: 11, color: effectiveFg.withValues(alpha: 0.70)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (showSubLine) ...[
                        const SizedBox(height: 4),
                        _buildSubLine(effectiveFg),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _buildRatingRow(effectiveFg, stacked: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThinDivider(Color color) {
    return Divider(height: 1, thickness: 1, color: color);
  }

  Widget _buildHeroStats(Color primary, Color secondary) {
    final items = <(String, String)>[];
    if (widget.totalTime > 0) items.add((_formatTime(widget.totalTime), 'Read Time'));
    if (widget.daysToComplete > 0) items.add(('${widget.daysToComplete}', 'Days'));
    if (widget.sessionCount > 0) items.add(('${widget.sessionCount}', 'Sessions'));

    if (items.isEmpty) return const SizedBox.shrink();

    final cells = <Widget>[];
    for (int i = 0; i < items.length; i++) {
      if (i > 0) {
        cells.add(Container(
          width: 1,
          height: 42,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          color: secondary.withValues(alpha: 0.25),
        ));
      }
      cells.add(Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                items[i].$1,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: primary,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              items[i].$2.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: secondary,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ));
    }

    return Row(children: cells);
  }

  bool get _hasSecondaryStats =>
      widget.pagesPerMinute > 0 || widget.wordsPerMinute > 0 ||
      (widget.sessionCount > 0 && widget.totalTime > 0);

  Widget _buildSpeedRow(Color secondary) {
    final parts = <String>[];
    if (widget.wordsPerMinute > 0) {
      parts.add('${widget.wordsPerMinute.round()} wpm');
    }
    if (widget.pagesPerMinute > 0) {
      parts.add('${widget.pagesPerMinute.toStringAsFixed(1)} pg/min');
    }
    if (widget.sessionCount > 0 && widget.totalTime > 0) {
      final avg = (widget.totalTime / widget.sessionCount).round();
      parts.add('${_formatTime(avg)} avg session');
    }

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        parts.join('  ·  '),
        maxLines: 1,
        softWrap: false,
        style: TextStyle(
          fontSize: 12,
          color: secondary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  bool get _hasReview =>
      widget.userReview != null && widget.userReview!.trim().isNotEmpty;

  /// Shared pull-quote used by the cover and review cards. A yellow accent bar
  /// (matching the rating stars) marks the text as a quote, so no literal
  /// quotation marks are needed — and none get clipped when the text truncates.
  /// [IntrinsicHeight] lets the bar stretch to the text's height exactly.
  Widget _buildQuote(
    String text, {
    required Color color,
    required double fontSize,
    required int maxLines,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 3,
            decoration: BoxDecoration(
              color: _starYellow,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: fontSize,
                fontStyle: FontStyle.italic,
                color: color,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(Color secondary, {bool forceLight = false}) {
    final brandColor = forceLight || widget.isDark || widget.isTransparent
        ? Colors.white.withValues(alpha: 0.85)
        : const Color(0xFF111827);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            widget.dateRangeString ?? '',
            style: TextStyle(fontSize: 11, color: secondary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/icon/readstats_white.png',
              width: 26,
              height: 26,
              color: brandColor,
            ),
            const SizedBox(width: 5),
            Text(
              'ReadStats',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: brandColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatTime(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return hours > 0 ? '${hours}h ${mins}m' : '${mins}m';
  }
}

/// Checkerboard background used in the share preview to indicate transparency.
/// Place this behind the transparent [BookShareCard] but outside its
/// [RepaintBoundary] so it is never included in the captured image.
class CheckerboardBackground extends StatelessWidget {
  final double squareSize;

  const CheckerboardBackground({super.key, this.squareSize = 22});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CheckerboardPainter(squareSize: squareSize),
      child: const SizedBox.expand(),
    );
  }
}

class _CheckerboardPainter extends CustomPainter {
  final double squareSize;

  _CheckerboardPainter({required this.squareSize});

  @override
  void paint(Canvas canvas, Size size) {
    final light = Paint()..color = const Color(0xFF888888);
    final dark = Paint()..color = const Color(0xFF606060);

    for (double y = 0; y < size.height; y += squareSize) {
      for (double x = 0; x < size.width; x += squareSize) {
        final isEven =
            ((x / squareSize).floor() + (y / squareSize).floor()) % 2 == 0;
        canvas.drawRect(
          Rect.fromLTWH(x, y, squareSize, squareSize),
          isEven ? light : dark,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
