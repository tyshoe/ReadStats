import 'package:flutter/cupertino.dart';
import '/viewmodels/SettingsViewModel.dart';

void showRatingStylePicker(BuildContext context, SettingsViewModel settingsViewModel) {
  final textColor = CupertinoColors.label.resolveFrom(context);
  final current = settingsViewModel.defaultRatingStyleNotifier.value;
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
                  'Rating Style',
                  style: TextStyle(fontSize: 18),
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
