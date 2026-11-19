import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:read_stats/domain/badges.dart';
import 'package:read_stats/domain/reading_activity.dart';
import 'package:read_stats/ui/widgets/book_cover.dart';

/// The kinds the full feed can be narrowed to.
enum _ActivityFilter {
  all('All'),
  finished('Finished'),
  started('Started'),
  added('Added'),
  setAside('Set aside'),
  goals('Goals'),
  badges('Badges');

  final String label;
  const _ActivityFilter(this.label);

  bool matches(ActivityKind kind) => switch (this) {
        _ActivityFilter.all => true,
        _ActivityFilter.finished => kind == ActivityKind.finished,
        _ActivityFilter.started => kind == ActivityKind.started,
        _ActivityFilter.added =>
          kind == ActivityKind.added || kind == ActivityKind.addedBooks,
        _ActivityFilter.setAside => kind == ActivityKind.setAside,
        _ActivityFilter.goals => kind == ActivityKind.goalMet,
        _ActivityFilter.badges => kind == ActivityKind.badge,
      };
}

/// The whole activity feed, a month at a time. Profile shows the latest few.
class ActivityPage extends StatefulWidget {
  final List<ActivityEntry> entries;
  final Color accent;

  /// Opens a medal's detail sheet. Handed the entry, not just the medal: a
  /// seasonal one is measured against the season it was earned in.
  final void Function(ActivityEntry entry)? onBadgeTap;

  const ActivityPage({
    super.key,
    required this.entries,
    required this.accent,
    this.onBadgeTap,
  });

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  _ActivityFilter _filter = _ActivityFilter.all;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Only offer the kinds the reader actually has — a "Set aside" chip that
    // empties the page is a dead end.
    final filters = [
      for (final f in _ActivityFilter.values)
        if (f == _ActivityFilter.all ||
            widget.entries.any((e) => f.matches(e.kind)))
          f,
    ];

