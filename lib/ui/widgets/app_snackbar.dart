import 'package:flutter/material.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class AppSnackbar {
  static void show(String message, {bool isError = false}) {
    final state = scaffoldMessengerKey.currentState;
    if (state == null) return;

    final context = scaffoldMessengerKey.currentContext;
    final colorScheme = context != null ? Theme.of(context).colorScheme : null;

    (state..hideCurrentSnackBar()).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: colorScheme?.onSurface),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError
            ? colorScheme?.error
            : colorScheme?.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
