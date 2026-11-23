import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
import 'package:read_stats/data/services/analytics_service.dart';
import 'package:read_stats/data/services/auto_backup_service.dart';
import 'package:read_stats/data/services/import_export_service.dart';
import 'package:read_stats/data/services/milestone_service.dart';
import 'package:read_stats/ui/widgets/app_snackbar.dart';
import 'package:read_stats/ui/widgets/import_progress_dialog.dart';

/// Automatic backup: where backups go (Google Drive or a folder), the daily
/// switch, and the backups there to restore from.
class AutoBackupPage extends StatefulWidget {
  /// Called after a restore lands, so every tab reloads.
  final VoidCallback onRestored;

  const AutoBackupPage({super.key, required this.onRestored});

  @override
  State<AutoBackupPage> createState() => _AutoBackupPageState();
}

class _AutoBackupPageState extends State<AutoBackupPage> {
  final _service = AutoBackupService.instance;

  /// Null while loading; empty when there are none yet.
  List<BackupFile>? _backups;
  String? _listError;
  bool _choosing = false;

  /// Whether a backup was running at the last status change.
  bool _wasRunning = false;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.screen('auto_backup');
    _wasRunning = _service.status.value.running;
    _service.status.addListener(_onStatus);
    if (_service.status.value.connected) _loadBackups();
  }

  @override
  void dispose() {
    _service.status.removeListener(_onStatus);
    super.dispose();
  }

  /// A backup the app started on its own — the daily one, landing while this
  /// page is open — shows up in the list when it finishes.
  void _onStatus() {
    final status = _service.status.value;
    if (_wasRunning && !status.running && status.connected && mounted) {
      _loadBackups();
    }
    _wasRunning = status.running;
  }

  Future<void> _loadBackups() async {
    setState(() => _listError = null);
    try {
      final backups = await _service.listBackups();
      if (mounted) setState(() => _backups = backups);
    } on BackupException catch (e) {
      if (mounted) setState(() => _listError = e.message);
    }
  }

  /// Runs a destination choice — Drive, a folder, or the same one again —
  /// then makes the first backup there.
  Future<void> _choose(Future<bool> Function() choose) async {
    setState(() => _choosing = true);
    try {
      if (!await choose()) return;
      if (!mounted) return;
      setState(() => _backups = null);
      if (await _service.backUpIfWorthIt()) AppSnackbar.show('Backed up');
    } on GoogleSignInException catch (e) {
      if (e.code != GoogleSignInExceptionCode.canceled) {
        AppSnackbar.show(
          'Couldn’t connect: ${e.description ?? e.code.name}',
          isError: true,
        );
      }
    } on BackupException catch (e) {
      AppSnackbar.show(e.message, isError: true);
    } finally {
      if (mounted) setState(() => _choosing = false);
    }
  }

  Future<void> _useDrive() => _choose(() async {
    await _service.useDrive();
    return true;
  });

  Future<void> _useFolder() => _choose(_service.useFolder);

  Future<void> _reconnect() => _choose(_service.reconnect);

  Future<void> _backUpNow() async {
    try {
      await _service.backUpNow();
      AppSnackbar.show('Backed up');
    } on BackupException catch (e) {
      AppSnackbar.show(e.message, isError: true);
    } on GoogleSignInException catch (e) {
      if (e.code != GoogleSignInExceptionCode.canceled) {
        AppSnackbar.show(
          'Couldn’t sign in: ${e.description ?? e.code.name}',
          isError: true,
        );
      }
    }
    // The list reloads itself as the backup finishes (see [_onStatus]).
  }

  void _confirmChange(AutoBackupStatus status) {
    final drive = status.kind == BackupDestinationKind.drive;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change where backups go?'),
        content: Text(
          drive
              ? 'ReadStats stops backing up to Google Drive and gives up access '
                    'to it. The backups already there stay, and you can come back '
                    'to them any time.'
              : 'ReadStats stops backing up to “${status.label}”. The backups '
                    'already there stay, and you can choose the folder again any '
                    'time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _service.stop();
              if (mounted) setState(() => _backups = null);
            },
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  void _confirmRestore(BackupFile backup) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore this backup?'),
        content: Text(
          'Adds the books, sessions, tags, goals and covers from the backup '
          'of ${_timeLabel(backup.modified)} to your library.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _restore(backup);
            },
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }

  /// Same pinned progress pill as Settings → Restore Backup, so the app stays
  /// usable while it runs.
  Future<void> _restore(BackupFile backup) async {
    if (importBanner.value != null) {
      AppSnackbar.show('An import is already running.');
      return;
    }
    MilestoneService.beginBulkChange();
    final ImportExportResult result;
    try {
      importBanner.value = const ImportProgress('Fetching backup…');
      result = await _service.restore(
        backup,
        onProgress: (value) => importBanner.value = value,
      );
    } finally {
      importBanner.value = null;
      MilestoneService.endBulkChange();
    }
    AppSnackbar.show(result.message, isError: !result.success);
    if (result.success) widget.onRestored();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Automatic Backup'),
        backgroundColor: colors.surfaceContainer,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      body: ValueListenableBuilder<AutoBackupStatus>(
        valueListenable: _service.status,
        builder: (context, status, _) =>
            status.connected ? _connected(context, status) : _intro(context),
      ),
    );
  }

  // ─── Not set up ───────────────────────────────────────────────────────────

  Widget _intro(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final ios = Platform.isIOS;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 24),
      children: [
        Center(
          child: CircleAvatar(
            radius: 36,
            backgroundColor: colors.primary.withAlpha(40),
            child: Icon(Icons.backup, size: 36, color: colors.primary),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Back up automatically',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Keep a copy of your library somewhere safe, so it’s there if you '
          'lose or change your phone.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        const Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              _Point(
                icon: Icons.event_repeat,
                title: 'Once a day, on its own',
                body: 'Only when something changed since the last one',
              ),
              _Point(
                icon: Icons.history,
                title: 'Your last ${AutoBackupService.keepDaily} days',
                body:
                    'Plus the ones you make yourself. Older ones are '
                    'cleared out',
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Where should backups go?',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              _Choice(
                icon: Icons.add_to_drive,
                title: 'Google Drive',
                body:
                    'Safe even if you lose your phone. ReadStats can only '
                    'see its own files.',
                onTap: _choosing ? null : _useDrive,
              ),
              _Choice(
                icon: Icons.folder,
                title: ios ? 'A folder in Files' : 'A folder on this device',
                body: ios
                    ? 'No account needed. Pick one in iCloud Drive to keep a '
                          'copy off your phone.'
                    : 'No account needed. Pick one another app syncs to keep '
                          'a copy off your phone.',
                onTap: _choosing ? null : _useFolder,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Set up ───────────────────────────────────────────────────────────────

  Widget _connected(BuildContext context, AutoBackupStatus status) {
    final colors = Theme.of(context).colorScheme;
    final backups = _backups;
    final drive = status.kind == BackupDestinationKind.drive;

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadBackups,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                _section(context, 'Saved to', [
                  ListTile(
                    leading: Icon(drive ? Icons.add_to_drive : Icons.folder),
                    title: Text(status.label ?? ''),
                    subtitle: Text(
                      drive
                          ? 'Google Drive'
                          : Platform.isIOS
                          ? 'Folder in Files'
                          : 'Folder on this device',
                    ),
                    trailing: TextButton(
                      onPressed: status.running || _choosing
                          ? null
                          : () => _confirmChange(status),
                      child: const Text('Change'),
                    ),
                  ),
                ]),
                _section(context, 'Backup', [
                  SwitchListTile(
                    secondary: const Icon(Icons.event_repeat),
                    title: const Text('Back up automatically'),
                    subtitle: const Text(
                      'Once a day, when something has changed',
                    ),
                    value: status.auto,
                    onChanged: _service.setAuto,
                  ),
                  if (status.error != null && !status.running)
                    ListTile(
                      leading: Icon(Icons.error, color: colors.error),
                      title: Text(
                        status.error!,
                        style: TextStyle(color: colors.error),
                      ),
                      trailing: status.needsReconnect
                          ? TextButton(
                              onPressed: _choosing ? null : _reconnect,
                              child: Text(
                                drive ? 'Reconnect' : 'Choose folder',
                              ),
                            )
                          : null,
                    ),
                ]),
                // Unreachable until it's chosen again — the error above says
                // so once.
                if (!status.needsReconnect)
                  _section(context, 'Backups', [
                    // Where the next backup will land — the list is newest
                    // first, so the top row is always the latest.
                    if (status.running)
                      const ListTile(
                        title: Text('Backing up…'),
                        trailing: SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    if (_listError != null)
                      ListTile(
                        title: Text(
                          _listError!,
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                        trailing: TextButton(
                          onPressed: _loadBackups,
                          child: const Text('Retry'),
                        ),
                      )
                    else if (backups == null)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (backups.isEmpty && !status.running)
                      ListTile(
                        title: Text(
                          'No backups yet',
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                      )
                    else
                      for (final backup in backups)
                        ListTile(
                          title: Text(_timeLabel(backup.modified)),
                          subtitle: Text.rich(
                            TextSpan(
                              children: [
                                // Manual ones in the accent — the ones you chose
                                // to make stand out from the routine daily ones.
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.middle,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    margin: const EdgeInsets.only(right: 6),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: backup.manual
                                          ? colors.primary
                                          : colors.outline,
                                    ),
                                  ),
                                ),
                                TextSpan(text: _detail(backup)),
                              ],
                            ),
                            style: TextStyle(color: colors.onSurfaceVariant),
                          ),
                          trailing: TextButton(
                            onPressed: status.running
                                ? null
                                : () => _confirmRestore(backup),
                            child: const Text('Restore'),
                          ),
                        ),
                  ]),
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: status.running ? null : _backUpNow,
              child: Text(status.running ? 'Backing up…' : 'Back up now'),
            ),
          ),
        ),
      ],
    );
  }

  /// Same header-above-card sections as Settings.
  Widget _section(BuildContext context, String header, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              header,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Card(
            margin: EdgeInsets.zero,
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  /// "Manual · 137 books · 677 sessions" (or "Auto · …") — what made it, and
  /// enough of what's in it to tell one from another.
  static String _detail(BackupFile backup) {
    final parts = <String>[
      backup.manual ? 'Manual' : 'Auto',
      if (backup.books != null) '${backup.books} books',
      if (backup.sessions != null) '${backup.sessions} sessions',
    ];
    return parts.join(' · ');
  }

  /// "Today", "Yesterday", else "Sun, Nov 22".
  static String _dayLabel(DateTime when) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(when.year, when.month, when.day);
    final ago = today.difference(day).inDays;
    if (ago == 0) return 'Today';
    if (ago == 1) return 'Yesterday';
    return DateFormat(
      when.year == now.year ? 'EEE, MMM d' : 'MMM d, y',
    ).format(when);
  }

  static String _timeLabel(DateTime when) =>
      '${_dayLabel(when)}, ${DateFormat.jm().format(when)}';
}

/// One line of the intro's what-you-get list.
class _Point extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _Point({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: colors.primary),
      title: Text(title),
      subtitle: Text(body, style: TextStyle(color: colors.onSurfaceVariant)),
    );
  }
}

/// One destination the intro offers.
class _Choice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback? onTap;

  const _Choice({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: colors.onSurfaceVariant),
      title: Text(title),
      subtitle: Text(body, style: TextStyle(color: colors.onSurfaceVariant)),
      trailing: Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
      enabled: onTap != null,
      onTap: onTap,
    );
  }
}
