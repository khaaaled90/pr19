package com.app.cardpay

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

class NativeSecureStorage(context: Context) {

    private val sharedPreferences: SharedPreferences? by lazy {
        try {
            val masterKey = MasterKey.Builder(context)
                .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                .build()

            EncryptedSharedPreferences.create(
                context,
                "FlutterEncryptedStorage", // اسم ملف التخزين لـ flutter_secure_storage
                masterKey,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
            )
        } catch (e: Exception) {
            Log.e("NativeSecureStorage", "❌ فشل فتح EncryptedSharedPreferences: ${e.message}")
            null
        }
    }

    private val keyPrefix = "VGhpcyBpcyB0aGUga2V5IGZvciBhIHNlY3VyZSBzdG9yYWdl"

    /**
     * دالة ذكية لمطابقة المفاتيح:
     * تبحث أولاً برمز المفتاح المباشر (Direct Key)، 
     * وإذا لم تجده تبحث بالمفتاح مع البادئة (Prefixed Key)
     */
    fun getStringValue(key: String, defaultValue: String = ""): String {
        val prefs = sharedPreferences ?: return defaultValue
        
        // 1. تجربة قراءة المفتاح المباشر
        if (prefs.contains(key)) {
            val directValue = prefs.getString(key, null)
            if (directValue != null) return directValue
        }

        // 2. تجربة قراءة المفتاح مع البادئة
        val prefixedKey = "${keyPrefix}_$key"
        if (prefs.contains(prefixedKey)) {
            val prefixedValue = prefs.getString(prefixedKey, null)
            if (prefixedValue != null) return prefixedValue
        }

        return defaultValue
    }

    /**
     * دالة ذكية لكتابة المفاتيح:
     * تحدّث المفتاح الموجود حالياً سواء كان ببادئة أو بدون، 
     * وإذا لم يكن موجوداً تحفظه بالمفتاح المباشر.
     */
    /*fun putStringValue(key: String, value: String) {
        val prefs = sharedPreferences ?: return
        val editor = prefs.edit()

        val prefixedKey = "${keyPrefix}_$key"

        if (prefs.contains(prefixedKey)) {
            editor.putString(prefixedKey, value)
        } else {
            editor.putString(key, value)
        }
        
        editor.apply()
    }*/
    private fun putStringValue(key: String, value: String): Boolean {
        val prefs = sharedPreferences ?: return false
        val editor = prefs.edit()

        val prefixedKey = "${keyPrefix}_$key"

        if (prefs.contains(prefixedKey)) {
            editor.putString(prefixedKey, value)
        } else {
            editor.putString(key, value)
        }

        return editor.commit() // 👈 تم الاستبدال هنا
    }

    // 🟢 1. معرف الجهاز
    fun getDeviceId(): String = getStringValue("device_id", "")

    // 🟢 2. حالة الترخيص
    @Synchronized
    fun isLicenseValid(): Boolean {
        val rawValue = getStringValue("is_license_valid", "true")
        return rawValue.toBooleanStrictOrNull() ?: true
    }

    @Synchronized
    fun setLicenseValid(isValid: Boolean) {
        putStringValue("is_license_valid", isValid.toString())
        Log.d("NativeSecureStorage", "✅ تم تحديث حالة الترخيص إلى: $isValid")
    }

    // 🟢 3. عدد القسائم المستهلكة
    @Synchronized
    fun getVouchersUsed(): Int {
        val rawValue = getStringValue("vouchers_used", "0")
        return rawValue.toIntOrNull() ?: 0
    }

    // 🟢 4. حد القسائم المتاحة (-1 تعني لا يوجد حد)
    @Synchronized
    fun getVouchersLimit(): Int {
        val rawValue = getStringValue("vouchers_limit", "-1")
        return rawValue.toIntOrNull() ?: -1
    }

    // 🟢 5. زيادة العداد بمقدار 1 مع تفعيل علم المزامنة
    @Synchronized
    fun incrementVouchersUsed() {
        val current = getVouchersUsed()
        val next = current + 1

        putStringValue("vouchers_used", next.toString())
        setNeedsSync(true)

        Log.d("NativeSecureStorage", "✅ تم تحديث العداد من Kotlin إلى: $next")
    }

    // 🟢 6. علم المزامنة (needs_sync)
    @Synchronized
    fun getNeedsSync(): Boolean {
        val rawValue = getStringValue("needs_sync", "false")
        return rawValue.toBooleanStrictOrNull() ?: false
    }

    @Synchronized
    fun setNeedsSync(needsSync: Boolean) {
        putStringValue("needs_sync", needsSync.toString())
    }

    // 🟢 7. التحقق من وصول الحد المسموح
    @Synchronized
    fun isLimitReached(): Boolean {
        val limit = getVouchersLimit()
        if (limit == -1) return false
        val used = getVouchersUsed()
        return used >= limit
    }
}

