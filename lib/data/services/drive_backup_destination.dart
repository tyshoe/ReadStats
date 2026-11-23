import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart'
    show
        AuthorizationRequestDetails,
        ClientAuthorizationTokensForScopesParameters,
        GoogleSignInPlatform;
import 'package:http/http.dart' as http;
import 'package:read_stats/data/services/auto_backup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Automatic backups in the reader's own Google Drive, in a "ReadStats
/// Backups" folder the app makes.
///
/// Uses the `drive.file` scope, which reaches only files this app created.
/// The folder and files are found again by ID and by hidden tags
/// (`appProperties`), so renaming or moving them in Drive changes nothing,
/// and a reinstall finds the same folder. Old backups go to Drive's trash.
class DriveBackupDestination implements BackupDestination {
  DriveBackupDestination._(this._email, this._prefs);

  static const folderName = 'ReadStats Backups';
  static const _scope = 'https://www.googleapis.com/auth/drive.file';
  static const _emailKey = 'drive_backup_email';
  static const _folderKey = 'drive_backup_folder_id';

  final String _email;
  final SharedPreferences _prefs;
  String? _token;
  String? _folderId;

  static final _client = http.Client();
  static Future<void>? _signInReady;

  /// The account saved from an earlier launch, if any.
  static DriveBackupDestination? saved(SharedPreferences prefs) {
    final email = prefs.getString(_emailKey);
    return email == null ? null : DriveBackupDestination._(email, prefs);
  }

  /// Asks the reader to pick a Google account and allow ReadStats its own
  /// files in that account's Drive. Throws [GoogleSignInException] (code
  /// `canceled`) if they back out.
  static Future<DriveBackupDestination> connect(SharedPreferences prefs) async {
    final token = await _authorize(prompt: true, email: null);
    if (token == null) {
      throw const BackupException('Google Drive access wasn’t granted.');
    }
    final destination = DriveBackupDestination._('', prefs).._token = token;
    final about = await destination._getJson(
        _api('about', {'fields': 'user(emailAddress)'}));
    final email = (about['user'] as Map?)?['emailAddress'] as String?;
    if (email == null) {
      throw const BackupException('Couldn’t read your Google account.');
    }
    if (prefs.getString(_emailKey) != email) {
      // Another account's folder isn't reachable from this one.
      await prefs.remove(_folderKey);
    }
    await prefs.setString(_emailKey, email);
    return DriveBackupDestination._(email, prefs).._token = token;
  }

  @override
  BackupDestinationKind get kind => BackupDestinationKind.drive;

  @override
  String get label => _email;

  @override
  String get restoreSource => 'drive';

  @override
  Future<void> prepare({required bool interactive}) async {
    _token = await _authorize(prompt: interactive, email: _email);
    if (_token == null) {
      throw const BackupException('Google Drive needs your permission again.',
          needsReconnect: true);
    }
    _folderId = await _folder();
  }

  @override
  Future<List<BackupFile>> list() => _list(_tag('backup'), pageSize: 200);

  @override
  Future<void> save(File zip,
      {required String name,
      required BackupFile? replace,
      required BackupMeta meta}) async {
    final length = await zip.length();
    final id = replace?.id;
    final metadata = <String, Object>{
      'name': name,
      'description': '${meta.books} books · ${meta.sessions} sessions · '
          '${meta.covers} covers. Restore it in ReadStats → Settings → '
          'Automatic Backup.',
      'appProperties': {
        'readstats': 'backup',
        'day': meta.day,
        'kind': meta.manual ? 'manual' : 'daily',
        'books': '${meta.books}',
        'sessions': '${meta.sessions}',
      },
      if (id == null) ...{
        'parents': [_folderId!],
        'mimeType': 'application/zip',
      },
    };
    // Resumable, so a library's worth of covers goes up as one stream rather
    // than in memory.
    final start = await _send(
      id == null ? 'POST' : 'PATCH',
      Uri.https('www.googleapis.com',
          '/upload/drive/v3/files${id == null ? '' : '/$id'}',
          {'uploadType': 'resumable'}),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'X-Upload-Content-Type': 'application/zip',
        'X-Upload-Content-Length': '$length',
      },
      body: jsonEncode(metadata),
    );
    if (start.statusCode != 200) throw _HttpFailure(start);
    final location = start.headers['location'];
    if (location == null) throw _HttpFailure(start);

