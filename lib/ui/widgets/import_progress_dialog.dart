import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:read_stats/data/services/import_export_service.dart';

/// What an import is doing and how far along it is, held on screen until it
/// ends: a line saying what is happening now, and a bar that fills as it
/// goes — or sweeps, while there is nothing to count yet.
///
/// For an import that leaves nothing to use while it runs — loading the demo
/// library empties the real one first. The rest show in [ImportBannerHost].
/// It can't be dismissed, and whoever showed it pops it when the import
/// returns.
class ImportProgressDialog extends StatelessWidget {
  final ValueListenable<ImportProgress?> progress;

  const ImportProgressDialog({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return PopScope(
      canPop: false,
      child: AlertDialog(
        content: ValueListenableBuilder<ImportProgress?>(
          valueListenable: progress,
          builder: (context, value, _) {
            final fraction = value?.fraction?.clamp(0.0, 1.0);
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        value?.label ?? 'Working…',
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                    if (fraction != null)
                      Text(
                        '${(fraction * 100).round()}%',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: muted,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 6,
                    backgroundColor:
                        theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Keep the app open until this finishes.',
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The import that is running, or null. Shown by [ImportBannerHost],
/// whatever screen the reader is on.
final importBanner = ValueNotifier<ImportProgress?>(null);

/// Pins [importBanner] over the app: a small pill under the status bar
/// saying what an import is doing and how far along it is, while everything
/// beneath stays usable.
///
/// Most of a restore's wait is its file arriving from a cloud folder, which
/// is no reason to hold the screen; the writing after it is over in a
/// moment. Sits in `MaterialApp.builder`, above every route.
class ImportBannerHost extends StatelessWidget {
  final Widget child;

  const ImportBannerHost({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        ValueListenableBuilder<ImportProgress?>(
          valueListenable: importBanner,
          builder: (context, value, _) {
            final theme = Theme.of(context);
            return Positioned(
              top: MediaQuery.paddingOf(context).top + 6,
              left: 0,
              right: 0,
              // Never in the way of what is under it.
              child: IgnorePointer(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: value == null
                      ? const SizedBox.shrink()
                      : Center(
                          child: Material(
                            elevation: 4,
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 14,
                                    height: 14,
                                    // Fills once there is something to
                                    // count; spins until then.
                                    child: CircularProgressIndicator(
                                      value: value.fraction,
                                      strokeWidth: 2,
                                      backgroundColor: theme
                                          .colorScheme.onSurface
                                          .withValues(alpha: 0.15),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    value.fraction == null
                                        ? value.label
                                        : '${value.label} · '
                                            '${(value.fraction! * 100).round()}%',
                                    style: theme.textTheme.labelLarge,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
