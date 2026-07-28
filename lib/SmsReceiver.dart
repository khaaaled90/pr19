import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import 'sms_worker.dart';

const String _smsTag = 'BG_MONITOR';

class SmsReceiver {
  static const EventChannel _smsEventChannel = EventChannel('com.example.pr19/sms_receiver');

  /// تهيئة وتفعيل الاستماع للرسائل النصية القادمة من Kotlin Native Receiver
  static void initializeSmsListener() {
    developer.log('🎬 [SMS INIT] جاري الاستماع للرسائل عبر Native EventChannel...', name: _smsTag);

    _smsEventChannel.receiveBroadcastStream().listen(
      (dynamic event) async {
        developer.log('========================================', name: _smsTag);
        developer.log('📩 [SMS STEP 1] تم استلام رسالة SMS قادمة من Native Receiver!', name: _smsTag);

        try {
          final Map<dynamic, dynamic> map = event as Map<dynamic, dynamic>;
          String? sender = map['sender'] as String?;
          String? body = map['message'] as String?;

          developer.log('👤 المرسل: $sender', name: _smsTag);
          developer.log('💬 المحتوى: "$body"', name: _smsTag);

          if (sender != null && body != null && body.isNotEmpty) {
            developer.log('✅ [SMS STEP 2] البيانات صحيحة، جاري التمرير لـ SmsWorker...', name: _smsTag);
            await SmsWorker.processIncomingMessage(
              sender: sender,
              messageText: body,
              source: 'SMS',
              senderName: sender,
            );
            developer.log('🎉 [SMS STEP 3] اكتمال المعالجة داخل SmsWorker بنجاح!', name: _smsTag);
          } else {
            developer.log('⚠️ [SMS STEP 2] تم التخطي: البيانات فارغة.', name: _smsTag);
          }
        } catch (e, stackTrace) {
          developer.log(
            '❌ [SMS ERROR] خطأ أثناء معالجة رسالة الـ SMS: $e',
            name: _smsTag,
            error: e,
            stackTrace: stackTrace,
          );
        }
        developer.log('========================================', name: _smsTag);
      },
      onError: (dynamic error) {
        developer.log('❌ [SMS ERROR] خطأ في EventChannel الخاص بالـ SMS: $error', name: _smsTag);
      },
    );

    developer.log('🚀 [SMS INIT] تم تفعيل مستمع الـ SMS بنجاح.', name: _smsTag);
  }
}
