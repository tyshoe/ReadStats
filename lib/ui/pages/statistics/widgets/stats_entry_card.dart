import 'package:flutter/material.dart';

/// The shared body of the recap and Wrapped entries on Stats: a row with a
/// chevron at full width, or a stacked tile when two of them share a row.
class StatsEntryCard extends StatelessWidget {
  final bool compact;
  final VoidCallback onTap;
  final String title;
  final String subtitle;

  /// Shows a "New" pill: there's something here not yet opened.
  final bool unseen;
  final Color accent;
  final Color iconBackground;
  final Color titleColor;
  final Color mutedColor;
  final Color? pillTextColor;
  final Gradient? gradient;

  const StatsEntryCard({
    super.key,
    required this.compact,
    required this.onTap,
    required this.title,
    required this.subtitle,
    required this.unseen,
    required this.accent,
    required this.iconBackground,
    required this.titleColor,
    required this.mutedColor,
    this.pillTextColor,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(color: iconBackground, shape: BoxShape.circle),
      child: Icon(Icons.auto_awesome, size: 19, color: accent),
    );
    final pill = _NewPill(color: accent, textColor: pillTextColor);
    final titleText = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: titleColor,
      ),
    );
    final subtitleText = Text(
      subtitle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall?.copyWith(color: mutedColor),
    );

    final Widget content = compact
        ? Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [icon, const Spacer(), if (unseen) pill],
                ),
                const SizedBox(height: 10),
                titleText,
                const SizedBox(height: 2),
                subtitleText,
              ],
            ),
          )
        : Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
            child: Row(
              children: [
                icon,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(child: titleText),
                          if (unseen) ...[const SizedBox(width: 8), pill],
                        ],
                      ),
                      const SizedBox(height: 2),
                      subtitleText,
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 22, color: mutedColor),
              ],
            ),
          );

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Ink(
        decoration: gradient == null ? null : BoxDecoration(gradient: gradient),
        child: InkWell(onTap: onTap, child: content),
      ),
    );
  }
}

/// Marks last month's recap as unopened. The notification announcing it is
/// easy to miss and can be switched off, so the page has to be able to say
/// so too.
class _NewPill extends StatelessWidget {
  final Color color;

  /// Defaults to the theme's on-primary, which suits the accent-coloured pill.
  final Color? textColor;

  const _NewPill({required this.color, this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'New',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: textColor ?? Theme.of(context).colorScheme.onPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 10,
          height: 1.2,
        ),
      ),
    );
  }
}
