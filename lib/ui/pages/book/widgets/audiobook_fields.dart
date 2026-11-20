import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:read_stats/ui/widgets/field_decoration.dart';

/// An audiobook's narrator and length, in hours and minutes.
class AudiobookFields extends StatelessWidget {
  final TextEditingController narratorController;
  final TextEditingController hoursController;
  final TextEditingController minutesController;
  final VoidCallback onChanged;

  const AudiobookFields({
    super.key,
    required this.narratorController,
    required this.hoursController,
    required this.minutesController,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        TextField(
          controller: narratorController,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => onChanged(),
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          decoration: filledFieldDecoration(theme).copyWith(
            labelText: 'Narrator',
            // Plural because full-cast recordings are common — the field
            // takes a comma-separated list.
            hintText: 'Enter narrator(s)',
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: hoursController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => onChanged(),
                onTapOutside: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
                decoration: filledFieldDecoration(
                  theme,
                ).copyWith(labelText: 'Hours'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: minutesController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (v) {
                  final val = int.tryParse(v);
                  if (val != null && val > 59) {
                    minutesController.text = '59';
                  }
                  onChanged();
                },
                onTapOutside: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
                decoration: filledFieldDecoration(
                  theme,
                ).copyWith(labelText: 'Minutes'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
