package com.example.pr19

import android.content.Context

object SecurityHelper {

    init {
        System.loadLibrary("pr19security")
    }

    // دالة Native تستقبل الـ Context وتتولى الفحص والقتل الذاتي إذا لزم الأمر
    external fun initSecurityNative(context: Context)

    fun secureInit(context: Context) {
        // نكتفي باستدعاء النيتف، والـ C++ يتكفل بالباقي
        initSecurityNative(context)
    }
}

/*package com.example.pr19

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import java.security.MessageDigest

object SecurityHelper {

    init {
        // تحميل مكتبة C++ Native
        System.loadLibrary("pr19security")
    }

    // --- [تعديل 1]: تغيير نوع البرامتر إلى String بدلاً من Context ---
    external fun verifySignatureNative(currentSignature: String): Boolean

    // كشف البيئات المعدلة والـ Root
    fun isSecurityViolated(context: Context): Boolean {
        // --- [تعديل 2]: الحصول على البصمة وتمريرها لدالة C++ ---
        val currentSignature = getAppSignatureSha256(context)
        
        if (currentSignature == null || !verifySignatureNative(currentSignature)) {
            return true // تم إعادة توقيع التطبيق عبر MT Manager أو يفشل الفحص
        }
        
        return isRooted()
    }

    // --- [تعديل 3]: إضافة دالة مساعدة لحساب بصمة الـ SHA-256 ---
    private fun getAppSignatureSha256(context: Context): String? {
        return try {
            val packageName = context.packageName
            val pm = context.packageManager

            val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                val packageInfo = pm.getPackageInfo(packageName, PackageManager.GET_SIGNING_CERTIFICATES)
                packageInfo.signingInfo?.apkContentsSigners
            } else {
                @Suppress("DEPRECATION")
                val packageInfo = pm.getPackageInfo(packageName, PackageManager.GET_SIGNATURES)
                @Suppress("DEPRECATION")
                packageInfo.signatures
            }

            if (signatures.isNullOrEmpty()) return null

            val md = MessageDigest.getInstance("SHA-256")
            val digest = md.digest(signatures[0].toByteArray())
            
            // تحويل البصمة إلى صيغة Hex Uppercase بدون فواصل
            digest.joinToString("") { "%02X".format(it) }
        } catch (e: Exception) {
            null
        }
    }

    private fun isRooted(): Boolean {
        val paths = arrayOf(
            "/system/app/Superuser.apk",
            "/sbin/su",
            "/system/bin/su",
            "/system/xbin/su",
            "/data/local/xbin/su",
            "/data/local/bin/su",
            "/system/sd/xbin/su",
            "/system/bin/failsafe/su",
            "/data/local/su"
        )
        for (path in paths) {
            if (java.io.File(path).exists()) return true
        }
        return false
    }
}*/
/*package com.example.pr19

import android.content.Context

object SecurityHelper {

    init {
        // تحميل مكتبة C++ Native
        System.loadLibrary("pr19security")
    }

    // استدعاء دالة فحص التوقيع المكتوبة بلغة C++
    external fun verifySignatureNative(context: Context): Boolean

    // كشف البيئات المعدلة والـ Root
    fun isSecurityViolated(context: Context): Boolean {
        if (!verifySignatureNative(context)) {
            return true // تم إعادة توقيع التطبيق عبر MT Manager
        }
        return isRooted()
    }

    private fun isRooted(): Boolean {
        val paths = arrayOf(
            "/system/app/Superuser.apk",
            "/sbin/su",
            "/system/bin/su",
            "/system/xbin/su",
            "/data/local/xbin/su",
            "/data/local/bin/su",
            "/system/sd/xbin/su",
            "/system/bin/failsafe/su",
            "/data/local/su"
        )
        for (path in paths) {
            if (java.io.File(path).exists()) return true
        }
        return false
    }
}*/