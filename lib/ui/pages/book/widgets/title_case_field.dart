import 'dart:async';

import 'package:flutter/material.dart';
import 'package:read_stats/ui/widgets/field_decoration.dart';

/// "the lord of the rings" → "The Lord of the Rings": every word capitalised
/// except short joining words after the first.
String toTitleCase(String text) {
  if (text.isEmpty) return text;

  const wordsToLowercase = {
    'a',
    'an',
    'the',
    'and',
    'but',
    'or',
    'nor',
    'as',
    'at',
    'by',
    'for',
    'from',
    'in',
    'into',
    'near',
    'of',
    'on',
    'onto',
    'to',
    'with',
  };

  final words = text.split(' ');
  final result = StringBuffer();

  for (int i = 0; i < words.length; i++) {
    if (words[i].isNotEmpty) {
      final currentWord = words[i].toLowerCase();

      if (i == 0 || !wordsToLowercase.contains(currentWord)) {
        result.write(words[i][0].toUpperCase());
        if (words[i].length > 1) {
          result.write(words[i].substring(1).toLowerCase());
        }
      } else {
        result.write(currentWord);
      }

      if (i < words.length - 1) {
        result.write(' ');
      }
    }
  }

  return result.toString();
}

/// A text field that title-cases as the reader types, with a button beside
/// it that turns that off (lower-casing the text) and back on. With
/// [suggestions], it also offers completions as the reader types.
class TitleCaseField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool titleCase;
  final ValueChanged<bool> onTitleCaseChanged;

  /// Called after every edit, once the text has been title-cased.
  final VoidCallback onChanged;
  final FutureOr<Iterable<String>> Function(String text)? suggestions;

  const TitleCaseField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.titleCase,
    required this.onTitleCaseChanged,
    required this.onChanged,
    this.suggestions,
  });

  void _formatAsTyped(String value) {
    if (titleCase && value.isNotEmpty) {
      final formattedValue = toTitleCase(value);
      if (value != formattedValue) {
        final cursorPos = controller.selection.baseOffset;
        controller.value = controller.value.copyWith(
          text: formattedValue,
          selection: TextSelection.collapsed(offset: cursorPos),
        );
      }
    }
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final decoration = filledFieldDecoration(theme).copyWith(
      labelText: label,
      hintText: hint,
      floatingLabelBehavior: FloatingLabelBehavior.auto,
    );
    final suggestions = this.suggestions;

    final Widget field;
    if (suggestions == null) {
      field = TextField(
        controller: controller,
        decoration: decoration,
        onChanged: _formatAsTyped,
      );
    } else {
      field = Autocomplete<String>(
        optionsBuilder: (textEditingValue) {
          if (textEditingValue.text.isEmpty) {
            return const Iterable<String>.empty();
          }
          return suggestions(textEditingValue.text);
        },
        fieldViewBuilder:
            (context, textEditingController, focusNode, onFieldSubmitted) {
              textEditingController.text = controller.text;
              controller.addListener(() {
                if (textEditingController.text != controller.text) {
                  textEditingController.text = controller.text;
                }
              });

              return TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: decoration,
                onChanged: _formatAsTyped,
              );
            },
        onSelected: (selection) {
          final formatted = titleCase ? toTitleCase(selection) : selection;
          controller.text = formatted;
          controller.selection = TextSelection.fromPosition(
            TextPosition(offset: formatted.length),
          );
          onChanged();
        },
      );
    }

    return Row(
      children: [
        Expanded(child: field),
        const SizedBox(width: 8),
        SizedBox(
          width: 56,
          height: 56,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              final next = !titleCase;
              if (controller.text.isNotEmpty) {
                controller.text = next
                    ? toTitleCase(controller.text)
                    : controller.text.toLowerCase();
              }
              onTitleCaseChanged(next);
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: titleCase
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceContainerHighest,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.text_fields,
                color: titleCase
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
