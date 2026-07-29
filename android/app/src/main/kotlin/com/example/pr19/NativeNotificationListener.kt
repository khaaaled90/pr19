package com.example.pr19

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

class NativeNotificationListener : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        if (sbn == null) return

        val packageName = sbn.packageName
        val extras = sbn.notification.extras

        val title = extras.getString("android.title") ?: ""
        val text = extras.getCharSequence("android.text")?.toString() ?: ""
        val fullContent = "$title $text"

        val targetPhone = extractPhoneNumberFromBody(fullContent)
        val formattedTargetPhone = if (targetPhone != null) formatToInternational(targetPhone) else ""

        // ⭐ الاستدعى الآمن اللاتزامني
        ProcessMessageProcessor.processMessageAsync(
            context = applicationContext,
            rawSender = packageName,
            originPackage = packageName,
            body = fullContent,
            customerPhoneInput = formattedTargetPhone
        )
    }

    private fun extractPhoneNumberFromBody(body: String): String? {
        val phoneRegex = Regex("""(7[01378]\d{7})""")
        return phoneRegex.find(body)?.value
    }

    private fun formatToInternational(phone: String): String {
        return if (phone.startsWith("7") && phone.length == 9) "+967$phone" else phone
    }
}