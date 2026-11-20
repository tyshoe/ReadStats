import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Small "Added Nov 5, 2026 at 9:14 PM" line shown at the bottom of the form when
/// editing an existing book. date_added is stored by the DB on insert.
class AddedDateLine extends StatelessWidget {
  /// The book's date_added, as stored.
  final Object? dateAdded;

  /// The reader's date format pattern.
  final String format;

  const AddedDateLine({
    super.key,
    required this.dateAdded,
    required this.format,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final raw = dateAdded?.toString();
    final added = (raw == null || raw.isEmpty) ? null : DateTime.tryParse(raw);
    if (added == null) return const SizedBox.shrink();

    String formatted;
    try {
      formatted = DateFormat(format).format(added);
    } catch (_) {
      formatted = DateFormat('MMM d, yyyy').format(added);
    }
    final time = DateFormat('h:mm a').format(added);

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Added $formatted at $time',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
