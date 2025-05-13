import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flex_color_picker/flex_color_picker.dart';

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

  @override
  void initState() {
    super.initState();
    selectedColor = widget.initialColor;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6.resolveFrom(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Choose Accent Color',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: CupertinoColors.label.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 16),

          // Random Color Button
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: CupertinoColors.systemGrey5,
            borderRadius: BorderRadius.circular(10),
            onPressed: () {
              final randomColor = (ColorTools.primaryColors.toList()..shuffle()).first;
              setState(() {
                selectedColor = randomColor;
              });
              widget.onColorSelected(randomColor);
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(CupertinoIcons.shuffle, size: 20),
                SizedBox(width: 6),
                Text("Random Color"),
              ],
            ),
          ),

          // Color Picker
          Expanded(
            child: ColorPicker(
              color: selectedColor,
              onColorChanged: (Color color) {
                setState(() {
                  selectedColor = color;
                });
                widget.onColorSelected(color);
              },
              width: 60,
              height: 60,
              borderRadius: 8,
              spacing: 8,
              runSpacing: 8,
              wheelDiameter: MediaQuery.of(context).size.width * 0.7,
              enableOpacity: false,
              subheading: const Text('Select color shade'),
              pickerTypeLabels: const {
                ColorPickerType.primary: 'Simple',
                ColorPickerType.wheel: 'Custom',
              },
              pickersEnabled: const {
                ColorPickerType.wheel: true,
                ColorPickerType.primary: true,
                ColorPickerType.accent: false,
                ColorPickerType.both: false,
                ColorPickerType.custom: false,
              },
            ),
          ),
        ],
      ),
    );
  }
}

void showAccentColorPickerModal(
    BuildContext context,
    Color currentColor,
    ValueChanged<Color> onColorSelected,
    ) {
  showCupertinoModalPopup(
    context: context,
    builder: (ctx) => AccentColorPicker(
      initialColor: currentColor,
      onColorSelected: onColorSelected,
    ),
  );
}
