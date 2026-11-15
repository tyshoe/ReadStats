import 'package:flutter/material.dart';

/// A book as one bar: what was logged before this session, what this session
/// adds, and what is left — in pages for a paper book, minutes for an
/// audiobook.
///
/// What was logged in sessions after this one sits with "before" in the
/// figures and after the session on the bar, so the session keeps its place
/// in the book when an earlier one is being edited.
class SessionProgressBar extends StatelessWidget {
  /// The book's length.
  final int total;
  final int before;
  final int session;
  final int after;

  /// What to call the first figure: "Read before", "Listened before".
  final String beforeLabel;

  /// A figure with its unit: "34 pages", "1h 5m".
  final String Function(int value) format;

  const SessionProgressBar({
    super.key,
    required this.total,
    required this.before,
    required this.session,
    this.after = 0,
    required this.beforeLabel,
    required this.format,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.primaryColor;
    final track = theme.colorScheme.surfaceContainerHighest;
    final earlier = color.withValues(alpha: 0.4);
    final left = (total - before - session - after).clamp(0, total);

    final segments = <(int, Color)>[
      (before, earlier),
      (session, color),
      (after, earlier),
      (left, track),
    ].where((s) => s.$1 > 0).toList();

    final shares = _wholeShares([before + after, session, left]);

    Widget figure(String label, int value, int share, Color dot,
        {bool strong = false}) {
      final muted = theme.colorScheme.onSurfaceVariant;
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(color: dot, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(color: muted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${format(value)} · $share%',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: strong ? theme.colorScheme.onSurface : muted,
                fontWeight: strong ? FontWeight.w600 : null,
              ),
            ),
          ],
        ),
      );
    }

    return Semantics(
      label: '$beforeLabel ${format(before + after)} of ${format(total)}, '
          'this session ${format(session)}, left ${format(left)}',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Container(
                height: 10,
                color: track,
                child: Row(
                  children: [
                    for (final (size, fill) in segments)
                      Expanded(flex: size, child: Container(color: fill)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                figure(beforeLabel, before + after, shares[0], earlier),
                const SizedBox(width: 8),
                figure('This session', session, shares[1], color,
                    strong: true),
                const SizedBox(width: 8),
                figure('Left', left, shares[2],
                    theme.colorScheme.outlineVariant),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// [values] as whole percentages of their sum that always add up to 100.
  ///
  /// Rounding each one on its own can leave 99 or 101 — three thirds come to
  /// 33 + 33 + 33. Each is rounded down instead, and the points left over go
  /// to the values that lost the most in the rounding.
  static List<int> _wholeShares(List<int> values) {
    final sum = values.fold<int>(0, (a, b) => a + b);
    if (sum <= 0) return List.filled(values.length, 0);
    final shares = [for (final v in values) v * 100 ~/ sum];
    final remainders = [for (final v in values) v * 100 % sum];
    var spare = 100 - shares.fold<int>(0, (a, b) => a + b);
    final order = List.generate(values.length, (i) => i)
      ..sort((a, b) => remainders[b].compareTo(remainders[a]));
    for (final i in order) {
      if (spare-- <= 0) break;
      shares[i]++;
    }
    return shares;
  }
}
