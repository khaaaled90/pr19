package com.example.pr19 // ⚠️ أصلح الباكيج إذا كان مختلفاً لديك

import android.util.Log
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class MyFirebaseMessagingService : FirebaseMessagingService() {

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        super.onMessageReceived(remoteMessage)

        // استخراج البيانات مع تحويلها الصريح إلى String لتجنب Type Mismatch
        val title: String = remoteMessage.notification?.title 
            ?: remoteMessage.data["title"]?.toString() 
            ?: "إشعار جديد"

        val body: String = remoteMessage.notification?.body 
            ?: remoteMessage.data["body"]?.toString() 
            ?: ""

        if (title.isNotBlank() || body.isNotBlank()) {
            try {
                // استخدام AppSqliteHelper الذي يمرر applicationContext
                val dbHelper = AppSqliteHelper(applicationContext)
                dbHelper.insertNotification(title, body)
                Log.d("FCM_NATIVE", "✅ تم حفظ الإشعار بنجاح: $title")
            } catch (e: Exception) {
                Log.e("FCM_NATIVE", "❌ خطأ أثناء حفظ الإشعار: ${e.message}")
            }
        }
    }
}