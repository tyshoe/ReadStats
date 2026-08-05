import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/data/services/milestone_service.dart';
import 'badges.dart';
import 'reading_stats.dart';

/// Full-screen celebration shown the moment a badge tier is earned.
///
/// Presented as a non-opaque route so it reads as an overlay dropped on top of
/// wherever the reader happened to be — usually the session they just saved.
/// Several tiers can fall at once (one long session crosses pages, minutes and
/// sessions together), so this pages through them rather than stacking dialogs.
class MilestoneCelebrationPage extends StatefulWidget {
  final List<MilestoneUnlock> unlocks;
  final ReadingStats stats;

  const MilestoneCelebrationPage({
    super.key,
    required this.unlocks,
    required this.stats,
  });

  /// Fades in over the current screen instead of sliding a new page in — the
  /// medal arriving in place is the whole effect.
  static Route<void> route({
    required List<MilestoneUnlock> unlocks,
    required ReadingStats stats,
  }) {
    return PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, _, _) =>
          MilestoneCelebrationPage(unlocks: unlocks, stats: stats),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    );
  }

  @override
  State<MilestoneCelebrationPage> createState() =>
      _MilestoneCelebrationPageState();
}

class _MilestoneCelebrationPageState extends State<MilestoneCelebrationPage>
    with TickerProviderStateMixin {
  late final AnimationController _entry;
  late final AnimationController _burst;
  int _index = 0;

  MilestoneUnlock get _unlock => widget.unlocks[_index];
  bool get _isLast => _index == widget.unlocks.length - 1;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
    _burst = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _play();
  }

  @override
  void dispose() {
    _entry.dispose();
    _burst.dispose();
    super.dispose();
  }

  void _play() {
    _entry.forward(from: 0);
    _burst.forward(from: 0);
    HapticFeedback.mediumImpact();
  }

  void _advance() {
    if (_isLast) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _index += 1);
    _play();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final goal = _unlock.goal;
    final tier = _unlock.tier;
    final tierColor = badgeTierColor(tier.tier);
    // Honour the OS "reduce motion" switch: the medal still fades in, but the
    // confetti and the overshoot on the scale are dropped.
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    final fade = CurvedAnimation(
      parent: _entry,
      curve: const Interval(0.25, 1, curve: Curves.easeOut),
    );

    return Scaffold(
      backgroundColor: cs.surface.withValues(alpha: 0.97),
      body: Stack(
        children: [
          // Tier-coloured wash behind the medal, strongest at its centre.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.35),
                  radius: 0.9,
                  colors: [
                    tierColor.withValues(alpha: 0.22),
                    tierColor.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          if (!reduceMotion)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _burst,
                  builder: (context, _) => CustomPaint(
                    painter: _ConfettiPainter(
                      progress: _burst.value,
                      seed: _index,
                      colors: [tierColor, cs.primary, cs.tertiary],
                    ),
                  ),
                ),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      color: cs.onSurfaceVariant,
                      tooltip: 'Dismiss',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildMedal(tierColor, goal, reduceMotion),
                        const SizedBox(height: 32),
                        FadeTransition(
                          opacity: fade,
                          child: Column(
                            children: [
                              Text(
                                '${badgeTierLabel(tier.tier).toUpperCase()} '
                                'UNLOCKED',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: tierColor,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.6,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                tier.title,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                goal.title,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 24),
                              _buildFooter(theme, goal, tierColor),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  FadeTransition(
                    opacity: fade,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        children: [
                          if (widget.unlocks.length > 1)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _buildDots(cs, tierColor),
                            ),
                          FilledButton(
                            onPressed: _advance,
                            style: FilledButton.styleFrom(
                              backgroundColor: tierColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 40,
                                vertical: 14,
                              ),
                            ),
                            child: Text(_isLast ? 'Nice' : 'Next'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The medal, scaled up from the Profile grid's tile so the two read as the
  /// same object. Springs in past its final size, then settles.
  Widget _buildMedal(Color tierColor, ReadingGoal goal, bool reduceMotion) {
    final scale = CurvedAnimation(
      parent: _entry,
      curve: reduceMotion ? Curves.easeOut : Curves.elasticOut,
    );
    return ScaleTransition(
      scale: Tween<double>(begin: reduceMotion ? 0.9 : 0.4, end: 1).animate(
        scale,
      ),
      child: Container(
        width: 156,
        height: 156,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: tierColor.withValues(alpha: 0.34),
              blurRadius: 44,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 156,
              height: 156,
              child: CircularProgressIndicator(
                value: 1,
                strokeWidth: 5,
                backgroundColor: tierColor.withValues(alpha: 0.18),
                valueColor: AlwaysStoppedAnimation(tierColor),
              ),
            ),
            Container(
              width: 118,
              height: 118,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tierColor.withValues(alpha: 0.16),
              ),
              child: Icon(goal.icon, size: 58, color: tierColor),
            ),
          ],
        ),
      ),
    );
  }

  /// Where the reader stands now, and what the next rung costs — a milestone
  /// screen that only looked backward would end the moment instead of feeding
  /// it forward.
  Widget _buildFooter(ThemeData theme, ReadingGoal goal, Color tierColor) {
    final cs = theme.colorScheme;
    final next = goal.nextTier(widget.stats);
    final total = goal.formatValue(goal.measure(widget.stats));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            total,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            next == null
                ? 'Every tier earned.'
                : 'Next: ${next.title} at '
                    '${goal.formatShortValue(next.threshold)}',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDots(ColorScheme cs, Color tierColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < widget.unlocks.length; i++)
          Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == _index
                  ? tierColor
                  : cs.onSurfaceVariant.withValues(alpha: 0.3),
            ),
          ),
      ],
    );
  }
}

/// A one-shot confetti fall. Particles are seeded per unlock index so each
/// medal in a run gets its own arrangement, and derived from [progress] rather
/// than stored, so there is no per-frame allocation.
class _ConfettiPainter extends CustomPainter {
  final double progress;
  final int seed;
  final List<Color> colors;

  static const int _count = 46;

  _ConfettiPainter({
    required this.progress,
    required this.seed,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress >= 1) return;
    final rng = math.Random(seed * 7919 + 13);
    final paint = Paint();

    for (var i = 0; i < _count; i++) {
      final startX = rng.nextDouble() * size.width;
      final drift = (rng.nextDouble() - 0.5) * 140;
      final delay = rng.nextDouble() * 0.25;
      final spin = (rng.nextDouble() - 0.5) * 12;
      final w = 5.0 + rng.nextDouble() * 5;
      final h = 8.0 + rng.nextDouble() * 6;
      final color = colors[i % colors.length];

      final t = ((progress - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;

      // Ease the fall so pieces decelerate slightly as they clear the screen,
      // and fade the last third out rather than clipping at the bottom edge.
      final y = -40 + (size.height + 80) * t * t * 0.85 + (size.height * t * 0.2);
      final x = startX + drift * t;
      final opacity = t > 0.7 ? (1 - (t - 0.7) / 0.3).clamp(0.0, 1.0) : 1.0;

      paint.color = color.withValues(alpha: opacity * 0.9);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(spin * t);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: w, height: h),
          const Radius.circular(1.5),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) =>
      old.progress != progress || old.seed != seed;
}
