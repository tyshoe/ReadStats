import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/data/models/goal.dart';
import '/data/repositories/goal_repository.dart';

Future<void> showGoalFormSheet({
  required BuildContext context,
  required GoalRepository goalRepository,
  required Color accentColor,
  required VoidCallback onSaved,
  Goal? existing,
  Set<String> takenSlots = const {},
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _GoalFormSheet(
      goalRepository: goalRepository,
      accentColor: accentColor,
      onSaved: onSaved,
      existing: existing,
      takenSlots: takenSlots,
    ),
  );
}

class _GoalFormSheet extends StatefulWidget {
  final GoalRepository goalRepository;
  final Color accentColor;
  final VoidCallback onSaved;
  final Goal? existing;
  final Set<String> takenSlots;

  const _GoalFormSheet({
    required this.goalRepository,
    required this.accentColor,
    required this.onSaved,
    required this.takenSlots,
    this.existing,
  });

  @override
  State<_GoalFormSheet> createState() => _GoalFormSheetState();
}

class _GoalFormSheetState extends State<_GoalFormSheet> {
  GoalMetric? _metric;
  GoalPeriod? _period;
  final TextEditingController _targetController = TextEditingController();
  final TextEditingController _hoursController = TextEditingController();
  final TextEditingController _minutesController = TextEditingController();
  bool _saving = false;

