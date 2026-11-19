import 'package:flutter/material.dart';
import 'package:read_stats/domain/wrapped_story.dart';
import 'package:read_stats/domain/year_wrapped.dart';
import 'package:read_stats/ui/pages/wrapped/slides/wrapped_slide_view.dart';
import 'package:read_stats/ui/pages/wrapped/wrapped_style.dart';

// ── Reader personality ───────────────────────────────────────────────────────

class PersonalitySlide extends StatelessWidget {
  final SlideEnv env;
  final WrappedPalette palette;

  const PersonalitySlide({super.key, required this.env, required this.palette});

  @override
  Widget build(BuildContext context) {
    final p = env.w.personality!;
    final a = env.entrance;
    final pop = CurvedAnimation(
      parent: a,
      curve: const Interval(0.1, 0.6, curve: Curves.elasticOut),
    );

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: SlideEyebrow('Your reader personality', entrance: a),
        ),
        const Spacer(flex: 2),
        AnimatedBuilder(
          animation: pop,
          builder: (context, child) => Transform.scale(
            scale: 0.4 + 0.6 * pop.value,
            child: Opacity(
                opacity: (a.value / 0.15).clamp(0.0, 1.0), child: child),
          ),
          child: Container(
            width: 148,
            height: 148,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.12),
              border: Border.all(
                  color: palette.accent.withValues(alpha: 0.7), width: 2),
              boxShadow: [
                BoxShadow(
                  color: palette.accent.withValues(alpha: 0.45),
                  blurRadius: 60,
                  spreadRadius: 6,
                ),
              ],
            ),
            child: Icon(personalityIcon(p.trait),
                size: 72, color: palette.accent),
          ),
        ),
        const Spacer(),
        Reveal(
          animation: a,
          start: 0.3,
          end: 0.65,
          child: Text('You’re',
              textAlign: TextAlign.center,
              style: WrappedType.title(context, size: 20)
                  .copyWith(color: Colors.white.withValues(alpha: 0.75))),
        ),
        const SizedBox(height: 4),
        Reveal(
          animation: a,
          start: 0.35,
          end: 0.7,
          lift: 40,
          child: Text(p.title,
              textAlign: TextAlign.center,
              style: WrappedType.hero(context, size: 46).copyWith(height: 1.0)),
        ),
        const SizedBox(height: 14),
        Reveal(
          animation: a,
          start: 0.45,
          end: 0.8,
          child: Text(p.tagline,
              textAlign: TextAlign.center,
              style: WrappedType.body(context, alpha: 0.88)),
        ),
        const Spacer(),
        Reveal(
          animation: a,
          start: 0.6,
          end: 0.95,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            ),
            child: Text(p.evidence,
                textAlign: TextAlign.center,
                style: WrappedType.title(context, size: 16)),
          ),
        ),
        const Spacer(flex: 2),
      ],
    );
  }
}

// ── Discoveries ──────────────────────────────────────────────────────────────

class DiscoveriesSlide extends StatelessWidget {
  final SlideEnv env;
  final WrappedPalette palette;

  const DiscoveriesSlide({super.key, required this.env, required this.palette});

  @override
  Widget build(BuildContext context) {
    final facts = env.story.facts;
    final a = env.entrance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SlideEyebrow('Unexpected discoveries', entrance: a),
        const SizedBox(height: 14),
        Reveal(
          animation: a,
          start: 0.02,
          end: 0.4,
          child: Text(
              facts.length == 1
                  ? 'Something you\nmight have missed.'
                  : 'Things you\nmight have missed.',
              style: WrappedType.headline(context, size: 32)),
        ),
        const Spacer(),
        for (var i = 0; i < facts.length; i++) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Divider(
                  height: 1, color: Colors.white.withValues(alpha: 0.15)),
            ),
          Reveal(
            animation: a,
            start: 0.15 + i * 0.18,
            end: 0.55 + i * 0.15,
            lift: 32,
            child: _FactRow(fact: facts[i], accent: palette.accent),
          ),
        ],
        const Spacer(),
      ],
    );
  }
}

class _FactRow extends StatelessWidget {
  final WrappedFact fact;
  final Color accent;

  const _FactRow({required this.fact, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(fact.label.toUpperCase(),
            style: WrappedType.eyebrow(context).copyWith(fontSize: 11)),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(fact.value,
              maxLines: 1,
              style: WrappedType.hero(context, size: 52, color: accent)),
        ),
        const SizedBox(height: 4),
        Text(fact.detail,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: WrappedType.body(context)),
      ],
    );
  }
}

// ── Finale ───────────────────────────────────────────────────────────────────

class FinaleSlide extends StatelessWidget {
  final SlideEnv env;
  final WrappedPalette palette;

  const FinaleSlide({super.key, required this.env, required this.palette});

