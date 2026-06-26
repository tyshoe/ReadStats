import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../widgets/app_snackbar.dart';
import 'package:intl/intl.dart';
import 'package:stylish_bottom_bar/stylish_bottom_bar.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app_config.dart';
import '../../../data/services/import_export_service.dart';
import '../onboarding/onboarding_page.dart';
import '/viewmodels/SettingsViewModel.dart';
import 'font_page.dart';
import 'widgets/accent_color_picker.dart';
import 'widgets/nav_style_picker.dart';
import 'widgets/rating_style_picker.dart';
import '../settings/widgets/book_type_picker.dart';
import '../settings/widgets/theme_mode_picker.dart';
import 'widgets/default_tab_picker.dart';
import 'widgets/date_format_picker.dart';

class SettingsPage extends StatelessWidget {
  final Function(ThemeMode) toggleTheme;
  final ThemeMode themeMode;
  final ImportExportService importExportService;
  final Function() refreshBooks;
  final Function() refreshSessions;
  final SettingsViewModel settingsViewModel;

  const SettingsPage({
    super.key,
    required this.toggleTheme,
    required this.themeMode,
    required this.importExportService,
    required this.refreshBooks,
    required this.refreshSessions,
    required this.settingsViewModel,
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
          // Appearance Section — everything about how the app looks, including
          // how individual values (ratings, dates) render.
          _buildSettingsSection(
            context,
            header: 'Appearance',
            children: [
              _buildSettingsTile(
                context,
                title: 'Theme',
                trailing: ValueListenableBuilder<ThemeMode>(
                  valueListenable: settingsViewModel.themeModeNotifier,
                  builder: (context, mode, _) => Text(
                    _getThemeModeString(mode),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                onTap: () => showThemeModePicker(context, settingsViewModel, toggleTheme),
              ),
              _buildSettingsTile(
                context,
                title: 'Accent Color',
                trailing: ValueListenableBuilder<Color>(
                  valueListenable: settingsViewModel.accentColorNotifier,
                  builder: (context, color, _) => Container(
                    width: 48,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                onTap: () => showAccentColorPickerModal(
                  context,
                  settingsViewModel.accentColorNotifier.value,
                      (newColor) => settingsViewModel.setAccentColor(newColor),
                ),
              ),
              _buildSettingsTile(
                context,
                title: 'Font',
                trailing: ValueListenableBuilder<String>(
                  valueListenable: settingsViewModel.selectedFontNotifier,
                  builder: (context, selectedFont, _) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        selectedFont,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        FontSelectionPage(settingsViewModel: settingsViewModel),
                  ),
                ),
              ),
              _buildSettingsTile(
                context,
                title: 'Navigation Style',
                trailing: ValueListenableBuilder<IconStyle>(
                  valueListenable: settingsViewModel.navStyleNotifier,
                  builder: (context, value, _) => Text(
                    _iconStyleToString(value),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                onTap: () => showNavStylePicker(context, settingsViewModel),
              ),
              _buildSettingsTile(
                context,
                title: 'Rating Style',
                trailing: ValueListenableBuilder<int>(
                  valueListenable: settingsViewModel.defaultRatingStyleNotifier,
                  builder: (context, style, _) => Text(
                    ratingStyleNames[style] ?? "Unknown",
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                onTap: () => showRatingStylePicker(context, settingsViewModel),
              ),
              _buildSettingsTile(
                context,
                title: 'Date Format',
                trailing: ValueListenableBuilder<String>(
                  valueListenable: settingsViewModel.defaultDateFormatNotifier,
                  builder: (context, format, _) => Text(
                    _getFormattedDate(DateTime.now(), format),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                onTap: () => showDateFormatPicker(context, settingsViewModel),
              ),
            ],
          ),

          // Defaults Section — pre-selected choices for new content & launch.
          _buildSettingsSection(
            context,
            header: 'Defaults',
            children: [
              _buildSettingsTile(
                context,
                title: 'Startup Tab',
                trailing: ValueListenableBuilder<int>(
                  valueListenable: settingsViewModel.defaultTabNotifier,
                  builder: (context, index, _) => Text(
                    _getTabName(index),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                onTap: () => showDefaultTabPicker(context, settingsViewModel),
              ),
              _buildSettingsTile(
                context,
                title: 'Default Book Format',
                trailing: ValueListenableBuilder<int>(
                  valueListenable: settingsViewModel.defaultBookTypeNotifier,
                  builder: (context, type, _) => Text(
                    bookTypeNames[type] ?? "Unknown",
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                onTap: () => showBookTypePicker(context, settingsViewModel),
              ),
            ],
          ),

          // Data Management Section
          _buildSettingsSection(
            context,
            header: 'Data',
            children: [
              _buildSettingsTile(
                context,
                title: 'Export to CSV',
                onTap: () =>
                    _handleImportExport(context, importExportService.exportDataToCSV),
              ),
              _buildSettingsTile(
                context,
                title: 'Import from Goodreads',
                onTap: () =>
                    _handleImportExport(context, importExportService.importGoodreadsCSV),
              ),
              ExpansionTile(
                title: Text(
                  'Import from CSV',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                childrenPadding: const EdgeInsets.only(bottom: 4),
                children: [
                  _buildSettingsTile(
                    context,
                    title: 'Books',
                    onTap: () =>
                        _handleImportExport(context, importExportService.importBooksFromCSV),
                  ),
                  _buildSettingsTile(
                    context,
                    title: 'Sessions',
                    onTap: () =>
                        _handleImportExport(context, importExportService.importSessionsFromCSV),
                  ),
                  _buildSettingsTile(
                    context,
                    title: 'Tags',
                    onTap: () =>
                        _handleImportExport(context, importExportService.importTagsFromCSV),
                  ),
                  _buildSettingsTile(
                    context,
                    title: 'Book Tags',
                    onTap: () =>
                        _handleImportExport(context, importExportService.importBookTagsFromCSV),
                  ),
                ],
              ),
              _buildSettingsTile(
                context,
                title: 'Delete All Data',
                textColor: colors.error,
                onTap: () => _confirmDeleteData(context),
              ),
            ],
          ),

          // Help & Feedback Section — support actions and community links.
          _buildSettingsSection(
            context,
            header: 'Help & Feedback',
            children: [
              _buildSettingsTile(
                context,
                title: 'Replay Tutorial',
                leading: const Icon(Icons.play_circle, size: 22),
                onTap: () => _replayOnboarding(context),
              ),
              _buildSettingsTile(
                context,
                title: 'Report a Bug',
                leading: const Icon(Icons.bug_report, size: 24),
                trailing: const Icon(Icons.open_in_new, size: 16),
                onTap: () =>
                    _launchUrl('https://github.com/tyshoe/ReadStats/issues/new'),
              ),
              _buildSettingsTile(
                context,
                title: 'Join our Discord',
                leading: const FaIcon(FontAwesomeIcons.discord, size: 20),
                trailing: const Icon(Icons.open_in_new, size: 16),
                onTap: () => _launchUrl('https://discord.gg/cA6CDkUY4x'),
              ),
              _buildSettingsTile(
                context,
                title: 'GitHub',
                leading: const FaIcon(FontAwesomeIcons.github, size: 20),
                trailing: const Icon(Icons.open_in_new, size: 16),
                onTap: () => _launchUrl('https://github.com/tyshoe/ReadStats'),
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

  Widget _buildSettingsTile(
      BuildContext context, {
        required String title,
        Widget? trailing,
        Widget? leading,
        VoidCallback? onTap,
        Color? textColor,
      }) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(
            color: textColor ?? Theme.of(context).colorScheme.onSurface),
      ),
      // Normalize every leading icon into an identical 24x24 centered slot so
      // icons of different sizes (Material vs brand) share one vertical line.
      leading: leading == null
          ? null
          : SizedBox(
              width: 24,
              height: 24,
              child: Center(child: leading),
            ),
      trailing: trailing,
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
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

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      throw Exception('Could not launch $url');
    }
  }

  String _getTabName(int index) {
    switch (index) {
      case 0:
        return 'Library';
      case 1:
        return 'Sessions';
      case 2:
        return 'Stats';
      case 3:
      default:
        return 'Profile';
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

  static String _iconStyleToString(IconStyle style) {
    switch (style) {
      case IconStyle.animated:
        return 'Animated';
      case IconStyle.Default:
        return 'Standard';
      default:
        return 'Simple';
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