  bool get _isEditing => widget.existing != null;
  bool get _isTimeMetric => _metric == GoalMetric.timeReading;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _metric = widget.existing!.metric;
      _period = widget.existing!.period;
      final target = widget.existing!.target;
      if (_metric == GoalMetric.timeReading) {
        _hoursController.text = (target ~/ 60).toString();
        _minutesController.text = (target % 60).toString();
      } else {
        _targetController.text = target.toString();
      }
    } else {
      _period = GoalPeriod.weekly;
    }
  }

  @override
  void dispose() {
    _targetController.dispose();
    _hoursController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  bool get _slotTaken {
    if (_isEditing || _metric == null || _period == null) return false;
    return widget.takenSlots.contains('${_metric!.dbValue}:${_period!.dbValue}');
  }

  bool get _canSave {
    if (_saving || _slotTaken || _period == null || _metric == null) return false;
    if (_isTimeMetric) {
      final h = int.tryParse(_hoursController.text) ?? 0;
      final m = int.tryParse(_minutesController.text) ?? 0;
      return h * 60 + m > 0;
    }
    return _targetController.text.isNotEmpty;
  }

  bool _isTaken(GoalMetric m) =>
      !_isEditing &&
      _period != null &&
      widget.takenSlots.contains('${m.dbValue}:${_period!.dbValue}');

  Widget _buildChip({
    required String label,
    required bool selected,
    required bool enabled,
    required bool taken,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return Opacity(
      opacity: taken ? 0.35 : 1.0,
      child: GestureDetector(
        onTap: (enabled && !taken) ? onTap : null,
        child: Container(
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: selected
                ? null
                : Border.all(color: theme.colorScheme.outline),
          ),
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: selected ? theme.colorScheme.onPrimaryContainer : null,
              fontWeight: selected ? FontWeight.w600 : null,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final int? target;
    if (_isTimeMetric) {
      final h = int.tryParse(_hoursController.text) ?? 0;
      final m = int.tryParse(_minutesController.text) ?? 0;
      target = h * 60 + m;
    } else {
      target = int.tryParse(_targetController.text);
    }
    if (target == null || target <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid target')),
      );
      return;
    }
    if (_slotTaken) return;

    setState(() => _saving = true);
    try {
      if (_isEditing) {
        await widget.goalRepository.updateTarget(widget.existing!, target);
      } else {
        await widget.goalRepository.createGoal(_metric!, _period!, target);
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keyboardBottom = MediaQuery.of(context).viewInsets.bottom;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withAlpha(80),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + keyboardBottom + safeBottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isEditing ? 'Edit Goal' : 'New Goal',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),

          // Step 1 — how often
          Text('What time frame do you want?', style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          )),
          const SizedBox(height: 8),
          Opacity(
            opacity: _isEditing ? 0.4 : 1.0,
            child: Row(
              children: GoalPeriod.values.expand((p) {
                final idx = GoalPeriod.values.indexOf(p);
                return [
                  if (idx > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _buildChip(
                      label: p.label,
                      selected: p == _period,
                      enabled: !_isEditing,
                      taken: false,
                      onTap: () => setState(() {
                        _period = p;
                        if (_metric != null && _isTaken(_metric!)) _metric = null;
                      }),
                      theme: theme,
                    ),
                  ),
                ];
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Step 2 — what to track, 2x2 grid
          Text('What type of goal are you going for?', style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          )),
          const SizedBox(height: 8),
          Opacity(
            opacity: _isEditing ? 0.4 : 1.0,
            child: Column(
              children: () {
                final metrics = GoalMetric.values;
                void selectMetric(GoalMetric m) => setState(() {
                  _metric = m;
                  _targetController.clear();
                  _hoursController.text = '0';
                  _minutesController.text = '0';
                });
                return [
                  Row(
                    children: [
                      Expanded(child: _buildChip(label: metrics[0].label, selected: metrics[0] == _metric, enabled: !_isEditing, taken: _isTaken(metrics[0]), onTap: () => selectMetric(metrics[0]), theme: theme)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildChip(label: metrics[1].label, selected: metrics[1] == _metric, enabled: !_isEditing, taken: _isTaken(metrics[1]), onTap: () => selectMetric(metrics[1]), theme: theme)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _buildChip(label: metrics[2].label, selected: metrics[2] == _metric, enabled: !_isEditing, taken: _isTaken(metrics[2]), onTap: () => selectMetric(metrics[2]), theme: theme)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildChip(label: metrics[3].label, selected: metrics[3] == _metric, enabled: !_isEditing, taken: _isTaken(metrics[3]), onTap: () => selectMetric(metrics[3]), theme: theme)),
                    ],
                  ),
                ];
              }(),
            ),
          ),
          const SizedBox(height: 16),

          // Step 3 — target, enabled after metric chosen
          Text("What's your goal?", style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          )),
          const SizedBox(height: 8),
          if (_isTimeMetric) ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _hoursController,
                    enabled: _metric != null || _isEditing,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(() {}),
                    onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                    decoration: InputDecoration(
                      labelText: 'Hours',
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest,
                      border: UnderlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      enabledBorder: UnderlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      focusedBorder: UnderlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      disabledBorder: UnderlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _minutesController,
                    enabled: _metric != null || _isEditing,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (v) {
                      final val = int.tryParse(v);
                      if (val != null && val > 59) _minutesController.text = '59';
                      setState(() {});
                    },
                    onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                    decoration: InputDecoration(
                      labelText: 'Minutes',
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest,
                      border: UnderlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      enabledBorder: UnderlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      focusedBorder: UnderlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      disabledBorder: UnderlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                    ),
                  ),
                ),
              ],
            ),
          ] else
            TextField(
              controller: _targetController,
              enabled: _metric != null || _isEditing,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
              decoration: InputDecoration(
                labelText: switch (_metric) {
                  GoalMetric.pagesRead => 'Pages',
                  GoalMetric.sessions => 'Sessions',
                  GoalMetric.booksFinished => 'Books',
                  _ => null,
                },
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
                border: UnderlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                enabledBorder: UnderlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                focusedBorder: UnderlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                disabledBorder: UnderlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              ),
            ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _canSave ? _save : null,
              style: FilledButton.styleFrom(
                backgroundColor: widget.accentColor,
                minimumSize: const Size.fromHeight(48),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_isEditing ? 'Update Goal' : 'Set Goal'),
            ),
          ),
          ],
        ),
      ),
    ],
  );
  }
}
