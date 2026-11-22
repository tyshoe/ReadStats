import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:read_stats/app_config.dart';
import 'package:read_stats/data/models/community_stats.dart';
import 'package:read_stats/data/services/analytics_service.dart';
import 'package:read_stats/data/services/community_stats_service.dart';
import 'package:read_stats/data/services/rating_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// The first Settings section: what readers have done with ReadStats so far,
/// then the two ways to support it — a tip and a store review.
///
/// Laid out like every other Settings section (header above a plain card) so
/// it belongs to the page rather than shouting over it. The totals come from
/// [CommunityStatsService] and are only ever real ones: until a published
/// file has been downloaded, the card says why the app is free instead.
class SupportCard extends StatefulWidget {
  final Color accent;

  const SupportCard({super.key, required this.accent});

  @override
  State<SupportCard> createState() => _SupportCardState();
}

class _SupportCardState extends State<SupportCard> {
  @override
  void initState() {
    super.initState();
    CommunityStatsService.instance.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = widget.accent;
    final onAccent =
        ThemeData.estimateBrightnessForColor(accent) == Brightness.dark
            ? Colors.white
            : Colors.black;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Support ReadStats',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Card(
            margin: EdgeInsets.zero,
            // Tinted with the accent so the one section that asks for
            // something stands out from the plain ones below it.
            color: Color.alphaBlend(
              accent.withValues(alpha: 0.12),
              theme.cardTheme.color ?? theme.colorScheme.surfaceContainerLow,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.favorite, color: onAccent, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: ValueListenableBuilder<CommunityStats?>(
                          valueListenable: CommunityStatsService.instance.stats,
                          builder: (context, stats, _) =>
                              _Message(stats: stats, accent: accent),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: onAccent,
                            minimumSize: const Size.fromHeight(44),
                          ),
                          icon: const Icon(Icons.coffee, size: 18),
                          label: const Text('Leave a tip'),
                          onPressed: () {
                            AnalyticsService.instance.supportTapped('tip');
                            launchUrl(
                              Uri.parse(AppConfig.supportUrl),
                              mode: LaunchMode.externalApplication,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: accent,
                            side: BorderSide(color: accent),
                            minimumSize: const Size.fromHeight(44),
                          ),
                          icon: const Icon(Icons.star, size: 18),
                          label: const Text('Rate app'),
                          onPressed: () {
                            AnalyticsService.instance.supportTapped('rate');
                            RatingService.instance.openStoreListing();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The card's sentence: the community totals with their numbers picked out,
/// or — before any have been published — why the app is free.
class _Message extends StatelessWidget {
  final CommunityStats? stats;
  final Color accent;

  const _Message({required this.stats, required this.accent});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.textTheme.bodyLarge;
    final stats = this.stats;

    if (stats == null || stats.readers == 0) {
      return Text(
        'ReadStats is free, with no ads and no account. If it has helped '
        'your reading, you can help it back.',
        style: base,
      );
    }

    final format = NumberFormat.decimalPattern();
    TextSpan number(int value) => TextSpan(
          text: format.format(value),
          style: TextStyle(color: accent, fontWeight: FontWeight.bold),
        );

    return Text.rich(
      TextSpan(
        style: base,
        children: [
          number(stats.readers),
          TextSpan(text: stats.readers == 1 ? ' reader is' : ' readers are'),
          const TextSpan(text: ' tracking '),
          number(stats.booksTracked),
          const TextSpan(text: ' books with ReadStats, '),
          number(stats.booksFinished),
          const TextSpan(text: ' finished. Thanks for being one of them.'),
        ],
      ),
    );
  }
}
