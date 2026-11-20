import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:read_stats/ui/pages/book/widgets/detail_section.dart';

/// The book's latest sessions, newest first, each opening its edit form;
/// a link to the rest when there are more.
class BookSessionsSection extends StatelessWidget {
  static const _recent = 3;

  /// Newest first. Must not be empty.
  final List<Map<String, dynamic>> sessions;
  final void Function(Map<String, dynamic> session) onTapSession;
  final VoidCallback onShowAll;

  const BookSessionsSection({
    super.key,
    required this.sessions,
    required this.onTapSession,
    required this.onShowAll,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final shown = sessions.take(_recent).toList();
    final more = sessions.length > _recent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DetailHeading(
          more ? 'Recent sessions' : 'Sessions',
          trailing: more ? 'All ${sessions.length}' : null,
          onTrailing: more ? onShowAll : null,
        ),
        Material(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < shown.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    indent: 64,
                    color: cs.outlineVariant.withValues(alpha: 0.5),
                  ),
                _row(theme, shown[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(ThemeData theme, Map<String, dynamic> s) {
    final cs = theme.colorScheme;
    final date = DetailFormat.parse(s['date']);
    final minutes = (s['duration_minutes'] as int?) ?? 0;
    final pages = (s['pages_read'] as int?) ?? 0;
    final notes = (s['notes'] as String?)?.trim() ?? '';
    final detail = [
      if (pages > 0) '$pages pp',
      if (pages > 0 && minutes > 0) '${(pages * 60 / minutes).round()}/hr',
    ].join(' · ');
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: cs.onSurfaceVariant,
    );

    return InkWell(
      onTap: () => onTapSession(s),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Row(
          children: [
            // Day of the month over its month, like a calendar tile.
            SizedBox(
              width: 36,
              child: Column(
                children: [
                  Text(
                    date == null ? '–' : DateFormat('d').format(date),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    date == null
                        ? ''
                        : DateFormat('MMM').format(date).toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    date == null ? '' : DateFormat('EEEE').format(date),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (notes.isNotEmpty)
                    Text(
                      notes,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: muted,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (minutes > 0)
                  Text(
                    DetailFormat.time(minutes),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (detail.isNotEmpty) Text(detail, style: muted),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
