import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:read_stats/data/services/analytics_service.dart';
import 'package:read_stats/data/services/cover_service.dart';
import 'package:read_stats/data/services/drive_backup_destination.dart';
import 'package:read_stats/data/services/folder_backup_destination.dart';
import 'package:read_stats/data/services/import_export_service.dart';
import 'package:read_stats/data/services/milestone_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where automatic backups go.
enum BackupDestinationKind { drive, folder }

/// Where automatic backup stands, for the screens that show it.
@immutable
class AutoBackupStatus {
  /// Where backups go; null until the reader picks somewhere.
  final BackupDestinationKind? kind;

  /// The Google account, or the folder's name.
  final String? label;

  /// Whether the daily backup is on.
  final bool auto;

  /// When a backup last landed.
  final DateTime? lastBackup;

  /// Why the last automatic backup didn't happen, in words for the reader;
  /// null once one succeeds.
  final String? error;

  /// True while the fix for [error] is choosing the destination again —
  /// access was lost — rather than waiting.
  final bool needsReconnect;

  /// A backup is being made right now.
  final bool running;

  const AutoBackupStatus({
    this.kind,
    this.label,
    this.auto = true,
    this.lastBackup,
    this.error,
    this.needsReconnect = false,
    this.running = false,
  });

  bool get connected => kind != null;

  AutoBackupStatus copyWith({
    DateTime? Function()? lastBackup,
    String? Function()? error,
    bool? auto,
    bool? needsReconnect,
    bool? running,
  }) =>
      AutoBackupStatus(
        kind: kind,
        label: label,
        auto: auto ?? this.auto,
        lastBackup: lastBackup != null ? lastBackup() : this.lastBackup,
        error: error != null ? error() : this.error,
        needsReconnect: needsReconnect ?? this.needsReconnect,
        running: running ?? this.running,
      );
}

/// One backup at its destination.
@immutable
class BackupFile {
  /// The destination's handle for it: a Drive file id, or a folder file ref.
  final String id;
  final String name;
  final DateTime modified;

  /// The day it was made for, `yyyy-MM-dd` — what a same-day daily backup
  /// replaces.
  final String? day;
  final int? sizeBytes;
  final int? books;
  final int? sessions;

  /// Made with Back up now rather than by the daily backup.
  final bool manual;

  const BackupFile({
    required this.id,
    required this.name,
    required this.modified,
    this.day,
    this.sizeBytes,
    this.books,
    this.sessions,
    this.manual = false,
  });
}

/// What a backup being saved holds, for destinations that label their files.
@immutable
class BackupMeta {
  final String day;
  final bool manual;
  final int books;
  final int sessions;
  final int covers;

  const BackupMeta({
    required this.day,
    required this.manual,
    required this.books,
    required this.sessions,
    required this.covers,
  });
}

/// A backup step that failed, with a message fit to show the reader.
class BackupException implements Exception {
  final String message;
  final bool needsReconnect;
  const BackupException(this.message, {this.needsReconnect = false});

  @override
  String toString() => message;
}

/// Somewhere backups can go: Google Drive, or a folder the reader picked.
abstract class BackupDestination {
  BackupDestinationKind get kind;

  /// The Google account, or the folder's name.
  String get label;

  /// What analytics hears a restore came from.
  String get restoreSource;

  /// Makes sure the destination can be reached before the covers are packed —
  /// so offline, or with access lost, a backup fails in a moment. May show
  /// UI when [interactive].
  Future<void> prepare({required bool interactive});

  /// Every backup there, newest first.
  Future<List<BackupFile>> list();

  /// Saves [zip] as [name], over [replace] if given.
  Future<void> save(File zip,
      {required String name,
      required BackupFile? replace,
      required BackupMeta meta});

  /// Removes an old backup (to Drive's trash, for Drive).
  Future<void> remove(BackupFile file);

  /// Copies [file] to [into], reporting bytes as they arrive.
  Future<void> fetch(BackupFile file, File into,
      {void Function(int done, int? total)? progress});

  /// Stops using this destination and gives up access to it. Backups already
  /// there stay.
  Future<void> forget();

  /// [error] in words for the reader.
  BackupException describe(Object error);
}

