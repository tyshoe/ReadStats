import 'package:in_app_review/in_app_review.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Handles both the automatic "please rate us" nudge and the explicit
/// "Rate ReadStats" tap from Settings.
///
/// The automatic prompt uses Apple's native review sheet
/// ([InAppReview.requestReview]), which is best-effort: iOS silently
/// rate-limits it (~3 shows/year) and may not display it at all, and we can't
/// tell whether it appeared. So we ask only at a moment of accomplishment
/// (finishing a book), and gate it to once per app version. The Settings tile
/// uses [openStoreListing], which reliably opens the App Store review screen
/// every time.
class RatingService {
  RatingService._();
  static final RatingService instance = RatingService._();

  final InAppReview _inAppReview = InAppReview.instance;

  /// Numeric App Store ID (from apps.apple.com/app/id6748966946).
  static const String appStoreId = '6748966946';

  /// Only auto-prompt once the user has finished at least this many books.
  static const int _minFinishedBooks = 3;

  /// Don't prompt within the first couple of days after install, even if the
  /// finished-book threshold is already met (e.g. a bulk import).
  static const Duration _minInstallAge = Duration(days: 2);

  static const String _kLastPromptedVersion = 'ratingLastPromptedVersion';
  static const String _kFirstLaunchMillis = 'ratingFirstLaunchMillis';

  /// Call once on app start to seed the install timestamp used by the age gate.
  Future<void> registerAppStart() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_kFirstLaunchMillis)) {
      await prefs.setInt(
          _kFirstLaunchMillis, DateTime.now().millisecondsSinceEpoch);
    }
  }

  /// Fire-and-forget from a clean "finished a book" success. Requests the
  /// native review sheet only if every gate passes: enough finished books, the
  /// install is old enough, and we haven't already asked on this version.
  Future<void> maybePromptAfterFinish({required int finishedBookCount}) async {
    if (finishedBookCount < _minFinishedBooks) return;

    final prefs = await SharedPreferences.getInstance();

    final firstLaunch = prefs.getInt(_kFirstLaunchMillis);
    if (firstLaunch != null) {
      final age = DateTime.now().millisecondsSinceEpoch - firstLaunch;
      if (age < _minInstallAge.inMilliseconds) return;
    }

    final version = (await PackageInfo.fromPlatform()).version;
    if (prefs.getString(_kLastPromptedVersion) == version) return;

    if (await _inAppReview.isAvailable()) {
      // Mark before showing: the sheet is best-effort and gives no callback, so
      // recording the attempt is the most we can do to avoid re-nagging.
      await prefs.setString(_kLastPromptedVersion, version);
      await _inAppReview.requestReview();
    }
  }

  /// Explicit user action from Settings — always opens the App Store listing.
  Future<void> openStoreListing() async {
    await _inAppReview.openStoreListing(appStoreId: appStoreId);
  }
}
