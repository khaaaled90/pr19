package com.yourcompany.app // تعديل الحزمة بحسب تطبيقك

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.core.app.NotificationCompat

object NotificationHelper {

    private const val CHANNEL_ID = "voucher_sent_channel"
    private const val CHANNEL_NAME = "إشعارات إرسال القسائم"

    fun showVoucherSentNotification(context: Context, categoryName: String, customerPhone: String) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // إنشاء قناة الإشعارات
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "تنبيهات عند إرسال قسيمة بنجاح للعملاء"
            }
            notificationManager.createNotificationChannel(channel)
        }

        // بناء الإشعار
        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_upload_done) // يمكنك تغييره بأيقونة تطبيقك
            .setContentTitle("✅ تم إرسال قسيمة بنجاح")
            .setContentText("تم إرسال قسيمة فئة $categoryName للعميل $customerPhone")
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)

        val notificationId = System.currentTimeMillis().toInt()
        notificationManager.notify(notificationId, builder.build())
    }
}