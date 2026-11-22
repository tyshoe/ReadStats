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
  static const _fetchedKey = 'communityStatsFetchedAt';

  /// The file changes once a day; checking more often only adds requests.
  static const _maxAge = Duration(hours: 6);

  final ValueNotifier<CommunityStats?> stats = ValueNotifier(null);

  bool _refreshing = false;

  /// Shows the cached totals, then downloads fresh ones if they're stale.
  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      if (cached != null && stats.value == null) {
        stats.value = _parse(cached);
      }

      final fetchedAt = prefs.getInt(_fetchedKey);
      if (fetchedAt != null &&
          DateTime.now().difference(
                  DateTime.fromMillisecondsSinceEpoch(fetchedAt)) <
              _maxAge) {
        return;
      }

      final response =
          await http.get(Uri.parse(_url)).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return;
      final fresh = _parse(response.body);
      if (fresh == null) return;
      stats.value = fresh;
      await prefs.setString(_cacheKey, response.body);
      await prefs.setInt(_fetchedKey, DateTime.now().millisecondsSinceEpoch);
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
