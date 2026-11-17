import '/ui/widgets/import_progress_dialog.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../widgets/app_snackbar.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app_config.dart';
import '../../../data/services/import_export_service.dart';
import '../../../data/services/milestone_service.dart';
import '../../../data/services/rating_service.dart';
import '../../../data/services/reading_timer_service.dart';
import '../onboarding/onboarding_page.dart';
import '/viewmodels/settings_view_model.dart';
import 'font_page.dart';
import 'notifications_page.dart';
import 'widgets/accent_color_picker.dart';
import 'widgets/nav_preview.dart';
import 'widgets/rating_style_picker.dart';
import '../settings/widgets/book_type_picker.dart';
import '../settings/widgets/theme_mode_picker.dart';
import 'widgets/date_format_picker.dart';
import 'widgets/currency_picker.dart';

class SettingsPage extends StatelessWidget {
  final Function(ThemeMode) toggleTheme;
  final ThemeMode themeMode;
  final ImportExportService importExportService;
  final Function() refreshBooks;
  final Function() refreshSessions;
  final SettingsViewModel settingsViewModel;
  final ReadingTimerService timerService;

  const SettingsPage({
    super.key,
    required this.toggleTheme,
    required this.themeMode,
    required this.importExportService,
    required this.refreshBooks,
    required this.refreshSessions,
    required this.settingsViewModel,
    required this.timerService,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: theme.colorScheme.surfaceContainer,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // Appearance Section — global app chrome: theme, accent, typeface.
          _buildSettingsSection(
            context,
            header: 'Appearance',
            children: [
              _buildValueTile(
                context,
                icon: Icons.brightness_6,
                title: 'Theme',
                value: ValueListenableBuilder<ThemeMode>(
                  valueListenable: settingsViewModel.themeModeNotifier,
                  builder: (context, mode, _) =>
                      _valueLabel(context, _getThemeModeString(mode)),
                ),
                onTap: () => showThemeModePicker(context, settingsViewModel, toggleTheme),
              ),
              _buildValueTile(
                context,
                icon: Icons.palette,
                title: 'Accent Color',
                value: ValueListenableBuilder<Color>(
                  valueListenable: settingsViewModel.accentColorNotifier,
                  builder: (context, color, _) => Container(
                    width: 48,
                    height: 28,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                onTap: () => showAccentColorPickerModal(
                  context,
                  settingsViewModel.accentColorNotifier.value,
                      (newColor) => settingsViewModel.setAccentColor(newColor),
                ),
              ),
              _buildValueTile(
                context,
                icon: Icons.text_fields_outlined,
                title: 'Font',
                value: ValueListenableBuilder<String>(
                  valueListenable: settingsViewModel.selectedFontNotifier,
                  builder: (context, selectedFont, _) =>
                      _valueLabel(context, selectedFont),
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        FontSelectionPage(settingsViewModel: settingsViewModel),
                  ),
                ),
              ),
            ],
          ),

          // Navigation Section — an interactive preview of the bottom tab bar.
          // The segmented control sets the bar's style; tapping a tab sets the
          // startup tab. Both settings are configured live, in place.
          _buildSettingsSection(
            context,
            header: 'Navigation',
            children: [
              NavPreview(settingsViewModel: settingsViewModel),
            ],
          ),

          // Defaults Section — how new entries are pre-filled and how stored
          // values (ratings, dates) are formatted throughout the app.
          _buildSettingsSection(
            context,
            header: 'Defaults',
            children: [
              _buildValueTile(
                context,
                icon: Icons.menu_book,
                title: 'Default Book Format',
                value: ValueListenableBuilder<int>(
                  valueListenable: settingsViewModel.defaultBookTypeNotifier,
                  builder: (context, type, _) =>
                      _valueLabel(context, bookTypeNames[type] ?? "Unknown"),
                ),
                onTap: () => showBookTypePicker(context, settingsViewModel),
              ),
              _buildValueTile(
                context,
                icon: Icons.star,
                title: 'Rating Style',
                value: ValueListenableBuilder<int>(
                  valueListenable: settingsViewModel.defaultRatingStyleNotifier,
                  builder: (context, style, _) =>
                      _valueLabel(context, ratingStyleNames[style] ?? "Unknown"),
                ),
                onTap: () => showRatingStylePicker(context, settingsViewModel),
              ),
              _buildValueTile(
                context,
                icon: Icons.event,
                title: 'Date Format',
                value: ValueListenableBuilder<String>(
                  valueListenable: settingsViewModel.defaultDateFormatNotifier,
                  builder: (context, format, _) => _valueLabel(
                      context, _getFormattedDate(DateTime.now(), format)),
                ),
                onTap: () => showDateFormatPicker(context, settingsViewModel),
              ),
            ],
          ),

          // Spending Section — an extra for readers who want to know what their
          // books cost. Off by default; while it is, no screen mentions money.
          ValueListenableBuilder<bool>(
            valueListenable: settingsViewModel.spendingEnabledNotifier,
            builder: (context, enabled, _) => _buildSettingsSection(
              context,
              header: 'Spending',
              children: [
                SwitchListTile(
                  secondary: _leadingSlot(
                      context, const Icon(Icons.payments, size: 22)),
                  title: Text('Track spending',
                      style: TextStyle(color: colors.onSurface)),
                  subtitle: Text(
                    'Record what you paid for each book',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                  value: enabled,
                  activeThumbColor:
                      settingsViewModel.accentColorNotifier.value,
                  onChanged: settingsViewModel.setSpendingEnabled,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                if (enabled)
                  _buildValueTile(
                    context,
                    icon: Icons.currency_exchange,
                    title: 'Currency',
                    value: ValueListenableBuilder<String>(
                      valueListenable: settingsViewModel.currencyNotifier,
                      builder: (context, code, _) => _valueLabel(
                          context, currencyLabel(code)),
                    ),
                    onTap: () =>
                        showCurrencyPicker(context, settingsViewModel),
                  ),
              ],
            ),
          ),

          // Notifications Section — local reminders, each configured on its own
          // schedule. A drill-in rather than inline rows: every type carries a
          // time and a set of days, which is more than a settings row can hold.
          _buildSettingsSection(
            context,
            header: 'Notifications',
            children: [
              _buildValueTile(
                context,
                icon: Icons.notifications,
                title: 'Reminders',
                value: Icon(Icons.chevron_right,
                    size: 20, color: colors.onSurfaceVariant),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationsPage()),
                ),
              ),
            ],
          ),

          // Data Section — import/export actions.
          _buildSettingsSection(
            context,
            header: 'Data',
            children: [
              _buildActionTile(
                context,
                icon: Icons.file_upload,
                title: 'Export Backup',
                onTap: () =>
                    _handleExport(context),
              ),
              _buildActionTile(
                context,
                icon: Icons.settings_backup_restore,
                title: 'Restore Backup',
                onTap: () =>
                    _handleImport(
                        context,
                        (report) => importExportService.importBackup(
                            onProgress: report)),
              ),
              _buildActionTile(
                context,
                icon: Icons.file_download,
                title: 'Import from Goodreads',
                onTap: () =>
                    _handleImport(
                        context,
                        (report) => importExportService.importGoodreadsCSV(
                            onProgress: report)),
              ),
              _buildActionTile(
                context,
                icon: Icons.file_download,
                title: 'Import from Bookmory',
                subtitle: "Use Bookmory's 'Database' export (.bookmory)",
                onTap: () =>
                    _handleImport(
                        context,
                        (report) => importExportService.importBookmory(
                            onProgress: report)),
              ),
              _buildActionTile(
                context,
                icon: Icons.science,
                title: 'Load Demo Data',
                subtitle: 'Replace your library with a sample one to explore',
                onTap: () => _confirmLoadDemo(context),
              ),
              _buildActionTile(
                context,
                icon: Icons.delete,
                title: 'Delete All Data',
                color: colors.error,
                onTap: () => _confirmDeleteData(context),
              ),
            ],
          ),

          // Help & Feedback Section — how a user gets help or reaches us.
          // Email is the primary, no-account-needed channel for bugs and
          // feature requests; Discord is the community option.
          _buildSettingsSection(
            context,
            header: 'Help & Feedback',
            children: [
              _buildLinkTile(
                context,
                icon: const Icon(Icons.star, size: 22),
                title: 'Rate ReadStats',
                onTap: () => RatingService.instance.openStoreListing(),
              ),
              _buildLinkTile(
                context,
                icon: const Icon(Icons.coffee, size: 22),
                title: 'Buy Me a Coffee',
                onTap: () => _launchUrl(
                  AppConfig.supportUrl,
                  mode: LaunchMode.externalApplication,
                ),
              ),
              _buildActionTile(
                context,
                icon: Icons.play_circle,
                title: 'Replay Tutorial',
                onTap: () => _replayOnboarding(context),
              ),
              _buildLinkTile(
                context,
                icon: const Icon(Icons.email, size: 22),
                title: 'Send Feedback',
                onTap: () => _launchUrl(
                    'mailto:readstatsdev@gmail.com?subject=ReadStats%20Feedback'),
              ),
              _buildLinkTile(
                context,
                icon: const FaIcon(FontAwesomeIcons.discord, size: 20),
                title: 'Join our Discord',
                onTap: () => _launchUrl('https://discord.gg/cA6CDkUY4x'),
              ),
            ],
          ),

          // About Section — project and legal references (not contact).
          _buildSettingsSection(
            context,
            header: 'About',
            children: [
              _buildLinkTile(
                context,
                icon: const FaIcon(FontAwesomeIcons.github, size: 20),
                title: 'Source Code',
                onTap: () => _launchUrl('https://github.com/tyshoe/ReadStats'),
              ),
              _buildLinkTile(
                context,
                icon: const Icon(Icons.privacy_tip, size: 22),
                title: 'Privacy Policy',
                onTap: () => _launchUrl(
                    'https://github.com/tyshoe/ReadStats/blob/main/PRIVACY.md'),
              ),
            ],
          ),

          // Quiet version footer, like most apps — informational, not an action.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Center(
              child: Text(
                'ReadStats · v${AppConfig.version}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleImportExport(
      BuildContext context,
      Future<ImportExportResult> Function() action, {
      // Report the result even after Settings has been left, for an import
      // the reader was free to walk away from.
      bool evenIfLeft = false,
      }) async {
    // Backup restores, CSV imports and the full wipe all move the numbers by
    // an amount the reader didn't just read — adopt the result rather than
    // celebrating it. Bracketed because a restore wipes before it inserts, and
    // a check landing in that gap would see an empty library.
    MilestoneService.beginBulkChange();
    final ImportExportResult result;
    try {
      result = await action();
    } finally {
      MilestoneService.endBulkChange();
    }
    if (evenIfLeft || context.mounted) {
      AppSnackbar.show(result.message, isError: !result.success);
      if (result.success) {
        refreshBooks();
        refreshSessions();
      }
    }
  }

  /// Exports a backup with its packing shown in the pinned pill. The pill
  /// comes down as the share sheet goes up: from there the file is the
  /// receiving app's to deal with.
  Future<void> _handleExport(BuildContext context) async {
    if (importBanner.value != null) {
      AppSnackbar.show('An import is already running.');
      return;
    }
    await _handleImportExport(context, () async {
      try {
        return await importExportService.exportBackup(onProgress: (value) {
          importBanner.value = value.fraction == 1 ? null : value;
        });
      } finally {
        importBanner.value = null;
      }
    }, evenIfLeft: true);
  }

  /// [_handleImportExport] for an import, with its progress on screen.
  ///
  /// Nothing shows until the import's first report: an import opens with the
  /// file picker, and there is nothing to wait for until a file is chosen.
  /// From then on its progress is a pill pinned over the app, which stays
  /// usable — Settings included, so it can be left. The snackbar says how it
  /// ended, wherever the reader is by then.
  ///
  /// [holdScreen] shows a dialog instead, for an import that empties the
  /// library before filling it and so leaves nothing to use meanwhile.
  Future<void> _handleImport(
    BuildContext context,
    Future<ImportExportResult> Function(ImportProgressCallback report)
        action, {
    bool holdScreen = false,
  }) async {
    if (importBanner.value != null) {
      AppSnackbar.show('An import is already running.');
      return;
    }
    final progress = ValueNotifier<ImportProgress?>(null);
    final navigator = Navigator.of(context, rootNavigator: true);
    var dialogUp = false;
    DateTime? pinnedAt;
    void report(ImportProgress value) {
      if (!holdScreen) {
        pinnedAt ??= DateTime.now();
        importBanner.value = value;
        return;
      }
      progress.value = value;
      if (dialogUp) return;
      dialogUp = true;
      navigator.push(DialogRoute<void>(
        context: navigator.context,
        barrierDismissible: false,
        builder: (_) => ImportProgressDialog(progress: progress),
      ));
    }

    await _handleImportExport(context, () async {
      try {
        return await action(report);
      } finally {
        if (dialogUp) navigator.pop();
        // A restore from a file already on the device is over in under a
        // second; keep the pill up long enough to be read, not glimpsed.
        final since = pinnedAt;
        if (since != null) {
          final shown = DateTime.now().difference(since);
          const least = Duration(milliseconds: 1200);
          if (shown < least) await Future<void>.delayed(least - shown);
        }
        importBanner.value = null;
      }
    }, evenIfLeft: true);
  }

  /// Same shape as [_confirmDeleteData] — loading the demo wipes first.
  void _confirmLoadDemo(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Load Demo Data?'),
        content: const Text(
          'This replaces every book, session, tag, goal, and planner entry '
          'with a sample library. Export a backup first to keep your own.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _handleExport(context);
            },
            child: const Text('Export Backup'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              timerService.stop();
              await _handleImport(
                  context,
                  (report) =>
                      importExportService.loadDemoData(onProgress: report),
                  holdScreen: true);
            },
            child: const Text('Load'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteData(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete All Data?'),
        content: const Text(
          'This permanently deletes every book, session, tag, and goal. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          // Exporting cancels the delete rather than chaining into it. The
          // export can fail or be dismissed at the share sheet, and chaining
          // would wipe data whose backup never actually saved — so the user
          // returns and confirms the delete explicitly.
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _handleExport(context);
            },
            child: const Text('Export Backup'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // Stop any active reading timer — its state lives in
              // SharedPreferences, so it would otherwise survive the wipe.
              timerService.stop();
              await _handleImportExport(context, importExportService.deleteAllData);
            },
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(ctx).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(
      BuildContext context, {
        required String header,
        required List<Widget> children,
      }) {
    // Header sits above the card (matching the Profile page's section titles)
    // rather than inside it, so Settings reads the same as the rest of the app.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              header,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  // Normalize every leading icon into an identical 24x24 centered slot so icons
  // of different sizes (Material vs brand) share one vertical line.
  Widget _leadingSlot(BuildContext context, Widget icon) {
    return SizedBox(
      width: 24,
      height: 24,
      child: Center(
        child: IconTheme.merge(
          data: IconThemeData(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          child: icon,
        ),
      ),
    );
  }

  // The right-aligned current-value text shared by every picker row.
  Widget _valueLabel(BuildContext context, String text) {
    return Text(text, style: Theme.of(context).textTheme.bodyMedium);
  }

  // Value row: a setting that holds a current value and opens a picker.
  // Reads as "icon · title ............ value ›".
  Widget _buildValueTile(
      BuildContext context, {
        required IconData icon,
        required String title,
        required Widget value,
        VoidCallback? onTap,
      }) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      leading: _leadingSlot(context, Icon(icon, size: 22)),
      title: Text(title, style: TextStyle(color: colors.onSurface)),
      trailing: value,
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  // Action row: performs something immediately (export, delete, replay). No
  // trailing chevron — it's a button, not a drill-in.
  Widget _buildActionTile(
      BuildContext context, {
        required IconData icon,
        required String title,
        String? subtitle,
        VoidCallback? onTap,
        Color? color,
      }) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      leading: _leadingSlot(
        context,
        Icon(icon, size: 22, color: color ?? colors.onSurfaceVariant),
      ),
      title: Text(title, style: TextStyle(color: color ?? colors.onSurface)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle, style: TextStyle(color: colors.onSurfaceVariant)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  // External link row: opens a URL off-app, signalled with open_in_new.
  Widget _buildLinkTile(
      BuildContext context, {
        required Widget icon,
        required String title,
        VoidCallback? onTap,
      }) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      leading: _leadingSlot(context, icon),
      title: Text(title, style: TextStyle(color: colors.onSurface)),
      trailing: Icon(Icons.open_in_new, size: 16, color: colors.onSurfaceVariant),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  void _replayOnboarding(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => OnboardingPage(
          onDone: () => Navigator.of(ctx).pop(),
          importExportService: importExportService,
          // Skip the first-run CSV import step; this is just a tour replay.
          hasBooks: true,
        ),
      ),
    );
  }

  Future<void> _launchUrl(
    String url, {
    LaunchMode mode = LaunchMode.platformDefault,
  }) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: mode)) {
      throw Exception('Could not launch $url');
    }
  }

  String _getFormattedDate(DateTime date, String format) {
    try {
      return DateFormat(format).format(date);
    } catch (e) {
      return DateFormat('yyyy-MM-dd').format(date);
    }
  }

  String _getThemeModeString(ThemeMode themeMode) {
    switch (themeMode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  static Map<int, String> ratingStyleNames = {
    0: "Stars",
    1: "Numbers",
  };
}