package com.example.pr19

import android.util.Log
import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import androidx.work.ListenableWorker

class ProcessMessageWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {

    override suspend fun doWork(): ListenableWorker.Result {
        // 1. استقبال البيانات
        val rawSender = inputData.getString("sender") ?: ""
        val originPackage = inputData.getString("origin_package") ?: rawSender
        val body = inputData.getString("body") ?: return ListenableWorker.Result.failure()
        
        val dbHelper = AppSqliteHelper.getInstance(applicationContext)

        // 2. التحقق من مفتاح الخدمة
        if (dbHelper.getSetting("service_enabled", "true") != "true") {
            return ListenableWorker.Result.success()
        }

        // 3. التحقق من السماح للـ Package المصدر (وليس رقم الهاتف)
        val allowAllSendersValue = dbHelper.getSetting("allow_all_senders", "false")
        val allowAllSenders = allowAllSendersValue == "true"
        
        Log.d("WORKER", "allowAllSenders = $allowAllSenders")
        Log.d("WORKER", "originPackage = $originPackage")
        
        // نفحص السماح عبر اسم الحزمة الأصلي (Origin Package)
        if (!allowAllSenders && !dbHelper.isSenderAllowed(originPackage) && !dbHelper.isSenderAllowed(rawSender)) {
            Log.d("WORKER", "Message rejected because sender package is not allowed")
            return ListenableWorker.Result.success()
        }

        // 4. مطابقة الكلمة المفتاحية / الفئة
        val matchedKwMap = dbHelper.matchKeyword(body)
        Log.d("WORKER", "body = $body")
        Log.d("WORKER", "matchedKwMap = $matchedKwMap")
        
        if (matchedKwMap == null) {
            dbHelper.addToArchive(
                sender = if (rawSender.isNotEmpty()) rawSender else originPackage,
                senderName = null,
                receivedMessage = body,
                matchedKeyword = null,
                sentNumber = null,
                status = "no_keyword_matched"
            )
            return ListenableWorker.Result.success()
        }

        val keywordId = matchedKwMap["id"] as Int
        val keywordText = matchedKwMap["keyword"] as String

        // 5. تحديد رقم العميل المستهدف بوضوح
        val extractedPhone = if (rawSender.startsWith("+967") || rawSender.startsWith("7")) {
            rawSender
        } else {
            dbHelper.findCustomerPhoneByIdentifier(body)
        }

        Log.d("WORKER", "Final targetCustomerPhone = $extractedPhone")

        // 6. إذا لم يتم العثور على رقم عميل صالح -> تحويل الرسالة لشاشة المعالجة اليدوية
        if (extractedPhone.isNull_Or_Empty_Or_Invalid()) {
            Log.w("WORKER", "No valid customer phone found. Sending to manual processing UI.")
            dbHelper.addToArchive(
                sender = originPackage,
                senderName = null,
                receivedMessage = body,
                matchedKeyword = keywordText,
                sentNumber = null,
                status = "pending_manual_processing" // ستظهر في شاشة المعالجة في التطبيق
            )
            return ListenableWorker.Result.success()
        }

        // 7. سحب القسيمة
        val voucherCode = dbHelper.getAndUseVoucher(keywordId, extractedPhone)
        Log.d("WORKER", "voucherCode = $voucherCode")

        if (voucherCode != null) {
            val defaultReply = dbHelper.getSetting("default_reply", "شكراً لتواصلك. رقمك الخاص هو: ")
            val fullMessage = "$defaultReply $voucherCode"
            
            Log.d("WORKER", "Sending SMS to $extractedPhone")
            
            val isSent = DualSimSmsSender.sendSms(
                context = applicationContext,
                phoneNumber = extractedPhone,
                message = fullMessage
            )

            Log.d("WORKER", "sendSms returned = $isSent")
            val status = if (isSent) "sent" else "failed_sending"

            dbHelper.addToArchive(
                sender = extractedPhone,
                senderName = null,
                receivedMessage = body,
                matchedKeyword = keywordText,
                sentNumber = voucherCode,
                status = status
            )
        } else {
            // نفاد الكروت / القسائم
            dbHelper.addToArchive(
                sender = extractedPhone,
                senderName = null,
                receivedMessage = body,
                matchedKeyword = keywordText,
                sentNumber = null,
                status = "out_of_stock"
            )
        }

        return ListenableWorker.Result.success()
    }

