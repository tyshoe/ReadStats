import 'package:flutter/material.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class AppSnackbar {
  /// Pass [actionLabel] and [onAction] to offer an undo. The bar stays up
  /// longer in that case — two seconds isn't enough to read it and react.
  static void show(
    String message, {
    bool isError = false,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final state = scaffoldMessengerKey.currentState;
    if (state == null) return;

    final context = scaffoldMessengerKey.currentContext;
    final colorScheme = context != null ? Theme.of(context).colorScheme : null;
    final hasAction = actionLabel != null && onAction != null;

    (state..hideCurrentSnackBar()).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: colorScheme?.onSurface),
        ),
        action: hasAction
            ? SnackBarAction(
                label: actionLabel,
                textColor: colorScheme?.primary,
                onPressed: onAction,
              )
            : null,
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError
            ? colorScheme?.error
            : colorScheme?.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        duration: Duration(seconds: hasAction ? 5 : 2),
      ),
    );
  }
}
