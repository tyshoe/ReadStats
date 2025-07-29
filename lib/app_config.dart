import 'package:package_info_plus/package_info_plus.dart';

class AppConfig {
  static late String version;

  static Future<void> init() async {
    final packageInfo = await PackageInfo.fromPlatform();
    version = packageInfo.version;
  }
}