import 'package:flutter/cupertino.dart';
import '/viewmodels/SettingsViewModel.dart';

const Map<int, String> bookTypeNames = {
  1: "Paperback",
  2: "Hardback",
  3: "eBook",
  4: "Audiobook",
};

void showBookTypePicker(BuildContext context, SettingsViewModel settingsViewModel) {
  final textColor = CupertinoColors.label.resolveFrom(context);
  final accentColor = settingsViewModel.accentColorNotifier.value;
  final selectedBookType = settingsViewModel.defaultBookTypeNotifier.value;

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
                  'Default Book Format',
                  style: TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 16),
                ...bookTypeNames.entries.map((entry) {
                  final int typeId = entry.key;
                  final String typeName = entry.value;
                  final bool isSelected = typeId == selectedBookType;

                  return _BookTypeOption(
                    label: typeName,
                    selected: isSelected,
                    accentColor: accentColor,
                    textColor: textColor,
                    onTap: () {
                      settingsViewModel.setDefaultBookType(typeId);
                      Navigator.pop(context);
                    },
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _BookTypeOption extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accentColor;
  final Color textColor;
  final VoidCallback onTap;

  const _BookTypeOption({
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
