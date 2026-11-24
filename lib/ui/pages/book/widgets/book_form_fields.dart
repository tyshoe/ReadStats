import 'package:flutter/material.dart';
import 'package:read_stats/ui/widgets/field_decoration.dart';

/// The book's format, as the form's 0-based index: paperback, hardback,
/// ebook, audiobook.
class FormatDropdown extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const FormatDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DropdownButtonFormField<int>(
      initialValue: value,
      style: theme.textTheme.bodyLarge,
      iconEnabledColor: theme.colorScheme.onSurfaceVariant,
      decoration: filledFieldDecoration(theme).copyWith(labelText: 'Format'),
      items: const [
        DropdownMenuItem(value: 0, child: Text('Paperback')),
        DropdownMenuItem(value: 1, child: Text('Hardback')),
        DropdownMenuItem(value: 2, child: Text('eBook')),
        DropdownMenuItem(value: 3, child: Text('Audiobook')),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

/// The shelf the book is on, from the reader's shelves.
class ShelfDropdown extends StatelessWidget {
  final List<Map<String, dynamic>> shelves;
  final int value;
  final ValueChanged<int> onChanged;

  const ShelfDropdown({
    super.key,
    required this.shelves,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DropdownButtonFormField<int>(
      initialValue: value,
      style: theme.textTheme.bodyLarge,
      iconEnabledColor: theme.colorScheme.onSurfaceVariant,
      decoration: filledFieldDecoration(theme).copyWith(labelText: 'Shelf'),
      items: [
        for (final shelf in shelves)
          DropdownMenuItem<int>(
            value: shelf['id'] as int,
            child: Text(shelf['name'] as String),
          ),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

/// The reader's review, growing as it's written, with a clear button.
class ReviewField extends StatelessWidget {
  final TextEditingController controller;

  /// Called after every edit, including clearing.
  final VoidCallback onChanged;

  const ReviewField({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: filledFieldDecoration(Theme.of(context)).copyWith(
        labelText: 'Review',
        hintText: 'Write your thoughts on this book...',
        alignLabelWithHint: true,
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  controller.clear();
                  onChanged();
                },
              )
            : null,
      ),
      minLines: 2,
      maxLines: null,
      onChanged: (_) => onChanged(),
      onTapOutside: (event) {
        FocusManager.instance.primaryFocus?.unfocus();
      },
    );
  }
}
