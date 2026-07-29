package com.example.pr19

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
}