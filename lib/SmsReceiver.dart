import 'package:telephony/telephony.dart';
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
}
