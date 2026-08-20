import 'package:flutter/material.dart';

import '/data/models/notification_pref.dart';
import '/data/services/notification_prefs_store.dart';
import '/data/services/notification_service.dart';
import '../../widgets/app_snackbar.dart';

/// Lists every reminder the app can send, each with its own switch and
/// schedule. Reminders are entirely local — nothing here reaches a server.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage>
    with WidgetsBindingObserver {
  final _store = NotificationPrefsStore.instance;

  /// Null until the first check resolves, so the "blocked" banner doesn't flash
  /// on a page that turns out to have permission.
  bool? _permitted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Permission can be changed in system settings while this page is open —
    // most likely right after the banner sent the reader there. Re-check on
    // the way back rather than leaving a stale warning on screen.
    if (state == AppLifecycleState.resumed) _refreshPermission();
  }

  Future<void> _refreshPermission() async {
    final permitted = await NotificationService.instance.hasPermission();
    if (!mounted) return;
    setState(() => _permitted = permitted);
    // Reminders can't be scheduled without permission, so anything switched on
    // while it was missing needs registering now that it's back.
    if (permitted) await NotificationService.instance.rescheduleAll();
  }

  Future<void> _setEnabled(NotificationType type, bool enabled) async {
    // Ask only when switching something on, and only the first time — the OS
    // ignores repeat requests once the reader has answered.
    if (enabled && !(_permitted ?? false)) {
      final granted = await NotificationService.instance.requestPermission();
      if (!mounted) return;
      setState(() => _permitted = granted);
      if (!granted) {
        // The switch stays off. Leaving it on would promise reminders the OS
        // will never deliver.
        AppSnackbar.show(
          'Notifications are turned off for ReadStats',
          isError: true,
        );
        return;
      }
    }
    await _save(type, _store.of(type).copyWith(enabled: enabled));
  }

  /// Schedule edits are inline, so each one is saved as it's made — there is no
  /// confirm step to batch them behind.
  Future<void> _save(NotificationType type, NotificationPref pref) async {
    await _store.update(type, pref);
    await NotificationService.instance.rescheduleAll();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final types = NotificationType.values
        .where(NotificationService.supportedTypes.contains)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: colors.surfaceContainer,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      body: ValueListenableBuilder<Map<NotificationType, NotificationPref>>(
        valueListenable: _store.prefs,
        builder: (context, prefs, _) {
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              // Only worth showing once something is switched on — before that,
              // missing permission isn't a problem the reader has yet.
              if (_permitted == false && _store.anyEnabled)
                _PermissionBanner(
                  onOpenSettings: () =>
                      NotificationService.instance.openSystemSettings(),
                ),
              for (final type in types)
                _ReminderTile(
                  type: type,
                  pref: prefs[type]!,
                  onToggle: (value) => _setEnabled(type, value),
                  onChanged: (pref) => _save(type, pref),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// One reminder: a switch, and — once on — a schedule row that expands in place
/// to reveal the time and day controls.
class _ReminderTile extends StatefulWidget {
  final NotificationType type;
  final NotificationPref pref;
  final ValueChanged<bool> onToggle;
  final ValueChanged<NotificationPref> onChanged;

  const _ReminderTile({
    required this.type,
    required this.pref,
    required this.onToggle,
    required this.onChanged,
  });

  @override
  State<_ReminderTile> createState() => _ReminderTileState();
}

class _ReminderTileState extends State<_ReminderTile> {
  bool _expanded = false;

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime:
          TimeOfDay(hour: widget.pref.hour, minute: widget.pref.minute),
    );
    if (picked == null) return;
    widget.onChanged(
      widget.pref.copyWith(hour: picked.hour, minute: picked.minute),
    );
  }

  void _setThreshold(int days) {
    if (days == widget.pref.thresholdDays) return;
    widget.onChanged(widget.pref.copyWith(thresholdDays: days));
  }

  void _toggleDay(int weekday) {
    final days = widget.pref.weekdays.toList();
    if (days.contains(weekday)) {
      // A reminder with no days would never fire, so the last one can't be
      // cleared. Nothing to explain — the day simply stays selected, the same
      // way a repeat-day picker behaves in a clock app.
      if (days.length == 1) return;
      days.remove(weekday);
    } else {
      days.add(weekday);
    }
    widget.onChanged(widget.pref.copyWith(weekdays: days));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final description = widget.type.description;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            SwitchListTile(
              value: widget.pref.enabled,
              onChanged: (value) {
                // Collapse on the way off, so switching back on doesn't reopen
                // to controls the reader had finished with.
                if (!value) setState(() => _expanded = false);
                widget.onToggle(value);
              },
              title: Text(widget.type.label),
              subtitle: description == null
                  ? null
                  : Text(
                      description,
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
            ),
            // The schedule is hidden while off — an inert time and day list
            // under a switched-off reminder invites the reader to set something
            // that won't happen.
            if (widget.pref.enabled) ...[
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                title: const Text('Schedule'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _summary(context, widget.type, widget.pref),
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 150),
                      child: Icon(Icons.expand_more,
                          size: 20, color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
                onTap: () => setState(() => _expanded = !_expanded),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: _expanded
                    ? _ScheduleEditor(
                        type: widget.type,
                        pref: widget.pref,
                        onPickTime: _pickTime,
                        onToggleDay: _toggleDay,
                        onSetThreshold: _setThreshold,
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// "Every day at 8:00 PM", "Weekdays at 8:00 PM", "Mon, Wed at 8:00 PM" —
  /// the common shapes get a name so the row stays short.
  static String _summary(
    BuildContext context,
    NotificationType type,
    NotificationPref pref,
  ) {
    final time =
        TimeOfDay(hour: pref.hour, minute: pref.minute).format(context);
    // Fixed to the 1st, so the date leads and the time follows it.
    if (type.usesMonthlySchedule) return '1st of the month · $time';
    // The day count is what actually decides whether — and for the streak,
    // when — this one fires, so it leads; the time only says what hour.
    if (!type.usesWeekdaySchedule) {
      return '${type.thresholdDisplay(pref.thresholdDays)} · $time';
    }

    final days = pref.weekdays;
    if (days.isEmpty) return 'No days';
    if (days.length == 7) return 'Every day at $time';

    const weekdaysOnly = [
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
    ];
    if (days.length == 5 && weekdaysOnly.every(days.contains)) {
      return 'Weekdays at $time';
    }
    if (days.length == 2 &&
        days.contains(DateTime.saturday) &&
        days.contains(DateTime.sunday)) {
      return 'Weekends at $time';
    }

    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days.map((d) => names[d - 1]).join(', ')} at $time';
  }
}

/// The expanded portion: time on its own row, days as a week of toggles.
class _ScheduleEditor extends StatelessWidget {
  final NotificationType type;
  final NotificationPref pref;
  final VoidCallback onPickTime;
  final ValueChanged<int> onToggleDay;
  final ValueChanged<int> onSetThreshold;

  const _ScheduleEditor({
    required this.type,
    required this.pref,
    required this.onPickTime,
    required this.onToggleDay,
    required this.onSetThreshold,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final hint = type.thresholdHint(pref.thresholdDays);

    return Container(
      width: double.infinity,
      // Tinted so the expanded controls read as belonging to the row above
      // rather than as more list.
      color: colors.surfaceContainerHighest.withAlpha(80),
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The day count comes first for the types that have one: it decides
          // whether — and for the streak, when — the reminder fires at all,
          // where the time below only says what hour it arrives.
          if (type.thresholdOptions.isNotEmpty)
            ListTile(
              dense: true,
              leading: Icon(Icons.hourglass_bottom, size: 20,
                  color: colors.onSurfaceVariant),
              title: Text(type.thresholdLabel),
              subtitle: hint == null
                  ? null
                  : Text(hint, style: TextStyle(color: colors.onSurfaceVariant)),
              trailing: PopupMenuButton<int>(
                initialValue: pref.thresholdDays,
                onSelected: onSetThreshold,
                tooltip: '',
                itemBuilder: (context) => [
                  for (final days in type.thresholdOptions)
                    PopupMenuItem(
                      value: days,
                      child: Text(type.thresholdDisplay(days)),
                    ),
                ],
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(type.thresholdDisplay(pref.thresholdDays),
                        style: theme.textTheme.bodyMedium),
                    Icon(Icons.arrow_drop_down,
                        size: 20, color: colors.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ListTile(
            dense: true,
            leading: Icon(Icons.schedule, size: 20,
                color: colors.onSurfaceVariant),
            title: const Text('Time'),
            // The date isn't the reader's to choose here, so it is stated
            // rather than left to be inferred from an editor with one control.
            subtitle: type.usesMonthlySchedule
                ? Text(
                    'Arrives on the 1st, covering the month just gone',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  )
                : null,
            trailing: Text(
              TimeOfDay(hour: pref.hour, minute: pref.minute).format(context),
              style: theme.textTheme.bodyMedium,
            ),
            onTap: onPickTime,
          ),
          if (type.usesWeekdaySchedule) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.event_repeat, size: 20,
                      color: colors.onSurfaceVariant),
                  const SizedBox(width: 16),
                  Text('Days', style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final weekday in kAllWeekdays)
                    _DayToggle(
                      label: _dayInitial(weekday),
                      selected: pref.weekdays.contains(weekday),
                      onTap: () => onToggleDay(weekday),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Single-letter labels, indexed by `DateTime.monday`..`DateTime.sunday`.
  static String _dayInitial(int weekday) =>
      const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][weekday - 1];
}

/// One circular day button. Reads as selected/unselected by fill, so the row
/// scans as a week at a glance rather than as seven separate controls.
class _DayToggle extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DayToggle({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? Theme.of(context).primaryColor : null,
          border: Border.all(
            color: selected
                ? Theme.of(context).primaryColor
                : colors.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? colors.onPrimary : colors.onSurfaceVariant,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

/// Shown when reminders are switched on but the OS won't deliver them —
/// otherwise the reader is left waiting for notifications that can't arrive.
class _PermissionBanner extends StatelessWidget {
  final VoidCallback onOpenSettings;

  const _PermissionBanner({required this.onOpenSettings});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Card(
        margin: EdgeInsets.zero,
        color: colors.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.notifications_off, color: colors.onErrorContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Notifications are blocked for ReadStats, so none of these '
                  'will arrive.',
                  style: TextStyle(color: colors.onErrorContainer),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: onOpenSettings,
                child: Text(
                  'Settings',
                  style: TextStyle(color: colors.onErrorContainer),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
