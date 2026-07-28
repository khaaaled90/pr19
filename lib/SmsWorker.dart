import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'DatabaseHelper.dart';
import 'NotificationHelper.dart';

class SmsWorker {
  static const String _logTag = 'BG_MONITOR';

  // قناة الاتصال النيتيف لإرسال الرسائل عبر الشريحة (DualSimSmsSender.kt)
  static const MethodChannel _smsChannel = MethodChannel('com.example.pr19/sms_sender');

  /// النقطة الأساسية للبدء في معالجة الإشعارات أو الرسائل الواصلة
  static Future<void> processIncomingMessage({
    required String sender,
    required String messageText,
    String source = 'Noti',
    String? senderName,
  }) async {
    // 🔹 ضمان تهيئة محرك Flutter داخل بيئة الـ Isolate للخلفية
    WidgetsFlutterBinding.ensureInitialized();

    developer.log('----------------------------------------', name: _logTag);
    developer.log('⚡ [WORKER STEP 1] البدء في معالجة الرسالة/الإشعار...', name: _logTag);
    developer.log('   👤 المصدر: $source | المرسل: $sender', name: _logTag);
    developer.log('   🏷️ اسم المرسل: $senderName', name: _logTag);
    developer.log('   💬 النص: "$messageText"', name: _logTag);

    final db = DatabaseHelper.instance;

    // 1. التحقق من تفعيل الخدمة العامة
    String serviceEnabled = await db.getSetting('service_enabled', 'true');
    developer.log('⚙️ [WORKER] حالة الخدمة العامة: $serviceEnabled', name: _logTag);
    if (serviceEnabled.toLowerCase() != 'true') {
      developer.log('⛔ [WORKER STOP] تم التوقف: الخدمة العامة معطلة من الإعدادات.', name: _logTag);
      developer.log('----------------------------------------', name: _logTag);
      return;
    }

    // 2. التحقق من صلاحية المرسل
    String allowAll = await db.getSetting('allow_all_senders', 'false');
    developer.log('⚙️ [WORKER] السماح لجميع المراسيل: $allowAll', name: _logTag);
    
    if (allowAll.toLowerCase() != 'true') {
      bool isAllowed = await db.isSenderAllowed(sender);
      developer.log('🔍 [WORKER] فحص المرسل المسموح به ($sender): $isAllowed', name: _logTag);
      if (!isAllowed) {
        developer.log('⛔ [WORKER STOP] تم التوقف: المرسل غير موجود في قائمة المسموح بهم.', name: _logTag);
        developer.log('----------------------------------------', name: _logTag);
        return;
      }
    }

    // 3. البحث عن كلمة مفتاحية مطابقة
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

    developer.log('✅ [WORKER STEP 2] تم العثور على كلمة مفتاحية: "${matchedKeyword['keyword']}" (ID: ${matchedKeyword['id']})', name: _logTag);

    // 4. تحديد رقم هاتف العميل
    String? targetPhone;
    RegExp phoneRegExp = RegExp(r'(7[0-9]{8})');
    Match? phoneMatch = phoneRegExp.firstMatch(messageText);

    if (phoneMatch != null) {
      targetPhone = phoneMatch.group(0);
      developer.log('📱 [WORKER] تم استخراج رقم هاتف العميل بالـ Regex: $targetPhone', name: _logTag);
    } else {
      developer.log('🔍 [WORKER] لم يتم العثور على رقم هاتف، جاري البحث بالحساب/المحفظة...', name: _logTag);
      targetPhone = await db.findCustomerPhoneByIdentifier(messageText);
      developer.log('📱 [WORKER] نتيجة البحث في قاعدة البيانات لرقم العميل: $targetPhone', name: _logTag);
    }

    int keywordId = matchedKeyword['id'];
    String keywordText = matchedKeyword['keyword'];
    int targetCount = matchedKeyword['target_count'] ?? 0;
    int? rewardKeywordId = matchedKeyword['reward_keyword_id'];
    int rewardQty = matchedKeyword['reward_qty'] ?? 1;

    // 5. المعالجة في حال وجود رقم الهاتف
    if (targetPhone != null && targetPhone.isNotEmpty) {
      developer.log('✅ [WORKER STEP 3] البدء في تجهيز القسائم للعميل: $targetPhone', name: _logTag);
      
      await db.saveOrUpdateCustomer(targetPhone, name: senderName);

      List<String> vouchersToSend = [];
      String processStatus = 'sent';

      // فحص نظام المكافآت والعدادات
      if (targetCount > 0 && rewardKeywordId != null) {
        developer.log('🎁 [WORKER] فحص عداد المكافآت (Target: $targetCount)...', name: _logTag);
        
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

      // سحب القسيمة الأساسية العادية
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

      // صياغة النص النهائي والإرسال عبر Native
      if (vouchersToSend.isNotEmpty) {
        String defaultReply = await db.getSetting(
          'default_reply',
          'شكراً لتواصلك. رقمك الخاص هو: ',
        );

        String finalMessage = "$defaultReply ${vouchersToSend.join(', ')}";
        developer.log('✉️ [WORKER STEP 4] جاري إرسال الـ SMS للرقم $targetPhone بالنص: "$finalMessage"', name: _logTag);

        bool sendSuccess = await _sendSmsNative(targetPhone, finalMessage);
        if (!sendSuccess) {
          processStatus = 'failed_sending';
        }

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
    // 6. تحويل للربط اليدوي عند تعذر تحديد العميل
    else {
      String extractedName = senderName ?? 'عميل غير معروف';
      developer.log('⚠️ [WORKER STEP 3] لم يتم التعرّف على رقم الهاتف! تحويل العملية للربط اليدوي...', name: _logTag);

      await db.addToArchive(
        sender: 'غير معروف',
        senderName: extractedName,
        receivedMessage: messageText,
        matchedKeyword: keywordText,
        sentNumber: '',
        status: 'manual_approval_required',
        source: source,
      );

      developer.log('🔔 [WORKER] إطلاق إشعار محلي للتنبيه بالعملية المعلقة...', name: _logTag);
      await NotificationHelper.showPendingNotification(
        title: "⚠️ عملية معلقة جديدة",
        body: "وصل إيداع جديد ($extractedName) - انقر لربط رقم الهاتف وسحب القسيمة وإرسالها.",
      );
    }
    developer.log('----------------------------------------', name: _logTag);
  }

  /// إرسال رسالة SMS عبر Native MethodChannel
  static Future<bool> _sendSmsNative(String recipient, String message) async {
    try {
      developer.log('📤 [SMS NATIVE] إرسال طلب الـ SMS عبر MethodChannel...', name: _logTag);
      final bool result = await _smsChannel.invokeMethod('sendSms', {
        'phone': recipient,
        'message': message,
      });
      developer.log('🎉 [SMS NATIVE] نتيجة الإرسال: $result', name: _logTag);
      return result;
    } on PlatformException catch (e, stackTrace) {
      developer.log(
        '❌ [SMS ERROR] حدث خطأ أثناء إرسال الـ SMS عبر Native: ${e.message}',
        name: _logTag,
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    } catch (e) {
      developer.log('❌ [SMS ERROR] خطأ غير متوقع: $e', name: _logTag);
      return false;
    }
  }
}
