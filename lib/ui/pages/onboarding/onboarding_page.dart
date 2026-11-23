import 'dart:async';
import 'dart:io';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:read_stats/app_config.dart';
import 'package:read_stats/data/services/analytics_service.dart';
import 'package:read_stats/data/services/auto_backup_service.dart';
import 'package:read_stats/data/services/import_export_service.dart';
import 'package:read_stats/data/services/milestone_service.dart';
import 'package:read_stats/data/services/notification_service.dart';
import 'package:read_stats/ui/settings_view_model.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:url_launcher/url_launcher.dart';

enum _ImportState { idle, loading, success, error }

class OnboardingPage extends StatefulWidget {
  final VoidCallback onDone;
  final ImportExportService importExportService;
  final bool hasBooks;

  const OnboardingPage({
    super.key,
    required this.onDone,
    required this.importExportService,
    required this.hasBooks,
  });

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.screen('onboarding');
  }

  final _controller = PageController();
  int _currentPage = 0;
  bool _hasImported = false;

  static const _infoPages = [
    _OnboardingData(
      imagePath: 'assets/icon/readstats.png',
      title: 'Welcome to ReadStats',
      body: 'Track your books, understand your habits, and turn reading into something you can actually measure.',
    ),
    _OnboardingData(
      icon: FluentIcons.library_24_filled,
      title: 'Build Your Library',
      body: 'Add books with covers, ratings, and reviews. Keep everything organized with shelves, tags, and favorites.',
    ),
    _OnboardingData(
      icon: FluentIcons.calendar_24_filled,
      title: 'Log Reading Sessions',
      body: 'Log your reading sessions and watch your progress grow over time. Visualize your habits with a simple calendar view.',
    ),
    _OnboardingData(
      icon: FluentIcons.data_pie_24_filled,
      title: 'Track Your Progress',
      body: 'Compare months, uncover trends, and see exactly how your reading has evolved over time.',
    ),
  ];

  /// Whether to offer automatic backup — not when it's already set up (a
  /// tour replayed from Settings). Decided once, so the page count holds
  /// still while the reader sets it up on that very page.
  late final bool _offerBackup =
      !AutoBackupService.instance.status.value.connected;

  /// Whether to offer importing, decided once for the same reason: [hasBooks]
  /// turns true the moment an import here lands, and dropping the page then
  /// would shift the reader onto the next one.
  late final bool _offerImport = !widget.hasBooks;

  // Info slides, the first-run import step, the backup step, then the support
  // page last — the ask comes only after the tour has shown what the app
  // actually does. Backup follows import so there is a library to protect.
  int get _importPage => _offerImport ? _infoPages.length : -1;
  int get _backupPage => !_offerBackup
      ? -1
      : _infoPages.length + (_offerImport ? 1 : 0);
  int get _totalPages =>
      _infoPages.length + (_offerImport ? 1 : 0) + (_offerBackup ? 1 : 0) + 1;

  bool get _isLastPage => _currentPage == _totalPages - 1;

  Future<void> _finish() async {
    await SettingsViewModel.setHasSeenOnboarding();
    AnalyticsService.instance.onboardingFinished();
    // The streak reminder ships switched on, so permission is asked for here —
    // at the end of the tour that just explained what the app tracks, which is
    // the most context this request will ever have. Awaited so the reader
    // answers the dialog before the app appears behind it.
    await NotificationService.instance.ensurePermissionRequested();
    widget.onDone();
  }

  Future<void> _openSupport() async {
    await launchUrl(
      Uri.parse(AppConfig.supportUrl),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _totalPages,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, i) {
                  if (i < _infoPages.length) {
                    return _PageContent(data: _infoPages[i]);
                  }
                  if (i == _importPage) {
                    return _ImportContent(
                      importExportService: widget.importExportService,
                      onImportSuccess: () => setState(() => _hasImported = true),
                    );
                  }
                  if (i == _backupPage) return const _BackupContent();
                  return _SupportContent(onSupport: _openSupport);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: SmoothPageIndicator(
                controller: _controller,
                count: _totalPages,
                effect: ExpandingDotsEffect(
                  dotHeight: 12,
                  dotWidth: 12,
                  expansionFactor: 3,
                  spacing: 6,
                  dotColor: colorScheme.outlineVariant,
                  activeDotColor: colorScheme.primary,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: FilledButton(
                onPressed: _isLastPage
                    ? _finish
                    : () => _controller.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: Text(
                  _isLastPage
                      ? (_hasImported ? 'Go to My Library' : 'Get Started')
                      : 'Continue',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Info page ────────────────────────────────────────────────────────────────

class _PageContent extends StatelessWidget {
  final _OnboardingData data;

  const _PageContent({required this.data});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(32),
            ),
            child: data.imagePath != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: Image.asset(
                      data.imagePath!,
                      width: 180,
                      height: 180,
                      fit: BoxFit.cover,
                    ),
                  )
                : Icon(data.icon, size: 80, color: colorScheme.primary),
          ),
          const SizedBox(height: 40),
          Text(
            data.title,
            style: textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            data.body,
            style: textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── Import page ──────────────────────────────────────────────────────────────

class _ImportContent extends StatefulWidget {
  final ImportExportService importExportService;
  final VoidCallback onImportSuccess;

  const _ImportContent({
    required this.importExportService,
    required this.onImportSuccess,
  });

  @override
  State<_ImportContent> createState() => _ImportContentState();
}

class _ImportContentState extends State<_ImportContent> {
  final Map<String, _ImportState> _states = {
    'goodreads': _ImportState.idle,
    'bookmory': _ImportState.idle,
    'books': _ImportState.idle,
    'demo': _ImportState.idle,
  };
  final Map<String, String> _messages = {};

  /// How far along the import that is running is, for its tile.
  final Map<String, ImportProgress> _progress = {};

  Future<void> _runImport(
    String key,
    Future<ImportExportResult> Function(ImportProgressCallback report) fn,
  ) async {
    setState(() => _states[key] = _ImportState.loading);
    final result = await fn((progress) {
      if (mounted) setState(() => _progress[key] = progress);
    });
    if (!mounted) return;
    _progress.remove(key);
    // Backing out of a picker or sign-in isn't a failure: the tile is just as
    // it was.
    if (!result.success && result.message == 'Cancelled.') {
      setState(() => _states[key] = _ImportState.idle);
      return;
    }
    final importedZero = result.success && result.message.startsWith('Imported 0');
    setState(() {
      _states[key] = importedZero
          ? _ImportState.error
          : result.success
              ? _ImportState.success
              : _ImportState.error;
      _messages[key] = importedZero ? 'No books found. Try a different file.' : result.message;
    });
    if (result.success && !importedZero) widget.onImportSuccess();
  }

  /// Where a ReadStats backup can come from — after a reinstall or on a new
  /// phone, most likely the automatic backups in Drive or a folder.
  void _showRestoreSheet() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final service = AutoBackupService.instance;

    Widget source(
      BuildContext sheet, {
      required IconData icon,
      required String title,
      required String hint,
      required Future<ImportExportResult> Function(ImportProgressCallback) run,
    }) =>
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: Icon(icon, color: colors.onSurfaceVariant),
          title: Text(title, style: TextStyle(color: colors.onSurface)),
          subtitle:
              Text(hint, style: TextStyle(color: colors.onSurfaceVariant)),
          trailing: Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
          onTap: () {
            Navigator.pop(sheet);
            _runImport('books', run);
          },
        );

    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.onSurfaceVariant.withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Restore a backup', style: theme.textTheme.titleLarge),
                  Text(
                    'Where did ReadStats save it?',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 4),
            source(
              sheet,
              icon: Icons.add_to_drive,
              title: 'Google Drive',
              hint: 'Your automatic backups',
              run: (report) => _restoreFromAutoBackup(
                  () => service.useDrive().then((_) => true), report),
            ),
            source(
              sheet,
              icon: Icons.folder,
              title: Platform.isIOS ? 'A folder in Files' : 'A folder',
              hint: 'Pick the folder your backups are in',
              run: (report) =>
                  _restoreFromAutoBackup(service.useFolder, report),
            ),
            source(
              sheet,
              icon: Icons.insert_drive_file,
              title: 'A file',
              hint: 'A backup you exported (.zip)',
              // Also takes a legacy books-only CSV export.
              run: (report) =>
                  widget.importExportService.importBackup(onProgress: report),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Points automatic backup at Drive or a folder via [choose], then restores
  /// the newest backup there. The destination stays chosen, so backups carry
  /// on from where the old install left off.
  Future<ImportExportResult> _restoreFromAutoBackup(
    Future<bool> Function() choose,
    ImportProgressCallback report,
  ) async {
    final service = AutoBackupService.instance;
    try {
      if (!await choose()) {
        return const ImportExportResult(success: false, message: 'Cancelled.');
      }
      report(const ImportProgress('Looking for backups…'));
      final backups = await service.listBackups();
      if (backups.isEmpty) {
        return const ImportExportResult(
          success: false,
          message: 'No backups there yet. New ones will be saved there daily.',
        );
      }
      // A whole library at once isn't something to celebrate medal by medal.
      MilestoneService.beginBulkChange();
      try {
        return await service.restore(backups.first, onProgress: report);
      } finally {
        MilestoneService.endBulkChange();
      }
    } on GoogleSignInException catch (e) {
      return ImportExportResult(
        success: false,
        message: e.code == GoogleSignInExceptionCode.canceled
            ? 'Cancelled.'
            : 'Couldn’t connect: ${e.description ?? e.code.name}',
      );
    } on BackupException catch (e) {
      return ImportExportResult(success: false, message: e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
          Text(
            'Import Your Books',
            style: textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'To help you get started, you can import your existing books now or any time later in Settings.',
            style: textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          _ImportTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/icon/goodreads.png',
                width: 36,
                height: 36,
                fit: BoxFit.cover,
              ),
            ),
            title: 'Import from Goodreads',
            subtitle: null,
            state: _states['goodreads']!,
            message: _messages['goodreads'],
            progress: _progress['goodreads'],
            onTap: () => _runImport(
              'goodreads',
              (report) => widget.importExportService
                  .importGoodreadsCSV(onProgress: report),
            ),
          ),
          const SizedBox(height: 16),
          _ImportTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/icon/bookmory.png',
                width: 36,
                height: 36,
                fit: BoxFit.cover,
              ),
            ),
            title: 'Import from Bookmory',
            subtitle: "Use Bookmory's 'Database' export (.bookmory)",
            state: _states['bookmory']!,
            message: _messages['bookmory'],
            progress: _progress['bookmory'],
            onTap: () => _runImport(
              'bookmory',
              (report) => widget.importExportService
                  .importBookmory(onProgress: report),
            ),
          ),
          const SizedBox(height: 16),
          _ImportTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/icon/readstats.png',
                width: 36,
                height: 36,
                fit: BoxFit.cover,
              ),
            ),
            title: 'Restore a ReadStats Backup',
            subtitle: 'From Google Drive, a folder or a file',
            state: _states['books']!,
            message: _messages['books'],
            progress: _progress['books'],
            onTap: _showRestoreSheet,
          ),
          const SizedBox(height: 16),
          _ImportTile(
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.science,
                size: 20,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            title: 'Explore with demo data',
            subtitle: 'A sample library you can replace any time',
            state: _states['demo']!,
            message: _messages['demo'],
            progress: _progress['demo'],
            onTap: () => _runImport('demo', (report) async {
              // A whole library at once isn't something to celebrate medal by
              // medal — adopt it, as Settings does for its bulk changes.
              MilestoneService.beginBulkChange();
              try {
                return await widget.importExportService
                    .loadDemoData(onlyIfEmpty: true, onProgress: report);
              } finally {
                MilestoneService.endBulkChange();
              }
            }),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                FluentIcons.info_16_regular,
                size: 14,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                'You can also restore a backup later in Settings',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
          ),
        ),
      ),
    );
  }

}

