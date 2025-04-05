import 'package:flutter/cupertino.dart';
import '/viewmodels/SettingsViewModel.dart';

void showDefaultTabPicker(BuildContext context, SettingsViewModel settingsViewModel) {
  final textColor = CupertinoColors.label.resolveFrom(context);
  final currentTabIndex = settingsViewModel.defaultTabNotifier.value;
  final accentColor = settingsViewModel.accentColorNotifier.value;

  showCupertinoModalPopup(
    context: context,
    builder: (context) => GestureDetector(
      onTap: () => Navigator.pop(context), // Dismiss when tapping outside
      child: Center(
        child: CupertinoPopupSurface(
          isSurfacePainted: true,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9, // Adjust width as needed
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, // Align left
              children: [
                const Text(
                  'Default Tab',
                  style: TextStyle(fontSize: 18),
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
