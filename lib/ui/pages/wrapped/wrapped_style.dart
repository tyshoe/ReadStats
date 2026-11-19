import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:read_stats/domain/reader_personality.dart';
import 'package:read_stats/domain/wrapped_story.dart';
import 'package:read_stats/domain/year_wrapped.dart';
import 'package:read_stats/ui/widgets/book_cover.dart';

/// Wrapped's own look: deep, saturated gradients with white type, the same in
/// light and dark mode. It is an event rather than a screen of the app, and a
/// share image has to look the same whoever posts it.
class WrappedPalette {
  /// Dark → bright, drawn top-left to bottom-right.
  final List<Color> gradient;

  /// The colour the slide's key figure is set in.
  final Color accent;

  const WrappedPalette(this.gradient, this.accent);

  Color get deep => gradient.first;
  Color get bright => gradient.last;

  static const intro = WrappedPalette(
      [Color(0xFF14072E), Color(0xFF431686), Color(0xFFB5179E)],
      Color(0xFFFFD166));
  static const numbers = WrappedPalette(
      [Color(0xFF031A17), Color(0xFF0B5D4B), Color(0xFF1FA67A)],
      Color(0xFFC6FF5E));
  static const shape = WrappedPalette(
      [Color(0xFF040826), Color(0xFF0B2A8A), Color(0xFF2D6BFF)],
      Color(0xFF5CE1FF));
  static const rhythm = WrappedPalette(
      [Color(0xFF220520), Color(0xFF7A1257), Color(0xFFE0457B)],
      Color(0xFFFFB86B));
  static const bigBooks = WrappedPalette(
      [Color(0xFF240808), Color(0xFF7C1D1D), Color(0xFFE2553C)],
      Color(0xFFFFD166));
  static const bookOfYear = WrappedPalette(
      [Color(0xFF110A02), Color(0xFF55380A), Color(0xFFC98A0B)],
      Color(0xFFFFE08A));
  static const people = WrappedPalette(
      [Color(0xFF021B1A), Color(0xFF0D5257), Color(0xFF1C9AA0)],
      Color(0xFF9BFFE0));
  static const formats = WrappedPalette(
      [Color(0xFF181002), Color(0xFF6B3A00), Color(0xFFF08A1C)],
      Color(0xFFFFC23D));
  static const discoveries = WrappedPalette(
      [Color(0xFF06152A), Color(0xFF14407A), Color(0xFF7B2FF7)],
      Color(0xFF7CF5FF));
  static const finale = WrappedPalette(
      [Color(0xFF09080F), Color(0xFF2A1458), Color(0xFFB5179E)],
      Color(0xFFFFD166));

  static WrappedPalette personality(PersonalityTrait trait) =>
      switch (trait) {
        PersonalityTrait.nightOwl => const WrappedPalette(
            [Color(0xFF03041A), Color(0xFF1A1B5E), Color(0xFF5B3FD9)],
            Color(0xFFB9A8FF)),
        PersonalityTrait.earlyBird => const WrappedPalette(
            [Color(0xFF2A0F05), Color(0xFFB4441C), Color(0xFFFFA24C)],
            Color(0xFFFFF0B3)),
        PersonalityTrait.weekendReader => const WrappedPalette(
            [Color(0xFF0B1A05), Color(0xFF2F6B12), Color(0xFF8CC63F)],
            Color(0xFFF4FF8A)),
        PersonalityTrait.marathonReader => const WrappedPalette(
            [Color(0xFF1C0303), Color(0xFF8A1010), Color(0xFFFF4D3D)],
            Color(0xFFFFD0A8)),
        PersonalityTrait.speedReader => const WrappedPalette(
            [Color(0xFF020F1F), Color(0xFF00589C), Color(0xFF00C2FF)],
            Color(0xFFFFF36B)),
        PersonalityTrait.audiobookDevotee => const WrappedPalette(
            [Color(0xFF1B0420), Color(0xFF6E1A84), Color(0xFFE056FD)],
            Color(0xFFFFC2F5)),
        PersonalityTrait.consistentReader => const WrappedPalette(
            [Color(0xFF021A12), Color(0xFF07694A), Color(0xFF14C38E)],
            Color(0xFFD5FFE8)),
        PersonalityTrait.bookworm => const WrappedPalette(
            [Color(0xFF1E0B02), Color(0xFF7A3B0C), Color(0xFFE8862A)],
            Color(0xFFFFE6B8)),
      };