    // دالة مساعدة للتأكد من صحة الرقم
    private fun String?.isNull_Or_Empty_Or_Invalid(): Boolean {
        if (this.isNullOrBlank()) return true
        // إذا كان يحتوي على حروف أو ليس رقم يمني مقبوض
        return !this.contains(Regex("""\d{9}"""))
    }
}






/*package com.example.pr19
import android.util.Log
import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import androidx.work.ListenableWorker

class ProcessMessageWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {

    override suspend fun doWork(): ListenableWorker.Result {
        val sender = inputData.getString("sender") ?: return ListenableWorker.Result.failure()
        val body = inputData.getString("body") ?: return ListenableWorker.Result.failure()
        val dbHelper = AppSqliteHelper.getInstance(applicationContext)

        if (dbHelper.getSetting("service_enabled", "true") != "true") {
            return ListenableWorker.Result.success()
        }

        // ===== تم تعطيل فلترة المرسل مؤقتاً =====
        val allowAllSendersValue = dbHelper.getSetting("allow_all_senders", "false")
        val allowAllSenders = allowAllSendersValue == "true"
        
        Log.d("WORKER", "allow_all_senders(DB) = $allowAllSendersValue")
        Log.d("WORKER", "allowAllSenders = $allowAllSenders")
        Log.d("WORKER", "sender = $sender")
        Log.d("WORKER", "isSenderAllowed = ${dbHelper.isSenderAllowed(sender)}")
        
        if (!allowAllSenders && !dbHelper.isSenderAllowed(sender)) {
            Log.d("WORKER", "Message rejected because sender is not allowed")
            return ListenableWorker.Result.success()
        }
        /*val allowAllSenders = dbHelper.getSetting("allow_all_senders", "false") == "true"
        Log.d("WORKER", "allow_all_senders (DB) = $allowAllSendersValue")
        if (!allowAllSenders && !dbHelper.isSenderAllowed(sender)) {
            return ListenableWorker.Result.success()
        }*/

        // تعطيل مطابقة الكلمات المفتاحية مؤقتاً
        /*val matchedKwMap = mapOf<String, Any>(
            "id" to 1,
            "keyword" to "ALL"
        )*/
        // ===== تم تعطيل فلترة المرسل مؤقتاً =====
        val matchedKwMap = dbHelper.matchKeyword(body)
        Log.d("WORKER", "body = $body")
        Log.d("WORKER", "matchedKwMap = $matchedKwMap")
        if (matchedKwMap == null) {
            dbHelper.addToArchive(sender, null, body, null, null, "no_keyword_matched")
            return ListenableWorker.Result.success()
        }

        val keywordId = matchedKwMap["id"] as Int
        val keywordText = matchedKwMap["keyword"] as String
        val targetCustomerPhone = dbHelper.findCustomerPhoneByIdentifier(body) ?: sender
        Log.d("WORKER", "targetCustomerPhone = $targetCustomerPhone")
        
        val voucherCode = dbHelper.getAndUseVoucher(keywordId, targetCustomerPhone)
        Log.d("WORKER", "voucherCode = $voucherCode")

        if (voucherCode != null) {
            val defaultReply = dbHelper.getSetting("default_reply", "شكراً لتواصلك. رقمك الخاص هو: ")
            val fullMessage = "$defaultReply $voucherCode"
            
            Log.d("WORKER", "Sending SMS to $targetCustomerPhone")
            val isSent = DualSimSmsSender.sendSms(
                context = applicationContext,
                phoneNumber = targetCustomerPhone,
                message = fullMessage
            )

            Log.d("WORKER", "sendSms returned = $isSent")

            val status = if (isSent) "sent" else "failed_sending"

            dbHelper.addToArchive(
                sender = targetCustomerPhone,
                senderName = null,
                receivedMessage = body,
                matchedKeyword = keywordText,
                sentNumber = voucherCode,
                status = status
            )
        } else {
            dbHelper.addToArchive(
                sender = targetCustomerPhone,
                senderName = null,
                receivedMessage = body,
                matchedKeyword = keywordText,
                sentNumber = null,
                status = "out_of_stock"
            )
        }

        return ListenableWorker.Result.success()
    }
}*/
