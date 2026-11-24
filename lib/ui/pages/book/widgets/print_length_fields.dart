import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:read_stats/ui/widgets/field_decoration.dart';

/// A printed or ebook's page and word counts.
class PrintLengthFields extends StatelessWidget {
  final TextEditingController pageController;
  final TextEditingController wordController;
  final VoidCallback onChanged;

  /// Shown right under the page count — what an edition changed there.
  final Widget? pageNote;

  const PrintLengthFields({
    super.key,
    required this.pageController,
    required this.wordController,
    required this.onChanged,
    this.pageNote,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        TextField(
          controller: pageController,
          decoration: filledFieldDecoration(
            theme,
          ).copyWith(labelText: 'Pages', hintText: 'Enter number of pages'),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => onChanged(),
          onTapOutside: (event) {
            FocusManager.instance.primaryFocus?.unfocus();
          },
        ),
        ?pageNote,
        const SizedBox(height: 16),
        TextField(
          controller: wordController,
          decoration: filledFieldDecoration(
            theme,
          ).copyWith(labelText: 'Words', hintText: 'Enter number of words'),
          keyboardType: TextInputType.number,
          onChanged: (_) => onChanged(),
          onTapOutside: (event) {
            FocusManager.instance.primaryFocus?.unfocus();
          },
        ),
      ],
    );
  }
}
