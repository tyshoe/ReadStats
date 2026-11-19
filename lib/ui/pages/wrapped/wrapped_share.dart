import 'dart:io';
import 'dart:typed_data';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:read_stats/data/services/gallery_save_service.dart';
import 'package:read_stats/domain/wrapped_story.dart';
import 'package:read_stats/ui/pages/wrapped/slides/wrapped_slide_view.dart';
import 'package:read_stats/ui/widgets/share_action.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

/// The share image's layout size. Captured at 3×, that is 1080×1920 — a full
/// story frame on Instagram, and a clean 9:16 everywhere else.
const Size kWrappedShareSize = Size(360, 640);
const double _kSharePixelRatio = 3;

/// Renders [slide] as a finished 9:16 image and offers to save or share it.
///
/// The slide is drawn by the same widget the player uses, with its entrance
/// complete, its backdrop still, and the ReadStats mark along the foot — so
/// what is posted is exactly what the reader just saw.
Future<void> shareWrappedSlide({
  required BuildContext context,
  required WrappedStory story,
  required WrappedSlide slide,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  Uint8List? bytes;
  try {
    // Covers are files on disk. Decoding them before the capture means the
    // off-screen frame paints with its art instead of empty boxes.
    final covers = <String>{
      for (final b in [...story.wrapped.finished, ...story.wrapped.booksRead])
        if (b.hasCover) b.coverPath!,
    };
    await Future.wait([
      for (final path in covers)
        precacheImage(FileImage(File(path)), context, onError: (_, _) {}),
    ]);
    if (!context.mounted) return;

    final view = MediaQuery(
      data: MediaQuery.of(context).copyWith(
        size: kWrappedShareSize,
        padding: EdgeInsets.zero,
        viewPadding: EdgeInsets.zero,
        viewInsets: EdgeInsets.zero,
        textScaler: TextScaler.noScaling,
        disableAnimations: true,
      ),
      child: SizedBox.fromSize(
        size: kWrappedShareSize,
        child: WrappedSlideView(
          slide: slide,
          env: SlideEnv(
            story: story,
            entrance: kAlwaysCompleteAnimation,
            ambient: const AlwaysStoppedAnimation(0.15),
            insets: const EdgeInsets.fromLTRB(0, 36, 0, 26),
            shareMode: true,
          ),
        ),
      ),
    );

    bytes = await ScreenshotController().captureFromWidget(
      view,
      context: context,
      targetSize: kWrappedShareSize,
      pixelRatio: _kSharePixelRatio,
      delay: const Duration(milliseconds: 120),
    );
  } catch (_) {
    bytes = null;
  }

  if (!context.mounted) return;
  if (bytes == null) {
    messenger?.showSnackBar(
      const SnackBar(content: Text('Couldn’t create the image. Try again.')),
    );
    return;
  }

  final year = story.wrapped.year;
  final name = 'wrapped_${year}_${slide.name}';
  final image = bytes;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _WrappedShareSheet(
      image: image,
      onSave: () => saveImageToGallery(
        image,
        name: '${name}_${DateTime.now().millisecondsSinceEpoch}',
      ),
      onShare: () async {
        try {
          final dir = await getTemporaryDirectory();
          final path = '${dir.path}/$name.png';
          await File(path).writeAsBytes(image);
          await SharePlus.instance.share(ShareParams(
            files: [XFile(path)],
            text: 'My $year in reading.',
          ));
          return true;
        } catch (_) {
          return false;
        }
      },
    ),
  );
}

class _WrappedShareSheet extends StatefulWidget {
  final Uint8List image;
  final Future<bool> Function() onSave;
  final Future<bool> Function() onShare;

  const _WrappedShareSheet({
    required this.image,
    required this.onSave,
    required this.onShare,
  });

  @override
  State<_WrappedShareSheet> createState() => _WrappedShareSheetState();
}

class _WrappedShareSheetState extends State<_WrappedShareSheet> {
  bool _saving = false;
  bool _sharing = false;
  bool _saved = false;
  String? _error;

  bool get _busy => _saving || _sharing;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final ok = await widget.onSave();
    if (!mounted) return;
    setState(() {
      _saving = false;
      _saved = ok;
      if (!ok) _error = 'Couldn’t save to your gallery.';
    });
  }

  Future<void> _share() async {
    setState(() {
      _sharing = true;
      _error = null;
    });
    final ok = await widget.onShare();
    if (!mounted) return;
    setState(() {
      _sharing = false;
      if (!ok) _error = 'Couldn’t open the share sheet.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxPreviewHeight = MediaQuery.sizeOf(context).height * 0.55;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxPreviewHeight),
              child: AspectRatio(
                aspectRatio: kWrappedShareSize.aspectRatio,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.memory(widget.image, fit: BoxFit.cover),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ShareAction(
                  icon: FluentIcons.arrow_download_16_filled,
                  label: 'Save',
                  theme: theme,
                  onTap: _busy || _saved ? null : _save,
                  isLoading: _saving,
                  isSuccess: _saved,
                ),
                const SizedBox(width: 40),
                ShareAction(
                  icon: FluentIcons.share_16_filled,
                  label: 'Share',
                  theme: theme,
                  onTap: _busy ? null : _share,
                  isLoading: _sharing,
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error)),
            ],
          ],
        ),
      ),
    );
  }
}
