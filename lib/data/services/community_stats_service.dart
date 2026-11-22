import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:read_stats/data/models/community_stats.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app-wide totals on the Settings support card.
///
/// Apps can't read Firestore (see `firestore.rules`), so a daily GitHub Action
/// (`.github/workflows/community_stats.yml`) sums the per-install counts
/// `LibrarySnapshotService` keeps there and publishes a small JSON file on
/// the repo's `stats` branch. This
/// downloads that file: a plain request like the Open Library or Google Fonts
/// ones, sending nothing about the reader, so it doesn't depend on the
/// "Share usage statistics" switch.
///
/// The last good copy is cached, so the card shows numbers offline and
/// straight away; with none yet, [stats] stays null and the card hides its
/// stats row.
class CommunityStatsService {
  CommunityStatsService._();
  static final CommunityStatsService instance = CommunityStatsService._();

  static const _url =
      'https://raw.githubusercontent.com/tyshoe/ReadStats/stats/community_stats.json';
  static const _cacheKey = 'communityStats';
  static const _etagKey = 'communityStatsEtag';

  /// GitHub serves the file from a cache that refreshes every 5 minutes, so
  /// checking more often than that can't find anything new.
  static const _minInterval = Duration(minutes: 5);

  final ValueNotifier<CommunityStats?> stats = ValueNotifier(null);

  bool _refreshing = false;
  DateTime? _checkedAt;

  /// Shows the cached totals, then asks GitHub whether the file has changed.
  ///
  /// The check sends the cached copy's ETag, so an unchanged file costs a
  /// tiny "304 Not Modified" reply; a new one replaces the cache straight
  /// away, so the card matches the published file within minutes.
  Future<void> refresh() async {
    if (_refreshing) return;
    final checkedAt = _checkedAt;
    if (checkedAt != null &&
        DateTime.now().difference(checkedAt) < _minInterval) {
      return;
    }
    _refreshing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      if (cached != null && stats.value == null) {
        stats.value = _parse(cached);
      }

      // Only revalidate a cached copy that parses: one that doesn't (say,
      // from before a format change) is downloaded again in full.
      final etag = stats.value == null ? null : prefs.getString(_etagKey);
      final response = await http
          .get(
            Uri.parse(_url),
            headers: {'If-None-Match': ?etag},
          )
          .timeout(const Duration(seconds: 10));
      _checkedAt = DateTime.now();
      if (response.statusCode != 200) return; // 304: still current.
      final fresh = _parse(response.body);
      if (fresh == null) return;
      stats.value = fresh;
      await prefs.setString(_cacheKey, response.body);
      final newEtag = response.headers['etag'];
      if (newEtag != null) {
        await prefs.setString(_etagKey, newEtag);
      } else {
        await prefs.remove(_etagKey);
      }
    } catch (e) {
      // Offline or blocked: keep whatever is showing.
      if (kDebugMode) debugPrint('Community stats unavailable: $e');
    } finally {
      _refreshing = false;
    }
  }

  CommunityStats? _parse(String body) {
    try {
      return CommunityStats.fromJson(jsonDecode(body));
    } catch (_) {
      return null;
    }
  }
}
