package com.example.pr19

import android.content.ComponentName
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
import android.util.Log

class MainActivity: FlutterActivity() {

    companion object {
        private const val CONTROL_CHANNEL = "com.example.pr19/native_control"
        private const val SMS_CHANNEL = "com.example.app/sms" // قناة إرسال القسائم عبر SMS
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val messenger = flutterEngine.dartExecutor.binaryMessenger
        
        // 1. قناة التحكم بالأذونات واستثناء البطارية وتفريغ الـ Cache والبدء التلقائي
        MethodChannel(messenger, CONTROL_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {

                // 🎯 تسجيل وتحديث العميل والـ AppCache
                "registerCustomer" -> {
                    val phone = call.argument<String>("phone") ?: ""
                    val name = call.argument<String>("name")
                    val wallet = call.argument<String>("wallet")
                    val balance = call.argument<String>("balance") ?: ""

                    if (phone.isNotBlank()) {
                        try {
                            AppSqliteHelper.getInstance(applicationContext).updateCustomerBalance(
                                phone = phone,
                                newBalance = balance,
                                name = name,
                                walletNumber = wallet
                            )
                            result.success(true)
                        } catch (e: Exception) {
                            Log.e("CLIENT_CACHE", "Error in registerCustomer: ${e.message}", e)
                            result.error("REGISTER_FAILED", e.localizedMessage, null)
                        }
                    } else {
                        result.error("INVALID_PHONE", "رقم الهاتف فارغ", null)
                    }
                }

                // طلب إذن استماع الإشعارات للمحافظ
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

                // التحقق من حالة إذن الإشعارات
                "isNotificationListenerGranted" -> {
                    result.success(isNotificationServiceEnabled())
                }

                // طلب استثناء البطارية (Doze Mode Bypass)
                "requestIgnoreBatteryOptimizations" -> {
                    requestBatteryOptimizationExemption()
                    result.success(true)
                }

                // التحقق من حالة استثناء البطارية
                "isIgnoringBatteryOptimizations" -> {
                    result.success(isIgnoringBatteryOptimizations())
                }

                // 🎯 فتح إعدادات التشغيل التلقائي / معلومات التطبيق (Auto-Start / App Info)
                "openAutoStartSettings" -> {
                    try {
                        val intent = Intent().apply {
                            action = Settings.ACTION_APPLICATION_DETAILS_SETTINGS
                            data = Uri.fromParts("package", packageName, null)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("PERMISSIONS", "Error opening auto start settings: ${e.message}", e)
                        result.error("ERR", e.message, null)
                    }
                }

                // تفريغ الذاكرة المؤقتة (Clear AppCache) عند التعديل في Flutter
                "clearCache" -> {
                    try {
                        Log.e("CLIENT_CACHE", "******** clearCache() CALLED ********")
                        AppCache.clearCache()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("CACHE_CLEAR_FAILED", e.localizedMessage, null)
                    }
                }

                // فحص وتنبيه مدير المخزون عند القسائم المفرغة
                "checkAndSendManagerAlert" -> {
                    val keywordId = call.argument<Int>("keywordId") ?: 0
                    val keywordText = call.argument<String>("keywordText") ?: ""

                    try {
                        val dbHelper = AppSqliteHelper.getInstance(applicationContext)
                        
                        ProcessMessageProcessor.checkAndSendManagerAlert(
                            context = applicationContext,
                            dbHelper = dbHelper,
                            keywordId = keywordId,
                            keywordText = keywordText
                        )
                        
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("STOCK_ALERT", "خطأ في استدعاء تنبيه المخزون: ${e.message}", e)
                        result.error("ALERT_FAILED", e.localizedMessage, null)
                    }
                }

                "warmupCache" -> {
                    try {
                        val dbHelper = AppSqliteHelper.getInstance(applicationContext)
                        Thread {
                            AppCache.warmupCache(dbHelper)
                        }.start()
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("CLIENT_CACHE", "Error in warmupCache: ${e.message}")
                        result.error("WARMUP_FAILED", e.localizedMessage, null)
                    }
                }

                "disableLicense" -> {
                    LicenseManager.stopAllBackgroundWork(applicationContext)
                    result.success(true)
                }

                "enableLicense" -> {
                    LicenseManager.enableBackgroundWork(applicationContext)
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
                        val secureStorage = NativeSecureStorage(this)

                        // التحقق من الحد قبل المحاولة
                        if (secureStorage.isLimitReached()) {
                            result.error("LIMIT_REACHED", "تم الوصول للحد الأقصى للقسائم", null)
                            return@setMethodCallHandler
                        }

                        val isSent = sendNativeSms(phone, message)
                        if (isSent) {
                            secureStorage.incrementVouchersUsed()
                            result.success(true)
                        } else {
                            result.success(false)
                        }
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
    private fun sendNativeSms(phone: String, message: String): Boolean {
        return try {
            val smsManager: SmsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                this.getSystemService(SmsManager::class.java)
            } else {
                @Suppress("DEPRECATION")
                SmsManager.getDefault()
            }

            val parts = smsManager.divideMessage(message)
            if (parts.size > 1) {
                smsManager.sendMultipartTextMessage(phone, null, parts, null, null)
            } else {
                smsManager.sendTextMessage(phone, null, message, null, null)
            }
            true
        } catch (e: Exception) {
            Log.e("SMS_SEND", "Failed to send SMS: ${e.message}", e)
            false
        }
    }

    // التحقق الدقيق مما إذا كانت خدمة قراءة الإشعارات مفعلة للتطبيق
    private fun isNotificationServiceEnabled(): Boolean {
        val pkgName = packageName
        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
        if (!flat.isNullOrEmpty()) {
            val names = flat.split(":")
            for (name in names) {
                val componentName = ComponentName.unflattenFromString(name)
                if (componentName != null && componentName.packageName == pkgName) {
                    return true
                }
            }
        }
        return false
    }

    // التحقق من أن التطبيق مستثنى من توفير البطارية
    private fun isIgnoringBatteryOptimizations(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            pm.isIgnoringBatteryOptimizations(packageName)
        } else {
            true
        }
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

/************************/
/*package com.example.pr19

import android.content.ComponentName
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
import android.util.Log


class MainActivity: FlutterActivity() {

    companion object {
        private const val CONTROL_CHANNEL = "com.example.pr19/native_control"
        private const val SMS_CHANNEL = "com.example.app/sms" // قناة إرسال القسائم عبر SMS
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val messenger = flutterEngine.dartExecutor.binaryMessenger
        
        // 1. قناة التحكم بالأذونات واستثناء البطارية وتفريغ الـ Cache
        MethodChannel(messenger, CONTROL_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {

                // 🎯 تسجيل وتحديث العميل والـ AppCache
                "registerCustomer" -> {
                    val phone = call.argument<String>("phone") ?: ""
                    val name = call.argument<String>("name")
                    val wallet = call.argument<String>("wallet")
                    val balance = call.argument<String>("balance") ?: ""

                    if (phone.isNotBlank()) {
                        try {
                            AppSqliteHelper.getInstance(applicationContext).updateCustomerBalance(
                                phone = phone,
                                newBalance = balance,
                                name = name,
                                walletNumber = wallet
                            )
                            result.success(true)
                        } catch (e: Exception) {
                            Log.e("CLIENT_CACHE", "Error in registerCustomer: ${e.message}", e)
                            result.error("REGISTER_FAILED", e.localizedMessage, null)
                        }
                    } else {
                        result.error("INVALID_PHONE", "رقم الهاتف فارغ", null)
                    }
                }
                // طلب إذن استماع الإشعارات للمحافظ
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

                // التحقق من حالة إذن الإشعارات
                "isNotificationListenerGranted" -> {
                    result.success(isNotificationServiceEnabled())
                }

                // طلب استثناء البطارية (Doze Mode Bypass)
                "requestIgnoreBatteryOptimizations" -> {
                    requestBatteryOptimizationExemption()
                    result.success(true)
                }

                // التحقق من حالة استثناء البطارية
                "isIgnoringBatteryOptimizations" -> {
                    result.success(isIgnoringBatteryOptimizations())
                }

                // تفريغ الذاكرة المؤقتة (Clear AppCache) عند التعديل في Flutter
                "clearCache" -> {
                    try {
                        Log.e("CLIENT_CACHE", "******** clearCache() CALLED ********")
                        // ✅ تم التعديل هنا واستدعاء clearCache() بدلاً من clear()
                        AppCache.clearCache()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("CACHE_CLEAR_FAILED", e.localizedMessage, null)
                    }
                }

                // ✅ الكود المصحح والمستقر:
                "checkAndSendManagerAlert" -> {
                    val keywordId = call.argument<Int>("keywordId") ?: 0
                    val keywordText = call.argument<String>("keywordText") ?: ""

                    try {
                        val dbHelper = AppSqliteHelper.getInstance(applicationContext)
                        
                        // 🎯 الاستدعاء المباشر عن طريق اسم الـ object
                        ProcessMessageProcessor.checkAndSendManagerAlert(
                            context = applicationContext,
                            dbHelper = dbHelper,
                            keywordId = keywordId,
                            keywordText = keywordText
                        )
                        
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("STOCK_ALERT", "خطأ في استدعاء تنبيه المخزون: ${e.message}", e)
                        result.error("ALERT_FAILED", e.localizedMessage, null)
                    }
                }
                // ✅ الكود المصحح والمستقر:
                /*"checkAndSendManagerAlert" -> {
                    val keywordId = call.argument<Int>("keywordId") ?: 0
                    val keywordText = call.argument<String>("keywordText") ?: ""

                    try {
                        val dbHelper = AppSqliteHelper.getInstance(applicationContext)
                        checkAndSendManagerAlert(
                            context = applicationContext,
                            dbHelper = dbHelper,
                            keywordId = keywordId,
                            keywordText = keywordText
                        )
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("STOCK_ALERT", "خطأ في استدعاء تنبيه المخزون: ${e.message}", e)
                        result.error("ALERT_FAILED", e.localizedMessage, null)
                    }
                }*/
                    
                /*"checkAndSendManagerAlert" -> {
                    val keywordId = call.argument<Int>("keywordId") ?: 0
                    val keywordText = call.argument<String>("keywordText") ?: ""

                    // 🎯 استدعاء دالتك الجاهزة مباشرة
                    checkAndSendManagerAlert(context, dbHelper, keywordId, keywordText)
                    result.success(true)
                }*/

                "warmupCache" -> {
                    try {
                        val dbHelper = AppSqliteHelper.getInstance(applicationContext)
                        // تشغيل التحميل في Thread خلفي كي لا يؤثر على سرعة فتح الواجهة
                        Thread {
                            AppCache.warmupCache(dbHelper)
                        }.start()
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("CLIENT_CACHE", "Error in warmupCache: ${e.message}")
                        result.error("WARMUP_FAILED", e.localizedMessage, null)
                    }
                }

                "disableLicense" -> {
                    LicenseManager.stopAllBackgroundWork(applicationContext)
                    result.success(true)
                }

                "enableLicense" -> {
                    LicenseManager.enableBackgroundWork(applicationContext)
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

                        val secureStorage = NativeSecureStorage(this)

                    // 1. التحقق من الحد قبل المحاولة
                    if (secureStorage.isLimitReached()) {
                        result.error("LIMIT_REACHED", "تم الوصول للحد الأقصى للقسائم", null)
                        return@setMethodCallHandler
                    }
                        val isSent = sendNativeSms(phone, message)
                        if (isSent) {
                            // 🟢 المكان الأفضل: الزيادة المباشرة في التخزين المشفر من أندرويد
                            secureStorage.incrementVouchersUsed()
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                        //result.success(true)
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

    // دالة إرسال الـ SMS عبر نظام أندرويد (مُعدّلة ومُستقرّة لجميع الإصدارات بما فيها Android 12+)
    /*private fun sendNativeSms(phone: String, message: String) {
        val smsManager: SmsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            this.getSystemService(SmsManager::class.java)
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
    }*/

    private fun sendNativeSms(phone: String, message: String): Boolean {
        return try {
            val smsManager: SmsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                this.getSystemService(SmsManager::class.java)
            } else {
                @Suppress("DEPRECATION")
                SmsManager.getDefault()
            }

            val parts = smsManager.divideMessage(message)
            if (parts.size > 1) {
                smsManager.sendMultipartTextMessage(phone, null, parts, null, null)
            } else {
                smsManager.sendTextMessage(phone, null, message, null, null)
            }
            true
        } catch (e: Exception) {
            Log.e("SMS_SEND", "Failed to send SMS: ${e.message}", e)
            false
        }
    }

    // التحقق الدقيق مما إذا كانت خدمة قراءة الإشعارات مفعلة للتطبيق
    private fun isNotificationServiceEnabled(): Boolean {
        val pkgName = packageName
        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
        if (!flat.isNullOrEmpty()) {
            val names = flat.split(":")
            for (name in names) {
                val componentName = ComponentName.unflattenFromString(name)
                if (componentName != null && componentName.packageName == pkgName) {
                    return true
                }
            }
        }
        return false
    }

    // التحقق من أن التطبيق مستثنى من توفير البطارية
    private fun isIgnoringBatteryOptimizations(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            pm.isIgnoringBatteryOptimizations(packageName)
        } else {
            true
        }
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
}*/