/// Backs the library up once a day, to Google Drive or to a folder the reader
/// picked, and restores from there.
///
/// What a destination holds:
///
/// ```
/// ReadStats Backups/                       (Drive: made by the app;
///  ├─ ReadStats Backup 2026-11-22.zip       folder: the one picked)
///  ├─ ReadStats Backup 2026-11-21 18-04.zip   ← made with Back up now
///  └─ …
/// ```
///
/// The daily backup keeps one file per day, replacing it if it runs again
/// that day, and the newest [keepDaily] are kept. Back up now always adds a
/// new file, and the newest [keepManual] of those are kept separately, so
/// they never push out the daily history.
///
/// Each zip is exactly what Settings → Export Backup makes, so either restore
/// takes either.
///
/// Once a day — at launch or on coming back to the app, the first time each
/// calendar day — and only when the library changed since the last backup, so
/// the days kept are all different. An empty library and the demo one are
/// never backed up automatically: a wiped phone must not push the real
/// backups out.
class AutoBackupService {
  AutoBackupService._();
  static final instance = AutoBackupService._();

  static const keepDaily = 7;
  static const keepManual = 5;

  static const _kindKey = 'auto_backup_destination';
  static const _autoKey = 'auto_backup_on';
  static const _lastBackupKey = 'auto_backup_last';
  static const _lastCheckKey = 'auto_backup_last_check';
  static const _fingerprintKey = 'auto_backup_fingerprint';

  final status = ValueNotifier<AutoBackupStatus>(const AutoBackupStatus());

  BackupDestination? _destination;
  ImportExportService? _io;
  Future<void>? _loaded;
  Future<bool>? _running;
  AppLifecycleListener? _lifecycle;

  /// Loads the saved state and starts the daily check. Called once, at
  /// launch.
  void start(ImportExportService io) {
    _io = io;
    _loaded ??= _load();
    _lifecycle ??= AppLifecycleListener(onResume: _backUpIfDue);
    // Let launch settle first: a backup reads every table and packs every
    // cover.
    Future<void>.delayed(const Duration(seconds: 8), _backUpIfDue);
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    var kind = BackupDestinationKind.values
        .where((k) => k.name == prefs.getString(_kindKey))
        .firstOrNull;
    // Set up before folders were an option, when Drive was the only place.
    if (kind == null && DriveBackupDestination.saved(prefs) != null) {
      kind = BackupDestinationKind.drive;
      await prefs.setString(_kindKey, kind.name);
    }
    _destination = switch (kind) {
      BackupDestinationKind.drive => DriveBackupDestination.saved(prefs),
      BackupDestinationKind.folder => FolderBackupDestination.saved(prefs),
      null => null,
    };
    final last = prefs.getString(_lastBackupKey);
    _publish(
      auto: prefs.getBool(_autoKey) ?? true,
      lastBackup: last == null ? null : DateTime.tryParse(last),
    );
  }

  /// Rebuilds [status] around the current destination.
  void _publish({
    required bool auto,
    DateTime? lastBackup,
    String? error,
    bool needsReconnect = false,
  }) {
    final destination = _destination;
    status.value = AutoBackupStatus(
      kind: destination?.kind,
      label: destination?.label,
      auto: auto,
      lastBackup: lastBackup,
      error: error,
      needsReconnect: needsReconnect,
    );
  }

  // ─── Choosing where ───────────────────────────────────────────────────────

  /// Asks for a Google account and Drive access. Throws
  /// [BackupException], or a sign-in exception if the reader backs out.
  Future<void> useDrive() async {
    await _loaded;
    final prefs = await SharedPreferences.getInstance();
    await _use(await DriveBackupDestination.connect(prefs), prefs);
  }

  /// Shows the folder picker. Returns false if the reader backs out.
  Future<bool> useFolder() async {
    await _loaded;
    final prefs = await SharedPreferences.getInstance();
    final folder = await FolderBackupDestination.pick(prefs);
    if (folder == null) return false;
    await _use(folder, prefs);
    return true;
  }

  /// Chooses the same kind of destination again — after access was lost.
  /// Returns false if the reader backs out.
  Future<bool> reconnect() async {
    switch (status.value.kind) {
      case BackupDestinationKind.drive:
        await useDrive();
        return true;
      case BackupDestinationKind.folder:
        return useFolder();
      case null:
        return false;
    }
  }

