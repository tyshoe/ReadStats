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
        maxHeight: MediaQuery.of(context).size.height * 0.8, // Max 80% of screen height
      ),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Choose Accent Color',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),

          // Random Color Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                final randomColor = (ColorTools.primaryColors.toList()..shuffle()).first;
                setState(() => selectedColor = randomColor);
                widget.onColorSelected(randomColor);
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shuffle, size: 20),
                  SizedBox(width: 8),
                  Text("Random Color"),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Color Picker
          Flexible(
            child: SingleChildScrollView(
              child: ColorPicker(
                color: selectedColor,
                onColorChanged: (Color color) {
                  setState(() => selectedColor = color);
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
          ),
          const SizedBox(height: 8),
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
  showModalBottomSheet(
    context: context,
    isScrollControlled: true, // Allows the sheet to take more space when needed
    builder: (ctx) => AccentColorPicker(
      initialColor: currentColor,
      onColorSelected: onColorSelected,
    ),
  );
}