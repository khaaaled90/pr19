import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../force_update_screen.dart';

class UpdateCheckerService {
  static Future<void> checkAndForceUpdate(BuildContext context) async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;

      // إعداد فترات التحديث المباشر
      await remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: Duration.zero, // جلب فوري أثناء التطوير
      ));

      // جلب وجلب وتفعيل القيم من الفايربيس
      await remoteConfig.fetchAndActivate();

      // قراءة رقم البناء الحالي للملف التطبيق
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      int currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;

      // قراءة الإعدادات من Remote Config
      int minBuildNumber = remoteConfig.getInt('min_build_number');
      String updateUrl = remoteConfig.getString('update_url');
      String releaseNotes = remoteConfig.getString('release_notes');

      // المقارنة والتوجيه الإجباري
      if (currentBuildNumber < minBuildNumber && updateUrl.isNotEmpty) {
        if (!context.mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ForceUpdateScreen(
              updateUrl: updateUrl,
              releaseNotes: releaseNotes,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('خطأ أثناء جلب Remote Config: $e');
    }
  }
}