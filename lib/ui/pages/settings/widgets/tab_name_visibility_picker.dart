import 'package:flutter/cupertino.dart';
import '/viewmodels/SettingsViewModel.dart'; // Adjust path as needed

void showTabNameVisibilityPicker(BuildContext context, SettingsViewModel settingsViewModel) {
  final textColor = CupertinoColors.label.resolveFrom(context);
  final current = settingsViewModel.tabNameVisibilityNotifier.value;
  final accentColor = settingsViewModel.accentColorNotifier.value;

  showCupertinoModalPopup(
    context: context,
    builder: (context) => GestureDetector(
      onTap: () => Navigator.pop(context),
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
                  'Tab Name Visibility',
                  style: TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 16),
                _TabVisibilityOption(
                  label: 'Always',
                  selected: current == 'Always',
                  accentColor: accentColor,
                  textColor: textColor,
                  onTap: () {
                    settingsViewModel.setTabNameVisibility('Always');
                    Navigator.pop(context);
                  },
                ),
                _TabVisibilityOption(
                  label: 'Selected',
                  selected: current == 'Selected',
                  accentColor: accentColor,
                  textColor: textColor,
                  onTap: () {
                    settingsViewModel.setTabNameVisibility('Selected');
                    Navigator.pop(context);
                  },
                ),
                _TabVisibilityOption(
                  label: 'Never',
                  selected: current == 'Never',
                  accentColor: accentColor,
                  textColor: textColor,
                  onTap: () {
                    settingsViewModel.setTabNameVisibility('Never');
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
    return CupertinoButton(
      onPressed: onTap,
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          if (selected) Icon(CupertinoIcons.check_mark, color: accentColor),
          if (selected) const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: selected ? accentColor : textColor,
            ),
          ),
        ],
      ),
    );
  }
}
