import 'package:telephony/telephony.dart';
import 'DatabaseHelper.dart';
import 'NotificationHelper.dart'; // استيراد خدمة الإشعارات المحلية

class SmsWorker {
  static final Telephony telephony = Telephony.instance;

  /// النقطة الأساسية للبدء في معالجة الإشعارات أو الرسائل الواصلة
  static Future<void> processIncomingMessage({
    required String sender,
    required String messageText,
    String source = 'Noti',
    String? senderName,
  }) async {
    final db = DatabaseHelper.instance;

    // 1. التحقق من تفعيل الخدمة العامة
    String serviceEnabled = await db.getSetting('service_enabled', 'true');
    if (serviceEnabled.toLowerCase() != 'true') return;

    // 2. التحقق من صلاحية المرسل (إلا إذا كان خيار السماح للكل مفعلاً)
    String allowAll = await db.getSetting('allow_all_senders', 'false');
    if (allowAll.toLowerCase() != 'true') {
      bool isAllowed = await db.isSenderAllowed(sender);
      if (!isAllowed) return;
    }

    // 3. البحث عن كلمة مفتاحية مطابقة داخل نص الرسالة
    List<Map<String, dynamic>> keywords = await db.getAllKeywords();
    Map<String, dynamic>? matchedKeyword;

    for (var kw in keywords) {
      if (kw['is_active'] == 1 &&
          messageText
              .toLowerCase()
              .contains((kw['keyword'] as String).toLowerCase())) {
        matchedKeyword = kw;
        break;
      }
    }

    // في حال عدم وجود كلمة مفتاحية مطابقة
    if (matchedKeyword == null) {
      await db.addToArchive(
        sender: sender,
        senderName: senderName,
        receivedMessage: messageText,
        status: 'ignored_no_keyword',
        source: source,
      );
      return;
    }

    // =========================================================
    // 4. تحديد رقم هاتف العميل (استخراج أو بحث بالاسم / رقم المحفظة)
    // =========================================================
    String? targetPhone;

    // أ. محاولة استخراج رقم الهاتف مباشرة من الرسالة (رقم يبدأ بـ 7 ويتكون من 9 أرقام)
    RegExp phoneRegExp = RegExp(r'(7[0-9]{8})');
    Match? phoneMatch = phoneRegExp.firstMatch(messageText);

    if (phoneMatch != null) {
      targetPhone = phoneMatch.group(0);
    } else {
      // ب. إذا لم يوجد رقم في النص، ابحث عن الاسم أو رقم المحفظة في جدول العملاء
      targetPhone = await db.findCustomerPhoneByIdentifier(messageText);
    }

    int keywordId = matchedKeyword['id'];
    String keywordText = matchedKeyword['keyword'];
    int targetCount = matchedKeyword['target_count'] ?? 0;
    int? rewardKeywordId = matchedKeyword['reward_keyword_id'];
    int rewardQty = matchedKeyword['reward_qty'] ?? 1;

    // =========================================================
    // 5. في حال معرفة رقم الهاتف (سواء كان قديماً أو جديداً استُخرج من النص)
    // =========================================================
    if (targetPhone != null && targetPhone.isNotEmpty) {
      // حفظ أو تحديث العميل تلقائياً (إذا كان رقماً جديداً يُضاف للجدول فوراً)
      await db.saveOrUpdateCustomer(targetPhone, name: senderName);

      List<String> vouchersToSend = [];
      String processStatus = 'sent';

      // فحص نظام المكافآت والعدادات للعميل
      if (targetCount > 0 && rewardKeywordId != null) {
        int currentCount =
            await db.incrementCustomerCounter(targetPhone, keywordId);

        if (currentCount >= targetCount) {
          for (int i = 0; i < rewardQty; i++) {
            var rewardVoucher =
                await db.getAndUseVoucher(rewardKeywordId, targetPhone);
            if (rewardVoucher != null) {
              vouchersToSend.add(rewardVoucher['number_code']);
            }
          }
          await db.resetCustomerCounter(targetPhone, keywordId);
        }
      }

      // سحب القسيمة الأساسية العادية إذا لم توجد مكافأة
      if (vouchersToSend.isEmpty) {
        var voucher = await db.getAndUseVoucher(keywordId, targetPhone);
        if (voucher != null) {
          vouchersToSend.add(voucher['number_code']);
        } else {
          processStatus = 'out_of_stock';
        }
      }

      // صياغة النص النهائي والإرسال
      if (vouchersToSend.isNotEmpty) {
        String defaultReply = await db.getSetting(
          'default_reply',
          'شكراً لتواصلك. رقمك الخاص هو: ',
        );

        String finalMessage = "$defaultReply ${vouchersToSend.join(', ')}";

        // إرسال عبر SMS للرقم
        await _sendSmsResponse(targetPhone, finalMessage);

        // أرشفة العملية كعملية مكتملة
        await db.addToArchive(
          sender: targetPhone,
          senderName: senderName,
          receivedMessage: messageText,
          matchedKeyword: keywordText,
          sentNumber: vouchersToSend.join(', '),
          status: processStatus,
          source: source,
        );
      } else {
        // أرشفة حالة نفاد المخزون
        await db.addToArchive(
          sender: targetPhone,
          senderName: senderName,
          receivedMessage: messageText,
          matchedKeyword: keywordText,
          sentNumber: '',
          status: 'failed_out_of_stock',
          source: source,
        );
      }
    }
    // =========================================================
    // 6. في حال تعذر معرفة العميل (لم يُعثر على رقم ولا اسم ولا محفظة)
    // =========================================================
    else {
      String extractedName = senderName ?? 'عميل غير معروف';

      // تسجيل العملية كـ "معلقة" بدون سحب أو حجز أي قسيمة من المخزون
      await db.addToArchive(
        sender: 'غير معروف',
        senderName: extractedName,
        receivedMessage: messageText,
        matchedKeyword: keywordText,
        sentNumber: '', // تترك فارغة حتى إتمام الربط اليدوي وسحب القسيمة لاحقاً
        status: 'manual_approval_required',
        source: source,
      );

      // إطلاق إشعار محلي للتنبيه
      await NotificationHelper.showPendingNotification(
        title: "⚠️ عملية معلقة جديدة",
        body:
            "وصل إيداع جديد ($extractedName) - انقر لربط رقم الهاتف وسحب القسيمة وإرسالها.",
      );
    }
  }

