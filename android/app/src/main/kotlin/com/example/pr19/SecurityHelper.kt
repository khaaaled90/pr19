package com.example.pr19

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
}