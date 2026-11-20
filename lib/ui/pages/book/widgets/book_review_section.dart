import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:read_stats/ui/pages/book/widgets/detail_section.dart';

/// The reader's review, four lines until tapped open; with none yet, a
/// "Write a review" row.
class BookReviewSection extends StatefulWidget {
  final String review;
  final VoidCallback onEdit;

  const BookReviewSection({
    super.key,
    required this.review,
    required this.onEdit,
  });

  @override
  State<BookReviewSection> createState() => _BookReviewSectionState();
}

class _BookReviewSectionState extends State<BookReviewSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final review = widget.review.trim();

    if (review.isEmpty) {
      return DetailCard(
        onTap: widget.onEdit,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(FluentIcons.compose_16_filled, size: 20, color: cs.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Write a review',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
          ],
        ),
      );
    }

    final style = theme.textTheme.bodyMedium?.copyWith(
      height: 1.5,
      color: cs.onSurface,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DetailHeading(
          'Your review',
          trailing: 'Edit',
          onTrailing: widget.onEdit,
        ),
        DetailCard(
          onTap: () => setState(() => _expanded = !_expanded),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final overflows = (TextPainter(
                text: TextSpan(text: review, style: style),
                maxLines: 4,
                textDirection: Directionality.of(context),
              )..layout(maxWidth: constraints.maxWidth)).didExceedMaxLines;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    alignment: Alignment.topCenter,
                    child: Text(
                      review,
                      style: style,
                      maxLines: _expanded ? null : 4,
                      overflow: _expanded
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                    ),
                  ),
                  if (overflows) ...[
                    const SizedBox(height: 6),
                    Text(
                      _expanded ? 'Show less' : 'Read more',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: cs.primary,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
