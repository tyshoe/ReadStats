import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Stores the user's profile avatar. Mirrors [CoverService]'s approach: only a
/// filename is persisted (never an absolute path), because the iOS sandbox UUID
/// changes across app updates and would invalidate stored absolute paths.
class AvatarService {
  static final ImagePicker _picker = ImagePicker();

  static const String _originalName = 'avatar_original.jpg';

  /// Pick an image from the gallery. Returns the temporary [File], or null if
  /// the user cancels. Downscaled only enough to keep the file manageable —
  /// the crop editor zooms into this image, so cropping a 600px source would
  /// leave the avatar soft.
  static Future<File?> pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 90,
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

  /// Copy [sourcePath] into permanent storage as the *original* (pre-crop)
  /// image. There is only ever one avatar, so this reuses a fixed name. The
  /// editor re-loads it so the photo can always be re-cropped from the full
  /// image instead of the already-cropped result. No-op if the source already
  /// is the stored original.
  static Future<void> saveOriginal(String sourcePath) async {
    final dir = await _dir();
    final dest = File(p.join(dir.path, _originalName));
    if (p.equals(sourcePath, dest.path)) return;
    await File(sourcePath).copy(dest.path);
    // The path is reused across changes; evict so the editor doesn't re-load
    // the previous original's cached bytes.
    await FileImage(dest).evict();
  }

  /// The stored original (pre-crop) image, or null if none exists.
  static Future<File?> originalFile() async {
    final dir = await _dir();
    final file = File(p.join(dir.path, _originalName));
    if (!await file.exists()) return null;
    await FileImage(file).evict();
    return file;
  }

  /// Delete the stored original (pre-crop) image if it exists.
  static Future<void> deleteOriginal() async {
    final dir = await _dir();
    final file = File(p.join(dir.path, _originalName));
    if (await file.exists()) await file.delete();
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
