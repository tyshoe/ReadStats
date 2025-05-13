import 'package:flutter/material.dart';
import '/viewmodels/SettingsViewModel.dart';

void showRatingStylePicker(
    BuildContext context, SettingsViewModel settingsViewModel) {
  final theme = Theme.of(context);
  final textColor = theme.textTheme.bodyMedium?.color ?? Colors.black;
  final accentColor = settingsViewModel.accentColorNotifier.value;
  final current = settingsViewModel.defaultRatingStyleNotifier.value;

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
            const Text(
              'Rating Style',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _RatingStyleOption(
              label: 'Stars',
              selected: current == 0,
              accentColor: accentColor,
              textColor: textColor,
              onTap: () {
                settingsViewModel.setDefaultRatingStyle(0);
                Navigator.pop(context);
              },
            ),
            _RatingStyleOption(
              label: 'Numbers',
              selected: current == 1,
              accentColor: accentColor,
              textColor: textColor,
              onTap: () {
                settingsViewModel.setDefaultRatingStyle(1);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class _RatingStyleOption extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accentColor;
  final Color textColor;
  final VoidCallback onTap;

  const _RatingStyleOption({
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
          : const SizedBox(width: 24), // keep alignment
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