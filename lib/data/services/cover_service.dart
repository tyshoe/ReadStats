import 'dart:io';
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
    return filename;
  }

  /// Resolve a stored cover value (filename or legacy absolute path) to the
  /// current absolute path. Always call this before passing to [Image.file].
  static Future<String> resolveFullPath(String storedPath) async {
    final dir = await _coversDir();
    return p.join(dir.path, p.basename(storedPath));
  }

  /// Delete the cover file for a book if it exists.
  static Future<void> delete(int bookId) async {
    final dir = await _coversDir();
    final file = File(p.join(dir.path, '$bookId.jpg'));
    if (await file.exists()) await file.delete();
  }

  /// Delete a cover by its stored value (filename or legacy absolute path).
  static Future<void> deleteByPath(String? path) async {
    if (path == null) return;
    final dir = await _coversDir();
    final file = File(p.join(dir.path, p.basename(path)));
    if (await file.exists()) await file.delete();
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
