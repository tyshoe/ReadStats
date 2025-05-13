import 'package:flutter/material.dart';
import 'package:stylish_bottom_bar/stylish_bottom_bar.dart';
import '/viewmodels/SettingsViewModel.dart';


void showNavStylePicker(BuildContext context, SettingsViewModel settingsViewModel) {
  final theme = Theme.of(context);
  final textColor = theme.textTheme.bodyMedium?.color ?? Colors.black;
  final current = settingsViewModel.navStyleNotifier.value;
  final accentColor = settingsViewModel.accentColorNotifier.value;

  showDialog(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: theme.dialogBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Navigation Style',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _TabVisibilityOption(
              label: 'Simple',
              selected: current == IconStyle.simple,
              accentColor: accentColor,
              textColor: textColor,
              onTap: () {
                settingsViewModel.setNavStyle(IconStyle.simple);
                Navigator.pop(context);
              },
            ),
            _TabVisibilityOption(
              label: 'Standard',
              selected: current == IconStyle.Default,
              accentColor: accentColor,
              textColor: textColor,
              onTap: () {
                settingsViewModel.setNavStyle(IconStyle.Default);
                Navigator.pop(context);
              },
            ),
            _TabVisibilityOption(
              label: 'Animated',
              selected: current == IconStyle.animated,
              accentColor: accentColor,
              textColor: textColor,
              onTap: () {
                settingsViewModel.setNavStyle(IconStyle.animated);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class _TabVisibilityOption extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accentColor;
  final Color textColor;
  final VoidCallback onTap;

  const _TabVisibilityOption({
    required this.label,
    required this.selected,
    required this.accentColor,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: selected
          ? Icon(Icons.check, color: accentColor)
          : const SizedBox(width: 24),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 16,
          color: selected ? accentColor : textColor,
        ),
      ),
    );
  }
}
