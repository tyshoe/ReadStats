import 'package:package_info_plus/package_info_plus.dart';

class AppConfig {
  static late String version;

  /// Donation page. Must stay a pure donation with nothing given in return —
  /// tying perks or features to it would reclassify the link as purchasing
  /// digital content, which App Store guideline 3.1.1 bars outside the US
  /// storefront. Opened in an external browser, never an in-app webview:
  /// 3.2.2(iv) only permits collecting funds outside the app.
  static const String supportUrl = 'https://buymeacoffee.com/tyshoe';

  static Future<void> init() async {
    final packageInfo = await PackageInfo.fromPlatform();
    version = packageInfo.version;
  }
}