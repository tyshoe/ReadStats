import 'package:flutter/material.dart';

/// The filled, rounded, borderless field the app's forms are built from.
///
/// A field adds what is its own with `copyWith` — a label, a hint, a suffix
/// icon — so the look is set here once rather than restated on every field.
InputDecoration filledFieldDecoration(ThemeData theme) {
  final border = UnderlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide.none,
  );
  return InputDecoration(
    filled: true,
    fillColor: theme.colorScheme.surfaceContainerHighest,
    border: border,
    enabledBorder: border,
    focusedBorder: border,
    contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
  );
}
