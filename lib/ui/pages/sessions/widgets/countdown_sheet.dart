import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Lets the user run a countdown alongside the reading timer.
///
/// Resolves to the chosen duration, [Duration.zero] to clear an existing
/// countdown, or null if the sheet was dismissed without a choice.
Future<Duration?> showCountdownSheet({
  required BuildContext context,
  required Duration? current,
  required Color accent,
}) {
  return showModalBottomSheet<Duration>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _CountdownSheet(current: current, accent: accent),
  );
}

class _CountdownSheet extends StatefulWidget {
  final Duration? current;
  final Color accent;

  const _CountdownSheet({required this.current, required this.accent});

  @override
  State<_CountdownSheet> createState() => _CountdownSheetState();
}

class _CountdownSheetState extends State<_CountdownSheet> {
  static const _presets = [15, 30, 60];

  late final TextEditingController _hours;
  late final TextEditingController _minutes;

  @override
  void initState() {
    super.initState();
    final minutes = widget.current?.inMinutes;
    final isCustom = minutes != null && !_presets.contains(minutes);
    _hours = TextEditingController(
      text: isCustom && minutes >= 60 ? '${minutes ~/ 60}' : '',
    );
    _minutes = TextEditingController(
      text: isCustom ? '${minutes % 60}' : '',
    );
  }

  @override
  void dispose() {
    _hours.dispose();
    _minutes.dispose();
    super.dispose();
  }

  Duration? get _customDuration {
    final h = int.tryParse(_hours.text) ?? 0;
    final m = int.tryParse(_minutes.text) ?? 0;
    final total = h * 60 + m;
    if (total < 1 || total > 600) return null;
    return Duration(minutes: total);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final currentMinutes = widget.current?.inMinutes;
    final custom = _customDuration;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Countdown',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                if (widget.current != null)
                  TextButton(
                    onPressed: () => Navigator.pop(context, Duration.zero),
                    child: const Text('Clear'),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.5)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Counts down beside the reading timer, which keeps running '
                  'as normal.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    for (final minutes in _presets) ...[
                      Expanded(
                        child: _PresetTile(
                          label: minutes < 60 ? '$minutes min' : '1h',
                          selected: currentMinutes == minutes,
                          accent: widget.accent,
                          onTap: () => Navigator.pop(
                            context,
                            Duration(minutes: minutes),
                          ),
                        ),
                      ),
                      if (minutes != _presets.last) const SizedBox(width: 10),
                    ],
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Custom',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _UnitField(
                        controller: _hours,
                        label: 'Hours',
                        onChanged: () => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _UnitField(
                        controller: _minutes,
                        label: 'Minutes',
                        onChanged: () => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: custom == null
                          ? null
                          : () => Navigator.pop(context, custom),
                      style: FilledButton.styleFrom(
                        backgroundColor: widget.accent,
                        minimumSize: const Size(72, 52),
                      ),
                      child: const Text('Set'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UnitField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final VoidCallback onChanged;

  const _UnitField({
    required this.controller,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(3),
      ],
      onChanged: (_) => onChanged(),
      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest,
        border: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      ),
    );
  }
}

class _PresetTile extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _PresetTile({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Material(
      color: selected ? accent : cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? cs.onPrimary : cs.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
