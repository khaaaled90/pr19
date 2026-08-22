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
import android.util.Log
import android.app.AlarmManager
import android.app.PendingIntent
import android.os.SystemClock
import com.example.pr19.R

class CardPayForegroundService : Service() {

    companion object {
        private const val CHANNEL_ID = "cardpay_foreground_channel"
        private const val NOTIFICATION_ID = 888
        private const val ALARM_REQUEST_CODE = 999

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

    /*override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
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
    }*/
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = createNotification()

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
            Log.e("ForegroundService", "Error starting foreground service: ${e.message}")
        }

        // 🟢 إبقاء الخدمة نشطة عبر المنبه الدوري
        scheduleServiceKeepAlive()
        
        // 🟢 START_STICKY تُجبر أندرويد على إعادة بناء الخدمة فوراً إذا قُتلت بسبب نقص الذاكرة
        return START_STICKY
    }

    // 🟢 إعداد AlarmManager يتفقد الخدمة كل 15 دقيقة
    private fun scheduleServiceKeepAlive() {
        try {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as? AlarmManager
            val intent = Intent(applicationContext, BootReceiver::class.java).apply {
                action = "com.example.pr19.ACTION_KEEP_ALIVE"
            }
            
            val pendingIntent = PendingIntent.getBroadcast(
                applicationContext,
                ALARM_REQUEST_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val triggerAt = SystemClock.elapsedRealtime() + (15 * 60 * 1000) // كل 15 دقيقة

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                // setAndAllowWhileIdle تتيح عمل المنبه حتى لو كان الهاتف في وضع Doze Mode
                alarmManager?.setAndAllowWhileIdle(
                    AlarmManager.ELAPSED_REALTIME_WAKEUP,
                    triggerAt,
                    pendingIntent
                )
            } else {
                alarmManager?.set(
                    AlarmManager.ELAPSED_REALTIME_WAKEUP,
                    triggerAt,
                    pendingIntent
                )
            }
        } catch (e: Exception) {
            Log.e("ForegroundService", "Failed to schedule keep-alive alarm: ${e.message}")
        }
    }
    
    // 🟢 إعادة التشغيل إذا قامت المنظومة بقتل الخدمة
    override fun onDestroy() {
        restartSelf()
        super.onDestroy()
    }
    
    private fun restartSelf() {
        try {
            val restartServiceIntent = Intent(applicationContext, CardPayForegroundService::class.java)
            restartServiceIntent.setPackage(packageName)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                applicationContext.startForegroundService(restartServiceIntent)
            } else {
                applicationContext.startService(restartServiceIntent)
            }
        } catch (e: Exception) {
            Log.e("ForegroundService", "Failed to restart service: ${e.message}")
        }
    }

    // 🟢 إعادة التشغيل عند سحب التطبيق من القائمة
    override fun onTaskRemoved(rootIntent: Intent?) {
        restartSelf()
        super.onTaskRemoved(rootIntent)
    }

    // 🟢 في حال سحب العميل للتطبيق من قائمة Recent Apps، يتم إعادة تشغيل الخدمة فوراً
    /*override fun onTaskRemoved(rootIntent: Intent?) {
        try {
            val restartServiceIntent = Intent(applicationContext, CardPayForegroundService::class.java)
            restartServiceIntent.setPackage(packageName)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                applicationContext.startForegroundService(restartServiceIntent)
            } else {
                applicationContext.startService(restartServiceIntent)
            }
        } catch (e: Exception) {
            Log.e("ForegroundService", "Failed to restart service on task removed: ${e.message}")
        }
        super.onTaskRemoved(rootIntent)
    }*/

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    /*private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("CardPay يعمل في الخلفية")
            .setContentText("جاري استماع ومعالجة الإشعارات والرسائل النصية...")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()
    }*/

    private fun createNotification(): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("CardPay يعمل في الخلفية")
            .setContentText("جاري استماع ومعالجة الإشعارات والرسائل النصية...")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setAutoCancel(false)
            .build()

        // 🔒 تطبيق خصائص منع المسح مباشرة على كائن الإشعار النهائي (Notification)
        notification.flags = notification.flags or
                Notification.FLAG_NO_CLEAR or
                Notification.FLAG_ONGOING_EVENT

        return notification
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