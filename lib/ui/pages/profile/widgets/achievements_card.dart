import 'package:flutter/material.dart';
import 'package:read_stats/domain/badges.dart';
import 'package:read_stats/domain/reading_activity.dart';
import 'package:read_stats/domain/reading_stats.dart';
import 'package:read_stats/domain/seasons.dart';
import 'package:read_stats/ui/pages/profile/activity_page.dart';

/// Profile's Achievements section: the medals most recently earned, lifetime
/// and seasonal together, and the one nearest to being earned next. Both
/// walls are a tap away, on the Achievements screen.
class AchievementsCard extends StatelessWidget {
  static const _recentMedalCount = 3;

  final List<Map<String, dynamic>> books;
  final List<Map<String, dynamic>> sessions;

  /// Lifetime stats.
  final ReadingStats stats;

  /// The activity feed, newest first; its medal entries are the recent ones.
  final List<ActivityEntry> activity;
  final Color accent;

  /// Opens the Achievements screen.
  final VoidCallback onOpen;

  /// Opens a medal's ladder — a seasonal one against its season.
  final void Function(ReadingGoal goal, Season? season) onMedalTap;

  const AchievementsCard({
    super.key,
    required this.books,
    required this.sessions,
    required this.stats,
    required this.activity,
    required this.accent,
    required this.onOpen,
    required this.onMedalTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final season = Season.of(DateTime.now());
    final inSeason = seasonStats(season, books, sessions);

    final recent = activity
        .where((e) => e.kind == ActivityKind.badge)
        .take(_recentMedalCount)
        .toList();

    // Every medal with a rung still to reach, nearest first, as the share of
    // the way to that rung. Ones not started yet aren't "next".
    final upcoming = <(double, ReadingGoal, GoalTier, ReadingStats, Season?)>[
      for (final (goals, stats, of) in [
        (kSeasonGoals, inSeason, season as Season?),
        (kGoals, this.stats, null as Season?),
      ])
        for (final goal in goals)
          if (goal.nextTier(stats) case final next?)
            if (goal.measure(stats) > 0)
              (goal.measure(stats) / next.threshold, goal, next, stats, of),
    ]..sort((a, b) => b.$1.compareTo(a.$1));
    // With nothing earned yet the card is all "next"; otherwise one is enough.
    final next = upcoming.take(recent.isEmpty ? _recentMedalCount : 1);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onOpen,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Text(
                  'Achievements',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  'See all',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: onOpen,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
                    child: Row(
                      children: [
                        Icon(season.icon, size: 16, color: season.color),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${season.name} · '
                            '${earnedSeasonMilestones(inSeason)} of '
                            '$totalSeasonMilestones'
                            '   Lifetime · ${earnedMilestones(stats)} of '
                            '$totalMilestones',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: muted,
                            ),
                          ),
                        ),
                        Icon(Icons.chevron_right, size: 18, color: muted),
                      ],
                    ),
                  ),
                ),
                if (recent.isEmpty && next.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(
                      'Finish a book or log a session to earn your first '
                      'medal.',
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ),
                for (final e in recent)
                  ActivityTile(
                    entry: e,
                    accent: accent,
                    onTap: () => onMedalTap(e.badge!, e.season),
                  ),
                for (final (share, goal, tier, stats, of) in next)
                  _nextMedal(theme, share, goal, tier, stats, of),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// A medal not yet earned and how far along it is: "Next: Half Dozen",
  /// "Fall 2026 · 5 of 6 books", and a bar.
  Widget _nextMedal(
    ThemeData theme,
    double share,
    ReadingGoal goal,
    GoalTier tier,
    ReadingStats stats,
    Season? season,
  ) {
    final muted = theme.colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: () => onMedalTap(goal, season),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Matches the medal rows above it, but unearned: no tier colour.
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(goal.icon, size: 18, color: muted),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      style: theme.textTheme.bodyMedium,
                      children: [
                        const TextSpan(text: 'Next: '),
                        TextSpan(
                          text: tier.title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${season?.name ?? 'Lifetime'} · '
                    '${goal.formatShortValue(goal.measure(stats))} of '
                    '${goal.formatValue(tier.threshold)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: share.clamp(0, 1).toDouble(),
                      minHeight: 4,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation(accent),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
