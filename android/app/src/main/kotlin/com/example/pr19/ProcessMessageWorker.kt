package com.example.pr19

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
        /*val allowAllSenders = dbHelper.getSetting("allow_all_senders", "false") == "true"
        if (!allowAllSenders && !dbHelper.isSenderAllowed(sender)) {
            return ListenableWorker.Result.success()
        }*/

        // تعطيل مطابقة الكلمات المفتاحية مؤقتاً
        val matchedKwMap = mapOf<String, Any>(
            "id" to 1,
            "keyword" to "ALL"
        )
        // ===== تم تعطيل فلترة المرسل مؤقتاً =====
        /*val matchedKwMap = dbHelper.matchKeyword(body)
        if (matchedKwMap == null) {
            dbHelper.addToArchive(sender, null, body, null, null, "no_keyword_matched")
            return ListenableWorker.Result.success()
        }*/

        val keywordId = matchedKwMap["id"] as Int
        val keywordText = matchedKwMap["keyword"] as String
        val targetCustomerPhone = dbHelper.findCustomerPhoneByIdentifier(body) ?: sender

        val voucherCode = dbHelper.getAndUseVoucher(keywordId, targetCustomerPhone)

        if (voucherCode != null) {
            val defaultReply = dbHelper.getSetting("default_reply", "شكراً لتواصلك. رقمك الخاص هو: ")
            val fullMessage = "$defaultReply $voucherCode"

            val isSent = DualSimSmsSender.sendSms(
                context = applicationContext,
                phoneNumber = targetCustomerPhone,
                message = fullMessage
            )

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
