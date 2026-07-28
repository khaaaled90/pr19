package com.example.pr19

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.telephony.SmsManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {

    companion object {
        private const val CONTROL_CHANNEL = "com.example.pr19/native_control"
        private const val SMS_CHANNEL = "com.example.app/sms" // قناة إرسال القسائم عبر SMS
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val messenger = flutterEngine.dartExecutor.binaryMessenger

        // 1. قناة التحكم بالأذونات واستثناء البطارية
        MethodChannel(messenger, CONTROL_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                // 1. طلب إذن استماع الإشعارات للمحافظ
                "requestNotificationListenerPermission" -> {
                    val isGranted = isNotificationServiceEnabled()
                    if (!isGranted) {
                        val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                    }
                    result.success(isGranted)
                }

                // 2. التحقق من حالة إذن الإشعارات
                "isNotificationListenerGranted" -> {
                    result.success(isNotificationServiceEnabled())
                }

                // 3. طلب استثناء البطارية (Doze Mode Bypass)
                "requestIgnoreBatteryOptimizations" -> {
                    requestBatteryOptimizationExemption()
                    result.success(true)
                }

                else -> {
                    result.notImplemented()
                }
            }
        }

        // 2. قناة إرسال الرسائل النصية القادمة من Flutter
        MethodChannel(messenger, SMS_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "sendSms") {
                val phone = call.argument<String>("phone") ?: call.argument<String>("address")
                val message = call.argument<String>("message") ?: call.argument<String>("body")

                if (!phone.isNullOrEmpty() && !message.isNullOrEmpty()) {
                    try {
                        sendNativeSms(phone, message)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SMS_FAILED", "فشل إرسال الرسالة: ${e.localizedMessage}", null)
                    }
                } else {
                    result.error("INVALID_ARGS", "رقم الهاتف أو نص الرسالة فارغ", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    // دالة إرسال الـ SMS عبر نظام أندرويد
    private fun sendNativeSms(phone: String, message: String) {
        val smsManager: SmsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            getSystemService(SmsManager::class.java)
        } else {
            @Suppress("DEPRECATION")
            SmsManager.getDefault()
        }

        // تقسيم الرسالة تلقائياً في حال كانت طويلة لضمان وصول نص القسيمة كاملاً
        val parts = smsManager.divideMessage(message)
        if (parts.size > 1) {
            smsManager.sendMultipartTextMessage(phone, null, parts, null, null)
        } else {
            smsManager.sendTextMessage(phone, null, message, null, null)
        }
    }

    // التحقق مما إذا كانت خدمة قراءة الإشعارات مفعلة للتطبيق
    private fun isNotificationServiceEnabled(): Boolean {
        val pkgName = packageName
        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
        if (!flat.isNullOrEmpty()) {
            val names = flat.split(":")
            for (name in names) {
                if (name.contains(pkgName)) {
                    return true
                }
            }
        }
        return false
    }

    // فتح نافذة طلب تعطيل قيود توفير البطارية
    private fun requestBatteryOptimizationExemption() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                    data = Uri.parse("package:$packageName")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
            }
        }
    }
}
