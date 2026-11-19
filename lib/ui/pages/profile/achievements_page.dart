import 'package:flutter/material.dart';
import 'package:read_stats/domain/badges.dart';
import 'package:read_stats/domain/reading_stats.dart';
import 'package:read_stats/domain/seasons.dart';
import 'package:read_stats/ui/pages/profile/seasons_page.dart';
import 'package:read_stats/ui/pages/profile/widgets/goal_medals.dart';

/// Opens a medal's ladder, measured the way that medal is: a seasonal one
/// against its own [season], captioned with it, and a lifetime one against
/// everything.
void showMedalDetail(
  BuildContext context, {
  required ReadingGoal goal,
  required List<Map<String, dynamic>> books,
  required List<Map<String, dynamic>> sessions,
  required Color accent,
  Season? season,
}) {
  if (season == null) {
    GoalDetailSheet.show(
      context,
      goal: goal,
      stats: ReadingStats.from(books: books, sessions: sessions),
      accent: accent,
    );
    return;
  }
  GoalDetailSheet.show(
    context,
    goal: goal,
    stats: seasonStats(season, books, sessions),
    accent: accent,
    caption: season.name,
    ended: !season.contains(DateTime.now()),
  );
}

/// Every medal there is, in two tabs: the seasons, which start over four
/// times a year, and the lifetime wall, which only ever fills up.
///
/// Profile shows the latest few earned and the next one in reach; this is
/// where the full walls live.
class AchievementsPage extends StatelessWidget {
  final List<Map<String, dynamic>> books;
  final List<Map<String, dynamic>> sessions;
  final Color accent;

  const AchievementsPage({
    super.key,
    required this.books,
    required this.sessions,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final stats = ReadingStats.from(books: books, sessions: sessions);
    final bottom = 24 + MediaQuery.paddingOf(context).bottom;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Achievements'),
          bottom: TabBar(
            indicatorColor: accent,
            labelColor: accent,
            dividerColor: theme.dividerColor.withAlpha(128),
            dividerHeight: .25,
            unselectedLabelColor: theme.colorScheme.onSurface.withAlpha(160),
            tabs: const [
              Tab(height: 40, text: 'Seasons'),
              Tab(height: 40, text: 'Lifetime'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            SeasonsList(books: books, sessions: sessions, accent: accent),
            ListView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, bottom),
              children: [
                Text(
                  '${earnedMilestones(stats)} of $totalMilestones earned',
                  style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                ),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 8,
                    mainAxisExtent: 96,
                  ),
                  itemCount: kGoals.length,
                  itemBuilder: (context, index) {
                    final goal = kGoals[index];
                    return GoalTile(
                      goal: goal,
                      stats: stats,
                      accent: accent,
                      onTap: () => GoalDetailSheet.show(
                        context,
                        goal: goal,
                        stats: stats,
                        accent: accent,
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
