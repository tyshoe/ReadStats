import 'package:flutter/material.dart';
import '/viewmodels/SettingsViewModel.dart';

void showThemeModePicker(
    BuildContext context,
    SettingsViewModel settingsViewModel,
    Function(ThemeMode) toggleTheme,
    ) {
  final theme = Theme.of(context);
  final textColor = theme.textTheme.bodyMedium?.color ?? Colors.black;
  final currentThemeMode = settingsViewModel.themeModeNotifier.value;
  final accentColor = settingsViewModel.accentColorNotifier.value;

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Text(
        'Theme',
        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ThemeModeOption(
            label: 'System',
            isSelected: currentThemeMode == ThemeMode.system,
            accentColor: accentColor,
            textColor: textColor,
            onTap: () {
              toggleTheme(ThemeMode.system);
              Navigator.pop(context);
            },
          ),
          _ThemeModeOption(
            label: 'Light',
            isSelected: currentThemeMode == ThemeMode.light,
            accentColor: accentColor,
            textColor: textColor,
            onTap: () {
              toggleTheme(ThemeMode.light);
              Navigator.pop(context);
            },
          ),
          _ThemeModeOption(
            label: 'Dark',
            isSelected: currentThemeMode == ThemeMode.dark,
            accentColor: accentColor,
            textColor: textColor,
            onTap: () {
              toggleTheme(ThemeMode.dark);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    ),
  );
}

class _ThemeModeOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color accentColor;
  final Color textColor;
  final VoidCallback onTap;

  const _ThemeModeOption({
    required this.label,
    required this.isSelected,
    required this.accentColor,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: isSelected
          ? Icon(Icons.check, color: accentColor)
          : const SizedBox(width: 24), // keep alignment
      title: Text(
        label,
        style: TextStyle(
          fontSize: 16,
          color: isSelected ? accentColor : textColor,
        ),
      ),
    );
  }
}