class _ImportTile extends StatelessWidget {
  final Widget leading;
  final String title;
  final String? subtitle;
  final _ImportState state;
  final String? message;

  /// What the running import is doing, shown in place of the subtitle.
  final ImportProgress? progress;

  /// Null while another tile's choice rules this one out — it greys out.
  final VoidCallback? onTap;

  const _ImportTile({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.state,
    required this.message,
    this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLoading = state == _ImportState.loading;

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: leading,
        title: Text(title),
        subtitle: (state == _ImportState.success || state == _ImportState.error) && message != null
            ? Text(
                message!,
                style: TextStyle(
                  color: state == _ImportState.success ? Colors.green : colorScheme.error,
                ),
              )
            : isLoading && progress != null
                ? Text(progress!.label)
                : subtitle != null
                    ? Text(subtitle!)
                    : null,
        trailing: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  // Fills as the import goes, once there is something to
                  // count; spins until then.
                  value: progress?.fraction,
                  strokeWidth: 2,
                  color: colorScheme.primary,
                ),
              )
            : state == _ImportState.success
                ? const Icon(Icons.check_circle, color: Colors.green)
                : state == _ImportState.error
                    ? Icon(Icons.error, color: colorScheme.error)
                    : Icon(
                        FluentIcons.chevron_right_24_filled,
                        color: colorScheme.onSurfaceVariant,
                      ),
        enabled: onTap != null || state != _ImportState.idle,
        onTap: isLoading || state == _ImportState.success ? null : onTap,
      ),
    );
  }
}

