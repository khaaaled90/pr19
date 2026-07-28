package com.example.pr19

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import androidx.work.Data
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager

class NativeNotificationListener : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        if (sbn == null) return

        val packageName = sbn.packageName
        val extras = sbn.notification.extras
        val title = extras.getString("android.title") ?: ""
        val text = extras.getCharSequence("android.text")?.toString() ?: ""
        val fullContent = "$title $text"

        // فحص ما إذا كان الإشعار قادم من تطبيق محفظة مصرح به
        val dbHelper = AppSqliteHelper.getInstance(applicationContext)
        if (dbHelper.isSenderAllowed(packageName)) {
            val inputData = Data.Builder()
                .putString("sender", packageName)
                .putString("body", fullContent)
                .build()

            val workRequest = OneTimeWorkRequestBuilder<ProcessMessageWorker>()
                .setInputData(inputData)
                .build()

            WorkManager.getInstance(applicationContext).enqueue(workRequest)
        }
    }
}
