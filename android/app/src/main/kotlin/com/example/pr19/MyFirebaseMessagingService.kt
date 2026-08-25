package com.example.pr19

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class MyFirebaseMessagingService : FirebaseMessagingService() {

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        super.onMessageReceived(remoteMessage)

        // 🟢 1. إعطاء الأولوية للـ data payload أولاً حتى يتم معالجتها فوراً
        val title = remoteMessage.data["title"] 
            ?: remoteMessage.notification?.title 
            ?: "إشعار جديد"

        val body = remoteMessage.data["body"] 
            ?: remoteMessage.notification?.body 
            ?: ""

        if (title.isNotBlank() || body.isNotBlank()) {
            // 🟢 2. الحفظ التلقائي في الداتا بيز (يتم تشغيله دائماً في Background Thread)
            saveNotification(title, body)

            // 🟢 3. إنشاء الإشعار محلياً ليظهر في شريط التنبيهات
            showLocalNotification(title, body)
        }
    }

    private fun saveNotification(title: String, body: String) {
        try {
            // 🟢 يفضل استخدام getInstance أو النمط الفردي لتفادي فتح أكثر من اتصال بقاعدة البيانات
            val dbHelper = AppSqliteHelper.getInstance(applicationContext)
            dbHelper.insertNotification(title, body)
            Log.d("FCM_NATIVE", "✅ تم حفظ الإشعار بنجاح في الخلفية: $title")
        } catch (e: Exception) {
            Log.e("FCM_NATIVE", "❌ خطأ أثناء حفظ الإشعار: ${e.message}", e)
        }
    }

    private fun showLocalNotification(title: String, body: String) {
        val channelId = "fcm_default_channel"
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "إشعارات التطبيق",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                enableVibration(true)
                enableLights(true)
            }
            notificationManager.createNotificationChannel(channel)
        }

        val intent = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("title", title)
            putExtra("body", body)
        }

        val pendingIntent = PendingIntent.getActivity(
            context,
            System.currentTimeMillis().toInt(), // ID فريد لمنع تداخل الإشعارات
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        /*val intent = Intent(this, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }

        val pendingIntent = PendingIntent.getActivity(
            this,
            System.currentTimeMillis().toInt(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )*/

        val builder = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(pendingIntent)

        notificationManager.notify(System.currentTimeMillis().toInt(), builder.build())
    }
}
/********************************/
/*package com.example.pr19 // ⚠️ استبدل الباكيج باسم مشروعك

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class MyFirebaseMessagingService : FirebaseMessagingService() {

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        super.onMessageReceived(remoteMessage)

        // 1. استخراج العنوان والنص
        val title = remoteMessage.notification?.title 
            ?: remoteMessage.data["title"] 
            ?: "إشعار جديد"

        val body = remoteMessage.notification?.body 
            ?: remoteMessage.data["body"] 
            ?: ""

        if (title.isNotBlank() || body.isNotBlank()) {
            // 2. الحفظ التلقائي في الداتا بيز في جميع الحالات
            saveNotification(title, body)

            // 3. إنشاء الإشعار محلياً ليظهر في شريط التنبيهات
            showLocalNotification(title, body)
        }
    }

    private fun saveNotification(title: String, body: String) {
        try {
            val dbHelper = AppSqliteHelper(applicationContext)
            dbHelper.insertNotification(title, body)
            Log.d("FCM_NATIVE", "✅ تم حفظ الإشعار بنجاح: $title")
        } catch (e: Exception) {
            Log.e("FCM_NATIVE", "❌ خطأ أثناء حفظ الإشعار: ${e.message}")
        }
    }

    private fun showLocalNotification(title: String, body: String) {
        val channelId = "fcm_default_channel"
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // إنشاء القناة لأجهزة أندرويد 8 وما فوق
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "إشعارات التطبيق",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                enableVibration(true)
                enableLights(true)
            }
            notificationManager.createNotificationChannel(channel)
        }

        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }

        val pendingIntent = PendingIntent.getActivity(
            this,
            System.currentTimeMillis().toInt(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(R.mipmap.ic_launcher) // أو أيقونة تطبيقك
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(pendingIntent)

        notificationManager.notify(System.currentTimeMillis().toInt(), builder.build())
    }
}*/
/*********************************************/
/*package com.example.pr19 // ⚠️ أصلح الباكيج إذا كان مختلفاً لديك

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
}*/