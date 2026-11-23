import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:read_stats/data/services/auto_backup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Automatic backups in a folder the reader picked — on the phone, or in a
/// folder another app syncs (iCloud Drive on iPhone, Dropbox, OneDrive…).
///
/// Picked with the system folder picker, so it lives outside the app and
/// survives an uninstall; picking it again after a reinstall finds the old
/// backups. Access is kept by the platform side of
/// `com.tyshoe.readstats/backup_folder` (BackupFolderChannel.kt on Android,
/// AppDelegate.swift on iOS).
///
/// A folder can't carry Drive's hidden tags, so backups are known by name:
/// `ReadStats Backup 2026-11-22.zip` is a daily one, and a time after the date
/// (`… 2026-11-22 18-04.zip`) marks one made with Back up now. Book and
/// session counts are remembered on the phone, so backups from before a
/// reinstall show without them.
class FolderBackupDestination implements BackupDestination {
  FolderBackupDestination._(this._id, this._name, this._prefs);

  static const _channel = MethodChannel('com.tyshoe.readstats/backup_folder');
  static const _idKey = 'backup_folder_id';
  static const _nameKey = 'backup_folder_name';
  static const _countsKey = 'backup_folder_counts';

  static final _backupName =
      RegExp(r'^ReadStats Backup (\d{4}-\d{2}-\d{2})(?: (\d{2})-(\d{2}))?\.zip$');

  final String _id;
  String _name;
  final SharedPreferences _prefs;

  /// The folder saved from an earlier launch, if any.
  static FolderBackupDestination? saved(SharedPreferences prefs) {
    final id = prefs.getString(_idKey);
    if (id == null) return null;
    return FolderBackupDestination._(id, prefs.getString(_nameKey) ?? '', prefs);
  }

  /// Shows the system folder picker; null if the reader backs out.
  static Future<FolderBackupDestination?> pick(SharedPreferences prefs) async {
    final Map<Object?, Object?>? picked;
    try {
      picked = await _channel.invokeMapMethod<Object?, Object?>('pick');
    } on PlatformException catch (e) {
      throw BackupException('Couldn’t open that folder (${e.message}).');
    }
    if (picked == null) return null;
    final id = picked['id']! as String;
    final name = picked['name']! as String;
    final previous = prefs.getString(_idKey);
    if (previous != null && previous != id) {
      await _release(previous);
      await prefs.remove(_countsKey);
    }
    await prefs.setString(_idKey, id);
    await prefs.setString(_nameKey, name);
    return FolderBackupDestination._(id, name, prefs);
  }

  @override
  BackupDestinationKind get kind => BackupDestinationKind.folder;

  @override
  String get label => _name;

  @override
  String get restoreSource => 'folder';

  @override
  Future<void> prepare({required bool interactive}) async {
    // Also picks up a rename made in the Files app.
    final name = await _channel.invokeMethod<String>('check', {'id': _id});
    if (name != null && name != _name) {
      _name = name;
      await _prefs.setString(_nameKey, name);
    }
  }

  @override
  Future<List<BackupFile>> list() async {
    final raw = await _channel
        .invokeListMethod<Map<Object?, Object?>>('list', {'id': _id});
    final counts = _counts();
    final backups = <BackupFile>[];
    for (final f in raw ?? const <Map<Object?, Object?>>[]) {
      final name = f['name']! as String;
      final match = _backupName.firstMatch(name);
      if (match == null) continue;
      final day = match.group(1)!;
      final manual = match.group(2) != null;
      final modified = f['modified'] as int?;
      final known = counts[name] as List?;
      backups.add(BackupFile(
        id: f['ref']! as String,
        name: name,
        day: day,
        manual: manual,
        modified: modified != null
            ? DateTime.fromMillisecondsSinceEpoch(modified)
            : DateTime.parse(manual
                ? '${day}T${match.group(2)}:${match.group(3)}'
                : day),
        sizeBytes: f['size'] as int?,
        books: known?[0] as int?,
        sessions: known?[1] as int?,
      ));
    }
    backups.sort((a, b) => b.modified.compareTo(a.modified));
    return backups;
  }

  @override
  Future<void> save(File zip,
      {required String name,
      required BackupFile? replace,
      required BackupMeta meta}) async {
    await _channel.invokeMethod<void>('write', {
      'id': _id,
      'name': name,
      'src': zip.path,
      'mime': 'application/zip',
    });
    final counts = _counts()..[name] = [meta.books, meta.sessions];
    await _prefs.setString(_countsKey, jsonEncode(counts));
  }

  @override
  Future<void> remove(BackupFile file) async {
    await _channel.invokeMethod<void>('delete', {'id': _id, 'ref': file.id});
    final counts = _counts()..remove(file.name);
    await _prefs.setString(_countsKey, jsonEncode(counts));
  }

  @override
  Future<void> fetch(BackupFile file, File into,
      {void Function(int done, int? total)? progress}) async {
    await _channel.invokeMethod<void>(
        'read', {'id': _id, 'ref': file.id, 'dest': into.path});
    final size = await into.length();
    progress?.call(size, size);
  }

  @override
  Future<void> forget() async {
    await _release(_id);
    for (final key in [_idKey, _nameKey, _countsKey]) {
      await _prefs.remove(key);
    }
  }

  @override
  BackupException describe(Object e) {
    if (e is BackupException) return e;
    if (e is PlatformException) {
      if (e.code == 'no_access') {
        return const BackupException(
            'ReadStats can’t reach the backup folder anymore. Choose it again.',
            needsReconnect: true);
      }
      final message = e.message ?? '';
      if (message.contains('ENOSPC') ||
          message.toLowerCase().contains('no space') ||
          message.toLowerCase().contains('not enough')) {
        return const BackupException('There isn’t enough storage space.');
      }
      return BackupException('Couldn’t use the backup folder ($message).');
    }
    return BackupException('Backup failed: $e');
  }

  Map<String, dynamic> _counts() {
    final raw = _prefs.getString(_countsKey);
    if (raw == null) return {};
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  static Future<void> _release(String id) async {
    try {
      await _channel.invokeMethod<void>('release', {'id': id});
    } on PlatformException {
      // Already gone.
    }
  }
}
