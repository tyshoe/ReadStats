import 'package:flutter/material.dart';
import 'package:read_stats/data/models/tag.dart';

/// The book's tags under the cover, each opening the tag editor.
class BookTagsRow extends StatelessWidget {
  final List<Tag> tags;

  /// Drawn over the blurred cover art rather than the plain page.
  final bool onArt;
  final VoidCallback onTap;

  const BookTagsRow({
    super.key,
    required this.tags,
    required this.onArt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = onArt
        ? Colors.white.withValues(alpha: 0.75)
        : theme.colorScheme.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6, right: 10),
          child: Icon(Icons.sell, size: 16, color: muted),
        ),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tag in tags) _chip(theme, tag.name, filled: true),
              _chip(theme, tags.isEmpty ? 'Add tags' : 'Add', icon: Icons.add),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chip(
    ThemeData theme,
    String label, {
    bool filled = false,
    IconData? icon,
  }) {
    final cs = theme.colorScheme;
    // The outlined "Add" chip goes white over the art, where theme outlines
    // vanish.
    final fg = filled
        ? cs.onSecondaryContainer
        : onArt
        ? Colors.white.withValues(alpha: 0.85)
        : cs.onSurfaceVariant;
    final outline = onArt
        ? Colors.white.withValues(alpha: 0.45)
        : cs.outlineVariant;
    return Material(
      color: filled ? cs.secondaryContainer : Colors.transparent,
      shape: StadiumBorder(
        side: filled ? BorderSide.none : BorderSide(color: outline),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: fg),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
