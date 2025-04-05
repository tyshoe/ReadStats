import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '/viewmodels/SettingsViewModel.dart';

void showThemeModePicker(BuildContext context, SettingsViewModel settingsViewModel, Function(ThemeMode) toggleTheme) {
  final textColor = CupertinoColors.label.resolveFrom(context);
  final currentThemeMode = settingsViewModel.themeModeNotifier.value;
  final accentColor = settingsViewModel.accentColorNotifier.value;

  showCupertinoModalPopup(
    context: context,
    builder: (context) => GestureDetector(
      onTap: () => Navigator.pop(context), // Dismiss when tapping outside
      child: Center(
        child: CupertinoPopupSurface(
          isSurfacePainted: true,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Theme',
                  style: TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 16),
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
        ),
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
    return CupertinoButton(
      onPressed: onTap,
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          if (isSelected) Icon(CupertinoIcons.check_mark, color: accentColor),
          if (isSelected) const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: isSelected ? accentColor : textColor,
            ),
          ),
        ],
      ),
    );
  }
}