// ─── Backup page ──────────────────────────────────────────────────────────────

/// Offers automatic backup, to Google Drive or a folder, the same way the
/// import step offers its sources. Skipping is just Continue; the hint says
/// where to find it later.
class _BackupContent extends StatefulWidget {
  const _BackupContent();

  @override
  State<_BackupContent> createState() => _BackupContentState();
}

class _BackupContentState extends State<_BackupContent> {
  final Map<BackupDestinationKind, _ImportState> _states = {
    BackupDestinationKind.drive: _ImportState.idle,
    BackupDestinationKind.folder: _ImportState.idle,
  };
  final Map<BackupDestinationKind, String> _messages = {};

  @override
  void initState() {
    super.initState();
    // Restoring from Drive or a folder on the import step already chose it.
    final status = AutoBackupService.instance.status.value;
    final kind = status.kind;
    if (kind != null) {
      _states[kind] = _ImportState.success;
      _messages[kind] = _doneMessage(kind, status.label ?? '');
    }
  }

  static String _doneMessage(BackupDestinationKind kind, String label) =>
      kind == BackupDestinationKind.drive
          ? 'Backing up daily to $label'
          : 'Backing up daily to “$label”';

  /// One destination at a time: once one is chosen, or while one is being
  /// chosen, the other is out.
  bool get _settled => _states.values
      .any((s) => s == _ImportState.loading || s == _ImportState.success);

