import 'dart:developer' as developer;
import 'package:flutter/services.dart';

const String _smsTag = 'BG_MONITOR';

class SmsReceiver {
  // القناة الخاصة باستقبال الأحداث (Events) من BroadcastReceiver في Kotlin
  static const EventChannel _smsEventChannel =
      EventChannel('com.app.cardpay/sms_receiver');

  // قناة الميثود تشانل لتنفيذ العمليات المباشرة إذا لزم الأمر
  static const MethodChannel _smsMethodChannel =
      MethodChannel('com.app.cardpay/sms');

  /// تهيئة وتفعيل الاستماع للرسائل النصية القادمة من Kotlin Native Receiver
  static void initializeSmsListener() {
    developer.log('🎬 [SMS INIT] جاري الاستماع للرسائل عبر Native EventChannel...',
        name: _smsTag);

    _smsEventChannel.receiveBroadcastStream().listen(
      (dynamic event) async {
        developer.log('========================================', name: _smsTag);
        developer.log('📩 [SMS STEP 1] تم استلام رسالة SMS قادمة من Native Receiver!',
            name: _smsTag);

        try {
          final Map<dynamic, dynamic> map = event as Map<dynamic, dynamic>;
          String? sender = map['sender'] as String?;
          String? body = map['message'] as String?;

          developer.log('👤 المرسل: $sender', name: _smsTag);
          developer.log('💬 المحتوى: "$body"', name: _smsTag);

          if (sender != null && body != null && body.isNotEmpty) {
            developer.log(
                '✅ [SMS STEP 2] البيانات صحيحة، جاري التمرير للمعالجة عبر MethodChannel...',
                name: _smsTag);

            // توجيه الرسالة للـ Native Handler أو معالج النظام الجديد
            await _processIncomingSms(
              sender: sender,
              messageText: body,
              source: 'SMS',
              senderName: sender,
            );

            developer.log('🎉 [SMS STEP 3] اكتمال المعالجة بنجاح!',
                name: _smsTag);
          } else {
            developer.log('⚠️ [SMS STEP 2] تم التخطي: البيانات فارغة.',
                name: _smsTag);
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
        developer.log('❌ [SMS ERROR] خطأ في EventChannel الخاص بالـ SMS: $error',
            name: _smsTag);
      },
    );

    developer.log('🚀 [SMS INIT] تم تفعيل مستمع الـ SMS بنجاح.', name: _smsTag);
  }

  /// دالة بديلة لمعالجة الرسالة المستلمة عبر الـ MethodChannel الخاص بكوتلن
  static Future<void> _processIncomingSms({
    required String sender,
    required String messageText,
    required String source,
    required String senderName,
  }) async {
    try {
      await _smsMethodChannel.invokeMethod('processIncomingMessage', {
        'sender': sender,
        'messageText': messageText,
        'source': source,
        'senderName': senderName,
      });
    } on PlatformException catch (e) {
      developer.log('❌ خطأ منصة أثناء معالجة الرسالة: ${e.message}',
          name: _smsTag);
    } catch (e) {
      developer.log('❌ خطأ غير متوقع أثناء معالجة الرسالة: $e', name: _smsTag);
    }
  }
}
