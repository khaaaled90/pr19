import 'dart:async';
import 'package:flutter_notification_listener/flutter_notification_listener.dart';
import 'SmsWorker.dart';

/// دالة المعالجة الخلفية للإشعارات
@pragma('vm:entry-point')
void _notificationCallback(NotificationEvent evt) async {
  if (evt.message == null || evt.message!.isEmpty) return;

  String senderApp = evt.packageName ?? 'Notification';
  String title = evt.title ?? '';
  String fullContent = "$title ${evt.message!}".trim();

  // تمرير محتوى الإشعار للمُعالج الموحد
  await SmsWorker.processIncomingMessage(
    sender: senderApp,
    messageText: fullContent,
    source: 'Noti',
    senderName: title.isNotEmpty ? title : senderApp,
  );
}

class NotificationListenerManager {
  /// بدء وتفعيل خدمة الاستماع للإشعارات
  static Future<void> startListening() async {
    // 1. التحقق من صلاحية الوصول للإشعارات
    bool? hasPermission = await NotificationsListener.hasPermission;
    if (hasPermission != true) {
      await NotificationsListener.openPermissionSettings();
    }

    // 2. تهيئة الخدمة وربطها بالدالة الخلفية
    await NotificationsListener.initialize(
      callbackHandle: _notificationCallback,
    );

    // 3. تشغيل الخدمة
    await NotificationsListener.startService();
  }
}
/*import 'dart:async';
import 'package:flutter_notification_listener/flutter_notification_listener.dart';
import 'SmsWorker.dart';

/// المعالج الخلفي المستقل للإشعارات
@pragma('vm:entry-point')
void notificationRawHandler() {
  NotificationListenerService.notificationsStream
      .listen((NotificationEvent event) async {
    // استخراج محتوى الإشعار (مراعاة احتمال اختلاف تسمية الحقوق بين message / text)
    String? content = event.message ?? event.content ?? event.text;
    if (content == null || content.isEmpty) return;

    // استخراج اسم التطبيق أو العنوان ونص الإشعار
    String senderApp = event.packageName ?? 'Notification';
    String title = event.title ?? '';
    String fullContent = "$title $content".trim();

    // إرسال البيانات للـ Worker الموحد
    await SmsWorker.processIncomingMessage(
      sender: senderApp,
      messageText: fullContent,
      source: 'Noti',
      senderName: title.isNotEmpty ? title : senderApp,
    );
  });
}

class NotificationListenerManager {
  /// التحقق من منح الصلاحيات وتفعيل الاستماع للإشعارات
  static Future<void> startListening() async {
    // 1. طلب الصلاحية للوصول للإشعارات
    bool isPermissionGranted =
        await NotificationListenerService.isPermissionGranted();
    if (!isPermissionGranted) {
      await NotificationListenerService.requestPermission();
    }

    // 2. البدء ببدء خدمة الاستماع للإشعارات في الخلفية
    NotificationListenerService.notificationsStream
        .listen((NotificationEvent event) {
      String? content = event.message ?? event.content ?? event.text;

      if (content != null && content.isNotEmpty) {
        String senderApp = event.packageName ?? 'Notification';
        String title = event.title ?? '';
        String fullContent = "$title $content".trim();

        SmsWorker.processIncomingMessage(
          sender: senderApp,
          messageText: fullContent,
          source: 'Noti',
          senderName: title.isNotEmpty ? title : senderApp,
        );
      }
    });
  }
}
*/
