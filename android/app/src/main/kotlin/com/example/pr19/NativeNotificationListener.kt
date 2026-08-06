package com.example.pr19

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log // 👈 أضف هذا الاستيراد

class NativeNotificationListener : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification?) {

        // 🛑 1. فحص الترخيص في أول سطر واستخدام this كـ Context
        val secureStorage = NativeSecureStorage(this)

        if (!secureStorage.isLicenseValid()) {
            Log.e("NotificationListener", "⚠️ انتهى الترخيص! تم التوقف عن قراءة الإشعارات.")
            
            // إيقاف وتأكيد تعطيل كل خدمات الخلفية
            LicenseManager.stopAllBackgroundWork(applicationContext)
            
            // الخروج فوراً وعدم معالجة الإشعار
            return
        }
        
        super.onNotificationPosted(sbn)
        if (sbn == null) return

        val packageName = sbn.packageName
        val extras = sbn.notification.extras

        val title = extras.getString("android.title") ?: ""
        val text = extras.getCharSequence("android.text")?.toString() ?: ""
        val fullContent = "$title $text"

        // 1. محاولة استخراج رقم مباشر بواسطة الـ Regex
        var targetPhone = extractPhoneNumberFromBody(fullContent)

        // 2. إذا لم نجد رقماً برمجياً، نبحث عن اسم/معرف العميل في الكاش الموحد
        if (targetPhone.isNullOrBlank()) {
            val dbHelper = AppSqliteHelper(applicationContext)
            targetPhone = AppCache.findPhoneByIdentifier(dbHelper, fullContent)
        }

        val formattedTargetPhone = if (!targetPhone.isNullOrBlank()) {
            formatToInternational(targetPhone)
        } else {
            ""
        }

        // ⭐ الاستدعاء الآمن اللاتزامني
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
/*package com.example.pr19

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
}*/