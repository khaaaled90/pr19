package com.example.pr19

import android.os.Bundle
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

    // 🟢 1. تعريف كائن التخزين على مستوى النشاط
    private lateinit var secureStorage: NativeSecureStorage
    private var controlChannel: MethodChannel? = null
    private var smsChannel: MethodChannel? = null
    
    // 🟢 1. إضافة دالة onCreate للتحقق من أمان التطبيق فور إقلاعه وقبل تحميل Flutter
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // تشغيل نظام الأمان النيتف
        SecurityHelper.secureInit(applicationContext)
        // 🔒 فحص السلامة وتوقيع الـ APK
        //checkAppSecurity()
    }
    /*private fun checkAppSecurity() {
        try {
            if (SecurityHelper.isSecurityViolated(applicationContext)) {
                Log.e("SECURITY_VIOLATION", "🚨 تم كشف تلاعب بالتوقيع (MT Manager) أو بيئة رووت!")
                
                // 1. إيقاف جميع خدمات الخلفية فوراً
                LicenseManager.stopAllBackgroundWork(applicationContext)
                
                // 2. إنهاء العملية وقتل التطبيق في الذاكرة
                android.os.Process.killProcess(android.os.Process.myPid())
                System.exit(0)
            }
        } catch (e: Exception) {
            Log.e("SECURITY_VIOLATION", "خطأ أثناء فحص الأمان: ${e.message}")
            // في حال حدوث أي استثناء أثناء الفحص، نغلق التطبيق احتياطاً
            android.os.Process.killProcess(android.os.Process.myPid())
        }
    }*/
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // تشغيل نظام الأمان النيتف
        SecurityHelper.secureInit(applicationContext)
        
        // إعادة الفحص هنا أيضاً للزيادة في التأكيد
        //checkAppSecurity()

        // 🟢 2. تهيئة الكائن مرة واحدة فقط عند بدء تشغيل المحرك
        secureStorage = NativeSecureStorage(this)

        val messenger = flutterEngine.dartExecutor.binaryMessenger
        
        //controlChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.pr19/native_control")
        //smsChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.app/sms")
        
        // 1. قناة التحكم بالأذونات واستثناء البطارية وتفريغ الـ Cache والبدء التلقائي
        //MethodChannel(messenger, CONTROL_CHANNEL).setMethodCallHandler { call, result ->
            controlChannel = MethodChannel(messenger, CONTROL_CHANNEL).apply {
                setMethodCallHandler { call, result ->
                    when (call.method) {

                        "startForegroundService" -> {
                            CardPayForegroundService.start(this@MainActivity)
                            result.success(true)
                        }
                        "stopForegroundService" -> {
                            CardPayForegroundService.stop(this@MainActivity)
                            result.success(true)
                        }

                        // 🎯 عرض إشعار النظام عند إرسال القسيمة يدويًا من Flutter
                    "showVoucherNotification" -> {
                        val categoryName = call.argument<String>("categoryName") ?: ""
                        val phone = call.argument<String>("phone") ?: ""

                        try {
                            NotificationHelper.showVoucherSentNotification(applicationContext, categoryName, phone)
                            result.success(true)
                        } catch (e: Exception) {
                            Log.e("NOTIFICATION_ERROR", "فشل عرض إشعار القسيمة: ${e.message}", e)
                            result.error("NOTIFICATION_FAILED", e.localizedMessage, null)
                        }
                    }

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
                    /*"isNotificationListenerGranted" -> {
                        result.success(isNotificationServiceEnabled())
                    }*/

                    "isNotificationListenerGranted" -> {
                        val packageName = packageName
                        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
                        val isGranted = flat != null && flat.contains(packageName)
                        result.success(isGranted)
                    }
                    "openNotificationListenerSettings" -> {
                        try {
                            val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
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
                    
                    /*"openAutoStartSettings" -> {
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
                    }*/

                    "isAutoStartGranted" -> {
                        // فحص هل التطبيق مستثنى من تحسينات البطارية (Battery Optimization)
                        val pm = getSystemService(POWER_SERVICE) as PowerManager
                        val isIgnoring = pm.isIgnoringBatteryOptimizations(packageName)
                        result.success(isIgnoring)
                    }
                    "openAutoStartSettings" -> {
                        var opened = false
                        val packageName = packageName
                        // 2. محاولة فتح قائمة Auto-Start الخاصة بـ Xiaomi / Oppo / Vivo
                        val autoStartIntents = arrayOf(
                            Intent().setComponent(ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity")),
                            Intent().apply {
                                action = "miui.intent.action.OP_AUTO_START_BACKGROUND_SETTINGS"
                                addCategory(Intent.CATEGORY_DEFAULT)
                            },
                            Intent().setComponent(ComponentName("com.letv.android.letvsafe", "com.letv.android.letvsafe.AutobootManageActivity")),
                            Intent().setComponent(ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.optimize.process.ProtectActivity")),
                            Intent().setComponent(ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity")),
                            Intent().setComponent(ComponentName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"))
                        )

                        for (intent in autoStartIntents) {
                            try {
                                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                startActivity(intent)
                                opened = true
                                break
                            } catch (e: Exception) {
                                // تجربة الشاشة التالية إن لم تكن الواجهة متوفرة
                            }
                        }
                        
                        if (!opened) {
                            // 🔴 الكود المُضاف لخيار سامسونج (ضع هذا الجزء فقط في البداية):
                            val samsungIntents = arrayOf(
                                Intent().setComponent(ComponentName("com.samsung.android.looper", "com.samsung.android.sm.ui.battery.BackgroundLimitsActivity")),
                                Intent().setComponent(ComponentName("com.samsung.android.sm", "com.samsung.android.sm.ui.battery.BackgroundLimitsActivity")),
                                Intent().setComponent(ComponentName("com.samsung.android.looper", "com.samsung.android.sm.ui.battery.BatteryActivity")),
                                Intent().setComponent(ComponentName("com.samsung.android.sm", "com.samsung.android.sm.ui.battery.BatteryActivity")),
                                Intent().setComponent(ComponentName("com.samsung.android.sm_cn", "com.samsung.android.sm.ui.battery.BatteryActivity")),
                                Intent().setComponent(ComponentName("com.samsung.android.sm", "com.samsung.android.sm.root.SettingsActivity")),
                                Intent("android.intent.action.POWER_USAGE_SUMMARY")
                            )

                            for (intent in samsungIntents) {
                                try {
                                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                    startActivity(intent)
                                    opened = true
                                    break
                                } catch (e: Exception) {
                                    // تجربة الشاشة التالية
                                }
                            }
                            
                        }

                        // 3. إذا لم ينجح، افتح صفحة استثناء البطارية القياسية لأندرويد
                        if (!opened) {
                            try {
                                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                    data = Uri.parse("package:$packageName")
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(intent)
                            } catch (e: Exception) {
                                // fallback لشاشة إعدادات التطبيق العامة
                                val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                    data = Uri.parse("package:$packageName")
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(intent)
                            }
                        }
                        result.success(true)
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
        }

        // 2. قناة إرسال الرسائل النصية القادمة من Flutter
        //MethodChannel(messenger, SMS_CHANNEL).setMethodCallHandler { call, result ->
        smsChannel = MethodChannel(messenger, SMS_CHANNEL).apply {
            setMethodCallHandler { call, result ->
                if (call.method == "sendSms") {
                    val phone = call.argument<String>("phone") ?: call.argument<String>("address")
                    val message = call.argument<String>("message") ?: call.argument<String>("body")

                    /*if (!phone.isNullOrEmpty() && !message.isNullOrEmpty()) {
                        try {
                            // 🟢 حصر التحقق والإرسال والزيادة في قفل متزامن واحد
                            synchronized(this) {
                                if (secureStorage.isLimitReached()) {
                                    result.error("LIMIT_REACHED", "تم الوصول للحد الأقصى للقسائم", null)
                                    //return@setMethodCallHandler
                                }else{
                                    val isSent = sendNativeSms(phone, message)
                                    if (isSent) {
                                        secureStorage.incrementVouchersUsed()
                                        result.success(true)
                                    } else {
                                        result.success(false)
                                    }
                                }                            
                            }
                        } catch (e: Exception) {
                            result.error("SMS_FAILED", "فشل إرسال الرسالة: ${e.localizedMessage}", null)
                        }
                    }*/ 
                    if (!phone.isNullOrEmpty() && !message.isNullOrEmpty()) {
                        kotlin.concurrent.thread {
                            try {
                                synchronized(this@MainActivity) {
                                    if (secureStorage.isLimitReached()) {
                                        runOnUiThread { result.error("LIMIT_REACHED", "تم الوصول للحد الأقصى للقسائم", null) }
                                    } else {
                                        val isSent = sendNativeSms(phone, message)
                                        if (isSent) {
                                            secureStorage.incrementVouchersUsed()
                                            runOnUiThread { result.success(true) }
                                        } else {
                                            runOnUiThread { result.success(false) }
                                        }
                                    }
                                }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("SMS_FAILED", "فشل إرسال الرسالة: ${e.localizedMessage}", null) }
                            }
                        }
                    } else {
                        result.error("INVALID_ARGS", "رقم الهاتف أو نص الرسالة فارغ", null)
                    }
                } else {
                    result.notImplemented()
                }
            }
        }    
    }


    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        controlChannel?.setMethodCallHandler(null)
        smsChannel?.setMethodCallHandler(null)
        controlChannel = null
        smsChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
    /*override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        super.cleanUpFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        MethodChannel(messenger, CONTROL_CHANNEL).setMethodCallHandler(null)
        MethodChannel(messenger, SMS_CHANNEL).setMethodCallHandler(null)
    }*/

    private fun hasSmsPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            checkSelfPermission(android.Manifest.permission.SEND_SMS) == android.content.pm.PackageManager.PERMISSION_GRANTED
        } else {
            true
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

                // --- أضف هذا الفحص هنا ---
                if (!hasSmsPermission()) {
                    result.error("PERMISSION_DENIED", "إذن إرسال الرسائل النصية غير ممنوح", null)
                    return@setMethodCallHandler
                }

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