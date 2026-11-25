import 'package:flutter/material.dart';
import 'package:read_stats/domain/wrapped_story.dart';
import 'package:read_stats/domain/year_wrapped.dart';
import 'package:read_stats/ui/pages/wrapped/slides/book_slides.dart';
import 'package:read_stats/ui/pages/wrapped/slides/self_slides.dart';
import 'package:read_stats/ui/pages/wrapped/slides/year_slides.dart';
import 'package:read_stats/ui/pages/wrapped/wrapped_style.dart';

/// Everything a slide needs to draw itself, in the player or in a share image.
class SlideEnv {
  final WrappedStory story;

  /// 0 → 1 as the slide makes its entrance. Complete in a share image.
  final Animation<double> entrance;

  /// Loops forever behind the slide. Stopped in a share image.
  final Animation<double> ambient;

  /// True when the slide is being drawn into a 9:16 image: no controls, no
  /// hints, and the ReadStats mark beneath the content.
  final bool shareMode;

  /// Room the player's own chrome takes at the top and bottom.
  final EdgeInsets insets;

  // The finale's controls. Null in a share image.
  final VoidCallback? onShare;
  final VoidCallback? onReplay;
  final ValueChanged<int>? onJump;
  final List<int> otherYears;
  final ValueChanged<int>? onOpenYear;

  /// Opens the picker for naming the book of the year. Null in a share image.
  final VoidCallback? onChooseBook;

  const SlideEnv({
    required this.story,
    required this.entrance,
    required this.ambient,
    required this.insets,
    this.shareMode = false,
    this.onShare,
    this.onReplay,
    this.onJump,
    this.otherYears = const [],
    this.onOpenYear,
    this.onChooseBook,
  });

  YearWrapped get w => story.wrapped;
}

/// The height slides are laid out at in a share image, before being scaled
/// into the room above the ReadStats mark. It is what the content had when
/// the mark sat at the image's very foot, so every slide keeps the layout it
/// was made to fit and simply shrinks a little, rather than overflowing.
const double kShareDesignHeight = 542;

/// One slide: its backdrop, its content, and — in a share image — the brand.
class WrappedSlideView extends StatelessWidget {
  final WrappedSlide slide;
  final SlideEnv env;

  const WrappedSlideView({super.key, required this.slide, required this.env});

  @override
  Widget build(BuildContext context) {
    final palette = WrappedPalette.of(slide, env.w);
    final content = _content(palette);
    return Stack(
      fit: StackFit.expand,
      children: [
        WrappedBackdrop(palette: palette, ambient: env.ambient),
        Padding(
          padding: env.insets + const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: env.shareMode ? _ShareFit(child: content) : content,
              ),
              // Centred and lifted clear of the image's foot — see the share
              // insets. The finale's poster carries the mark itself.
              if (env.shareMode && slide != WrappedSlide.finale) ...[
                const SizedBox(height: 18),
                const WrappedBrand(),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _content(WrappedPalette palette) => switch (slide) {
        WrappedSlide.intro => IntroSlide(env: env, palette: palette),
        WrappedSlide.numbers => NumbersSlide(env: env, palette: palette),
        WrappedSlide.shape => ShapeSlide(env: env, palette: palette),
        WrappedSlide.rhythm => RhythmSlide(env: env, palette: palette),
        WrappedSlide.timing => TimingSlide(env: env, palette: palette),
        WrappedSlide.bigBooks => BigBooksSlide(env: env, palette: palette),
        WrappedSlide.bookOfYear => BookOfYearSlide(env: env, palette: palette),
        WrappedSlide.people => PeopleSlide(env: env, palette: palette),
        WrappedSlide.formats => FormatsSlide(env: env, palette: palette),
        WrappedSlide.personality =>
          PersonalitySlide(env: env, palette: palette),
        WrappedSlide.discoveries =>
          DiscoveriesSlide(env: env, palette: palette),
        WrappedSlide.finale => FinaleSlide(env: env, palette: palette),
      };
}

/// Lays [child] out at [kShareDesignHeight] (and the width that keeps the
/// room's shape), then scales it to fill the room it is given. Never grows
/// it: a room taller than the design height lays out as normal.
class _ShareFit extends StatelessWidget {
  final Widget child;

  const _ShareFit({required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final scale = box.maxHeight >= kShareDesignHeight
          ? 1.0
          : box.maxHeight / kShareDesignHeight;
      return FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: box.maxWidth / scale,
          height: box.maxHeight / scale,
          child: child,
        ),
      );
    });
  }
}

/// A slide's content held together as one block and centred in the height
/// there is. Spacers between the parts would pin the headline to the top
/// and the last line to the bottom, and stretch a tall phone into gaps;
/// [SlideGap]s keep each part its set distance from the next instead.
class SlideBody extends StatelessWidget {
  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;

  const SlideBody({
    super.key,
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: crossAxisAlignment,
      children: children,
    );
  }
}

/// A gap between parts of a [SlideBody]: [size] where there is room, and
/// less where there isn't — a short screen or a share image — rather than
/// overflowing.
class SlideGap extends StatelessWidget {
  final double size;

  const SlideGap(this.size, {super.key});

  @override
  Widget build(BuildContext context) =>
      Flexible(child: SizedBox(height: size));
}

/// A slide's small-caps label, at the head of the slide.
class SlideEyebrow extends StatelessWidget {
  final String text;
  final Animation<double> entrance;
  final Color? color;

  const SlideEyebrow(this.text,
      {super.key, required this.entrance, this.color});

  @override
  Widget build(BuildContext context) {
    return Reveal(
      animation: entrance,
      end: 0.35,
      lift: 12,
      child: Text(text.toUpperCase(),
          style: WrappedType.eyebrow(context, color: color)),
    );
  }
}
