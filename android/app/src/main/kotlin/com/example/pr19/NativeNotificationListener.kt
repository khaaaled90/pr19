package com.example.pr19

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import androidx.work.Data
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager

class NativeNotificationListener : NotificationListenerService() {

    override fun onCreate() {
        super.onCreate()
        Log.d("NOTIFICATION", "Service Created")
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.d("NOTIFICATION", "Listener Connected")
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        Log.d("NOTIFICATION", "Listener Disconnected")
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)

        Log.d("NOTIFICATION", "Notification Received")

        if (sbn == null) {
            Log.d("NOTIFICATION", "StatusBarNotification is NULL")
            return
        }

        val packageName = sbn.packageName
        val extras = sbn.notification.extras

        val title = extras.getString("android.title") ?: ""
        val text = extras.getCharSequence("android.text")?.toString() ?: ""
        val fullContent = "$title $text"

        Log.d("NOTIFICATION", "Package = $packageName")
        Log.d("NOTIFICATION", "Title = $title")
        Log.d("NOTIFICATION", "Text = $text")
        Log.d("NOTIFICATION", "Content = $fullContent")
        // فحص قاعدة البيانات
        /*val dbHelper = AppSqliteHelper.getInstance(applicationContext)
        val allowed = dbHelper.isSenderAllowed(packageName)
        Log.d("NOTIFICATION", "Allowed = $allowed")
        // إذا لم يكن التطبيق ضمن التطبيقات المسموح بها
        if (!allowed) {
            Log.d("NOTIFICATION", "Notification ignored")
            return
        }*/
        // ===== تم تعطيل فلترة التطبيقات مؤقتاً =====
        Log.d("NOTIFICATION", "Filtering disabled - accepting all notifications")

        Log.d("NOTIFICATION", "Creating WorkManager request")

        val inputData = Data.Builder()
            .putString("sender", packageName)
            .putString("body", fullContent)
            .build()

        val workRequest = OneTimeWorkRequestBuilder<ProcessMessageWorker>()
            .setInputData(inputData)
            .build()

        WorkManager.getInstance(applicationContext).enqueue(workRequest)

        Log.d("NOTIFICATION", "WorkManager enqueued successfully")
    }
}
/*package com.example.pr19

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import androidx.work.Data
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager

class NativeNotificationListener : NotificationListenerService() {

    override fun onListenerConnected() {
        super.onListenerConnected()
            Log.d("NOTIFICATION", "Listener Connected")
    }
    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
            Log.d("NOTIFICATION", "Notification Received")
        if (sbn == null) return

        val packageName = sbn.packageName
        val extras = sbn.notification.extras
        val title = extras.getString("android.title") ?: ""
        val text = extras.getCharSequence("android.text")?.toString() ?: ""
        val fullContent = "$title $text"
            Log.d("NOTIFICATION", "Package = $packageName")
        // فحص ما إذا كان الإشعار قادم من تطبيق محفظة مصرح به
        val dbHelper = AppSqliteHelper.getInstance(applicationContext)
            Log.d("NOTIFICATION", "Checking Package = $packageName")
        if (dbHelper.isSenderAllowed(packageName)) {
            val allowed = dbHelper.isSenderAllowed(packageName)
            Log.d("NOTIFICATION", "Allowed = $allowed")    
            val inputData = Data.Builder()
                .putString("sender", packageName)
                .putString("body", fullContent)
                .build()

            val workRequest = OneTimeWorkRequestBuilder<ProcessMessageWorker>()
                .setInputData(inputData)
                .build()

            WorkManager.getInstance(applicationContext).enqueue(workRequest)
        }
        Log.d("NOTIFICATION", "Content = $fullContent")
    }
}
*/
