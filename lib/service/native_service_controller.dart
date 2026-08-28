import 'package:flutter/services.dart';

class NativeServiceController {
  // قناة الاتصال المباشر مع ملف MainActivity.kt
  static const MethodChannel _channel = MethodChannel('com.app.cardpay/native_control');

  /// 1. فتح صفحة إعدادات أندرويد لطلب إذن قراءة إشعارات المحافظ (Notification Listener)
  static Future<bool> requestNotificationListenerPermission() async {
    try {
      final bool isGranted = await _channel.invokeMethod('requestNotificationListenerPermission');
      return isGranted;
    } on PlatformException catch (e) {
      print("خطأ في طلب إذن الإشعارات: ${e.message}");
      return false;
    }
  }

  // دعم الاسم القديم لمنع أي كسر في أماكن أخرى
  static Future<bool> requestNotificationPermission() => requestNotificationListenerPermission();

  /// 2. التحقق مما إذا كان إذن قراءة الإشعارات مفعلاً بالفعل أم لا
  static Future<bool> isNotificationPermissionGranted() async {
    try {
      final bool isGranted = await _channel.invokeMethod('isNotificationListenerGranted');
      return isGranted;
    } on PlatformException catch (e) {
      print("خطأ في التحقق من إذن الإشعارات: ${e.message}");
      return false;
    }
  }

  /// 3. فتح نافذة استثناء التطبيق من قيود توفير البطارية (Doze Mode Bypass)
  static Future<void> requestIgnoreBatteryOptimizations() async {
    try {
      await _channel.invokeMethod('requestIgnoreBatteryOptimizations');
    } on PlatformException catch (e) {
      print("خطأ في طلب استثناء البطارية: ${e.message}");
    }
  }

  // دعم الاسم القديم لمنع أي كسر في أماكن أخرى
  static Future<void> requestBatteryExemption() => requestIgnoreBatteryOptimizations();
}
