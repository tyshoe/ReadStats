import 'package:flutter/material.dart';
import '/viewmodels/SettingsViewModel.dart';

void showDefaultTabPicker(BuildContext context, SettingsViewModel settingsViewModel) {
  final theme = Theme.of(context);
  final textColor = theme.textTheme.bodyMedium?.color ?? Colors.black;
  final accentColor = settingsViewModel.accentColorNotifier.value;
  final currentTabIndex = settingsViewModel.defaultTabNotifier.value;

  showDialog(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Default Tab',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _DefaultTabOption(
              label: 'Library',
              isSelected: currentTabIndex == 0,
              accentColor: accentColor,
              textColor: textColor,
              onTap: () {
                settingsViewModel.setDefaultTab(0);
                Navigator.pop(context);
              },
            ),
            _DefaultTabOption(
              label: 'Sessions',
              isSelected: currentTabIndex == 1,
              accentColor: accentColor,
              textColor: textColor,
              onTap: () {
                settingsViewModel.setDefaultTab(1);
                Navigator.pop(context);
              },
            ),
            _DefaultTabOption(
              label: 'Stats',
              isSelected: currentTabIndex == 2,
              accentColor: accentColor,
              textColor: textColor,
              onTap: () {
                settingsViewModel.setDefaultTab(2);
                Navigator.pop(context);
              },
            ),
            _DefaultTabOption(
              label: 'Settings',
              isSelected: currentTabIndex == 3,
              accentColor: accentColor,
              textColor: textColor,
              onTap: () {
                settingsViewModel.setDefaultTab(3);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class _DefaultTabOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color accentColor;
  final Color textColor;
  final VoidCallback onTap;

  const _DefaultTabOption({
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