/*package com.app.cardpay

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

class NativeSecureStorage(context: Context) {

    private val sharedPreferences: SharedPreferences? by lazy {
        try {
            val masterKey = MasterKey.Builder(context)
                .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                .build()

            EncryptedSharedPreferences.create(
                context,
                "FlutterEncryptedStorage", // اسم ملف التخزين لـ flutter_secure_storage
                masterKey,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
            )
        } catch (e: Exception) {
            Log.e("NativeSecureStorage", "❌ فشل فتح EncryptedSharedPreferences: ${e.message}")
            null
        }
    }

    private val keyPrefix = "VGhpcyBpcyB0aGUga2V5IGZvciBhIHNlY3VyZSBzdG9yYWdl"

    /**
     * دالة ذكية لمطابقة المفاتيح:
     * تبحث أولاً برمز المفتاح المباشر (Direct Key)، 
     * وإذا لم تجده تبحث بالمفتاح مع البادئة (Prefixed Key)
     */
    private fun getStringValue(key: String, defaultValue: String): String {
        val prefs = sharedPreferences ?: return defaultValue
        
        // 1. تجربة قراءة المفتاح المباشر
        if (prefs.contains(key)) {
            val directValue = prefs.getString(key, null)
            if (directValue != null) return directValue
        }

        // 2. تجربة قراءة المفتاح مع البادئة
        val prefixedKey = "${keyPrefix}_$key"
        if (prefs.contains(prefixedKey)) {
            val prefixedValue = prefs.getString(prefixedKey, null)
            if (prefixedValue != null) return prefixedValue
        }

        return defaultValue
    }

    /**
     * دالة ذكية لكتابة المفاتيح:
     * تحدّث المفتاح الموجود حالياً سواء كان ببادئة أو بدون، 
     * وإذا لم يكن موجوداً تحفظه بالمفتاح المباشر.
     */
    private fun putStringValue(key: String, value: String): Boolean {
    val prefs = sharedPreferences ?: return false
    val editor = prefs.edit()

    val prefixedKey = "${keyPrefix}_$key"

    if (prefs.contains(prefixedKey)) {
        editor.putString(prefixedKey, value)
    } else {
        editor.putString(key, value)
    }

    return editor.commit() // 👈 استبدال apply() بـ commit() وإرجاع النتيجة
}
    /*private fun putStringValue(key: String, value: String) {
        val prefs = sharedPreferences ?: return
        val editor = prefs.edit()

        val prefixedKey = "${keyPrefix}_$key"

        if (prefs.contains(prefixedKey)) {
            editor.putString(prefixedKey, value)
        } else {
            editor.putString(key, value)
        }
        
        editor.apply()
    }*/

    // 🟢 1. التحقق من صلاحية الترخيص
    fun isLicenseValid(): Boolean {
        val rawValue = getStringValue("is_license_valid", "true")
        return rawValue.toBooleanStrictOrNull() ?: true
    }

    // 🟢 2. حفظ/تحديث حالة الترخيص
    fun setLicenseValid(isValid: Boolean) {
        putStringValue("is_license_valid", isValid.toString())
        Log.d("NativeSecureStorage", "✅ تم تحديث حالة الترخيص إلى: $isValid")
    }

    // 🟢 3. قراءة عدد القسائم المستهلكة
    fun getVouchersUsed(): Int {
        val rawValue = getStringValue("vouchers_used", "0")
        return rawValue.toIntOrNull() ?: 0
    }

    // 🟢 4. قراءة حد القسائم المتاحة
    fun getVouchersLimit(): Int {
        val rawValue = getStringValue("vouchers_limit", "-1")
        return rawValue.toIntOrNull() ?: -1
    }

    // 🟢 5. زيادة العداد بمقدار 1 من Kotlin مباشرة
    fun incrementVouchersUsed() {
        val current = getVouchersUsed()
        val next = current + 1

        putStringValue("vouchers_used", next.toString())
        putStringValue("needs_sync", "true")

        Log.d("NativeSecureStorage", "✅ تم تحديث العداد من Kotlin إلى: $next")
    }

    // 🟢 6. التحقق من وصول الحد المسموح
    fun isLimitReached(): Boolean {
        val limit = getVouchersLimit()
        if (limit == -1) return false
        val used = getVouchersUsed()
        return used >= limit
    }
    
}*/
/*package com.app.cardpay

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

class NativeSecureStorage(context: Context) {

    private val sharedPreferences: SharedPreferences? by lazy {
        try {
            val masterKey = MasterKey.Builder(context)
                .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                .build()

            EncryptedSharedPreferences.create(
                context,
                "FlutterEncryptedStorage", // اسم ملف التخزين الافتراضي لـ flutter_secure_storage
                masterKey,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
            )
        } catch (e: Exception) {
            Log.e("NativeSecureStorage", "❌ فشل فتح EncryptedSharedPreferences: ${e.message}")
            null
        }
    }

    // البادئة الافتراضية لمكتبة flutter_secure_storage
    private val keyPrefix = "VGhpcyBpcyB0aGUga2V5IGZvciBhIHNlY3VyZSBzdG9yYWdl"

    private fun getFullKey(key: String): String {
        return "${keyPrefix}_$key"
    }

    // 🟢 1. التحقق من صلاحية الترخيص (معدلة لاستخدام sharedPreferences المشفّرة وبادئة Flutter)
    fun isLicenseValid(): Boolean {
        val prefs = sharedPreferences ?: return true
        val rawValue = prefs.getString(getFullKey("is_license_valid"), "true")
        return rawValue?.toBooleanStrictOrNull() ?: true
    }

    // 🟢 2. حفظ/تحديث حالة الترخيص (معدلة لتنسجم مع flutter_secure_storage)
    fun setLicenseValid(isValid: Boolean) {
        val prefs = sharedPreferences ?: return
        prefs.edit()
            .putString(getFullKey("is_license_valid"), isValid.toString())
            .apply()
        Log.d("NativeSecureStorage", "✅ تم تحديث حالة الترخيص إلى: $isValid")
    }

    // 3. قراءة عدد القسائم المستهلكة
    fun getVouchersUsed(): Int {
        val prefs = sharedPreferences ?: return 0
        val rawValue = prefs.getString(getFullKey("vouchers_used"), "0")
        return rawValue?.toIntOrNull() ?: 0
    }

    // 4. قراءة حد القسائم المتاحة
    fun getVouchersLimit(): Int {
        val prefs = sharedPreferences ?: return -1
        val rawValue = prefs.getString(getFullKey("vouchers_limit"), "-1")
        return rawValue?.toIntOrNull() ?: -1
    }

    // 5. زيادة العداد بمقدار 1 مباشرة من Kotlin
    fun incrementVouchersUsed() {
        val prefs = sharedPreferences ?: return
        val current = getVouchersUsed()
        val next = current + 1
        
        prefs.edit()
            .putString(getFullKey("vouchers_used"), next.toString())
            .putString(getFullKey("needs_sync"), "true") // علم المزامنة ليقرأه SyncManager في Flutter
            .apply()
            
        Log.d("NativeSecureStorage", "✅ تم تحديث العداد من Kotlin: $next")
    }

    // 6. التحقق من صلاحية الحد مباشرة قبل تنفيذ أي رد آلي
    fun isLimitReached(): Boolean {
        val limit = getVouchersLimit()
        if (limit == -1) return false // ترخيص غير محدود
        val used = getVouchersUsed()
        return used >= limit
    }
}*/

