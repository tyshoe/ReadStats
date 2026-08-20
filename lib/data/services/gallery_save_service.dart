import 'dart:io';
import 'dart:typed_data';

import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Writes a captured share card to the device's photo library.
///
/// Always goes via a file rather than handing the plugin raw bytes. On iOS
/// `ImageGallerySaverPlus.saveImage` re-encodes whatever it is given as JPEG:
///
/// ```swift
/// let newImage = image.jpegData(compressionQuality: CGFloat(quality / 100))!
/// ```
///
/// JPEG carries no alpha channel, so every transparent pixel composites to
/// white — which turns a card's rounded corners into white wedges and its
/// part-covered edge column into a white hairline. Sharing a card never showed
/// this because it hands over a PNG file, untouched; this takes the same route.
Future<bool> saveImageToGallery(Uint8List bytes, {required String name}) async {
  try {
    final directory = await getTemporaryDirectory();
    final path = '${directory.path}/$name.png';
    await File(path).writeAsBytes(bytes);

    // `isReturnPathOfIOS` is load-bearing, not cosmetic: it picks which branch
    // the plugin takes, and only the path-returning one registers the asset
    // straight from the file. The other decodes to a UIImage and drops the
    // alpha all over again, putting the white corners right back.
    final result = await ImageGallerySaverPlus.saveFile(
      path,
      name: name,
      isReturnPathOfIOS: true,
    ).timeout(
      // That branch reports success from inside a Photos callback that can
      // decline to fire, and a never-completing save leaves the calling sheet
      // spinning with no way back.
      const Duration(seconds: 20),
      onTimeout: () => null,
    );
    return result is Map && result['isSuccess'] == true;
  } catch (_) {
    return false;
  }
}
