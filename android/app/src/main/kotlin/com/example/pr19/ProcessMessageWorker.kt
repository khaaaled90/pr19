package com.example.pr19
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
}