  @override
  Widget build(BuildContext context) {
    final a = env.entrance;
    final poster = Reveal(
      animation: a,
      start: 0,
      end: 0.5,
      lift: 40,
      child: WrappedPoster(story: env.story, palette: palette),
    );

    if (env.shareMode) return Center(child: poster);

    final jumpable = [
      for (var i = 0; i < env.story.slides.length; i++)
        if (env.story.slides[i] != WrappedSlide.finale) i,
    ];

    return Column(
      children: [
        Expanded(child: Center(child: SingleChildScrollView(child: poster))),
        const SizedBox(height: 16),
        Reveal(
          animation: a,
          start: 0.35,
          end: 0.75,
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: env.onShare,
                  icon: const Icon(Icons.ios_share, size: 18),
                  label: const Text('Share'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: env.onReplay,
                  icon: const Icon(Icons.replay, size: 18),
                  label: const Text('Replay'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Reveal(
          animation: a,
          start: 0.45,
          end: 0.85,
          child: SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: jumpable.length + env.otherYears.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                if (i < jumpable.length) {
                  final index = jumpable[i];
                  return _Chip(
                    label: env.story.slides[index].label,
                    onTap: () => env.onJump?.call(index),
                  );
                }
                final year = env.otherYears[i - jumpable.length];
                return _Chip(
                  label: '$year Wrapped',
                  icon: Icons.history,
                  onTap: () => env.onOpenYear?.call(year),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;

  const _Chip({required this.label, required this.onTap, this.icon});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: Colors.white),
                const SizedBox(width: 6),
              ],
              Text(label,
                  style: WrappedType.caption(context, alpha: 0.95)
                      .copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The year on one card — the thing most worth posting.
class WrappedPoster extends StatelessWidget {
  final WrappedStory story;
  final WrappedPalette palette;

  const WrappedPoster({super.key, required this.story, required this.palette});

  @override
  Widget build(BuildContext context) {
    final w = story.wrapped;
    final pick = w.bookOfTheYear;
    final personality = w.personality;

    final cells = <(String, String)>[
      if (w.booksFinished > 0)
        (YearWrapped.formatNumber(w.booksFinished),
            w.booksFinished == 1 ? 'book' : 'books'),
      if (w.minutes > 0) (YearWrapped.formatMinutes(w.minutes), 'reading'),
      if (w.displayPages > 0) (YearWrapped.formatNumber(w.displayPages), 'pages'),
      if (w.sessions > 0)
        (YearWrapped.formatNumber(w.sessions),
            w.sessions == 1 ? 'session' : 'sessions'),
    ].take(4).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: Colors.black.withValues(alpha: 0.28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('MY YEAR IN READING', style: WrappedType.eyebrow(context)),
          const SizedBox(height: 4),
          ShaderMask(
            shaderCallback: (rect) => LinearGradient(
              colors: [Colors.white, palette.accent],
            ).createShader(rect),
            child: Text('${w.year}', style: WrappedType.hero(context, size: 72)),
          ),
          const SizedBox(height: 18),
          for (var row = 0; row < cells.length; row += 2)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  Expanded(child: _PosterCell(cells[row], palette.accent)),
                  Expanded(
                    child: row + 1 < cells.length
                        ? _PosterCell(cells[row + 1], palette.accent)
                        : const SizedBox(),
                  ),
                ],
              ),
            ),
          if (pick != null || personality != null)
            Divider(height: 18, color: Colors.white.withValues(alpha: 0.15)),
          if (pick != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                WrappedCover(book: pick.$1, width: 40, palette: palette),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('BOOK OF THE YEAR',
                          style: WrappedType.eyebrow(context)
                              .copyWith(fontSize: 10)),
                      const SizedBox(height: 3),
                      Text(pick.$1.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: WrappedType.title(context, size: 16)),
                    ],
                  ),
                ),
              ],
            ),
          ],
          if (personality != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                  child: Icon(personalityIcon(personality.trait),
                      size: 20, color: palette.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('READER PERSONALITY',
                          style: WrappedType.eyebrow(context)
                              .copyWith(fontSize: 10)),
                      const SizedBox(height: 3),
                      Text(personality.title,
                          style: WrappedType.title(context, size: 16)),
                      // The figure that earned it — without it, the label
                      // reads as arbitrary to anyone seeing the card cold.
                      const SizedBox(height: 2),
                      Text(personality.evidence,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: WrappedType.caption(context, alpha: 0.7)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PosterCell extends StatelessWidget {
  final (String, String) cell;
  final Color accent;

  const _PosterCell(this.cell, this.accent);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(cell.$1,
              maxLines: 1, style: WrappedType.hero(context, size: 38)),
        ),
        const SizedBox(height: 2),
        Text(cell.$2,
            style: WrappedType.caption(context, alpha: 0.75)
                .copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
