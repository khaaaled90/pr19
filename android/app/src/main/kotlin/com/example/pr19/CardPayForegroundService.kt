package com.example.pr19

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.example.pr19.R

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

        // 🟢 التعديل الجوهري: معالجة قيود Android 14+ وإضافة try-catch لمنع Crash التطبيق
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) { // Android 14+
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("CardPay يعمل في الخلفية")
            .setContentText("جاري استماع ومعالجة الإشعارات والرسائل النصية...")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
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
            
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            manager?.createNotificationChannel(channel)
        }
    }
}
/*package com.example.pr19

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.example.pr19.R

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
        startForeground(
            NOTIFICATION_ID, 
            notification)
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("CardPay يعمل في الخلفية")
            .setContentText("جاري استماع ومعالجة الإشعارات والرسائل النصية...")
            .setSmallIcon(R.mipmap.ic_launcher) // تم التغيير لأيقونة التطبيق مباشرة
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
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
            
            // 🟢 التعديل الصحيح لاستدراج المانجر بدون خطأ في الكومبايلر
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            manager?.createNotificationChannel(channel)
        }
    }
}*/