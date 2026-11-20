import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:read_stats/data/models/cover_shape.dart';
import 'package:read_stats/ui/pages/book/widgets/cover_loading_placeholder.dart';

/// Where a book cover is sourced from in the cover-source chooser.
enum CoverSource { online, gallery, camera }

/// Bottom-sheet chooser for where the cover comes from: online (Open
/// Library) search, the device photo library, or the camera.
Future<CoverSource?> showCoverSourceSheet(BuildContext context) {
  return showModalBottomSheet<CoverSource>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.cloud_outlined),
            title: const Text('Search online'),
            subtitle: const Text('Find a cover from Open Library'),
            onTap: () => Navigator.pop(ctx, CoverSource.online),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Photo library'),
            subtitle: const Text('Choose an image from your device'),
            onTap: () => Navigator.pop(ctx, CoverSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take a photo'),
            subtitle: const Text('Capture a cover with your camera'),
            onTap: () => Navigator.pop(ctx, CoverSource.camera),
          ),
        ],
      ),
    ),
    backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
  );
}

/// The book form's cover well: the cover over a blur of itself, with crop
/// and remove buttons, or an "Add cover image" prompt.
class BookCoverPicker extends StatelessWidget {
  final File? coverFile;
  final int coverShape;

  /// A cover on its way down. Shown as a placeholder, or a spinner over the
  /// cover it would replace.
  final bool loading;

  /// Opens the source chooser; null while a cover is being picked.
  final VoidCallback? onTap;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const BookCoverPicker({
    super.key,
    required this.coverFile,
    required this.coverShape,
    required this.loading,
    required this.onTap,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const double coverW = 150;
    final double coverH = coverW / CoverShape.aspectRatio(coverShape);
    final cover = coverFile;
    final bool hasCover = cover != null;
    // Enough room for the cover plus the surrounding blurred margin. Follows
    // the cover's height so a square one doesn't sit in a portrait-sized well.
    final double areaH = hasCover || loading ? coverH + 70 : 90.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: areaH,
        width: double.infinity,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Background — blurred cover or plain surface
            if (cover != null)
              Positioned.fill(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                  child: Image.file(cover, fit: BoxFit.cover),
                ),
              )
            else
              Positioned.fill(
                child: Container(
                  color: theme.colorScheme.surfaceContainerHighest,
                ),
              ),

            // Dim overlay so cover pops
            if (hasCover)
              Positioned.fill(
                child: Container(color: Colors.black.withValues(alpha: 0.35)),
              ),

            // Ripple layer — above backgrounds so the ink is visible
            Positioned.fill(
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(onTap: onTap),
              ),
            ),

            // Cover image
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: cover != null
                      ? Image.file(
                          cover,
                          width: coverW,
                          height: coverH,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              _coverPlaceholder(theme, coverW, coverH),
                        )
                      : loading
                      ? CoverLoadingPlaceholder(
                          width: coverW,
                          height: coverH,
                          theme: theme,
                        )
                      : _emptyPlaceholder(theme),
                ),
              ],
            ),

            // A replacement on its way down. The cover underneath is still
            // the book's, and stays so if the new one never arrives.
            if (loading && hasCover)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.35),
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(color: Colors.white),
                  ),
                ),
              ),

            // Edit button — top-left corner.
            if (hasCover)
              Positioned(
                top: 8,
                left: 8,
                child: IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.crop, size: 22),
                  color: Colors.white,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.45),
                    minimumSize: const Size(44, 44),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),

            // Remove button — top-right corner
            if (hasCover || loading)
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete, size: 22),
                  color: Colors.white,
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.error.withValues(
                      alpha: 0.85,
                    ),
                    minimumSize: const Size(44, 44),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _emptyPlaceholder(ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.add_photo_alternate_outlined,
          size: 20,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Text(
          'Add cover image',
          style: TextStyle(
            fontSize: 13,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _coverPlaceholder(ThemeData theme, double w, double h) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate_outlined,
            size: 32,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 6),
          Text(
            'Add cover',
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
