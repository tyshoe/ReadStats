import 'package:flutter/material.dart';

import 'goal_medals.dart';
import 'reading_stats.dart';
import 'seasons.dart';

/// One season's medals as the Achievements wall draws them, four across.
/// Tapping one opens its ladder, captioned with the season — and, for a
/// season that is over, saying where it finished rather than what is next.
class SeasonMedalGrid extends StatelessWidget {
  final Season season;

  /// The season's [seasonStats].
  final ReadingStats stats;
  final Color accent;

  const SeasonMedalGrid({
    super.key,
    required this.season,
    required this.stats,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final ended = !season.contains(DateTime.now());
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 12,
        crossAxisSpacing: 8,
        // A fixed height, not a ratio: inside a season's card the tiles are
        // narrower than on Profile, and a ratio would squeeze the label out.
        mainAxisExtent: 96,
      ),
      itemCount: kSeasonGoals.length,
      itemBuilder: (context, index) {
        final goal = kSeasonGoals[index];
        return GoalTile(
          goal: goal,
          stats: stats,
          accent: accent,
          onTap: () => GoalDetailSheet.show(
            context,
            goal: goal,
            stats: stats,
            accent: accent,
            caption: season.name,
            ended: ended,
          ),
        );
      },
    );
  }
}

/// Every season the reader has read in, newest first, each with the medals
/// it ended on.
///
/// Nothing is stored for this: a season's medals are worked out from the
/// sessions and finish dates inside it, so seasons from before the feature
/// existed are here too, and editing an old session changes its season.
class SeasonsPage extends StatelessWidget {
  final List<Map<String, dynamic>> books;
  final List<Map<String, dynamic>> sessions;
  final Color accent;

  const SeasonsPage({
    super.key,
    required this.books,
    required this.sessions,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final now = DateTime.now();
    final seasons = seasonsWithReading(books, sessions, now);

    return Scaffold(
      appBar: AppBar(title: const Text('Seasons')),
      body: ListView.separated(
        padding: EdgeInsets.fromLTRB(
            16, 8, 16, 24 + MediaQuery.paddingOf(context).bottom),
        itemCount: seasons.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final season = seasons[index];
          final stats = seasonStats(season, books, sessions);
          final current = season.contains(now);

          return Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(season.icon, size: 18, color: season.color),
                    const SizedBox(width: 8),
                    Text(
                      season.name,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Text(
                      '${earnedSeasonMilestones(stats)} of '
                      '$totalSeasonMilestones',
                      style:
                          theme.textTheme.bodyMedium?.copyWith(color: muted),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    current ? 'In progress' : season.months,
                    _summary(stats),
                  ].join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
                const SizedBox(height: 10),
                SeasonMedalGrid(season: season, stats: stats, accent: accent),
              ],
            ),
          );
        },
      ),
    );
  }

  /// "4 books · 31h"
  static String _summary(ReadingStats stats) {
    final books = stats.booksFinished;
    return '$books ${books == 1 ? 'book' : 'books'} · ${stats.totalHours}h';
  }
}
