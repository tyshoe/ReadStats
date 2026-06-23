import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Stores the user's profile avatar. Mirrors [CoverService]'s approach: only a
/// filename is persisted (never an absolute path), because the iOS sandbox UUID
/// changes across app updates and would invalidate stored absolute paths.
class AvatarService {
  static final ImagePicker _picker = ImagePicker();

  /// Pick an image from the gallery, downscaled for an avatar. Returns the
  /// temporary [File], or null if the user cancels.
  static Future<File?> pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 600,
      maxHeight: 600,
      imageQuality: 85,
    );
    if (picked == null) return null;
    return File(picked.path);
  }

  /// Copy [sourcePath] into permanent storage and return the new filename.
  /// A timestamped name guarantees [Image.file] reloads instead of serving a
  /// stale cached image when the avatar changes.
  static Future<String> save(String sourcePath) async {
    final dir = await _dir();
    final filename = 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(sourcePath).copy(p.join(dir.path, filename));
    return filename;
  }

  /// Resolve a stored filename to its current absolute path.
  static Future<String> resolve(String filename) async {
    final dir = await _dir();
    return p.join(dir.path, p.basename(filename));
  }

  /// Delete the avatar file for [filename] if it exists.
  static Future<void> delete(String? filename) async {
    if (filename == null) return;
    final dir = await _dir();
    final file = File(p.join(dir.path, p.basename(filename)));
    if (await file.exists()) await file.delete();
  }

  static Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'profile'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }
}