  Future<void> _use(BackupDestination destination, SharedPreferences prefs) async {
    final previous = _destination;
    if (previous != null &&
        (previous.kind != destination.kind ||
            previous.label != destination.label)) {
      // A new place has none of the backups the fingerprint vouches for.
      await prefs.remove(_fingerprintKey);
      await prefs.remove(_lastCheckKey);
    }
    _destination = destination;
    await prefs.setString(_kindKey, destination.kind.name);
    _publish(auto: status.value.auto, lastBackup: status.value.lastBackup);
    AnalyticsService.instance.backupDestinationSet(destination.kind.name);
  }

  /// Stops backing up and gives up access to the destination. The backups
  /// already there stay.
  Future<void> stop() async {
    await _loaded;
    final destination = _destination;
    if (destination == null) return;
    await destination.forget();
    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      _kindKey,
      _lastBackupKey,
      _lastCheckKey,
      _fingerprintKey,
    ]) {
      await prefs.remove(key);
    }
    _destination = null;
    _publish(auto: status.value.auto);
    AnalyticsService.instance.backupDestinationRemoved(destination.kind.name);
  }

  Future<void> setAuto(bool on) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoKey, on);
    status.value = status.value.copyWith(auto: on);
    if (on) unawaited(_backUpIfDue());
  }

  // ─── Backing up ───────────────────────────────────────────────────────────

  /// Backs up now, even if nothing changed. Throws [BackupException] with a
  /// message to show if it fails.
  ///
  /// A [manual] backup is saved as its own file and never replaced;
  /// otherwise this is today's daily backup, made early (the first one after
  /// choosing a destination).
  Future<void> backUpNow({bool manual = true}) async {
    await _loaded;
    await _run(automatic: false, daily: !manual);
  }

  Future<void> _backUpIfDue() async {
    await _loaded;
    final s = status.value;
    if (!s.connected || !s.auto || s.needsReconnect || _io == null) return;
    // A restore or import is half-written until it ends.
    if (MilestoneService.bulkInProgress) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_lastCheckKey) == _today()) return;
    try {
      await _run(automatic: true, daily: true);
    } catch (_) {
      // Recorded in [status] for the backup page; tried again next time.
    }
  }

  /// One backup at a time: a second request joins the one running.
  Future<bool> _run({required bool automatic, required bool daily}) {
    return _running ??= _backUp(automatic: automatic, daily: daily)
        .whenComplete(() => _running = null);
  }

  /// Returns whether a backup was saved (false when there was nothing new).
  ///
  /// [automatic]: started by the app, not the reader — skipped when nothing
  /// changed, and quiet when offline. [daily]: today's one-per-day file rather
  /// than a manual one.
  Future<bool> _backUp({required bool automatic, required bool daily}) async {
    final io = _io!;
    final destination = _destination!;
    final prefs = await SharedPreferences.getInstance();
    status.value = status.value.copyWith(running: true);
    try {
      final contents = await io.backupCsvs();
      if (automatic &&
          (contents.books == 0 || AnalyticsService.instance.demoLibrary)) {
        await prefs.setString(_lastCheckKey, _today());
        return false;
      }
      final fingerprint = await _fingerprint(contents.csvs);
      if (automatic && prefs.getString(_fingerprintKey) == fingerprint) {
        await prefs.setString(_lastCheckKey, _today());
        return false;
      }

      await destination.prepare(interactive: !automatic);
      final packed = await io.packBackupZip(contents.csvs,
          fileName: 'readstats_auto_backup.zip');
      final file = File(packed.path);
      try {
        final now = DateTime.now();
        final day = _today();
        final existing = daily
            ? (await destination.list())
                .where((f) => !f.manual && f.day == day)
                .firstOrNull
            : null;
        await destination.save(
          file,
          name: daily
              ? 'ReadStats Backup $day.zip'
              : 'ReadStats Backup $day ${DateFormat('HH-mm').format(now)}.zip',
          replace: existing,
          meta: BackupMeta(
            day: day,
            manual: !daily,
            books: contents.books,
            sessions: contents.sessions,
            covers: packed.covers,
          ),
        );
      } finally {
        if (await file.exists()) await file.delete();
      }
      await _prune(destination);

      final now = DateTime.now();
      await prefs.setString(_lastBackupKey, now.toIso8601String());
      // A manual backup leaves today's daily one still to come, so changes
      // made after it are backed up today too.
      if (daily) await prefs.setString(_lastCheckKey, _today());
      await prefs.setString(_fingerprintKey, fingerprint);
      status.value = status.value.copyWith(
        lastBackup: () => now,
        error: () => null,
        needsReconnect: false,
      );
      AnalyticsService.instance
          .autoBackupSaved(destination.kind.name, automatic: automatic);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('Backup failed: $e');
      final failure = destination.describe(e);
      // An automatic backup that couldn't get online just waits for the next
      // try; anything else is worth showing on the backup page.
      if (!automatic || e is! SocketException) {
        status.value = status.value.copyWith(
          error: () => failure.message,
          needsReconnect: failure.needsReconnect,
        );
      }
      throw failure;
    } finally {
      status.value = status.value.copyWith(running: false);
    }
  }

  /// Removes every daily backup past the newest [keepDaily], and every manual
  /// one past the newest [keepManual].
  Future<void> _prune(BackupDestination destination) async {
    final backups = await destination.list();
    final stale = [
      ...backups.where((b) => !b.manual).skip(keepDaily),
      ...backups.where((b) => b.manual).skip(keepManual),
    ];
    for (final old in stale) {
      await destination.remove(old);
    }
  }

  /// Changes whenever anything a backup holds does: every table's text, and
  /// each cover's name, size and age.
  Future<String> _fingerprint(Map<String, String> csvs) async {
    final parts = <String>[
      for (final name in csvs.keys.toList()..sort()) '$name\n${csvs[name]}',
    ];
    final dir = await CoverService.coversDirectory();
    if (await dir.exists()) {
      final covers = await dir.list().where((e) => e is File).toList();
      covers.sort((a, b) => a.path.compareTo(b.path));
      for (final cover in covers) {
        final stat = await cover.stat();
        parts.add('${p.basename(cover.path)}:${stat.size}:'
            '${stat.modified.millisecondsSinceEpoch}');
      }
    }
    return sha1.convert(utf8.encode(parts.join('\n'))).toString();
  }

  // ─── Restoring ────────────────────────────────────────────────────────────

  /// The backups at the destination, newest first.
  Future<List<BackupFile>> listBackups() async {
    await _loaded;
    final destination = _destination;
    if (destination == null) return const [];
    try {
      await destination.prepare(interactive: false);
      return await destination.list();
    } catch (e) {
      final failure = destination.describe(e);
      // Lost access is the destination's problem, not the list's: show it
      // once, where the fix is.
      if (failure.needsReconnect) {
        status.value = status.value
            .copyWith(error: () => failure.message, needsReconnect: true);
      }
      throw failure;
    }
  }

  /// Fetches [backup] and restores it like Settings → Restore Backup does.
  Future<ImportExportResult> restore(BackupFile backup,
      {ImportProgressCallback? onProgress}) async {
    final io = _io!;
    final destination = _destination!;
    final file = File(p.join(
        (await getTemporaryDirectory()).path, 'readstats_auto_restore.zip'));
    try {
      await destination.prepare(interactive: true);
      onProgress?.call(const ImportProgress('Fetching backup…'));
      await destination.fetch(backup, file, progress: (done, total) {
        if (total == null || total <= 0) return;
        onProgress?.call(ImportProgress(
          'Fetching backup · ${_megabytes(done)} of ${_megabytes(total)}',
          done / total,
        ));
      });
    } catch (e) {
      if (kDebugMode) debugPrint('Backup fetch failed: $e');
      if (await file.exists()) await file.delete();
      return ImportExportResult(
          success: false,
          message: 'Restore failed: ${destination.describe(e).message}');
    }
    try {
      return await io.restoreBackupFile(file.path,
          onProgress: onProgress, source: destination.restoreSource);
    } finally {
      if (await file.exists()) await file.delete();
    }
  }

  static String _today() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  static String _megabytes(int bytes) =>
      '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