  static WrappedPalette of(WrappedSlide slide, YearWrapped w) =>
      switch (slide) {
        WrappedSlide.intro => intro,
        WrappedSlide.numbers => numbers,
        WrappedSlide.shape => shape,
        WrappedSlide.rhythm => rhythm,
        WrappedSlide.bigBooks => bigBooks,
        WrappedSlide.bookOfYear => bookOfYear,
        WrappedSlide.people => people,
        WrappedSlide.formats => formats,
        WrappedSlide.personality => w.personality == null
            ? intro
            : personality(w.personality!.trait),
        WrappedSlide.discoveries => discoveries,
        WrappedSlide.finale => finale,
      };
}

IconData personalityIcon(PersonalityTrait trait) => switch (trait) {
      PersonalityTrait.nightOwl => Icons.bedtime,
      PersonalityTrait.earlyBird => Icons.wb_sunny,
      PersonalityTrait.weekendReader => Icons.weekend,
      PersonalityTrait.marathonReader => Icons.timer,
      PersonalityTrait.speedReader => Icons.bolt,
      PersonalityTrait.audiobookDevotee => Icons.headphones,
      PersonalityTrait.consistentReader => Icons.event_repeat,
      PersonalityTrait.bookworm => Icons.auto_stories,
    };

/// Wrapped's type, built on the reader's chosen font so the event still feels
/// like their app. Everything is white on the gradients.
class WrappedType {
  WrappedType._();

  static TextStyle _base(BuildContext context) =>
      (Theme.of(context).textTheme.bodyMedium ?? const TextStyle())
          .copyWith(color: Colors.white, decoration: TextDecoration.none);

  static TextStyle eyebrow(BuildContext context, {Color? color}) =>
      _base(context).copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 2.2,
        color: color ?? Colors.white.withValues(alpha: 0.75),
      );

  static TextStyle headline(BuildContext context, {double size = 32}) =>
      _base(context).copyWith(
        fontSize: size,
        fontWeight: FontWeight.w800,
        height: 1.08,
        letterSpacing: -0.6,
      );

  static TextStyle hero(BuildContext context,
          {double size = 96, Color? color}) =>
      _base(context).copyWith(
        fontSize: size,
        fontWeight: FontWeight.w900,
        height: 0.95,
        letterSpacing: -size * 0.035,
        color: color,
      );

  static TextStyle title(BuildContext context, {double size = 20}) =>
      _base(context).copyWith(
        fontSize: size,
        fontWeight: FontWeight.w700,
        height: 1.2,
      );

  static TextStyle body(BuildContext context, {double alpha = 0.78}) =>
      _base(context).copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.35,
        color: Colors.white.withValues(alpha: alpha),
      );

  static TextStyle caption(BuildContext context, {double alpha = 0.62}) =>
      _base(context).copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 1.3,
        color: Colors.white.withValues(alpha: alpha),
      );
}

/// The slide's backdrop: its gradient, with two soft glows drifting slowly
/// across it. [ambient] loops; a stopped animation gives a still frame, which
/// is what share images and reduced-motion get.
class WrappedBackdrop extends StatelessWidget {
  final WrappedPalette palette;
  final Animation<double> ambient;

  const WrappedBackdrop({
    super.key,
    required this.palette,
    required this.ambient,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _BackdropPainter(palette: palette, ambient: ambient),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _BackdropPainter extends CustomPainter {
  final WrappedPalette palette;
  final Animation<double> ambient;

  _BackdropPainter({required this.palette, required this.ambient})
      : super(repaint: ambient);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette.gradient,
          stops: palette.gradient.length == 3 ? const [0, 0.55, 1] : null,
        ).createShader(rect),
    );

    final t = ambient.value * 2 * math.pi;
    void glow(Offset center, double radius, Color color) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    final w = size.width;
    final h = size.height;
    glow(
      Offset(w * (0.82 + 0.10 * math.sin(t)), h * (0.18 + 0.06 * math.cos(t))),
      w * 0.85,
      palette.bright.withValues(alpha: 0.45),
    );
    glow(
      Offset(w * (0.12 + 0.08 * math.cos(t * 1.3)),
          h * (0.86 + 0.05 * math.sin(t * 1.3))),
      w * 0.75,
      palette.accent.withValues(alpha: 0.16),
    );
    // A dark floor, so white type near the bottom always has contrast.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0),
            Colors.black.withValues(alpha: 0.35),
          ],
          stops: const [0.55, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _BackdropPainter old) =>
      old.palette != palette || old.ambient != ambient;
}

