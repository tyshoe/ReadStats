import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A fold-out start and end time that works out the session's duration.
/// The times themselves aren't saved.
class TimeRangeCalculator extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;
  final TextEditingController startHours;
  final TextEditingController startMinutes;
  final TextEditingController endHours;
  final TextEditingController endMinutes;

  /// Why the times give no duration, if they don't.
  final String? error;

  /// Called after any of the four fields changes.
  final VoidCallback onChanged;

  const TimeRangeCalculator({
    super.key,
    required this.expanded,
    required this.onToggle,
    required this.startHours,
    required this.startMinutes,
    required this.endHours,
    required this.endMinutes,
    required this.error,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withAlpha(120),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                Text(
                  'calculate duration — not saved',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.expand_more,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: expanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      _timeRow(theme, 'Start Time', startHours, startMinutes),
                      const SizedBox(height: 8),
                      _timeRow(theme, 'End Time', endHours, endMinutes),
                      if (error != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          error!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _timeRow(
    ThemeData theme,
    String label,
    TextEditingController hoursCtrl,
    TextEditingController minutesCtrl,
  ) {
    InputDecoration decoration(String label) {
      final border = UnderlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      );
      return InputDecoration(
        labelText: label,
        filled: true,
        fillColor: theme.colorScheme.surfaceContainer,
        border: border,
        enabledBorder: border,
        focusedBorder: border,
        contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: hoursCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => onChanged(),
                onTapOutside: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
                decoration: decoration('Hours'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: minutesCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (v) {
                  final val = int.tryParse(v);
                  if (val != null && val > 59) minutesCtrl.text = '59';
                  onChanged();
                },
                onTapOutside: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
                decoration: decoration('Minutes'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
