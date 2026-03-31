import 'dart:io';
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
  /// new permanent path.
  static Future<String> saveFromPath(int bookId, String sourcePath) async {
    final dir = await _coversDir();
    final dest = File(p.join(dir.path, '$bookId.jpg'));
    await File(sourcePath).copy(dest.path);
    return dest.path;
  }

  /// Delete the cover file for a book if it exists.
  static Future<void> delete(int bookId) async {
    final dir = await _coversDir();
    final file = File(p.join(dir.path, '$bookId.jpg'));
    if (await file.exists()) await file.delete();
  }

  /// Delete a cover by its stored path (used when the path is already known).
  static Future<void> deleteByPath(String? path) async {
    if (path == null) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  static Future<Directory> _coversDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'covers'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }
}
