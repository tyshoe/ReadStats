import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:read_stats/ui/widgets/field_decoration.dart';

/// An audiobook's narrator and length, in hours and minutes.
class AudiobookFields extends StatefulWidget {
  final TextEditingController narratorController;
  final TextEditingController hoursController;
  final TextEditingController minutesController;
  final VoidCallback onChanged;

  /// Narrators on the reader's other books matching what is typed, offered
  /// for the name being typed now.
  final FutureOr<Iterable<String>> Function(String text)? narratorSuggestions;

  /// Shown right under the narrator and under the length — what an edition
  /// changed there.
  final Widget? narratorNote;
  final Widget? lengthNote;

  const AudiobookFields({
    super.key,
    required this.narratorController,
    required this.hoursController,
    required this.minutesController,
    required this.onChanged,
    this.narratorSuggestions,
    this.narratorNote,
    this.lengthNote,
  });

  @override
  State<AudiobookFields> createState() => _AudiobookFieldsState();
}

class _AudiobookFieldsState extends State<AudiobookFields> {
  final _narratorFocus = FocusNode();

  @override
  void dispose() {
    _narratorFocus.dispose();
    super.dispose();
  }

  /// The field takes a comma-separated cast, so suggestions are for the
  /// name after the last comma, and picking one keeps the names before it.
  String get _earlierNames {
    final text = widget.narratorController.text;
    final comma = text.lastIndexOf(',');
    return comma < 0 ? '' : text.substring(0, comma).trim();
  }

  Future<Iterable<String>> _options(TextEditingValue value) async {
    final suggestions = widget.narratorSuggestions;
    final text = value.text;
    final current = text.substring(text.lastIndexOf(',') + 1).trim();
    if (suggestions == null || current.isEmpty) return const [];
    final entered = {
      for (final name in text.split(',')) name.trim().toLowerCase(),
    };
    return (await suggestions(current)).where(
      (name) => !entered.contains(name.toLowerCase()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) => RawAutocomplete<String>(
            textEditingController: widget.narratorController,
            focusNode: _narratorFocus,
            optionsBuilder: _options,
            displayStringForOption: (name) {
              final earlier = _earlierNames;
              return earlier.isEmpty ? name : '$earlier, $name';
            },
            onSelected: (_) => widget.onChanged(),
            fieldViewBuilder: (context, controller, focusNode, _) => TextField(
              controller: controller,
              focusNode: focusNode,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => widget.onChanged(),
              onTapOutside: (_) =>
                  FocusManager.instance.primaryFocus?.unfocus(),
              decoration: filledFieldDecoration(theme).copyWith(
                labelText: 'Narrator',
                // Plural because full-cast recordings are common — the field
                // takes a comma-separated list.
                hintText: 'Enter narrator(s)',
              ),
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
        ?widget.narratorNote,
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: widget.hoursController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => widget.onChanged(),
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
                controller: widget.minutesController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (v) {
                  final val = int.tryParse(v);
                  if (val != null && val > 59) {
                    widget.minutesController.text = '59';
                  }
                  widget.onChanged();
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
        ?widget.lengthNote,
      ],
    );
  }
}
