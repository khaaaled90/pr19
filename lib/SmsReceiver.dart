import 'dart:developer' as developer;
import 'package:another_telephony/telephony.dart';
import 'SmsWorker.dart';

const String _smsTag = 'BG_MONITOR';


/// الدالة الخلفية المنفصلة المعالجة لرسائل SMS (يجب أن تكون Top-Level Function)
@pragma('vm:entry-point')
void backGroundSmsHandler(SmsMessage message) async {
  developer.log('========================================', name: _smsTag);
  developer.log('📩 [SMS BG STEP 1] تم التقاط رسالة SMS في الخلفية!', name: _smsTag);

  String? sender = message.address;
  String? body = message.body;

  developer.log('👤 المرسل (Address): $sender', name: _smsTag);
  developer.log('💬 محتوى الرسالة (Body): "$body"', name: _smsTag);

  if (sender != null && body != null && body.isNotEmpty) {
    developer.log('✅ [SMS BG STEP 2] البيانات صحيحة، جاري التمرير إلى SmsWorker...', name: _smsTag);
    try {
      await SmsWorker.processIncomingMessage(
        sender: sender,
        messageText: body,
        source: 'SMS',
        senderName: sender,
      );
      developer.log('🎉 [SMS BG STEP 3] اكتمال المعالجة داخل SmsWorker بنجاح!', name: _smsTag);
    } catch (e, stackTrace) {
      developer.log(
        '❌ [SMS BG ERROR] خطأ أثناء المعالجة داخل SmsWorker: $e',
        name: _smsTag,
        error: e,
        stackTrace: stackTrace,
      );
    }
  } else {
    developer.log('⚠️ [SMS BG STEP 2] تم التخطي: المرسل أو النص فارغ.', name: _smsTag);
  }

  developer.log('========================================', name: _smsTag);
}

class SmsReceiver {
  static final Telephony telephony = Telephony.instance;

  /// تهيئة وتفعيل الاستماع للرسائل النصية القادمة
  static Future<void> initializeSmsListener() async {
    developer.log('🎬 [SMS INIT] جاري طلب صلاحيات الهاتف والـ SMS...', name: _smsTag);

    bool? permissionsGranted = await telephony.requestPhoneAndSmsPermissions;
    developer.log('🔑 [SMS INIT] نتيجة طلب الصلاحيات: $permissionsGranted', name: _smsTag);

    if (permissionsGranted == true) {
      developer.log('📡 [SMS INIT] جاري بدء الاستماع للرسائل (listenIncomingSms)...', name: _smsTag);

      telephony.listenIncomingSms(
        onNewMessage: (SmsMessage message) {
          developer.log('========================================', name: _smsTag);
          developer.log('📱 [SMS FG STEP 1] تم استلام رسالة SMS (التطبيق مفتوح)!', name: _smsTag);

          String? sender = message.address;
          String? body = message.body;

          developer.log('👤 المرسل: $sender', name: _smsTag);
          developer.log('💬 المحتوى: "$body"', name: _smsTag);

          if (sender != null && body != null && body.isNotEmpty) {
            developer.log('✅ [SMS FG STEP 2] جاري التمرير إلى SmsWorker...', name: _smsTag);
            SmsWorker.processIncomingMessage(
              sender: sender,
              messageText: body,
              source: 'SMS',
              senderName: sender,
            );
          } else {
            developer.log('⚠️ [SMS FG STEP 2] تم التخطي: المرسل أو النص فارغ.', name: _smsTag);
          }
          developer.log('========================================', name: _smsTag);
        },
        onBackgroundMessage: backGroundSmsHandler,
        listenInBackground: true,
      );

      developer.log('🚀 [SMS INIT] تم تفعيل مستمع الـ SMS بنجاح.', name: _smsTag);
    } else {
      developer.log('❌ [SMS INIT] فشل التفعيل: تم رفض صلاحيات الـ SMS!', name: _smsTag);
    }
  }
}
/*import 'package:telephony/telephony.dart';
//import 'package:telephony_plus/telephony_plus.dart';
import 'SmsWorker.dart';

/// الدالة الخلفية المنفصلة المعالجة لرسائل SMS (يجب أن تكون Top-Level Function)
@pragma('vm:entry-point')
void backGroundSmsHandler(SmsMessage message) async {
  String? sender = message.address;
  String? body = message.body;

  if (sender != null && body != null && body.isNotEmpty) {
    await SmsWorker.processIncomingMessage(
      sender: sender,
      messageText: body,
      source: 'SMS',
      senderName: sender,
    );
  }
}

class SmsReceiver {
  static final Telephony telephony = Telephony.instance;

  /// تهيئة وتفعيل الاستماع للرسائل النصية القادمة
  static Future<void> initializeSmsListener() async {
    bool? permissionsGranted = await telephony.requestPhoneAndSmsPermissions;

    if (permissionsGranted == true) {
      telephony.listenIncomingSms(
        onNewMessage: (SmsMessage message) {
          String? sender = message.address;
          String? body = message.body;

          if (sender != null && body != null) {
            SmsWorker.processIncomingMessage(
              sender: sender,
              messageText: body,
              source: 'SMS',
              senderName: sender,
            );
          }
        },
        onBackgroundMessage: backGroundSmsHandler,
        listenInBackground: true,
      );
    }
  }
}*/
