import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/data/services/reading_timer_service.dart';

/// A countdown as chosen in the sheet: how long it runs, and what it does when
/// it gets there. A [duration] of [Duration.zero] clears an existing countdown.
typedef CountdownChoice = ({Duration duration, CountdownEnd end});

/// Lets the user run a countdown alongside the reading timer.
///
/// Resolves to the chosen countdown, or null if the sheet was dismissed
/// without a choice.
Future<CountdownChoice?> showCountdownSheet({
  required BuildContext context,
  required Duration? current,
  required CountdownEnd currentEnd,
  required Color accent,
}) {
  return showModalBottomSheet<CountdownChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _CountdownSheet(
      current: current,
      currentEnd: currentEnd,
      accent: accent,
    ),
  );
}

class _CountdownSheet extends StatefulWidget {
  final Duration? current;
  final CountdownEnd currentEnd;
  final Color accent;

  const _CountdownSheet({
    required this.current,
    required this.currentEnd,
    required this.accent,
  });

  @override
  State<_CountdownSheet> createState() => _CountdownSheetState();
}

class _CountdownSheetState extends State<_CountdownSheet> {
  /// Coarse jumps; the slider covers everything between and around them.
  static const _presets = [15, 30, 60];

  static const _minMinutes = 5;
  static const _maxMinutes = 180;
  static const _stepMinutes = 5;

  /// What an unset countdown opens on — long enough to be a real stint, short
  /// enough that a reader nudging it downwards has less distance to travel.
  static const _defaultMinutes = 30;

  late int _minutes;
  late CountdownEnd _end;

  @override
  void initState() {
    super.initState();
    // A fresh countdown defaults to the sleep behaviour: it's the mode that
    // protects the stats, and the asymmetry favours it — a wrong pause costs
    // one tap on Resume, a wrong chime banks a night's sleep as reading.
    _end = widget.current == null ? CountdownEnd.pause : widget.currentEnd;
    _minutes = _snap(widget.current?.inMinutes ?? _defaultMinutes);
  }

  /// Nudges any length onto the slider's 5-minute grid and inside its range,
  /// so a countdown set before this sheet existed still lands on a step.
  int _snap(int minutes) =>
      ((minutes / _stepMinutes).round() * _stepMinutes)
          .clamp(_minMinutes, _maxMinutes);

  void _setMinutes(int value) {
    final next = _snap(value);
    if (next == _minutes) return;
    HapticFeedback.selectionClick();
    setState(() => _minutes = next);
  }

  void _pop(Duration duration) =>
      Navigator.pop(context, (duration: duration, end: _end));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isSleep = _end == CountdownEnd.pause;

    return Column(
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
                  isSleep ? 'Sleep timer' : 'Countdown',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              if (widget.current != null)
                TextButton(
                  onPressed: () => _pop(Duration.zero),
                  child: const Text('Clear'),
                ),
            ],
          ),
        ),
        Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.5)),
        Flexible(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isSleep
                        ? 'Pauses the session when it reaches zero, so a night '
                            'you fall asleep on isn\'t counted as reading.'
                        : 'Counts down beside the reading timer, which keeps '
                            'running as normal.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      for (final minutes in _presets) ...[
                        Expanded(
                          child: _ChoiceTile(
                            label: minutes < 60 ? '$minutes min' : '1h',
                            selected: _minutes == minutes,
                            accent: widget.accent,
                            onTap: () => _setMinutes(minutes),
                          ),
                        ),
                        if (minutes != _presets.last) const SizedBox(width: 10),
                      ],
                    ],
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: Text(
                      _formatLength(_minutes),
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontFeatures: [const FontFeature.tabularFigures()],
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // The slider covers the range in one sweep; the buttons on
                  // either side land an exact value without fighting a thumb
                  // that is five minutes wide.
                  Row(
                    children: [
                      _NudgeButton(
                        icon: Icons.remove,
                        tooltip: '5 minutes less',
                        onPressed: _minutes > _minMinutes
                            ? () => _setMinutes(_minutes - _stepMinutes)
                            : null,
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: widget.accent,
                            thumbColor: widget.accent,
                            inactiveTrackColor: cs.surfaceContainerHighest,
                            // The grid is already felt through the haptic on
                            // each step; drawn ticks would only be clutter.
                            showValueIndicator: ShowValueIndicator.never,
                          ),
                          child: Slider(
                            value: _minutes.toDouble(),
                            min: _minMinutes.toDouble(),
                            max: _maxMinutes.toDouble(),
                            divisions:
                                (_maxMinutes - _minMinutes) ~/ _stepMinutes,
                            onChanged: (value) => _setMinutes(value.round()),
                          ),
                        ),
                      ),
                      _NudgeButton(
                        icon: Icons.add,
                        tooltip: '5 minutes more',
                        onPressed: _minutes < _maxMinutes
                            ? () => _setMinutes(_minutes + _stepMinutes)
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'When it ends',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _ChoiceTile(
                          label: 'Chime',
                          icon: Icons.notifications,
                          selected: !isSleep,
                          accent: widget.accent,
                          onTap: () =>
                              setState(() => _end = CountdownEnd.chime),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ChoiceTile(
                          label: 'Pause timer',
                          icon: Icons.bedtime,
                          selected: isSleep,
                          accent: widget.accent,
                          onTap: () =>
                              setState(() => _end = CountdownEnd.pause),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => _pop(Duration(minutes: _minutes)),
                style: FilledButton.styleFrom(
                  backgroundColor: widget.accent,
                  minimumSize: const Size.fromHeight(52),
                  textStyle: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                child: Text(
                  isSleep ? 'Start sleep timer' : 'Start countdown',
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

String _formatLength(int minutes) {
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

/// Square-off button for stepping the slider one increment at a time.
class _NudgeButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _NudgeButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
    );
  }
}

/// A pill in one of the sheet's pick-one rows: the length presets and the
/// end-of-countdown modes.
class _ChoiceTile extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _ChoiceTile({
    required this.label,
    this.icon,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final foreground = selected ? cs.onPrimary : cs.onSurface;

    final text = Text(
      label,
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodyLarge?.copyWith(
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: foreground,
      ),
    );

    return Material(
      color: selected ? accent : cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: icon == null
              ? text
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 18, color: foreground),
                    const SizedBox(width: 8),
                    Flexible(child: text),
                  ],
                ),
        ),
      ),
    );
  }
}
