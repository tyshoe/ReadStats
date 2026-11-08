import 'package:flutter/material.dart';

import '/data/models/wrapped_story.dart';
import '/data/models/year_wrapped.dart';
import '../wrapped_style.dart';
import 'book_slides.dart';
import 'self_slides.dart';
import 'year_slides.dart';

/// Everything a slide needs to draw itself, in the player or in a share image.
class SlideEnv {
  final WrappedStory story;

  /// 0 → 1 as the slide makes its entrance. Complete in a share image.
  final Animation<double> entrance;

  /// Loops forever behind the slide. Stopped in a share image.
  final Animation<double> ambient;

  /// True when the slide is being drawn into a 9:16 image: no controls, no
  /// hints, and the ReadStats mark along the bottom.
  final bool shareMode;

  /// Room the player's own chrome takes at the top and bottom.
  final EdgeInsets insets;

  // The finale's controls. Null in a share image.
  final VoidCallback? onShare;
  final VoidCallback? onReplay;
  final ValueChanged<int>? onJump;
  final List<int> otherYears;
  final ValueChanged<int>? onOpenYear;

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
  });

  YearWrapped get w => story.wrapped;
}

/// One slide: its backdrop, its content, and — in a share image — the brand.
class WrappedSlideView extends StatelessWidget {
  final WrappedSlide slide;
  final SlideEnv env;

  const WrappedSlideView({super.key, required this.slide, required this.env});

  @override
  Widget build(BuildContext context) {
    final palette = WrappedPalette.of(slide, env.w);
    return Stack(
      fit: StackFit.expand,
      children: [
        WrappedBackdrop(palette: palette, ambient: env.ambient),
        Padding(
          padding: env.insets + const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _content(palette)),
              if (env.shareMode) ...[
                const SizedBox(height: 18),
                WrappedBrand(year: env.w.year),
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
