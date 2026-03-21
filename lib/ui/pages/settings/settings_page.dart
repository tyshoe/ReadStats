import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:stylish_bottom_bar/stylish_bottom_bar.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app_config.dart';
import '../../../data/services/import_export_service.dart';
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
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: false,
      ),
      body: ListView(
        children: [
          // Appearance Section
          _buildSettingsSection(
            context,
            header: 'Appearance',
            children: [
              _buildSettingsTile(
                context,
                title: 'Theme',
                trailing: Text(
                  _getThemeModeString(themeMode),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                onTap: () => showThemeModePicker(context, settingsViewModel, toggleTheme),
              ),
              _buildSettingsTile(
                context,
                title: 'Accent Color',
                trailing: Container(
                  width: 48,
                  height: 32,
                  decoration: BoxDecoration(
                    color: settingsViewModel.accentColorNotifier.value,
                    borderRadius: BorderRadius.circular(12),
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
                  builder: (context, selectedFont, _) => Text(
                    selectedFont,
                    style: Theme.of(context).textTheme.bodyMedium,
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
            ],
          ),

          // Preferences Section
          _buildSettingsSection(
            context,
            header: 'Preferences',
            children: [
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
                title: 'Default Tab',
                trailing: ValueListenableBuilder<int>(
                  valueListenable: settingsViewModel.defaultTabNotifier,
                  builder: (context, index, _) => Text(
                    _getTabName(index),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                onTap: () => showDefaultTabPicker(context, settingsViewModel),
              ),
            ],
          ),

          // Data Management Section
          _buildSettingsSection(
            context,
            header: 'Manage Your Data',
            children: [
              _buildSettingsTile(
                context,
                title: 'Export data as CSV',
                onTap: () =>
                    _handleImportExport(context, importExportService.exportDataToCSV),
              ),
              _buildSettingsTile(
                context,
                title: 'Import Goodreads data',
                onTap: () =>
                    _handleImportExport(context, importExportService.importGoodreadsCSV),
              ),
              _buildSettingsTile(
                context,
                title: 'Import Books from CSV',
                onTap: () =>
                    _handleImportExport(context, importExportService.importBooksFromCSV),
              ),
              _buildSettingsTile(
                context,
                title: 'Import Sessions from CSV',
                onTap: () =>
                    _handleImportExport(context, importExportService.importSessionsFromCSV),
              ),
              _buildSettingsTile(
                context,
                title: 'Import Tags from CSV',
                onTap: () =>
                    _handleImportExport(context, importExportService.importTagsFromCSV),
              ),
              _buildSettingsTile(
                context,
                title: 'Import Book Tags from CSV',
                onTap: () =>
                    _handleImportExport(context, importExportService.importBookTagsFromCSV),
              ),
              _buildSettingsTile(
                context,
                title: 'Delete All Data',
                textColor: colors.error,
                onTap: () => _confirmDeleteData(context),
              ),
            ],
          ),

          // About Section
          _buildSettingsSection(
            context,
            header: 'About',
            children: [
              _buildSettingsTile(
                context,
                title: 'Join our Discord',
                onTap: () => _launchUrl('https://discord.gg/cA6CDkUY4x'),
              ),
              _buildSettingsTile(
                context,
                title: 'GitHub',
                onTap: () => _launchUrl('https://github.com/tyshoe/ReadStats'),
              ),
              _buildSettingsTile(
                context,
                title: 'App Version',
                trailing: Text(
                  AppConfig.version,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.error,
        ),
      );
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
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
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
    return Card(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              header,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSettingsTile(
      BuildContext context, {
        required String title,
        Widget? trailing,
        VoidCallback? onTap,
        Color? textColor,
      }) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(
            color: textColor ?? Theme.of(context).colorScheme.onSurface),
      ),
      trailing: trailing,
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
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
        return 'Settings';
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