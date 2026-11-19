import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:read_stats/domain/series_progress.dart';
import 'package:read_stats/ui/widgets/book_cover.dart';

/// The colour of a finished book's marks: the green a met goal turns — or
/// blue where the accent is itself green-ish, so finished still reads apart
/// from it.
///
/// A series keeps its colours to what they say: this for a book that is
/// done, the accent for the one being read or up next, and grey for the
/// rest.
Color seriesFinishedColor(ColorScheme cs) {
  final hue = HSLColor.fromColor(cs.primary).hue;
  if (hue >= 80 && hue <= 170) return const Color(0xFF2196F3);
  return Colors.green.shade600;
}

/// A series as a row of little books, one per number, each showing its
/// number. A book with a cover shows the cover — in full colour once read,
/// greyed while it's still to read. Without one, the tile is filled in for
/// read, in the finished green, and outlined otherwise. The book being read
/// has an accent border;
/// the one up next a dashed accent outline; a missing number is an empty
/// dashed slot.
///
/// [compact] is the small strip on Library rows and the book detail sheet;
/// the full size is the Series page's. [highlight] marks one number with a
/// bar underneath — the book the detail sheet is showing.
class SeriesStrip extends StatelessWidget {
  final SeriesProgress progress;
  final bool compact;
  final double? highlight;

  /// Drawn over a cover image, where theme outlines vanish.
  final bool onImage;

  /// Tapping a tile, on the Series page.
  final void Function(SeriesSlot slot)? onTap;

  const SeriesStrip({
    super.key,
    required this.progress,
    this.compact = false,
    this.highlight,
    this.onImage = false,
    this.onTap,
  });

  /// Tiles shown before the strip folds the rest into "+N".
  static const _compactMax = 10;
  static const _compactWidth = 24.0;

