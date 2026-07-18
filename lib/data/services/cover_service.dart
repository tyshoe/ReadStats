import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class CoverService {
  static final ImagePicker _picker = ImagePicker();

  /// Pick an image from the gallery and return the temporary [File].
  /// Returns null if the user cancels. The file is NOT yet in permanent storage.
  static Future<File?> pickImage() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return null;
    return File(picked.path);
  }

  /// Copy [sourcePath] to permanent app storage for [bookId] and return the
  /// filename only (e.g. "42.jpg"). Storing just the filename avoids stale
  /// absolute paths after iOS app updates, where the sandbox UUID changes.
  static Future<String> saveFromPath(int bookId, String sourcePath) async {
    final dir = await _coversDir();
    final filename = '$bookId.jpg';
    final dest = File(p.join(dir.path, filename));
    await File(sourcePath).copy(dest.path);
    // Covers overwrite the same path (<bookId>.jpg), but FileImage caches by
    // path — without evicting, the library keeps showing the old decoded image
    // until an app restart.
    await FileImage(dest).evict();
    return filename;
  }

  /// Copy [sourcePath] to permanent storage as the book's *original*
  /// (pre-crop) image, named `<bookId>_original.jpg`. The editor re-loads this
  /// so a cover can always be re-cropped from the full image instead of the
  /// already-cropped result. Returns the filename only. No-op copy if the
  /// source already is the stored original.
  static Future<String> saveOriginalFromPath(
      int bookId, String sourcePath) async {
    final dir = await _coversDir();
    final filename = '${bookId}_original.jpg';
    final dest = File(p.join(dir.path, filename));
    if (!p.equals(sourcePath, dest.path)) {
      await File(sourcePath).copy(dest.path);
      // Same path is reused across swaps; evict so the editor doesn't re-load
      // the previous original's cached bytes.
      await FileImage(dest).evict();
    }
    return filename;
  }

  /// The stored original (pre-crop) image for [bookId], or null if none exists.
  static Future<File?> originalFile(int bookId) async {
    final dir = await _coversDir();
    final file = File(p.join(dir.path, '${bookId}_original.jpg'));
    if (!await file.exists()) return null;
    // Drop any cached decode so the editor always renders (and captures) the
    // current on-disk original, not a stale one from a previous cover.
    await FileImage(file).evict();
    return file;
  }

  /// Delete a book's stored original (pre-crop) image if it exists.
  static Future<void> deleteOriginal(int bookId) async {
    final dir = await _coversDir();
    final file = File(p.join(dir.path, '${bookId}_original.jpg'));
    if (await file.exists()) await file.delete();
  }

  /// Resolve a stored cover value (filename or legacy absolute path) to the
  /// current absolute path. Always call this before passing to [Image.file].
  static Future<String> resolveFullPath(String storedPath) async {
    final dir = await _coversDir();
    return p.join(dir.path, p.basename(storedPath));
  }

  /// Delete the cover file for a book (and its stored original) if they exist.
  static Future<void> delete(int bookId) async {
    final dir = await _coversDir();
    final file = File(p.join(dir.path, '$bookId.jpg'));
    if (await file.exists()) await file.delete();
    final original = File(p.join(dir.path, '${bookId}_original.jpg'));
    if (await original.exists()) await original.delete();
  }

  /// Delete a cover by its stored value (filename or legacy absolute path).
  static Future<void> deleteByPath(String? path) async {
    if (path == null) return;
    final dir = await _coversDir();
    final file = File(p.join(dir.path, p.basename(path)));
    if (await file.exists()) await file.delete();
  }

  /// The directory where covers live. Exposed for backup export/restore.
  static Future<Directory> coversDirectory() => _coversDir();

  /// Delete every stored cover file. Used by the full data wipe so images
  /// don't linger after their books are gone.
  static Future<void> deleteAllCovers() async {
    final dir = await _coversDir();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  /// Download a cover image from [url] and return a temporary [File].
  /// Returns null if the download fails or [url] is empty.
  static Future<File?> downloadFromUrl(String url) async {
    if (url.isEmpty) return null;
    try {
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/api_cover_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await file.writeAsBytes(response.bodyBytes);
      return file;
    } catch (_) {
      return null;
    }
  }

  static Future<Directory> _coversDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'covers'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }
}
