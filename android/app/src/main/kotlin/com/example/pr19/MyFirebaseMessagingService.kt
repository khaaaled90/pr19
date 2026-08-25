package com.example.pr19 // ⚠️ استبدل الباكيج باسم تطبيقك

import android.content.ContentValues
import android.util.Log
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class MyFirebaseMessagingService : FirebaseMessagingService() {

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        super.onMessageReceived(remoteMessage)

        // 1. استخراج عنوان ونص الإشعار سواء جاء كـ Notification أو Data
        val title = remoteMessage.notification?.title 
            ?: remoteMessage.data["title"] 
            ?: "إشعار جديد"
            
        val body = remoteMessage.notification?.body 
            ?: remoteMessage.data["body"] 
            ?: ""

        // 2. الحفظ المباشر في قاعدة بيانات SQLite الخاصة بالتطبيق
        if (title.isNotEmpty() || body.isNotEmpty()) {
            try {
                saveToDatabase(title, body)
                Log.d("FCM_NATIVE", "✅ تم حفظ إشعار الفايربيس من كوتلن: $title")
            } catch (e: Exception) {
                Log.e("FCM_NATIVE", "❌ خطأ أثناء حفظ الإشعار: ${e.message}")
            }
        }
    }

    private fun saveToDatabase(title: String, body: String) {
        // افترضنا استخدام نفس اسم الجدول والأعمدة في SQLite لدى تطبيقك
        val dbHelper = DatabaseHelper(applicationContext) 
        val db = dbHelper.writableDatabase

        val values = ContentValues().apply {
            put("title", title)
            put("body", body)
            put("timestamp", java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", java.util.Locale.US).format(java.util.Date()))
        }

        // إدراج البيانات في جدول tableNotifications (أو اسم جدولك)
        db.insert("notifications", null, values) 
        db.close()
    }
}