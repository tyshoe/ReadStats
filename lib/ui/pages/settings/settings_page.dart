import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../widgets/app_snackbar.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app_config.dart';
import '../../../data/services/import_export_service.dart';
import '../../../data/services/rating_service.dart';
import '../../../data/services/reading_timer_service.dart';
import '../onboarding/onboarding_page.dart';
import '/viewmodels/SettingsViewModel.dart';
import 'font_page.dart';
import 'widgets/accent_color_picker.dart';
import 'widgets/nav_preview.dart';
import 'widgets/rating_style_picker.dart';
import '../settings/widgets/book_type_picker.dart';
import '../settings/widgets/theme_mode_picker.dart';
import 'widgets/date_format_picker.dart';

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
                    _handleImportExport(context, importExportService.exportBackup),
              ),
              _buildActionTile(
                context,
                icon: Icons.settings_backup_restore,
                title: 'Restore Backup',
                onTap: () =>
                    _handleImportExport(context, importExportService.importBackup),
              ),
              _buildActionTile(
                context,
                icon: Icons.file_download,
                title: 'Import from Goodreads',
                onTap: () =>
                    _handleImportExport(context, importExportService.importGoodreadsCSV),
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
      Future<ImportExportResult> Function() action,
      ) async {
    final result = await action();
    if (context.mounted) {
      AppSnackbar.show(result.message, isError: !result.success);
      if (result.success) {
        refreshBooks();
        refreshSessions();
      }
    }
  }

  void _confirmDeleteData(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete All Data?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
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

  static const Map<int, String> bookTypeNames = {
    1: "Paperback",
    2: "Hardback",
    3: "eBook",
    4: "Audiobook",
  };
}