import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:read_stats/ui/widgets/field_decoration.dart';

/// A read-only date field: tapping it opens a picker ([onTap]), and once
/// it holds a date, a clear button replaces the calendar icon.
class FormDateField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const FormDateField({
    super.key,
    required this.label,
    required this.date,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final date = this.date;
    return TextFormField(
      readOnly: true,
      onTap: onTap,
      controller: TextEditingController(
        text: date == null ? '' : DateFormat('MMM d, y').format(date),
      ),
      decoration: filledFieldDecoration(Theme.of(context)).copyWith(
        labelText: label,
        suffixIcon: date != null
            ? IconButton(icon: const Icon(Icons.clear), onPressed: onClear)
            : const Icon(Icons.calendar_today),
      ),
      onTapOutside: (event) {
        FocusManager.instance.primaryFocus?.unfocus();
      },
    );
  }
}
