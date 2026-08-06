package com.example.pr19

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
}

/*package com.example.pr19 // استبدل بـ package التطبيق لديك

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