  /// إرسال رسالة SMS عبر الشريحة الهاتفيّة للعميل
  static Future<void> _sendSmsResponse(String recipient, String message) async {
    try {
      await telephony.sendSms(
        to: recipient,
        message: message,
        isMultipart: true,
      );
    } catch (e) {
      print("خطأ أثناء إرسال الـ SMS: $e");
    }
  }
}
/*import 'package:telephony/telephony.dart';
import 'DatabaseHelper.dart';
import 'NotificationHelper.dart'; // استيراد خدمة الإشعارات المحلية

class SmsWorker {
  static final Telephony telephony = Telephony.instance;

  /// النقطة الأساسية للبدء في معالجة الإشعارات أو الرسائل الواصلة
  static Future<void> processIncomingMessage({
    required String sender,
    required String messageText,
    String source = 'Noti',
    String? senderName,
  }) async {
    final db = DatabaseHelper.instance;

    // 1. التحقق من تفعيل الخدمة العامة
    String serviceEnabled = await db.getSetting('service_enabled', 'true');
    if (serviceEnabled.toLowerCase() != 'true') return;

    // 2. التحقق من صلاحية المرسل (إلا إذا كان خيار السماح للكل مفعلاً)
    String allowAll = await db.getSetting('allow_all_senders', 'false');
    if (allowAll.toLowerCase() != 'true') {
      bool isAllowed = await db.isSenderAllowed(sender);
      if (!isAllowed) return;
    }

    // 3. البحث عن كلمة مفتاحية مطابقة داخل نص الرسالة
    List<Map<String, dynamic>> keywords = await db.getAllKeywords();
    Map<String, dynamic>? matchedKeyword;

    for (var kw in keywords) {
      if (kw['is_active'] == 1 &&
          messageText
              .toLowerCase()
              .contains((kw['keyword'] as String).toLowerCase())) {
        matchedKeyword = kw;
        break;
      }
    }

    // في حال عدم وجود كلمة مفتاحية مطابقة
    if (matchedKeyword == null) {
      await db.addToArchive(
        sender: sender,
        senderName: senderName,
        receivedMessage: messageText,
        status: 'ignored_no_keyword',
        source: source,
      );
      return;
    }

    // =========================================================
    // 4. تحديد رقم هاتف العميل (استخراج أو بحث بالاسم)
    // =========================================================
    String? targetPhone;

    // أ. محاولة استخراج رقم الهاتف من نص الرسالة مباشرة (رقم يبدأ بـ 7 و يتكون من 9 أرقام)
    RegExp phoneRegExp = RegExp(r'(7[0-9]{8})');
    Match? phoneMatch = phoneRegExp.firstMatch(messageText);

    if (phoneMatch != null) {
      targetPhone = phoneMatch.group(0);
    } else {
      // ب. إذا لم يوجد رقم بالرسالة، ابحث عن اسم العميل في جدول العملاء
      targetPhone = await db.findCustomerPhoneByIdentifier(messageText);
      //targetPhone = await db.findCustomerPhoneByName(messageText);
    }

    int keywordId = matchedKeyword['id'];
    String keywordText = matchedKeyword['keyword'];
    int targetCount = matchedKeyword['target_count'] ?? 0;
    int? rewardKeywordId = matchedKeyword['reward_keyword_id'];
    int rewardQty = matchedKeyword['reward_qty'] ?? 1;

    // =========================================================
    // 5. في حال معرفة رقم الهاتف (معالجة تلقائية وإرسال فوراً)
    // =========================================================
    if (targetPhone != null && targetPhone.isNotEmpty) {
      // حفظ / تحديث العميل تلقائياً
      await db.saveOrUpdateCustomer(targetPhone, name: senderName);

      List<String> vouchersToSend = [];
      String processStatus = 'sent';

      // فحص نظام المكافآت والعدادات للعميل
      if (targetCount > 0 && rewardKeywordId != null) {
        int currentCount =
            await db.incrementCustomerCounter(targetPhone, keywordId);

        if (currentCount >= targetCount) {
          for (int i = 0; i < rewardQty; i++) {
            var rewardVoucher =
                await db.getAndUseVoucher(rewardKeywordId, targetPhone);
            if (rewardVoucher != null) {
              vouchersToSend.add(rewardVoucher['number_code']);
            }
          }
          await db.resetCustomerCounter(targetPhone, keywordId);
        }
      }

      // سحب القسيمة الأساسية العادية إذا لم توجد مكافأة
      if (vouchersToSend.isEmpty) {
        var voucher = await db.getAndUseVoucher(keywordId, targetPhone);
        if (voucher != null) {
          vouchersToSend.add(voucher['number_code']);
        } else {
          processStatus = 'out_of_stock';
        }
      }

      // صياغة النص النهائي والإرسال
      if (vouchersToSend.isNotEmpty) {
        String defaultReply = await db.getSetting(
          'default_reply',
          'شكراً لتواصلك. رقمك الخاص هو: ',
        );

        String finalMessage = "$defaultReply ${vouchersToSend.join(', ')}";

        // إرسال عبر SMS للرقم المستخرج
        await _sendSmsResponse(targetPhone, finalMessage);

        // أرشفة العملية
        await db.addToArchive(
          sender: targetPhone,
          senderName: senderName,
          receivedMessage: messageText,
          matchedKeyword: keywordText,
          sentNumber: vouchersToSend.join(', '),
          status: processStatus,
          source: source,
        );
      } else {
        // أرشفة حالة النفاد
        await db.addToArchive(
          sender: targetPhone,
          senderName: senderName,
          receivedMessage: messageText,
          matchedKeyword: keywordText,
          sentNumber: '',
          status: 'failed_out_of_stock',
          source: source,
        );
      }
    }
    // =========================================================
    // 6. في حال تعذر معرفة العميل (تعليق العملية + حجز القسيمة + تنبيه)
    // =========================================================
    else {
      // حجز قسيمة بصورة مؤقتة باسم 'PENDING'
      var voucher = await db.getAndUseVoucher(keywordId, 'PENDING');
      String reservedCode =
          voucher != null ? voucher['number_code'] : 'نفذت القسائم';

      String extractedName = senderName ?? 'عميل غير معروف';

      // حفظ السجل في الأرشيف كعملية معلقة تنتظر الإدخال اليدوي
      await db.addToArchive(
        sender: 'غير معروف',
        senderName: extractedName,
        receivedMessage: messageText,
        matchedKeyword: keywordText,
        sentNumber: reservedCode,
        status: 'manual_approval_required',
        source: source,
      );

      // إطلاق إشعار محلي في شريط الإشعارات العلوي
      await NotificationHelper.showPendingNotification(
        title: "⚠️ عملية معلقة جديدة",
        body:
            "وصل إيداع باسم ($extractedName) - انقر لربط رقم الهاتف وإرسال القسيمة المحجوزة.",
      );
    }
  }

  /// إرسال رسالة SMS عبر الشريحة الهاتفيّة للعميل
  static Future<void> _sendSmsResponse(String recipient, String message) async {
    try {
      await telephony.sendSms(
        to: recipient,
        message: message,
        isMultipart: true,
      );
    } catch (e) {
      print("خطأ أثناء إرسال الـ SMS: $e");
    }
  }
}
*/
