import 'dart:developer' as developer;
import 'package:another_telephony/telephony.dart';
import 'DatabaseHelper.dart';
import 'NotificationHelper.dart'; // استيراد خدمة الإشعارات المحلية

class SmsWorker {
  static final Telephony telephony = Telephony.instance;
  static const String _logTag = 'BG_MONITOR';

  /// النقطة الأساسية للبدء في معالجة الإشعارات أو الرسائل الواصلة
  static Future<void> processIncomingMessage({
    required String sender,
    required String messageText,
    String source = 'Noti',
    String? senderName,
  }) async {
    developer.log('----------------------------------------', name: _logTag);
    developer.log('⚡ [WORKER STEP 1] البدء في معالجة الرسالة/الإشعار...', name: _logTag);
    developer.log('   👤 المصدر (Source): $source | المرسل (Sender): $sender', name: _logTag);
    developer.log('   🏷️ اسم المرسل (SenderName): $senderName', name: _logTag);
    developer.log('   💬 النص (MessageText): "$messageText"', name: _logTag);

    final db = DatabaseHelper.instance;

    // 1. التحقق من تفعيل الخدمة العامة
    String serviceEnabled = await db.getSetting('service_enabled', 'true');
    developer.log('⚙️ [WORKER] حالة الخدمة العامة (service_enabled): $serviceEnabled', name: _logTag);
    if (serviceEnabled.toLowerCase() != 'true') {
      developer.log('⛔ [WORKER STOP] تم التوقف: الخدمة العامة معطلة من الإعدادات.', name: _logTag);
      developer.log('----------------------------------------', name: _logTag);
      return;
    }

    // 2. التحقق من صلاحية المرسل (إلا إذا كان خيار السماح للكل مفعلاً)
    String allowAll = await db.getSetting('allow_all_senders', 'false');
    developer.log('⚙️ [WORKER] السماح لجميع المراسيل (allow_all_senders): $allowAll', name: _logTag);
    
    if (allowAll.toLowerCase() != 'true') {
      bool isAllowed = await db.isSenderAllowed(sender);
      developer.log('🔍 [WORKER] فحص المرسل المسموح به ($sender): $isAllowed', name: _logTag);
      if (!isAllowed) {
        developer.log('⛔ [WORKER STOP] تم التوقف: المرسل غير موجود في قائمة المسموح بهم.', name: _logTag);
        developer.log('----------------------------------------', name: _logTag);
        return;
      }
    }

    // 3. البحث عن كلمة مفتاحية مطابقة داخل نص الرسالة
    List<Map<String, dynamic>> keywords = await db.getAllKeywords();
    developer.log('🔍 [WORKER] جاري مطابقة النص مع عدد (${keywords.length}) كلمات مفتاحية...', name: _logTag);
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
      developer.log('⚠️ [WORKER] لم يتم العثور على أي كلمة مفتاحية مطابقة في النص.', name: _logTag);
      developer.log('📥 [WORKER] جاري الأرشفة كـ (ignored_no_keyword)...', name: _logTag);
      
      await db.addToArchive(
        sender: sender,
        senderName: senderName,
        receivedMessage: messageText,
        status: 'ignored_no_keyword',
        source: source,
      );
      
      developer.log('----------------------------------------', name: _logTag);
      return;
    }

    developer.log('✅ [WORKER STEP 2] تم العثور على كلمة مفتاحية مطابقة: "${matchedKeyword['keyword']}" (ID: ${matchedKeyword['id']})', name: _logTag);

    // =========================================================
    // 4. تحديد رقم هاتف العميل (استخراج أو بحث بالاسم / رقم المحفظة)
    // =========================================================
    String? targetPhone;

    // أ. محاولة استخراج رقم الهاتف مباشرة من الرسالة (رقم يبدأ بـ 7 ويتكون من 9 أرقام)
    RegExp phoneRegExp = RegExp(r'(7[0-9]{8})');
    Match? phoneMatch = phoneRegExp.firstMatch(messageText);

