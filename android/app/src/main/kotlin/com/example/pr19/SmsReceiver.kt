package com.example.pr19

import android.content.BroadcastReceiver
import android.util.Log
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import androidx.work.Data
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager

class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Log.d("SMS_RECEIVER", "onReceive Called")
        if (intent.action == Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            Log.d("SMS_RECEIVER", "SMS_RECEIVED_ACTION")
            val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            for (sms in messages) {
                val originSender = sms.originatingAddress ?: ""
                val body = sms.messageBody ?: continue

                Log.d("SMS_RECEIVER", "OriginSender=$originSender Body=$body")

                // ✅ 1. استخراج رقم العميل الحقيقي الموجود داخل نص الرسالة (مثلاً: 734555333)
                val targetPhone = extractPhoneNumberFromBody(body) ?: originSender

                // ✅ 2. تهيئة الرقم بالصيغة الدولية لتجنب رفض Mms/SmsManager له صامتاً
                val formattedTargetPhone = formatToInternational(targetPhone)

                Log.d("SMS_RECEIVER", "TargetPhoneForVoucher=$formattedTargetPhone")

                val inputData = Data.Builder()
                    .putString("sender", formattedTargetPhone) // نمرر الآن رقم العميل الحقيقي للـ Worker
                    .putString("body", body)
                    .build()

                val workRequest = OneTimeWorkRequestBuilder<ProcessMessageWorker>()
                    .setInputData(inputData)
                    .build()

                WorkManager.getInstance(context).enqueue(workRequest)
            }
        }
    }

    // دالة استخراج الرقم اليمني من داخل نص الرسالة
    private fun extractPhoneNumberFromBody(body: String): String? {
        val phoneRegex = Regex("""(7[01378]\d{7})""")
        val match = phoneRegex.find(body)
        return match?.value
    }

    // دالة إضافة مفتاح الدولة لضمان نجاح الإرسال من الخلفية
    private fun formatToInternational(phone: String): String {
        return if (phone.startsWith("7") && phone.length == 9) {
            "+967$phone"
        } else {
            phone
        }
    }
}

/*package com.example.pr19

import android.content.BroadcastReceiver
import android.util.Log
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import androidx.work.Data
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager

class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Log.d("SMS_RECEIVER", "onReceive Called")
        if (intent.action == Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            Log.d("SMS_RECEIVER", "SMS_RECEIVED_ACTION")
            val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            for (sms in messages) {
                Log.d(
                    "SMS_RECEIVER",
                    "Sender=${sms.originatingAddress} Body=${sms.messageBody}"
                )
                val sender = sms.originatingAddress ?: continue
                val body = sms.messageBody ?: continue

                val inputData = Data.Builder()
                    .putString("sender", sender)
                    .putString("body", body)
                    .build()

                val workRequest = OneTimeWorkRequestBuilder<ProcessMessageWorker>()
                    .setInputData(inputData)
                    .build()

                WorkManager.getInstance(context).enqueue(workRequest)
            }
        }
    }
}
*/
