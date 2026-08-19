import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// The month chooser that drops out of a month label: a year stepper over a
/// grid of the twelve months, with anything outside the readable range greyed.
///
/// Shared by Tracking's calendar and the monthly recap, which both sit on one
/// month at a time and both hang this off the label between their chevrons.
///
/// Anchored under [anchorKey]'s widget rather than centred, so it reads as
/// belonging to the label that opened it. Returns the chosen month, or null if
/// the reader dismissed it or tapped the month already selected.
Future<DateTime?> showMonthPickerPopup({
  required BuildContext context,
  required GlobalKey anchorKey,
  required DateTime selected,
  required DateTime firstMonth,
  required DateTime lastMonth,
}) async {
  final box = anchorKey.currentContext?.findRenderObject() as RenderBox?;
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
  if (box == null || overlay == null) return null;

  final theme = Theme.of(context);
  final cs = theme.colorScheme;
  const popupWidth = 300.0;

  final labelTopLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
  final left = (labelTopLeft.dx + box.size.width / 2 - popupWidth / 2)
      .clamp(8.0, overlay.size.width - popupWidth - 8.0);
  final top = labelTopLeft.dy + box.size.height + 6;

  int displayYear = selected.year;

  return showGeneralDialog<DateTime>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (dialogCtx, anim, _) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return Stack(
        children: [
          Positioned(
            left: left,
            top: top,
            width: popupWidth,
            child: FadeTransition(
              opacity: anim,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.9, end: 1.0).animate(curved),
                alignment: Alignment.center,
                child: Material(
                  color: cs.surfaceContainerHigh,
                  elevation: 12,
                  shadowColor: Colors.black.withValues(alpha: 0.35),
                  surfaceTintColor: Colors.transparent,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: cs.outlineVariant),
                  ),
                  child: StatefulBuilder(
                    builder: (ctx, setMenuState) {
                      bool inRange(int month) {
                        final m = DateTime(displayYear, month);
                        return !m.isBefore(firstMonth) && !m.isAfter(lastMonth);
                      }

                      Widget monthCell(int month) {
                        final enabled = inRange(month);
                        final isSelected = displayYear == selected.year &&
                            month == selected.month;
                        return Material(
                          color: isSelected
                              ? cs.primaryContainer
                              : cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: (!enabled || isSelected)
                                ? null
                                : () => Navigator.pop(
                                    dialogCtx, DateTime(displayYear, month)),
                            child: Center(
                              child: Text(
                                DateFormat('MMM')
                                    .format(DateTime(displayYear, month)),
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: !enabled
                                      ? cs.onSurface.withValues(alpha: 0.3)
                                      : isSelected
                                          ? cs.onPrimaryContainer
                                          : cs.onSurface,
                                ),
                              ),
                            ),
                          ),
                        );
                      }

                      return Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.chevron_left),
                                  onPressed: displayYear > firstMonth.year
                                      ? () => setMenuState(() => displayYear--)
                                      : null,
                                  color: cs.onSurface,
                                  disabledColor: cs.onSurface.withAlpha(40),
                                ),
                                Expanded(
                                  child: Text(
                                    '$displayYear',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.chevron_right),
                                  onPressed: displayYear < lastMonth.year
                                      ? () => setMenuState(() => displayYear++)
                                      : null,
                                  color: cs.onSurface,
                                  disabledColor: cs.onSurface.withAlpha(40),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              // Without this, GridView falls back to
                              // MediaQuery.padding for its vertical insets and
                              // pads itself with the status bar and home
                              // indicator heights inside the dialog.
                              padding: EdgeInsets.zero,
                              crossAxisCount: 3,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                              childAspectRatio: 2.0,
                              children: [
                                for (int mo = 1; mo <= 12; mo++) monthCell(mo),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}
