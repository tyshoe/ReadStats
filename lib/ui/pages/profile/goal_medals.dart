import 'package:flutter/material.dart';

import 'badges.dart';
import 'reading_stats.dart';

// ── Goal tile (progress ring + tiered medal) ──────────────────────────────────

class GoalTile extends StatelessWidget {
  final ReadingGoal goal;
  final ReadingStats stats;
  final Color accent;
  final VoidCallback onTap;

  const GoalTile({
    super.key,
    required this.goal,
    required this.stats,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tier = goal.highestTier(stats);
    final started = tier != null;
    final tierColor = started ? badgeTierColor(tier.tier) : null;
    final muted = theme.colorScheme.onSurfaceVariant;

    // Unearned badges deliberately recede so they don't compete with the
    // metallic tier colors (silver especially): a faint neutral track, a barely
    // tinted well, and a dimmed icon read as "locked", not as a medal.
    final ringValue = goal.isComplete(stats) ? 1.0 : goal.progress(stats);
    final ringTrack = started
        ? theme.colorScheme.surfaceContainerHighest
        : theme.colorScheme.surfaceContainerHighest.withAlpha(110);
    final ringColor = started ? tierColor! : muted.withAlpha(45);
    final wellColor = started
        ? tierColor!.withAlpha(38)
        : theme.colorScheme.surfaceContainerHighest.withAlpha(80);
    final iconColor = started ? tierColor! : muted.withAlpha(75);
    final labelColor =
        started ? theme.colorScheme.onSurface : muted.withAlpha(130);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 54,
              height: 54,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 54,
                    height: 54,
                    child: CircularProgressIndicator(
                      value: ringValue,
                      strokeWidth: 3,
                      backgroundColor: ringTrack,
                      valueColor: AlwaysStoppedAnimation(ringColor),
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: wellColor,
                    ),
                    child: Icon(goal.icon, size: 21, color: iconColor),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              goal.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: labelColor,
                fontWeight: started ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Goal detail sheet (tier ladder) ───────────────────────────────────────────

/// A medal's ladder: the rank reached, how far the next rung is, and every
/// tier with its threshold.
///
/// [caption] sits under the title to say what the numbers are counted over —
/// a season's name, for a seasonal medal. [ended] is for a season that is
/// over: there is no next rung to point at, so the sheet says where it
/// finished instead.
class GoalDetailSheet extends StatelessWidget {
  final ReadingGoal goal;
  final ReadingStats stats;
  final Color accent;
  final String? caption;
  final bool ended;

  const GoalDetailSheet({
    super.key,
    required this.goal,
    required this.stats,
    required this.accent,
    this.caption,
    this.ended = false,
  });

  /// Shows the sheet for [goal] measured against [stats].
  static void show(
    BuildContext context, {
    required ReadingGoal goal,
    required ReadingStats stats,
    required Color accent,
    String? caption,
    bool ended = false,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => GoalDetailSheet(
        goal: goal,
        stats: stats,
        accent: accent,
        caption: caption,
        ended: ended,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final achievedIndex = goal.achievedIndex(stats);
    final current = goal.measure(stats);
    final highest = goal.highestTier(stats);
    final next = goal.nextTier(stats);
    final remaining = goal.remainingToNext(stats);
    final complete = goal.isComplete(stats);
    final headColor =
        highest != null ? badgeTierColor(highest.tier) : theme.colorScheme.onSurfaceVariant;

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: highest != null
                      ? headColor.withAlpha(36)
                      : theme.colorScheme.surfaceContainerHighest,
                  border: Border.all(
                    color: highest != null ? headColor : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Icon(goal.icon, size: 38, color: headColor),
              ),
              const SizedBox(height: 14),
              Text(
                goal.title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (caption != null) ...[
                const SizedBox(height: 4),
                Text(
                  caption!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              // Current rank chip.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: highest != null
                      ? headColor.withAlpha(30)
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: highest != null
                        ? headColor.withAlpha(110)
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      highest != null
                          ? Icons.workspace_premium_rounded
                          : Icons.lock_open_rounded,
                      size: 14,
                      color: headColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      highest != null
                          ? '${badgeTierLabel(highest.tier)} · ${highest.title}'
                          : 'Unranked',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: headColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Forward path — one line: how far, and the reward it unlocks.
              if (ended && !complete) ...[
                Text(
                  current > 0
                      ? 'Finished with ${goal.formatValue(current)}'
                      : 'Nothing counted this season',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
              ] else if (!complete && next != null) ...[
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${goal.formatValue(remaining ?? 0)} ',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: accent,
                        ),
                      ),
                      TextSpan(
                        text: 'until ',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      TextSpan(
                        text: next.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: goal.progress(stats),
                    minHeight: 8,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(accent),
                  ),
                ),
                const SizedBox(height: 6),
                // The bar spans the tier already earned to the next one, so the
                // ends label those bounds. The live count sits between them,
                // where it reads as a position on that span rather than as the
                // bar's origin.
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        goal.formatShortValue(highest?.threshold ?? 0),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: goal.formatShortValue(current),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextSpan(
                            // "so far" is what separates this from the two
                            // bounds either side of it — without it, three bare
                            // numbers read as three tick marks. Percentage is
                            // of this tier's span, matching the bar above, not
                            // of the whole ladder.
                            text: ' so far · '
                                '${(goal.progress(stats) * 100).round()}%',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Text(
                        goal.formatShortValue(next.threshold),
                        textAlign: TextAlign.end,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ] else if (complete) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.verified_rounded, size: 18, color: headColor),
                    const SizedBox(width: 6),
                    Text(
                      'Maxed out — ${goal.formatValue(current)} total',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: headColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
              Divider(color: theme.dividerColor.withAlpha(80)),
              const SizedBox(height: 4),
              // Tier ladder — the next tier is highlighted so the goal still
              // points forward even while showing what's already earned.
              ...List.generate(goal.tiers.length, (i) {
                final t = goal.tiers[i];
                final earned = i <= achievedIndex;
                final isNext = !ended && i == achievedIndex + 1;
                final color = badgeTierColor(t.tier);
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: isNext ? accent.withAlpha(22) : null,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        earned
                            ? Icons.check_circle
                            : (isNext
                                ? Icons.radio_button_unchecked
                                : Icons.lock_outline),
                        size: 20,
                        color: earned
                            ? color
                            : (isNext
                                ? accent
                                : theme.colorScheme.onSurfaceVariant
                                    .withAlpha(120)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          t.title,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: (earned || isNext)
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: (earned || isNext)
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Text(
                        goal.formatShortValue(t.threshold),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isNext
                              ? accent
                              : theme.colorScheme.onSurfaceVariant,
                          fontWeight:
                              isNext ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