    // Entries are newest first, so each month's run is contiguous.
    final months = <(DateTime, List<ActivityEntry>)>[];
    for (final e in widget.entries) {
      if (!_filter.matches(e.kind)) continue;
      final month = DateTime(e.date.year, e.date.month);
      if (months.isEmpty || months.last.$1 != month) months.add((month, []));
      months.last.$2.add(e);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
        bottom: filters.length <= 2
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: _buildFilters(theme, filters),
              ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        itemCount: months.length,
        itemBuilder: (context, i) {
          final (month, monthEntries) = months[i];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
                child: Text(
                  DateFormat('MMMM y').format(month),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ActivityCard(
                entries: monthEntries,
                accent: widget.accent,
                onBadgeTap: widget.onBadgeTap,
              ),
            ],
          );
        },
      ),
    );
  }

  /// Same chip look as the year filter on Statistics.
  Widget _buildFilters(ThemeData theme, List<_ActivityFilter> filters) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(
        height: 32,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            for (final f in filters)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: Text(f.label),
                  selected: _filter == f,
                  onSelected: (_) => setState(() => _filter = f),
                  showCheckmark: false,
                  labelStyle: theme.textTheme.bodySmall,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  selectedColor: theme.colorScheme.primaryContainer,
                  elevation: 0,
                  pressElevation: 0,
                  side: BorderSide.none,
                  shape: const StadiumBorder(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A run of activity rows in the Profile card style.
class ActivityCard extends StatelessWidget {
  final List<ActivityEntry> entries;
  final Color accent;
  final void Function(ActivityEntry entry)? onBadgeTap;

  const ActivityCard({
    super.key,
    required this.entries,
    required this.accent,
    this.onBadgeTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            for (final e in entries)
              ActivityTile(
                entry: e,
                accent: accent,
                onTap: e.badge != null && onBadgeTap != null
                    ? () => onBadgeTap!(e)
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}

/// One activity row: cover or icon, what happened, and when.
class ActivityTile extends StatelessWidget {
  final ActivityEntry entry;
  final Color accent;
  final VoidCallback? onTap;

  const ActivityTile({
    super.key,
    required this.entry,
    required this.accent,
    this.onTap,
  });

  static const _leadingSize = 36.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final base = theme.textTheme.bodyMedium;
    final strong = base?.copyWith(fontWeight: FontWeight.w600);
    final detail = _detail();

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: _leadingSize,
              child: Center(child: _leading(theme)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text.rich(
                    TextSpan(
                      style: base,
                      children: _title(strong),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (detail != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              ReadingActivity.dateLabel(entry.date),
              style: theme.textTheme.labelSmall?.copyWith(color: muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _leading(ThemeData theme) {
    final cover = entry.book?['cover_path'] as String?;
    if (cover != null && cover.isNotEmpty) {
      return BookCover(
        path: cover,
        shape: entry.book!['cover_shape'] as int?,
        width: 30,
        borderRadius: 4,
      );
    }

    final (icon, color) = switch (entry.kind) {
      ActivityKind.addedBooks || ActivityKind.added => (Icons.library_add, accent),
      ActivityKind.started => (Icons.auto_stories, accent),
      ActivityKind.finished => (Icons.check_circle, accent),
      ActivityKind.setAside =>
        (Icons.pause_circle, theme.colorScheme.onSurfaceVariant),
      ActivityKind.goalMet => (Icons.flag, accent),
      ActivityKind.badge =>
        (entry.badge!.icon, badgeTierColor(entry.tier!.tier)),
    };
    return Container(
      width: _leadingSize,
      height: _leadingSize,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }

  List<InlineSpan> _title(TextStyle? strong) {
    final bookTitle = TextSpan(
      text: entry.book?['title']?.toString() ?? 'Untitled',
      style: strong,
    );
    return switch (entry.kind) {
      ActivityKind.addedBooks => [
          const TextSpan(text: 'Added '),
          TextSpan(text: '${entry.count} books', style: strong),
        ],
      ActivityKind.added => [const TextSpan(text: 'Added '), bookTitle],
      ActivityKind.started => [const TextSpan(text: 'Started '), bookTitle],
      ActivityKind.finished => [const TextSpan(text: 'Finished '), bookTitle],
      ActivityKind.setAside => [const TextSpan(text: 'Set aside '), bookTitle],
      ActivityKind.goalMet => [
          const TextSpan(text: 'Met your '),
          TextSpan(
            text: '${entry.goal!.period.label.toLowerCase()} goal',
            style: strong,
          ),
        ],
      ActivityKind.badge => [
          const TextSpan(text: 'Earned '),
          TextSpan(text: entry.tier!.title, style: strong),
        ],
    };
  }

  String? _detail() {
    switch (entry.kind) {
      case ActivityKind.addedBooks:
        return null;
      case ActivityKind.goalMet:
        final metric = entry.goal!.metric;
        return '${metric.label} · ${metric.unitLabel(entry.target)}';
      case ActivityKind.badge:
        return [
          if (entry.season case final season?) season.name,
          badgeTierLabel(entry.tier!.tier),
          entry.badge!.formatValue(entry.tier!.threshold),
        ].join(' · ');
      case ActivityKind.added:
      case ActivityKind.started:
      case ActivityKind.setAside:
      case ActivityKind.finished:
        final author = entry.book?['author']?.toString().trim() ?? '';
        final rating = _rating();
        final parts = [
          if (author.isNotEmpty) author,
          if (entry.kind == ActivityKind.finished && rating != null) rating,
        ];
        return parts.isEmpty ? null : parts.join(' · ');
    }
  }

  String? _rating() {
    final raw = entry.book?['rating'];
    final r = raw is num ? raw.toDouble() : double.tryParse('$raw');
    if (r == null || r <= 0) return null;
    final text = r == r.roundToDouble() ? r.toInt().toString() : r.toString();
    return '★ $text';
  }
}
