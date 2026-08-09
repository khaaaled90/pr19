package com.example.pr19 // ✅ تم تعديل الحزمة لتطابق مشروعك

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.example.pr19.R // ✅ تم إضافة استيراد R لاستخدام آيقونة التطبيق


class CardPayForegroundService : Service() {

    companion object {
        private const val CHANNEL_ID = "cardpay_foreground_channel"
        private const val NOTIFICATION_ID = 888

        fun start(context: Context) {
            val intent = Intent(context, CardPayForegroundService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, CardPayForegroundService::class.java)
            context.stopService(intent)
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = createNotification()
        startForeground(NOTIFICATION_ID, notification)
        
        // START_STICKY تضمن إعادات تشغيل الخدمة تلقائياً إذا أغلقت للضرورة
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("CardPay يعمل في الخلفية")
            .setContentText("جاري استماع ومعالجة الإشعارات والرسائل النصية...")
            .setSmallIcon(android.R.drawable.stat_notify_sync) // أو R.mipmap.ic_launcher
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true) // إشعار ثابت لا يمكن مسحه
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "خدمة معالجة CardPay في الخلفية",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "تُبقي تطبيق CardPay نشطاً لمعالجة حوالات ورسائل المحافظ"
            }
            val manager = getSystemService(Context::class.java)
            manager?.createNotificationChannel(channel)
        }
    }
}