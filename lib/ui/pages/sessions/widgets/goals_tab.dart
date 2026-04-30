import 'package:flutter/material.dart';
import '/data/models/goal.dart';
import '/data/repositories/goal_repository.dart';
import '/viewmodels/SettingsViewModel.dart';
import 'goal_form_sheet.dart';
import 'goal_history_sheet.dart';

class GoalsTab extends StatefulWidget {
  final GoalRepository goalRepository;
  final SettingsViewModel settingsViewModel;

  const GoalsTab({
    super.key,
    required this.goalRepository,
    required this.settingsViewModel,
  });

  @override
  State<GoalsTab> createState() => GoalsTabState();
}

class GoalsTabState extends State<GoalsTab> {
  List<Goal> _goals = [];
  Map<int, PeriodProgress> _progressMap = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final goals = await widget.goalRepository.getGoals();
    final progressMap = <int, PeriodProgress>{};
    for (final g in goals) {
      progressMap[g.id!] = await widget.goalRepository.getCurrentProgress(g);
    }
    if (mounted) {
      setState(() {
        _goals = goals;
        _progressMap = progressMap;
      });
    }
  }

  Set<String> get _takenSlots =>
      _goals.map((g) => '${g.metric.dbValue}:${g.period.dbValue}').toSet();

  void openAdd() => _openAdd();

  void _openAdd() {
    final accentColor = widget.settingsViewModel.accentColorNotifier.value;
    showGoalFormSheet(
      context: context,
      goalRepository: widget.goalRepository,
      accentColor: accentColor,
      takenSlots: _takenSlots,
      onSaved: _load,
    );
  }

  void _openEdit(Goal goal) {
    final accentColor = widget.settingsViewModel.accentColorNotifier.value;
    showGoalFormSheet(
      context: context,
      goalRepository: widget.goalRepository,
      accentColor: accentColor,
      existing: goal,
      onSaved: _load,
    );
  }

  Future<void> _confirmDelete(Goal goal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Goal'),
        content: Text(
            'Delete your ${goal.period.label.toLowerCase()} ${goal.metric.label.toLowerCase()} goal?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.goalRepository.deleteGoal(goal.id!);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = widget.settingsViewModel.accentColorNotifier.value;

    final content = _goals.isEmpty
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.flag_outlined,
                  size: 48,
                  color: theme.colorScheme.onSurface.withAlpha(80),
                ),
                const SizedBox(height: 12),
                Text(
                  'No goals yet',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(120),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap + to set your first reading goal',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(80),
                  ),
                ),
              ],
            ),
          )
        : ListView(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 88),
            children: [
              for (final period in GoalPeriod.values) ...[
                ...() {
                  final group = _goals.where((g) => g.period == period).toList();
                  if (group.isEmpty) return <Widget>[];
                  return [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
                      child: Text(
                        period.label,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha(120),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    for (final goal in group)
                      _GoalCard(
                        goal: goal,
                        progress: _progressMap[goal.id!],
                        accentColor: accentColor,
                        goalRepository: widget.goalRepository,
                        onEdit: () => _openEdit(goal),
                        onDelete: () => _confirmDelete(goal),
                      ),
                  ];
                }(),
              ],
            ],
          );

    return Stack(
      children: [
        content,
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            heroTag: 'goals_fab',
            backgroundColor: accentColor,
            onPressed: _openAdd,
            child: Icon(Icons.add, color: theme.colorScheme.onPrimary),
          ),
        ),
      ],
    );
  }
}

class _GoalCard extends StatefulWidget {
  final Goal goal;
  final PeriodProgress? progress;
  final Color accentColor;
  final GoalRepository goalRepository;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _GoalCard({
    required this.goal,
    required this.progress,
    required this.accentColor,
    required this.goalRepository,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_GoalCard> createState() => _GoalCardState();
}

class _GoalCardState extends State<_GoalCard> {
  bool _expanded = false;
  List<PeriodProgress>? _history;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final raw = await widget.goalRepository.getHistory(widget.goal);
    if (mounted) setState(() => _history = raw.reversed.toList());
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
  }

  bool get _useSegments =>
      (widget.goal.metric == GoalMetric.sessions ||
          widget.goal.metric == GoalMetric.booksFinished) &&
      widget.goal.target <= 12;

  Widget _buildProgressBar(
      int actual, int target, double ratio, bool met, Color completionColor, ThemeData theme) {
    if (_useSegments) {
      final filled = actual.clamp(0, target);
      final segmentColor = met ? completionColor : widget.accentColor.withOpacity(0.3);
      return Row(
        children: List.generate(target, (i) {
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              height: 6,
              decoration: BoxDecoration(
                color: i < filled
                    ? segmentColor
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          );
        }),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: ratio,
        minHeight: 6,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        valueColor: AlwaysStoppedAnimation<Color>(
          met ? completionColor : widget.accentColor.withOpacity(0.3),
        ),
      ),
    );
  }

  Color _completionColor() {
    final hsl = HSLColor.fromColor(widget.accentColor);
    final hue = hsl.hue;
    // If accent is green-ish (hue 80–170), use teal instead
    if (hue >= 80 && hue <= 170) return const Color(0xFF2196F3); // blue fallback
    return Colors.green.shade600;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = widget.progress;
    final ratio = p?.ratio ?? 0.0;
    final met = p?.met ?? false;
    final completionColor = _completionColor();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Card(
        elevation: 1,

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: GestureDetector(
          onTap: _toggle,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${widget.goal.period.label} ${widget.goal.metric.label}',
                                style: theme.textTheme.bodyMedium,
                              ),
                              if (met) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: completionColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check, size: 11, color: completionColor),
                                      const SizedBox(width: 3),
                                      Text(
                                        'Complete',
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: completionColor,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (p != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  widget.goal.metric.cardDisplay(p.actual),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '/ ${widget.goal.metric.cardDisplay(p.target)}',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurface.withAlpha(120),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'edit') widget.onEdit();
                        if (v == 'delete') widget.onDelete();
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                            value: 'edit', child: Text('Edit target')),
                        const PopupMenuItem(
                            value: 'delete', child: Text('Delete')),
                      ],
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        Icons.more_vert,
                        color: theme.colorScheme.onSurface.withAlpha(120),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildProgressBar(
                  p?.actual ?? 0,
                  widget.goal.target,
                  ratio,
                  met,
                  completionColor,
                  theme,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Spacer(),
                    if (_history != null && _history!.isNotEmpty)
                      Text(
                        'last ${_history!.length} ${switch (widget.goal.period) {
                          GoalPeriod.weekly => 'weeks',
                          GoalPeriod.monthly => 'months',
                          GoalPeriod.yearly => 'years',
                        }}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha(120),
                        ),
                      ),
                    const SizedBox(width: 2),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.expand_more,
                        size: 22,
                        color: theme.colorScheme.onSurface.withAlpha(120),
                      ),
                    ),
                  ],
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: _expanded
                      ? Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: _history == null
                              ? const Center(
                                  child: Padding(
                                    padding:
                                        EdgeInsets.symmetric(vertical: 16),
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              : _history!.isEmpty
                                  ? Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16),
                                      child: Center(
                                        child: Text(
                                          'No history yet',
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                            color: theme.colorScheme
                                                .onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    )
                                  : GoalHistoryChart(
                                      periods: _history!,
                                      accentColor: widget.accentColor,
                                      goalPeriod: widget.goal.period,
                                      goalMetric: widget.goal.metric,
                                    ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
