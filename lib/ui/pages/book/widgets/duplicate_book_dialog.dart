import 'package:flutter/material.dart';

/// Warns that a book with this title and author is already in the library.
/// True when the reader chooses to add it anyway.
Future<bool> confirmDuplicateBook(BuildContext context) async {
  final proceed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Duplicate Book'),
      content: const Text(
        'A book with this title and author already exists. '
        'Are you sure you want to add it anyway?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'Cancel',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Add Anyway'),
        ),
      ],
    ),
  );
  return proceed == true;
}
