import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A section title on the book page, with an optional link at the end
/// ("Edit", "All 12").
class DetailHeading extends StatelessWidget {
  final String title;
  final String? trailing;
  final VoidCallback? onTrailing;

  const DetailHeading(this.title, {super.key, this.trailing, this.onTrailing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Row(
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          if (trailing != null)
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onTrailing,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      trailing!,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: theme.colorScheme.primary,
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

/// The rounded card every book page section sits in.
class DetailCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  const DetailCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Small formatters shared by the book page and its sections.
abstract final class DetailFormat {
  static DateTime? parse(Object? v) =>
      v is String ? DateTime.tryParse(v) : null;

  static int daysBetween(DateTime a, DateTime b) => DateTime.utc(
    b.year,
    b.month,
    b.day,
  ).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

  static String number(int n) => NumberFormat.decimalPattern().format(n);

  static String time(int minutes) {
    final h = minutes ~/ 60, m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${number(h)}h';
    return '${number(h)}h ${m}m';
  }
}
