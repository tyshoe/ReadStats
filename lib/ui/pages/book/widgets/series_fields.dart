import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:read_stats/ui/widgets/field_decoration.dart';

/// Series name (suggesting the reader's existing series) and its number.
class SeriesFields extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController positionController;
  final FocusNode nameFocus;

  /// The reader's existing series, offered as the name is typed.
  final List<String> names;

  /// Called after the name changes; the number only takes input once there
  /// is one.
  final VoidCallback onNameChanged;

  const SeriesFields({
    super.key,
    required this.nameController,
    required this.positionController,
    required this.nameFocus,
    required this.names,
    required this.onNameChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    InputDecoration decoration(String label, String hint) =>
        filledFieldDecoration(theme).copyWith(labelText: label, hintText: hint);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => RawAutocomplete<String>(
              textEditingController: nameController,
              focusNode: nameFocus,
              optionsBuilder: (value) {
                final q = value.text.trim().toLowerCase();
                if (q.isEmpty) return const Iterable<String>.empty();
                return names.where(
                  (n) => n.toLowerCase().contains(q) && n.toLowerCase() != q,
                );
              },
              fieldViewBuilder: (context, controller, focusNode, _) =>
                  TextField(
                    controller: controller,
                    focusNode: focusNode,
                    textCapitalization: TextCapitalization.words,
                    decoration: decoration('Series', 'Part of a series?'),
                    onChanged: (_) => onNameChanged(),
                    onTapOutside: (_) =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                  ),
              optionsViewBuilder: (context, onSelected, options) => Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: 220,
                      maxWidth: constraints.maxWidth,
                    ),
                    child: ListView(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      children: [
                        for (final option in options)
                          ListTile(
                            dense: true,
                            title: Text(option),
                            onTap: () => onSelected(option),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 88,
          child: TextField(
            controller: positionController,
            enabled: nameController.text.trim().isNotEmpty,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            // Whole numbers, or a decimal for an in-between novella (1.5).
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            decoration: decoration('#', '1'),
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          ),
        ),
      ],
    );
  }
}
