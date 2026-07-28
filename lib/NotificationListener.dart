import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter_notification_listener/flutter_notification_listener.dart';
import 'SmsWorker.dart';

const String _bgTag = 'BG_MONITOR';

/// دالة المعالجة الخلفية للإشعارات
@pragma('vm:entry-point')
void _notificationCallback(NotificationEvent evt) async {
  developer.log('========================================', name: _bgTag);
  developer.log('🚀 [NOTI STEP 1] تم استلام حدث إشعار جديد في الخلفية!', name: _bgTag);

  String senderApp = evt.packageName ?? 'Notification';
  String title = evt.title ?? '';
  String? rawMessage = evt.message;

  developer.log('📌 التطبيق (Package): $senderApp', name: _bgTag);
  developer.log('🏷️ العنوان (Title): $title', name: _bgTag);
  developer.log('📝 النص الخام (Message): $rawMessage', name: _bgTag);

  if (rawMessage == null || rawMessage.isEmpty) {
    developer.log('⚠️ [NOTI STEP 2] تم التخطي: محتوى الإشعار فارغ أو null.', name: _bgTag);
    developer.log('========================================', name: _bgTag);
    return;
  }

  String fullContent = "$title $rawMessage".trim();
  String senderName = title.isNotEmpty ? title : senderApp;

  developer.log('✅ [NOTI STEP 2] تم تجهيز نص الإشعار بنجاح:', name: _bgTag);
  developer.log('   💬 النص الكامل: "$fullContent"', name: _bgTag);
  developer.log('   👤 اسم المرسل: "$senderName"', name: _bgTag);

  try {
    developer.log('🔄 [NOTI STEP 3] جاري تمرير البيانات إلى SmsWorker.processIncomingMessage...', name: _bgTag);

    await SmsWorker.processIncomingMessage(
      sender: senderApp,
      messageText: fullContent,
      source: 'Noti',
      senderName: senderName,
    );

    developer.log('🎉 [NOTI STEP 4] اكتملت معالجة SmsWorker بنجاح!', name: _bgTag);
  } catch (e, stackTrace) {
    developer.log(
      '❌ [NOTI ERROR] حدث خطأ أثناء المعالجة داخل SmsWorker: $e',
      name: _bgTag,
      error: e,
      stackTrace: stackTrace,
    );
  }

  developer.log('========================================', name: _bgTag);
}

class NotificationListenerManager {
  /// بدء وتفعيل خدمة الاستماع للإشعارات
  static Future<void> startListening() async {
    developer.log('🎬 [INIT] جاري التحقق من صلاحية وصول الإشعارات...', name: _bgTag);

    bool? hasPermission = await NotificationsListener.hasPermission;
    developer.log('🔑 [INIT] حالة الصلاحية الحالية: $hasPermission', name: _bgTag);

    if (hasPermission != true) {
      developer.log('⚠️ [INIT] الصلاحية غير ممنوحة! جاري فتح شاشة الإعدادات للمستخدم...', name: _bgTag);
      await NotificationsListener.openPermissionSettings();
    }

    developer.log('⚙️ [INIT] جاري تهيئة NotificationsListener...', name: _bgTag);
    await NotificationsListener.initialize(
      callbackHandle: _notificationCallback,
    );

    developer.log('📡 [INIT] جاري تشغيل خدمة الاستماع في الخلفية (startService)...', name: _bgTag);
    bool? isServiceStarted = await NotificationsListener.startService();
    developer.log('🚀 [INIT] نتيجة تشغيل الخدمة: $isServiceStarted', name: _bgTag);
  }
}
