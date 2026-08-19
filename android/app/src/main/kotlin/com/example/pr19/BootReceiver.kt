package com.example.pr19

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        Log.d("BootReceiver", "Received action: $action")

        if (action == Intent.ACTION_BOOT_COMPLETED || 
            action == Intent.ACTION_MY_PACKAGE_REPLACED ||
            action == "android.intent.action.QUICKBOOT_POWERON" ||
            action == "com.htc.intent.action.QUICKBOOT_POWERON") {
            
            try {
                // 🛑 فحص الترخيص محلياً قبل البدء
                val secureStorage = NativeSecureStorage(context)
                if (secureStorage.isLicenseValid()) {
                    // 🚀 تشغيل الخدمة الأمامية فوراً لإظهار الإشعار الدائم
                    CardPayForegroundService.start(context)
                    Log.d("BootReceiver", "CardPayForegroundService started successfully on boot.")
                } else {
                    Log.w("BootReceiver", "License is invalid. Skipping service start.")
                }
            } catch (e: Exception) {
                Log.e("BootReceiver", "Failed to start service on boot: ${e.message}")
            }
        }
    }
}
//***************************************/
/*package com.example.pr19

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED || 
            intent.action == "android.intent.action.QUICKBOOT_POWERON") {
            // يمكن الاستفادة منه في جدولة مهام معلقة إن وجدت
        }
    }
}*/
