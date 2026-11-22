import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:read_stats/app_config.dart';
import 'package:read_stats/data/models/community_stats.dart';
import 'package:read_stats/data/services/analytics_service.dart';
import 'package:read_stats/data/services/community_stats_service.dart';
import 'package:read_stats/data/services/rating_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// The first Settings section: what readers have done with ReadStats so far,
/// then the two ways to support it — a tip and a store review — each saying
/// what it does for the app.
///
/// Laid out like every other Settings section (header above a card). Inside,
/// the totals sit straight on the accent-tinted card as its headline, and the
/// two actions are the only raised surfaces, so it's clear what can be
/// tapped. They match on purpose: both are equal ways to help.
///
/// The totals come from [CommunityStatsService] and are only ever real ones:
/// until a published file has been downloaded, the card says why the app is
/// free instead.
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Support ReadStats',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Card(
            margin: EdgeInsets.zero,
            // Tinted with the accent so the one section that asks for
            // something stands out from the plain ones below it.
            color: Color.alphaBlend(
              accent.withValues(alpha: 0.10),
              theme.cardTheme.color ?? theme.colorScheme.surfaceContainerLow,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ValueListenableBuilder<CommunityStats?>(
                    valueListenable: CommunityStatsService.instance.stats,
                    builder: (context, stats, _) =>
                        stats == null || stats.readers == 0
                        ? _Pitch(accent: accent)
                        : _Totals(stats: stats),
                  ),
                  const SizedBox(height: 20),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _SupportAction(
                            icon: Icons.coffee,
                            title: 'Leave a tip',
                            message: 'Keeps ReadStats free, with no ads',
                            accent: accent,
                            onTap: () {
                              AnalyticsService.instance.supportTapped('tip');
                              launchUrl(
                                Uri.parse(AppConfig.supportUrl),
                                mode: LaunchMode.externalApplication,
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _SupportAction(
                            icon: Icons.star,
                            title: 'Rate ReadStats',
                            message: 'Helps new readers discover it',
                            accent: accent,
                            onTap: () {
                              AnalyticsService.instance.supportTapped('rate');
                              RatingService.instance.openStoreListing();
                            },
                          ),
                        ),
                      ],
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
}

/// The community totals: three soft tiles, each a large number over a
/// small icon and label, with a line telling the reader they are part of it.
class _Totals extends StatelessWidget {
  final CommunityStats stats;

  const _Totals({required this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Total(
              icon: Icons.people,
              value: stats.readers,
              label: stats.readers == 1 ? 'reader' : 'readers',
            ),
            const SizedBox(width: 8),
            _Total(
              icon: Icons.menu_book,
              value: stats.booksTracked,
              label: stats.booksTracked == 1 ? 'book' : 'books',
            ),
            const SizedBox(width: 8),
            _Total(
              icon: Icons.schedule,
              value: stats.hoursRead,
              label: stats.hoursRead == 1 ? 'hour read' : 'hours read',
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'Every book and session you log adds to these.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _Total extends StatelessWidget {
  final IconData icon;
  final int value;
  final String label;

  const _Total({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Expanded(
      // A faint wash, not a solid surface: grouped, but clearly not one of
      // the tappable actions below.
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 12, 6, 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                NumberFormat.decimalPattern().format(value),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Grey like every other Settings icon.
                Icon(icon, size: 14, color: muted),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One way to support the app. Both actions use this, so they carry equal
/// weight: a raised surface with an accent badge (the cue that it's tappable),
/// a title, and one line on what it does for ReadStats.
class _SupportAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color accent;
  final VoidCallback onTap;

  const _SupportAction({
    required this.icon,
    required this.title,
    required this.message,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 20, color: accent),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.open_in_new,
                    size: 16,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Before any totals have been published: why the app is free.
class _Pitch extends StatelessWidget {
  final Color accent;

  const _Pitch({required this.accent});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.16),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.favorite, color: accent, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            'ReadStats is free, with no ads and no account. If it has '
            'helped your reading, you can help it back.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
