import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';

class DeviceUtils {
  /// جلب معرّف الجهاز الفريد والمشفر بـ SHA-256
  static Future<String> getDeviceId() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    String rawId = "";

    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        // دمج المعرفات الثابتة للجوال لضمان عدم تغير المعرف مع الفورمات
        rawId = "${androidInfo.id}-${androidInfo.hardware}-${androidInfo.model}";
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        rawId = iosInfo.identifierForVendor ?? "unknown_ios";
      } else if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        rawId = windowsInfo.deviceId;
      }
    } catch (e) {
      rawId = "fallback_unknown_device_id";
    }

    // تحويل النص المجمع إلى Hash معقد من 16 حرفاً بصيغة منظمة
    var bytes = utf8.encode(rawId);
    var digest = sha256.convert(bytes);
    String fullHash = digest.toString().toUpperCase();

    // اقتطاع أول 16 حرف وتقسيمها إلى 4 أجزاء يسهل قراءتها (مثال: A1B2-C3D4-E5F6-7890)
    String cleanId = fullHash.substring(0, 16);
    return "${cleanId.substring(0, 4)}-${cleanId.substring(4, 8)}-${cleanId.substring(8, 12)}-${cleanId.substring(12, 16)}";
  }
}