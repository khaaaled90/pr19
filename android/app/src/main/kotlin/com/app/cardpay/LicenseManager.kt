package com.app.cardpay

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import android.util.Log
import androidx.work.WorkManager

object LicenseManager {

    private const val TAG = "LicenseManager"

    /**
     * إيقاف كافة العمليات والخدمات والمستقبلات في الخلفية فور انتهاء الترخيص
     */
    fun stopAllBackgroundWork(context: Context) {
        val appContext = context.applicationContext

        Log.d(TAG, "🛑 بدء إيقاف كافة عمليات الخلفية لعدم صلاحية الترخيص...")

        // 1. إيقاف WorkManager (إلغاء جميع المهام المجدولة في الخلفية)
        try {
            WorkManager.getInstance(appContext).cancelAllWork()
            Log.d(TAG, "تم إلغاء جميع مهام WorkManager بنجاح")
        } catch (e: Exception) {
            Log.e(TAG, "خطأ أثناء إيقاف WorkManager: ${e.message}", e)
        }

        // 2. تعطيل مستقبل الرسائل (SmsReceiver) لمنع استلام أو معالجة أي SMS جديدة
        try {
            disableComponent(appContext, SmsReceiver::class.java)
        } catch (e: Exception) {
            Log.e(TAG, "خطأ أثناء تعطيل SmsReceiver: ${e.message}", e)
        }

        // 🟢 2.1 إضافة تعطيل مستمع الإشعارات (NativeNotificationListener) هنا 👇
        try {
            disableComponent(appContext, NativeNotificationListener::class.java)
        } catch (e: Exception) {
            Log.e(TAG, "خطأ أثناء تعطيل NativeNotificationListener: ${e.message}", e)
        }

        // 3. تحديث حالة الترخيص إلى غير صالح في التخزين الآمن
        try {
            val secureStorage = NativeSecureStorage(appContext)
            secureStorage.setLicenseValid(false)
            Log.d(TAG, "تم تحديث حالة الترخيص إلى (غير صالح) في SecureStorage")
        } catch (e: Exception) {
            Log.e(TAG, "خطأ أثناء حفظ حالة الترخيص: ${e.message}", e)
        }
    }

    /**
     * إعادة تفعيل الخدمات والمستقبلات عند تجديد الترخيص بنجاح
     */
    fun enableBackgroundWork(context: Context) {
        val appContext = context.applicationContext

        Log.d(TAG, "🟢 بدء إعادة تفعيل خدمات الخلفية لتجديد الترخيص...")

        // 1. إعادة تمكين مستقبل الـ SMS
        try {
            enableComponent(appContext, SmsReceiver::class.java)
        } catch (e: Exception) {
            Log.e(TAG, "خطأ أثناء تمكين SmsReceiver: ${e.message}", e)
        }

        // 🟢 1.1 إضافة إعادة تمكين مستمع الإشعارات (NativeNotificationListener) هنا 👇
        try {
            enableComponent(appContext, NativeNotificationListener::class.java)
        } catch (e: Exception) {
            Log.e(TAG, "خطأ أثناء تمكين NativeNotificationListener: ${e.message}", e)
        }

        // 2. تحديث حالة الترخيص إلى صالح في التخزين الآمن
        try {
            val secureStorage = NativeSecureStorage(appContext)
            secureStorage.setLicenseValid(true)
            Log.d(TAG, "تم تحديث حالة الترخيص إلى (صالح) في SecureStorage")
        } catch (e: Exception) {
            Log.e(TAG, "خطأ أثناء حفظ حالة الترخيص: ${e.message}", e)
        }
    }

    /**
     * تعطيل مكون (Receiver / Service) من مستوى النظام
     */
    private fun disableComponent(context: Context, componentClass: Class<*>) {
        val receiver = ComponentName(context, componentClass)
        context.packageManager.setComponentEnabledSetting(
            receiver,
            PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
            PackageManager.DONT_KILL_APP
        )
        Log.d(TAG, "تم تعطيل المكون: ${componentClass.simpleName}")
    }

    /**
     * تمكين مكون (Receiver / Service) من مستوى النظام
     */
    private fun enableComponent(context: Context, componentClass: Class<*>) {
        val receiver = ComponentName(context, componentClass)
        context.packageManager.setComponentEnabledSetting(
            receiver,
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP
        )
        Log.d(TAG, "تم تمكين المكون: ${componentClass.simpleName}")
    }
}