    final put = http.StreamedRequest('PUT', Uri.parse(location))
      ..contentLength = length
      ..headers['Content-Type'] = 'application/zip';
    unawaited(put.sink
        .addStream(zip.openRead())
        .whenComplete(put.sink.close)
        .catchError((_) {}));
    final done = await http.Response.fromStream(await _client.send(put));
    if (done.statusCode != 200 && done.statusCode != 201) {
      throw _HttpFailure(done);
    }
  }

  @override
  Future<void> remove(BackupFile file) async {
    await _getJson(_api('files/${file.id}', {'fields': 'id'}),
        method: 'PATCH', body: {'trashed': true});
  }

  @override
  Future<void> fetch(BackupFile file, File into,
      {void Function(int done, int? total)? progress}) async {
    final request = http.Request('GET', _api('files/${file.id}', {'alt': 'media'}))
      ..headers['Authorization'] = 'Bearer $_token';
    final response = await _client.send(request);
    if (response.statusCode != 200) {
      throw _HttpFailure(await http.Response.fromStream(response));
    }
    final total = response.contentLength ?? file.sizeBytes;
    final sink = into.openWrite();
    var received = 0;
    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        progress?.call(received, total);
      }
    } finally {
      await sink.close();
    }
  }

  /// Withdraws ReadStats' access to Drive.
  @override
  Future<void> forget() async {
    await (_signInReady ??= GoogleSignIn.instance.initialize());
    try {
      final token = await _authorize(prompt: false, email: _email);
      if (token != null) {
        await GoogleSignIn.instance.authorizationClient
            .clearAuthorizationToken(accessToken: token);
        await _client.post(
            Uri.https('oauth2.googleapis.com', '/revoke', {'token': token}));
      }
    } catch (e) {
      // Offline, or already revoked: forgetting the account locally is what
      // matters.
      if (kDebugMode) debugPrint('Drive disconnect: $e');
    }
    try {
      // iOS keeps the signed-in account after its token is revoked, and the
      // next connect would silently reuse it instead of offering the account
      // picker.
      await GoogleSignIn.instance.disconnect();
    } catch (e) {
      if (kDebugMode) debugPrint('Google sign-out: $e');
    }
    await _prefs.remove(_emailKey);
    await _prefs.remove(_folderKey);
  }

  @override
  BackupException describe(Object e) {
    if (e is BackupException) return e;
    if (e is SocketException || e is http.ClientException) {
      return const BackupException(
          'Couldn’t reach Google Drive. Check your connection.');
    }
    if (e is _HttpFailure) {
      if (e.status == 401) {
        return const BackupException(
            'Google Drive needs your permission again.',
            needsReconnect: true);
      }
      if (e.body.contains('storageQuotaExceeded')) {
        return const BackupException('Your Google Drive is full.');
      }
      return BackupException(
          'Google Drive didn’t accept the backup (error ${e.status}).');
    }
    if (e is GoogleSignInException) {
      return BackupException(
          'Couldn’t sign in to Google: ${e.description ?? e.code.name}');
    }
    return BackupException('Backup failed: $e');
  }

  // ─── Drive plumbing ───────────────────────────────────────────────────────

  static Future<String?> _authorize(
      {required bool prompt, required String? email}) async {
    await (_signInReady ??= GoogleSignIn.instance.initialize());
    // Straight to the platform, to name the account: the app-level client
    // can only do that for an account signed in this launch, and signing in
    // silently on Android may still show an account sheet.
    final tokens =
        await GoogleSignInPlatform.instance.clientAuthorizationTokensForScopes(
      ClientAuthorizationTokensForScopesParameters(
        request: AuthorizationRequestDetails(
          scopes: const [_scope],
          userId: null,
          email: email,
          promptIfUnauthorized: prompt,
        ),
      ),
    );
    return tokens?.accessToken;
  }

  /// The backups folder's ID: the one saved, else the one carrying this
  /// app's tag (after a reinstall), else a new one.
  Future<String> _folder() async {
    final saved = _prefs.getString(_folderKey);
    if (saved != null) {
      final response =
          await _send('GET', _api('files/$saved', {'fields': 'id,trashed'}));
      if (response.statusCode == 200 &&
          (jsonDecode(response.body) as Map)['trashed'] != true) {
        return saved;
      }
      if (response.statusCode != 404 && response.statusCode != 200) {
        throw _HttpFailure(response);
      }
    }
    final found = await _list(
        "${_tag('folder')} and mimeType='application/vnd.google-apps.folder'",
        pageSize: 1);
    final String id;
    if (found.isNotEmpty) {
      id = found.first.id;
    } else {
      final created = await _getJson(
        _api('files', {'fields': 'id'}),
        method: 'POST',
        body: {
          'name': folderName,
          'mimeType': 'application/vnd.google-apps.folder',
          'description': 'Backups of your ReadStats library. Rename or move '
              'this folder freely — ReadStats will still find it.',
          'appProperties': {'readstats': 'folder'},
        },
      );
      id = created['id'] as String;
    }
    await _prefs.setString(_folderKey, id);
    return id;
  }

  static Uri _api(String path, [Map<String, String>? query]) =>
      Uri.https('www.googleapis.com', '/drive/v3/$path', query);

  static String _tag(String kind) =>
      "appProperties has { key='readstats' and value='$kind' } "
      'and trashed=false';

  Future<http.Response> _send(String method, Uri uri,
      {Map<String, String>? headers, String? body}) async {
    final token = _token!;
    final request = http.Request(method, uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..headers.addAll(headers ?? const {});
    if (body != null) request.body = body;
    final response =
        await http.Response.fromStream(await _client.send(request));
    if (response.statusCode == 401) {
      // Revoked from outside the app, or expired: forget the token so the
      // next try asks again.
      await GoogleSignIn.instance.authorizationClient
          .clearAuthorizationToken(accessToken: token);
    }
    return response;
  }

  Future<Map<String, dynamic>> _getJson(Uri uri,
      {String method = 'GET', Map<String, Object>? body}) async {
    final response = await _send(
      method,
      uri,
      headers: body == null
          ? null
          : {'Content-Type': 'application/json; charset=UTF-8'},
      body: body == null ? null : jsonEncode(body),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _HttpFailure(response);
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<BackupFile>> _list(String query, {required int pageSize}) async {
    final json = await _getJson(
      _api('files', {
        'q': query,
        'orderBy': 'modifiedTime desc',
        'pageSize': '$pageSize',
        'spaces': 'drive',
        'fields': 'files(id,name,modifiedTime,size,appProperties)',
      }),
    );
    return [
      for (final f in (json['files'] as List).cast<Map<String, dynamic>>())
        _file(f),
    ];
  }

  static BackupFile _file(Map<String, dynamic> f) {
    final props = (f['appProperties'] as Map?) ?? const {};
    return BackupFile(
      id: f['id'] as String,
      name: f['name'] as String,
      modified: DateTime.parse(f['modifiedTime'] as String).toLocal(),
      day: props['day'] as String?,
      sizeBytes: int.tryParse('${f['size']}'),
      books: int.tryParse('${props['books']}'),
      sessions: int.tryParse('${props['sessions']}'),
      manual: props['kind'] == 'manual',
    );
  }
}

class _HttpFailure implements Exception {
  final int status;
  final String body;
  _HttpFailure(http.Response response)
      : status = response.statusCode,
        body = response.body;

  @override
  String toString() => 'HTTP $status: $body';
}
