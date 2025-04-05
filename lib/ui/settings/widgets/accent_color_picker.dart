import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AccentColorPicker extends StatefulWidget {
  final Color initialColor;
  final ValueChanged<Color> onColorSelected;

  const AccentColorPicker({
    required this.initialColor,
    required this.onColorSelected,
    super.key,
  });

  @override
  State<AccentColorPicker> createState() => _AccentColorPickerState();
}

class _AccentColorPickerState extends State<AccentColorPicker> {
  late Color selectedColor;

  final List<Color> colors = [
    CupertinoColors.systemPink,
    CupertinoColors.systemOrange,
    CupertinoColors.systemYellow,
    CupertinoColors.systemGreen,
    CupertinoColors.systemTeal,
    CupertinoColors.systemCyan,
    CupertinoColors.systemBlue,
    CupertinoColors.systemIndigo,
    CupertinoColors.systemPurple,
    CupertinoColors.systemMint,
    CupertinoColors.systemBrown,
    CupertinoColors.systemGrey,
  ];

  @override
  void initState() {
    super.initState();
    selectedColor = widget.initialColor;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 340,
      padding: const EdgeInsets.all(16),
      color: CupertinoColors.systemGrey6.resolveFrom(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.center,
            child: Text('Choose Accent Color', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.center,
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: CupertinoColors.systemGrey5,
              borderRadius: BorderRadius.circular(10),
              onPressed: () {
                final randomColor = (colors.toList()..shuffle()).first;
                setState(() => selectedColor = randomColor);
                widget.onColorSelected(randomColor);
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(CupertinoIcons.shuffle, size: 20),
                  SizedBox(width: 6),
                  Text("Random"),
                ],
              ),
            ),
          ),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: colors.length,
              itemBuilder: (context, index) {
                final color = colors[index];
                final isSelected = color == selectedColor;

                final isDarkColor = ThemeData.estimateBrightnessForColor(color) == Brightness.dark;
                final checkmarkColor = isDarkColor ? CupertinoColors.white : CupertinoColors.black;

                final borderColor = isSelected
                    ? HSLColor.fromColor(color)
                    .withLightness((HSLColor.fromColor(color).lightness - 0.25).clamp(0.0, 1.0))
                    .toColor()
                    : null;

                return GestureDetector(
                  onTap: () {
                    setState(() => selectedColor = color);
                    widget.onColorSelected(color);
                    Navigator.pop(context);
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected ? Border.all(color: borderColor!, width: 3) : null,
                        ),
                      ),
                      if (isSelected)
                        Icon(
                          CupertinoIcons.check_mark,
                          color: checkmarkColor,
                          size: 28,
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

void showAccentColorPickerModal(BuildContext context, Color currentColor, ValueChanged<Color> onColorSelected) {
  showCupertinoModalPopup(
    context: context,
    builder: (ctx) => AccentColorPicker(
      initialColor: currentColor,
      onColorSelected: onColorSelected,
    ),
  );
}
