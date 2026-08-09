package com.example.pr19 // ✅ تم تعديل الحزمة لتطابق مشروعك

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.util.Log // ✅ تم إضافة استيراد Log
import androidx.core.app.NotificationCompat
import com.example.pr19.R // ✅ تم إضافة استيراد R لاستخدام آيقونة التطبيق

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
            .setSmallIcon(R.mipmap.ic_launcher) // ✅ استخدام آيقونة تطبيقك
            .setContentTitle("✅ تم إرسال قسيمة بنجاح")
            .setContentText("تم إرسال قسيمة فئة $categoryName للعميل $customerPhone")
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)

        val notificationId = System.currentTimeMillis().toInt()
        notificationManager.notify(notificationId, builder.build())
    }

    // 🎯 إشعار للعمليات المعلقة التي لا تحتوي على رقم العميل وتحتاج ربط/موافقة يدوية
    fun showManualApprovalNotification(context: Context, receivedMessage: String) {
        try {
            val channelId = "manual_approval_channel"
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            // إنشاء القناة لنظام Android 8.0 وما فوق
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    channelId,
                    "إشعارات الموافقة اليدوية",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "تنبيهات عند وجود رسائل بدون رقم عميل تحتاج إلى ربط يدوي"
                }
                notificationManager.createNotificationChannel(channel)
            }

            // اقتطاع جزء من الرسالة للعرض في الإشعار
            val snippet = if (receivedMessage.length > 40) receivedMessage.take(40) + "..." else receivedMessage

            val builder = NotificationCompat.Builder(context, channelId)
                .setSmallIcon(R.mipmap.ic_launcher) // ✅ آيقونة تطبيقك
                .setContentTitle("⚠️ عملية معلقة تحتاج إلى ربط")
                .setContentText("رسالة بدون رقم عميل: $snippet")
                .setStyle(
                    NotificationCompat.BigTextStyle()
                        .bigText("توجد عملية معلقة بحاجة الى ربط الهاتف:\n\n\"$receivedMessage\"")
                )
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(true)

            val notificationId = System.currentTimeMillis().toInt()
            notificationManager.notify(notificationId, builder.build())

        } catch (e: Exception) {
            Log.e("NotificationHelper", "فشل عرض إشعار الربط اليدوي: ${e.message}", e)
        }
    }
}
/*package com.yourcompany.app // تعديل الحزمة بحسب تطبيقك

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

    // 🎯 إشعار للعمليات المعلقة التي لا تحتوي على رقم العميل وتحتاج ربط/موافقة يدوية
    fun showManualApprovalNotification(context: Context, receivedMessage: String) {
        try {
            val channelId = "manual_approval_channel"
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            // إنشاء القناة لنظام Android 8.0 وما فوق
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    channelId,
                    "إشعارات الموافقة اليدوية",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "تنبيهات عند وجود رسائل بدون رقم عميل تحتاج إلى ربط يدوي"
                }
                notificationManager.createNotificationChannel(channel)
            }

            // اقتطاع جزء من الرسالة للعرض في الإشعار
            val snippet = if (receivedMessage.length > 40) receivedMessage.take(40) + "..." else receivedMessage

            val builder = NotificationCompat.Builder(context, channelId)
                .setSmallIcon(R.mipmap.ic_launcher) // أو آيقونة الإشعارات في تطبيقك
                .setContentTitle("⚠️ عملية معلقة تحتاج إلى ربط")
                .setContentText("رسالة بدون رقم عميل: $snippet")
                .setStyle(
                    NotificationCompat.BigTextStyle()
                        //.bigText("تم تسجيل عملية جديدة بدون رقم هاتف العميل وتحتاج إلى موافقة وربط يدوي:\n\n\"$receivedMessage\"")
                        .bigText("توجد عملية معلقة بحاجة الى ربط الهاتف:\n\n\"$receivedMessage\"")

                )
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(true)

            val notificationId = System.currentTimeMillis().toInt()
            notificationManager.notify(notificationId, builder.build())

        } catch (e: Exception) {
            Log.e("NotificationHelper", "فشل عرض إشعار الربط اليدوي: ${e.message}", e)
        }
    }
}*/