    if (phoneMatch != null) {
      targetPhone = phoneMatch.group(0);
      developer.log('📱 [WORKER] تم استخراج رقم هاتف العميل بالـ Regex: $targetPhone', name: _logTag);
    } else {
      developer.log('🔍 [WORKER] لم يتم العثور على رقم هاتف في النص، جاري البحث بالحساب/المحفظة في الداتا بيز...', name: _logTag);
      // ب. إذا لم يوجد رقم في النص، ابحث عن الاسم أو رقم المحفظة في جدول العملاء
      targetPhone = await db.findCustomerPhoneByIdentifier(messageText);
      developer.log('📱 [WORKER] نتيجة البحث في قاعدة البيانات لرقم العميل: $targetPhone', name: _logTag);
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
      developer.log('✅ [WORKER STEP 3] البدء في تجهيز القسائم للعميل صاحب الرقم: $targetPhone', name: _logTag);
      
      // حفظ أو تحديث العميل تلقائياً (إذا كان رقماً جديداً يُضاف للجدول فوراً)
      await db.saveOrUpdateCustomer(targetPhone, name: senderName);

      List<String> vouchersToSend = [];
      String processStatus = 'sent';

      // فحص نظام المكافآت والعدادات للعميل
      if (targetCount > 0 && rewardKeywordId != null) {
        developer.log('🎁 [WORKER] فحص عداد المكافآت (Target: $targetCount, Reward Keyword ID: $rewardKeywordId)...', name: _logTag);
        
        int currentCount = await db.incrementCustomerCounter(targetPhone, keywordId);
        developer.log('📊 [WORKER] العداد الحالي للعميل: $currentCount / $targetCount', name: _logTag);

        if (currentCount >= targetCount) {
          developer.log('🎉 [WORKER] العميل استحق المكافأة! جاري سحب قسائم المكافأة (العدد: $rewardQty)...', name: _logTag);
          for (int i = 0; i < rewardQty; i++) {
            var rewardVoucher = await db.getAndUseVoucher(rewardKeywordId, targetPhone);
            if (rewardVoucher != null) {
              vouchersToSend.add(rewardVoucher['number_code']);
              developer.log('🎟️ [WORKER] تم سحب قسيمة مكافأة: ${rewardVoucher['number_code']}', name: _logTag);
            } else {
              developer.log('❌ [WORKER] نفاد مخزون قسائم المكافأة!', name: _logTag);
            }
          }
          await db.resetCustomerCounter(targetPhone, keywordId);
          developer.log('🔄 [WORKER] تم إعادة تصفير العداد للعميل.', name: _logTag);
        }
      }

      // سحب القسيمة الأساسية العادية إذا لم توجد مكافأة
      if (vouchersToSend.isEmpty) {
        developer.log('🎟️ [WORKER] جاري سحب القسيمة الأساسية للكلمة المفتاحية (ID: $keywordId)...', name: _logTag);
        var voucher = await db.getAndUseVoucher(keywordId, targetPhone);
        if (voucher != null) {
          vouchersToSend.add(voucher['number_code']);
          developer.log('✅ [WORKER] تم سحب القسيمة بنجاح: ${voucher['number_code']}', name: _logTag);
        } else {
          developer.log('❌ [WORKER] نفاد مخزون القسائم العادية!', name: _logTag);
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
        developer.log('✉️ [WORKER STEP 4] جاري إرسال الـ SMS للرقم $targetPhone بالنص: "$finalMessage"', name: _logTag);

        // إرسال عبر SMS للرقم
        await _sendSmsResponse(targetPhone, finalMessage);

        // أرشفة العملية كعملية مكتملة
        developer.log('📥 [WORKER] جاري أرشفة العملية كـ ($processStatus)...', name: _logTag);
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
        developer.log('📥 [WORKER] جاري أرشفة العملية كـ (failed_out_of_stock)...', name: _logTag);
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
      developer.log('⚠️ [WORKER STEP 3] لم يتم التعرّف على رقم الهاتف! تحويل العملية للربط اليدوي...', name: _logTag);

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

      developer.log('🔔 [WORKER] إطلاق إشعار محلي بالتنبيه للعملية المعلقة...', name: _logTag);
      // إطلاق إشعار محلي للتنبيه
      await NotificationHelper.showPendingNotification(
        title: "⚠️ عملية معلقة جديدة",
        body:
            "وصل إيداع جديد ($extractedName) - انقر لربط رقم الهاتف وسحب القسيمة وإرسالها.",
      );
    }
    developer.log('----------------------------------------', name: _logTag);
  }

  /// إرسال رسالة SMS عبر الشريحة الهاتفيّة للعميل
  static Future<void> _sendSmsResponse(String recipient, String message) async {
    try {
      developer.log('📤 [SMS ENGINE] جاري توجيه طلب الإرسال لـ Telephony...', name: _logTag);
      await telephony.sendSms(
        to: recipient,
        message: message,
        isMultipart: true,
      );
      developer.log('🎉 [SMS ENGINE] تم تسليم طلب إرسال الـ SMS للشريحة بنجاح.', name: _logTag);
    } catch (e, stackTrace) {
      developer.log(
        '❌ [SMS ERROR] حدث خطأ أثناء إرسال الـ SMS: $e',
        name: _logTag,
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
}
/*import 'package:telephony/telephony.dart';
//import 'package:telephony_plus/telephony_plus.dart';
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
}*/
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