/*package com.app.cardpay // استبدل بـ package التطبيق لديك

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

class NativeSecureStorage(context: Context) {

    private val sharedPreferences: SharedPreferences? by lazy {
        try {
            val masterKey = MasterKey.Builder(context)
                .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                .build()

            EncryptedSharedPreferences.create(
                context,
                "FlutterEncryptedStorage", // اسم ملف التخزين الافتراضي لـ flutter_secure_storage
                masterKey,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
            )
        } catch (e: Exception) {
            Log.e("NativeSecureStorage", "❌ فشل فتح EncryptedSharedPreferences: ${e.message}")
            null
        }
    }

    // البادئة الافتراضية لمكتبة flutter_secure_storage
    private val keyPrefix = "VGhpcyBpcyB0aGUga2V5IGZvciBhIHNlY3VyZSBzdG9yYWdl"

    fun isLicenseValid(): Boolean {
        return prefs.getBoolean("is_license_valid", true) // القيمة الافتراضية true أو حسب منطقك
    }

    // 🟢 2. حفظ/تحديث حالة الترخيص
    fun setLicenseValid(isValid: Boolean) {
        prefs.edit().putBoolean("is_license_valid", isValid).apply()
    }

    private fun getFullKey(key: String): String {
        return "${keyPrefix}_$key"
    }

    // 1. قراءة عدد القسائم المستهلكة
    fun getVouchersUsed(): Int {
        val prefs = sharedPreferences ?: return 0
        val rawValue = prefs.getString(getFullKey("vouchers_used"), "0")
        return rawValue?.toIntOrNull() ?: 0
    }

    // 2. قراءة حد القسائم المتاحة
    fun getVouchersLimit(): Int {
        val prefs = sharedPreferences ?: return -1
        val rawValue = prefs.getString(getFullKey("vouchers_limit"), "-1")
        return rawValue?.toIntOrNull() ?: -1
    }

    // 3. زيادة العداد بمقدار 1 مباشرة من Kotlin
    fun incrementVouchersUsed() {
        val prefs = sharedPreferences ?: return
        val current = getVouchersUsed()
        val next = current + 1
        
        prefs.edit()
            .putString(getFullKey("vouchers_used"), next.toString())
            .putString(getFullKey("needs_sync"), "true") // علم المزامنة ليقرأه SyncManager في Flutter
            .apply()
            
        Log.d("NativeSecureStorage", "✅ تم تحديث العداد من Kotlin: $next")
    }

    // 4. التحقق من صلاحية الحد مباشرة قبل تنفيذ أي رد آلي
    fun isLimitReached(): Boolean {
        val limit = getVouchersLimit()
        if (limit == -1) return false // ترخيص غير محدود
        val used = getVouchersUsed()
        return used >= limit
    }
}*/