  @override
  Widget build(BuildContext context) {
    final slots = progress.slots;
    if (slots.isEmpty) return const SizedBox.shrink();

    if (compact) {
      final shown = slots.length > _compactMax
          ? slots.take(_compactMax - 1).toList()
          : slots;
      final hidden = slots.length - shown.length;
      return Wrap(
        spacing: 4,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.start,
        children: [
          for (final s in shown) _withMarker(context, s, _compactWidth),
          if (hidden > 0) _moreTile(context, hidden),
        ],
      );
    }

    // Full size: six to a row, wrapping for long series.
    return LayoutBuilder(builder: (context, constraints) {
      const gap = 8.0;
      const perRow = 6;
      final w = (constraints.maxWidth - gap * (perRow - 1)) / perRow;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final s in slots) _withMarker(context, s, w)],
      );
    });
  }

  /// The tile, with the highlight bar under it — or the same space empty,
  /// so highlighted and plain tiles line up.
  Widget _withMarker(BuildContext context, SeriesSlot slot, double w) {
    final tile = _tile(context, slot, w);
    if (highlight == null) return tile;
    final cs = Theme.of(context).colorScheme;
    final marked = highlight == slot.position;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        tile,
        const SizedBox(height: 3),
        Container(
          width: w * 0.6,
          height: 3,
          decoration: BoxDecoration(
            color: marked
                ? (onImage ? Colors.white : cs.primary)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }

  Widget _tile(BuildContext context, SeriesSlot slot, double w) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final h = w * 1.5;
    final radius = compact ? 3.0 : 6.0;
    final next = progress.nextUp;
    final isNext = next != null &&
        next.position == slot.position &&
        (slot.state == SeriesSlotState.toRead ||
            slot.state == SeriesSlotState.missing);
    final number = SeriesProgress.formatNumber(slot.position);
    final cover = slot.book?['cover_path'] as String?;
    final hasCover = cover != null && cover.isNotEmpty;
    final outline = onImage
        ? Colors.white.withValues(alpha: 0.55)
        : cs.onSurfaceVariant.withValues(alpha: 0.45);
    final muted =
        onImage ? Colors.white.withValues(alpha: 0.8) : cs.onSurfaceVariant;

    final plain = _plainTile(theme, slot, w, h, radius, number, outline,
        muted, isNext);

    Widget body;
    if (slot.isMissing || !hasCover) {
      body = plain;
    } else {
      final unread = slot.state == SeriesSlotState.toRead ||
          slot.state == SeriesSlotState.unfinished;
      Widget art = BookCoverFill(
        path: cover,
        shape: slot.book!['cover_shape'] as int?,
        fallback: plain,
      );
      if (unread) {
        art = Opacity(
          opacity: 0.55,
          child: ColorFiltered(colorFilter: _greyscale, child: art),
        );
      }
      body = SizedBox(
        width: w,
        height: h,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: cs.surfaceContainerHighest),
              art,
              Positioned(
                left: 0,
                right: 0,
                bottom: compact ? 2 : 4,
                child: Center(child: _numberPill(theme, number)),
              ),
              if (!compact && slot.state == SeriesSlotState.finished)
                Positioned(
                    top: 4,
                    right: 4,
                    child: _badge(cs, Icons.check,
                        color: seriesFinishedColor(cs))),
              if (!compact && slot.state == SeriesSlotState.unfinished)
                Positioned(
                    top: 4,
                    right: 4,
                    child: _badge(cs, Icons.do_not_disturb_on,
                        muted: true)),
            ],
          ),
        ),
      );
    }

    // Reading: a solid accent border over the tile. Up next: dashed.
    if (slot.state == SeriesSlotState.reading) {
      body = Container(
        foregroundDecoration: BoxDecoration(
          border: Border.all(
              color: onImage ? Colors.white : cs.primary,
              width: compact ? 1.5 : 2.5),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: body,
      );
    } else if (isNext) {
      body = CustomPaint(
        foregroundPainter: _DashedBorderPainter(
          color: onImage ? Colors.white : cs.primary,
          radius: radius,
        ),
        child: body,
      );
    }

    final label = '${SeriesProgress.label(slot.position)}, ${switch (slot.state) {
      SeriesSlotState.finished => 'finished',
      SeriesSlotState.reading => 'reading',
      SeriesSlotState.unfinished => 'unfinished',
      SeriesSlotState.toRead => isNext ? 'up next' : 'to read',
      SeriesSlotState.missing =>
        slot.isPlanned ? 'planned' : 'not in your library',
    }}';

    if (onTap == null) return Semantics(label: label, child: body);
    return Semantics(
      label: label,
      button: true,
      child: GestureDetector(onTap: () => onTap!(slot), child: body),
    );
  }

  /// A tile with no cover: filled once read, outlined otherwise, the number
  /// in the middle.
  Widget _plainTile(ThemeData theme, SeriesSlot slot, double w, double h,
      double radius, String number, Color outline, Color muted, bool isNext) {
    final cs = theme.colorScheme;
    Color? fill;
    Border? border;
    Color fg;
    IconData? icon;
    switch (slot.state) {
      case SeriesSlotState.finished:
        fill = onImage ? Colors.white : seriesFinishedColor(cs);
        fg = onImage ? Colors.black87 : Colors.white;
        icon = Icons.check_rounded;
      case SeriesSlotState.reading:
        fill = onImage
            ? Colors.white.withValues(alpha: 0.25)
            : cs.primaryContainer;
        fg = onImage ? Colors.white : cs.onPrimaryContainer;
        icon = Icons.menu_book_rounded;
      case SeriesSlotState.unfinished:
        border = Border.all(color: outline);
        fg = muted;
        icon = Icons.do_not_disturb_on;
      case SeriesSlotState.toRead:
        border = isNext ? null : Border.all(color: outline);
        fg = isNext ? (onImage ? Colors.white : cs.primary) : muted;
      case SeriesSlotState.missing:
        fill = isNext
            ? null
            : (onImage
                ? Colors.white.withValues(alpha: 0.08)
                : cs.surfaceContainerHighest.withValues(alpha: 0.5));
        fg = isNext
            ? (onImage ? Colors.white : cs.primary)
            : muted.withValues(alpha: 0.7);
        if (!compact) icon = slot.isPlanned ? Icons.schedule : Icons.add;
    }
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: fill,
        border: border,
        borderRadius: BorderRadius.circular(radius),
      ),
      padding: EdgeInsets.symmetric(vertical: compact ? 2 : 8),
      child: compact
          ? Center(
              child: Text(
                number,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                  fontSize: number.length > 2 ? 9 : 11,
                ),
              ),
            )
          : Column(
              mainAxisAlignment: icon == null
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.spaceBetween,
              children: [
                if (icon != null) Icon(icon, size: 18, color: fg),
                Text(
                  number,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
    );
  }

  /// The number over a cover, on a dark chip so it reads on any art.
  Widget _numberPill(ThemeData theme, String number) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 3 : 6, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(compact ? 3 : 5),
      ),
      child: Text(
        number,
        style: theme.textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: compact ? 8.5 : 11,
          height: 1.2,
        ),
      ),
    );
  }

  Widget _badge(ColorScheme cs, IconData icon,
      {bool muted = false, Color? color}) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: muted
            ? Colors.black.withValues(alpha: 0.6)
            : (color ?? cs.primary),
        shape: BoxShape.circle,
      ),
      child: Icon(icon,
          size: 12,
          color: Colors.white),
    );
  }

  Widget _moreTile(BuildContext context, int hidden) {
    final theme = Theme.of(context);
    return SizedBox(
      width: _compactWidth + 6,
      height: _compactWidth * 1.5,
      child: Center(
        child: Text(
          '+$hidden',
          style: theme.textTheme.labelSmall?.copyWith(
            color: onImage
                ? Colors.white.withValues(alpha: 0.8)
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  static const _greyscale = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 1, 0,
  ]);
}

/// A series at a glance: one segment per number, read ones filled, the one
/// being read half-tone, missing numbers hollow.
///
/// [highlight] makes one number's segment taller — the book the detail
/// sheet is showing.
class SeriesProgressBar extends StatelessWidget {
  final SeriesProgress progress;
  final double height;
  final double? highlight;

  /// Drawn over a cover image, where theme greys vanish.
  final bool onImage;

  const SeriesProgressBar({
    super.key,
    required this.progress,
    this.height = 6,
    this.highlight,
    this.onImage = false,
  });

  @override
  Widget build(BuildContext context) {
    final slots = progress.slots;
    if (slots.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final gap = slots.length > 12 ? 2.0 : 3.0;
    final empty = onImage
        ? Colors.white.withValues(alpha: 0.22)
        : cs.surfaceContainerHighest;
    final outline = onImage
        ? Colors.white.withValues(alpha: 0.45)
        : cs.outline.withValues(alpha: 0.6);
    final tall = height + 6;

    return Semantics(
      label: '${progress.read} of ${progress.total} read',
      child: SizedBox(
        height: highlight == null ? height : tall,
        child: Row(
          children: [
            for (var i = 0; i < slots.length; i++) ...[
              if (i > 0) SizedBox(width: gap),
              Expanded(
                child: Center(
                  child: _segment(
                    slots[i],
                    cs,
                    empty,
                    outline,
                    slots[i].position == highlight ? tall : height,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _segment(SeriesSlot s, ColorScheme cs, Color empty, Color outline,
      double h) {
    final (Color? fill, Border? border) = switch (s.state) {
      SeriesSlotState.finished => (seriesFinishedColor(cs), null),
      SeriesSlotState.reading => (cs.primary.withValues(alpha: 0.45), null),
      SeriesSlotState.unfinished => (outline.withValues(alpha: 0.35), null),
      SeriesSlotState.toRead => (empty, null),
      SeriesSlotState.missing => (null, Border.all(color: outline)),
    };
    return Container(
      height: h,
      decoration: BoxDecoration(
        color: fill,
        border: border,
        borderRadius: BorderRadius.circular(h / 2),
      ),
    );
  }
}

/// A dashed outline in the shape of a book cover — a number in the series
/// the reader doesn't have yet.
class MissingCover extends StatelessWidget {
  final double width;
  final IconData icon;

  const MissingCover({super.key, required this.width, this.icon = Icons.add});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return CustomPaint(
      foregroundPainter: _DashedBorderPainter(
        color: cs.outline.withValues(alpha: 0.7),
        radius: 4,
      ),
      child: Container(
        width: width,
        height: width * 1.5,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, size: width * 0.4, color: cs.onSurfaceVariant),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;

  _DashedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        (Offset.zero & size).deflate(0.75),
        Radius.circular(radius),
      ));
    const dash = 4.0, gap = 3.0;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}

/// Up to three covers fanned behind one another — a series as a pile of
/// books. Books without a cover show as plain spines in the theme's colours.
class SeriesCoverStack extends StatelessWidget {
  final List<Map<String, dynamic>> books;

  /// Width of each cover; the stack is wider by its offsets.
  final double coverWidth;

  /// How far the back cover sits from the front one, as a fraction of
  /// [coverWidth].
  final double spread;

  const SeriesCoverStack({
    super.key,
    required this.books,
    required this.coverWidth,
    this.spread = 0.3,
  });

  static const _max = 3;

  /// How much higher each cover sits than the one in front of it.
  static const _rise = 4.0;

  /// The width the stack takes for [coverWidth] and [spread].
  static double widthFor(double coverWidth, {double spread = 0.3}) =>
      coverWidth * (1 + spread);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Front of the pile is the first book; draw back to front.
    final shown = books.take(_max).toList().reversed.toList();
    final coverHeight = coverWidth * 1.5;
    final step = coverWidth * spread / math.max(1, _max - 1);

    return SizedBox(
      width: widthFor(coverWidth, spread: spread),
      height: coverHeight + _rise * (_max - 1),
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              // Each cover further back sits further right and a step higher.
              left: (shown.length - 1 - i) * step,
              top: i * _rise,
              child: _cover(theme, shown[i], coverWidth, coverHeight,
                  front: i == shown.length - 1),
            ),
        ],
      ),
    );
  }

  Widget _cover(ThemeData theme, Map<String, dynamic> book, double w, double h,
      {required bool front}) {
    final path = book['cover_path'] as String?;
    final placeholder = Container(
      color: theme.colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(Icons.menu_book_rounded,
          size: w * 0.4, color: theme.colorScheme.onSurfaceVariant),
    );
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: front ? 0.35 : 0.2),
            blurRadius: 4,
            offset: const Offset(-1, 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: path == null || path.isEmpty
          ? placeholder
          : BookCoverFill(
              path: path,
              shape: book['cover_shape'] as int?,
              fallback: placeholder,
            ),
    );
  }
}