  Future<void> _choose(BackupDestinationKind kind) async {
    final service = AutoBackupService.instance;
    setState(() {
      _states[kind] = _ImportState.loading;
      _messages.remove(kind);
    });
    try {
      final chosen = switch (kind) {
        BackupDestinationKind.drive =>
          await service.useDrive().then((_) => true),
        BackupDestinationKind.folder => await service.useFolder(),
      };
      if (!mounted) return;
      if (!chosen) {
        setState(() => _states[kind] = _ImportState.idle);
        return;
      }
      // In the background: the tour shouldn't wait on packing covers. Skips
      // an empty library, so a new phone never replaces the backups already
      // there with nothing.
      unawaited(service.backUpIfWorthIt().catchError((_) => false));
      setState(() {
        _states[kind] = _ImportState.success;
        _messages[kind] =
            _doneMessage(kind, service.status.value.label ?? '');
      });
    } on GoogleSignInException catch (e) {
      if (!mounted) return;
      final canceled = e.code == GoogleSignInExceptionCode.canceled;
      setState(() {
        _states[kind] = canceled ? _ImportState.idle : _ImportState.error;
        if (!canceled) {
          _messages[kind] =
              'Couldn’t connect: ${e.description ?? e.code.name}';
        }
      });
    } on BackupException catch (e) {
      if (!mounted) return;
      setState(() {
        _states[kind] = _ImportState.error;
        _messages[kind] = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final ios = Platform.isIOS;

    Widget badge(IconData icon) => Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: colorScheme.onPrimaryContainer),
        );

    VoidCallback? tap(BackupDestinationKind kind) =>
        _settled && _states[kind] == _ImportState.idle
            ? null
            : () => _choose(kind);

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Keep Your Library Safe',
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'ReadStats can back up your library once a day, so it isn’t '
                'lost if you lose or change your phone.',
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              _ImportTile(
                leading: badge(Icons.add_to_drive),
                title: 'Back up to Google Drive',
                subtitle: 'Safe even if you lose your phone',
                state: _states[BackupDestinationKind.drive]!,
                message: _messages[BackupDestinationKind.drive],
                onTap: tap(BackupDestinationKind.drive),
              ),
              const SizedBox(height: 16),
              _ImportTile(
                leading: badge(Icons.folder),
                title: 'Back up to a folder',
                subtitle: ios
                    ? 'In Files or iCloud Drive, no account needed'
                    : 'On this device, no account needed',
                state: _states[BackupDestinationKind.folder]!,
                message: _messages[BackupDestinationKind.folder],
                onTap: tap(BackupDestinationKind.folder),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    FluentIcons.info_16_regular,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'You can set this up any time in Settings → Data',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Support page ─────────────────────────────────────────────────────────────

class _SupportContent extends StatelessWidget {
  final VoidCallback onSupport;

  const _SupportContent({required this.onSupport});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Icon(
                  FluentIcons.drink_coffee_24_filled,
                  size: 80,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 40),
              Text(
                'Support ReadStats',
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'ReadStats is free and ad-free, built and maintained by one '
                'person in their spare time. If you find it useful, a coffee '
                'helps cover the developer fees that keep it on the store.',
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              // Deliberately not full-width: the bottom CTA is the primary
              // action on this page, and skipping must stay the easy path.
              FilledButton.tonalIcon(
                onPressed: onSupport,
                icon: const Icon(FluentIcons.drink_coffee_24_regular, size: 20),
                label: const Text('Buy Me a Coffee'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // States the zero-reciprocity rule in the UI itself. Keep this
              // true — see AppConfig.supportUrl for why it matters.
              Text(
                'Completely optional — every feature stays free either way.',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Data class ───────────────────────────────────────────────────────────────

class _OnboardingData {
  final IconData? icon;
  final String? imagePath;
  final String title;
  final String body;

  const _OnboardingData({
    this.icon,
    this.imagePath,
    required this.title,
    required this.body,
  });
}