/// Fades and lifts [child] in over a window of the slide's entrance.
class Reveal extends StatelessWidget {
  final Animation<double> animation;
  final double start;
  final double end;
  final double lift;
  final Widget child;

  const Reveal({
    super.key,
    required this.animation,
    required this.child,
    this.start = 0,
    this.end = 0.5,
    this.lift = 28,
  });

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) => Opacity(
        opacity: curved.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, lift * (1 - curved.value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// A number that counts up to [value] over a window of the entrance.
class CountUp extends StatelessWidget {
  final Animation<double> animation;
  final int value;
  final String Function(int) format;
  final TextStyle style;
  final double start;
  final double end;

  const CountUp({
    super.key,
    required this.animation,
    required this.value,
    required this.style,
    this.format = YearWrapped.formatNumber,
    this.start = 0.1,
    this.end = 0.7,
  });

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Interval(start, end, curve: Curves.easeOutExpo),
    );
    return AnimatedBuilder(
      animation: curved,
      builder: (context, _) => Text(
        format((value * curved.value).round()),
        maxLines: 1,
        style: style,
      ),
    );
  }
}

/// A cover with weight: rounded, shadowed, and a designed stand-in when the
/// book has no art — a blank grey box would undercut the moment.
class WrappedCover extends StatelessWidget {
  final WrappedBook book;
  final double width;
  final WrappedPalette palette;

  const WrappedCover({
    super.key,
    required this.book,
    required this.width,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final radius = width * 0.06;
    final shadow = [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.45),
        blurRadius: width * 0.22,
        offset: Offset(0, width * 0.08),
      ),
    ];

    if (book.hasCover) {
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: shadow,
        ),
        child: BookCover(
          path: book.coverPath!,
          shape: book.coverShape,
          width: width,
          borderRadius: radius,
        ),
      );
    }

    return Container(
      width: width,
      height: width * 1.5,
      padding: EdgeInsets.all(width * 0.1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadow,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.bright, palette.deep],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_stories,
              size: width * 0.18, color: Colors.white.withValues(alpha: 0.8)),
          const Spacer(),
          Text(
            book.title,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: WrappedType.title(context, size: math.max(9, width * 0.11)),
          ),
          if (book.author.isNotEmpty && width >= 70) ...[
            SizedBox(height: width * 0.04),
            Text(
              book.author,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: WrappedType.caption(context)
                  .copyWith(fontSize: math.max(8, width * 0.075)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Small ReadStats mark for share images: present, never shouting.
class WrappedBrand extends StatelessWidget {
  final int year;

  const WrappedBrand({super.key, required this.year});

  @override
  Widget build(BuildContext context) {
    final style = WrappedType.caption(context, alpha: 0.85)
        .copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.3);
    return Row(
      children: [
        Image.asset('assets/icon/readstats_white.png', width: 18, height: 18),
        const SizedBox(width: 6),
        Text('ReadStats', style: style),
        const Spacer(),
        Text('$year Wrapped',
            style: style.copyWith(
                color: Colors.white.withValues(alpha: 0.6),
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}

/// A row of stars for a rating out of five, in the app's star yellow.
class WrappedStars extends StatelessWidget {
  final double rating;
  final double size;

  const WrappedStars({super.key, required this.rating, this.size = 20});

  static const Color starColor = Color(0xFFFBCB04);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            rating >= i
                ? Icons.star_rounded
                : rating >= i - 0.5
                    ? Icons.star_half_rounded
                    : Icons.star_outline_rounded,
            size: size,
            color: rating >= i - 0.5
                ? starColor
                : Colors.white.withValues(alpha: 0.35),
          ),
      ],
    );
  }
}
