package com.example.pr19

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.util.Log // 👈 أضف هذا الاستيراد

class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        // 🛑 1. فحص الترخيص في أول سطر قبل أي شيء
        val secureStorage = NativeSecureStorage(context)

        if (!secureStorage.isLicenseValid()) {
            Log.e("SmsReceiver", "⚠️ انتهى الترخيص! تم التوقف عن معالجة الرسالة وإيقاف العمليات.")
            
            // إيقاف وتأكيد تعطيل كل خدمات الخلفية
            LicenseManager.stopAllBackgroundWork(context)
            
            // الخروج فوراً لعدم معالجة الـ SMS
            return
        }
        if (intent.action == Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            val dbHelper = AppSqliteHelper(context.applicationContext)

            for (sms in messages) {
                val originSender = sms.originatingAddress ?: ""
                val body = sms.messageBody ?: continue

                // 1. البحث عن رقم هاتف مباشر داخل نص الرسالة
                var targetPhone = extractPhoneNumberFromBody(body)

                // 2. إذا لم يتوفر رقم هاتف، نبحث عن المعرف/الاسم المسجل في الكاش
                if (targetPhone.isNullOrBlank()) {
                    targetPhone = AppCache.findPhoneByIdentifier(dbHelper, body)
                }

                val formattedTargetPhone = if (!targetPhone.isNullOrBlank()) {
                    formatToInternational(targetPhone)
                } else {
                    ""
                }

                // ⭐ الاستدعاء الآمن اللاتزامني لحماية BroadcastReceiver من ANR
                ProcessMessageProcessor.processMessageAsync(
                    context = context.applicationContext,
                    rawSender = originSender,
                    originPackage = originSender,
                    body = body,
                    customerPhoneInput = formattedTargetPhone
                )
            }
        }
    }

    private fun extractPhoneNumberFromBody(body: String): String? {
        val phoneRegex = Regex("""(7[01378]\d{7})""")
        return phoneRegex.find(body)?.value
    }

    private fun formatToInternational(phone: String): String {
        return if (phone.startsWith("7") && phone.length == 9) "+967$phone" else phone
    }
}
/*package com.example.pr19

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony

class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            for (sms in messages) {
                val originSender = sms.originatingAddress ?: ""
                val body = sms.messageBody ?: continue

                val targetPhone = extractPhoneNumberFromBody(body) ?: ""
                val formattedTargetPhone = formatToInternational(targetPhone)

                // ⭐ الاستدعى الآمن اللاتزامني لحماية BroadcastReceiver من ANR
                ProcessMessageProcessor.processMessageAsync(
                    context = context,
                    rawSender = originSender,
                    originPackage = originSender,
                    body = body,
                    customerPhoneInput = formattedTargetPhone
                )
            }
        }
    }

    private fun extractPhoneNumberFromBody(body: String): String? {
        val phoneRegex = Regex("""(7[01378]\d{7})""")
        return phoneRegex.find(body)?.value
    }

    private fun formatToInternational(phone: String): String {
        return if (phone.startsWith("7") && phone.length == 9) "+967$phone" else phone
    }
}*/