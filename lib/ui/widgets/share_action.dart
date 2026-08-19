import 'package:flutter/material.dart';

/// The Save / Share button at the foot of a share sheet: a round icon with its
/// label under it, swapping to a spinner while the capture runs and to a green
/// tick once a save has landed.
///
/// Shared by the book and monthly recap sheets rather than written twice, so a
/// change to one is a change to both — the two sheets are meant to be the same
/// sheet with different cards in it.
class ShareAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final ThemeData theme;

  /// Null disables the button, which is also how a sheet greys the pair out
  /// while either of them is working.
  final VoidCallback? onTap;

  final bool isLoading;
  final bool isSuccess;

  const ShareAction({
    super.key,
    required this.icon,
    required this.label,
    required this.theme,
    required this.onTap,
    this.isLoading = false,
    this.isSuccess = false,
  });

  static const Color _successColor = Color(0xFF34C759);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: isSuccess
                ? _successColor
                : theme.colorScheme.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          child: isLoading
              ? Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                )
              : isSuccess
                  ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 28)
                  : IconButton(
                      icon: Icon(icon, size: 26),
                      color: onTap != null
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                      onPressed: onTap,
                    ),
        ),
        const SizedBox(height: 6),
        Text(
          isSuccess ? 'Saved!' : label,
          style: TextStyle(
            fontSize: 12,
            color: isSuccess
                ? _successColor
                : onTap != null
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.3),
          ),
        ),
      ],
    );
  }
}
