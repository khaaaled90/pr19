package com.example.pr19

import android.content.Context

object AppCache {
    @Volatile private var cachedKeywords: List<Map<String, Any>>? = null
    @Volatile private var serviceEnabled: Boolean? = null
    @Volatile private var allowAllSenders: Boolean? = null
    @Volatile private var defaultReply: String? = null
    
    // ✅ 1. خريطة المعرفات: المفتاح هو المعرف/الاسم المفحوص، والقيمة هي رقم الهاتف
    @Volatile private var clientIdentifiers: Map<String, String>? = null

    fun getKeywords(dbHelper: AppSqliteHelper): List<Map<String, Any>> {
        return cachedKeywords ?: synchronized(this) {
            cachedKeywords ?: dbHelper.getAllActiveKeywords().also { cachedKeywords = it }
        }
    }

    fun isServiceEnabled(dbHelper: AppSqliteHelper): Boolean {
        return serviceEnabled ?: synchronized(this) {
            serviceEnabled ?: (dbHelper.getSetting("service_enabled", "true") == "true").also { serviceEnabled = it }
        }
    }

    fun isAllowAllSenders(dbHelper: AppSqliteHelper): Boolean {
        return allowAllSenders ?: synchronized(this) {
            allowAllSenders ?: (dbHelper.getSetting("allow_all_senders", "false") == "true").also { allowAllSenders = it }
        }
    }

    fun getDefaultReply(dbHelper: AppSqliteHelper): String {
        return defaultReply ?: synchronized(this) {
            defaultReply ?: dbHelper.getSetting("default_reply", "شكراً لتواصلك. رقمك الخاص هو: ").also { defaultReply = it }
        }
    }

    // ✅ 2. جلب جميع المعرفات من قاعدة البيانات عند أول طلب
    fun getClientIdentifiers(dbHelper: AppSqliteHelper): Map<String, String> {
        return clientIdentifiers ?: synchronized(this) {
            clientIdentifiers ?: dbHelper.getAllClientIdentifiers().also { clientIdentifiers = it }
        }
    }

    // ✅ 3. دالة سريعة للبحث عن رقم العميل بواسطة المعرف/الاسم
    fun findPhoneByIdentifier(dbHelper: AppSqliteHelper, rawIdentifier: String): String? {
        val cleanKey = normalizeText(rawIdentifier)
        val map = getClientIdentifiers(dbHelper)
        return map[cleanKey]
    }

    // ✅ 4. دالة لتحديث الكاش فورياً عند ربط معاملة معلقة جديدة
    @Synchronized
    fun updateIdentifierCache(rawIdentifier: String, phone: String) {
        val cleanKey = normalizeText(rawIdentifier)
        val currentMap = clientIdentifiers?.toMutableMap() ?: mutableMapOf()
        currentMap[cleanKey] = phone
        clientIdentifiers = currentMap
    }

    // ✅ 5. دالة تنظيف وتوحيد الحروف لتسهيل المطابقة (إزالة المسافات والهمزات)
    private fun normalizeText(text: String): String {
        return text.trim()
            .replace(Regex("[أإآ]"), "ا")
            .replace("ة", "ه")
            .replace(Regex("\\s+"), " ")
            .lowercase()
    }

    @Synchronized
    fun clearCache() {
        cachedKeywords = null
        serviceEnabled = null
        allowAllSenders = null
        defaultReply = null
        clientIdentifiers = null // ✅ تفريغ كاش المعرفات أيضاً
    }
}
/*package com.example.pr19

import android.content.Context

object AppCache {
    @Volatile private var cachedKeywords: List<Map<String, Any>>? = null
    @Volatile private var serviceEnabled: Boolean? = null
    @Volatile private var allowAllSenders: Boolean? = null
    @Volatile private var defaultReply: String? = null

    fun getKeywords(dbHelper: AppSqliteHelper): List<Map<String, Any>> {
        return cachedKeywords ?: synchronized(this) {
            cachedKeywords ?: dbHelper.getAllActiveKeywords().also { cachedKeywords = it }
        }
    }

    fun isServiceEnabled(dbHelper: AppSqliteHelper): Boolean {
        return serviceEnabled ?: synchronized(this) {
            serviceEnabled ?: (dbHelper.getSetting("service_enabled", "true") == "true").also { serviceEnabled = it }
        }
    }

    fun isAllowAllSenders(dbHelper: AppSqliteHelper): Boolean {
        return allowAllSenders ?: synchronized(this) {
            allowAllSenders ?: (dbHelper.getSetting("allow_all_senders", "false") == "true").also { allowAllSenders = it }
        }
    }

    fun getDefaultReply(dbHelper: AppSqliteHelper): String {
        return defaultReply ?: synchronized(this) {
            defaultReply ?: dbHelper.getSetting("default_reply", "شكراً لتواصلك. رقمك الخاص هو: ").also { defaultReply = it }
        }
    }

    @Synchronized
    fun clearCache() {
        cachedKeywords = null
        serviceEnabled = null
        allowAllSenders = null
        defaultReply = null
    }
}*/