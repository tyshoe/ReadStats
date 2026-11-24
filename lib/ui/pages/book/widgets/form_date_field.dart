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

/// The book form's start and finish dates, side by side. [onPick] and
/// [onClear] are told which one: true for the start date.
class ReadingDateFields extends StatelessWidget {
  final DateTime? started;
  final DateTime? finished;
  final void Function(bool start) onPick;
  final void Function(bool start) onClear;

  const ReadingDateFields({
    super.key,
    required this.started,
    required this.finished,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FormDateField(
            label: 'Start Date',
            date: started,
            onTap: () => onPick(true),
            onClear: () => onClear(true),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FormDateField(
            label: 'Finish Date',
            date: finished,
            onTap: () => onPick(false),
            onClear: () => onClear(false),
          ),
        ),
      ],
    );
  }
}
