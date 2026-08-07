package com.example.pr19

import android.content.Context
import android.util.Log

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

    fun warmupCache(dbHelper: AppSqliteHelper) {
        synchronized(this) {
            Log.e("CLIENT_CACHE", ">>> 🚀 بدء تحميل الكاش تلقائياً...")

            // 1. تحميل الفئات والكلمات المفتاحية
            cachedKeywords = dbHelper.getAllActiveKeywords()

            // 2. تحميل الإعدادات
            serviceEnabled = (dbHelper.getSetting("service_enabled", "true") == "true")
            allowAllSenders = (dbHelper.getSetting("allow_all_senders", "false") == "true")
            defaultReply = dbHelper.getSetting("default_reply", "شكراً لتواصلك. رقمك الخاص هو: ")

            // 3. تحميل جميع العملاء والمعرفات مع تنقية المفاتيح (Normalization)
            val rawMap = dbHelper.getAllClientIdentifiers()
            val normalizedMap = mutableMapOf<String, String>()

            rawMap.forEach { (key, phone) ->
                val cleanKey = normalizeText(key)
                if (cleanKey.isNotEmpty() && phone.isNotEmpty()) {
                    normalizedMap[cleanKey] = phone
                }
            }

            clientIdentifiers = normalizedMap
            Log.e("CLIENT_CACHE", "✅ تم تحميل ${clientIdentifiers?.size ?: 0} عميل ومعرف إلى الكاش بنجاح!")
        }
    }

    fun getClientIdentifiers(dbHelper: AppSqliteHelper): Map<String, String> {
        Log.e("CLIENT_CACHE", ">>> ENTER getClientIdentifiers()")

        return clientIdentifiers ?: synchronized(this) {
            Log.e("CLIENT_CACHE", ">>> clientIdentifiers = $clientIdentifiers")

            clientIdentifiers ?: run {
                val rawMap = dbHelper.getAllClientIdentifiers()
                val normalizedMap = mutableMapOf<String, String>()
                rawMap.forEach { (key, phone) ->
                    val cleanKey = normalizeText(key)
                    if (cleanKey.isNotEmpty() && phone.isNotEmpty()) {
                        normalizedMap[cleanKey] = phone
                    }
                }
                Log.e("CLIENT_CACHE", ">>> Loaded ${normalizedMap.size} identifiers")
                normalizedMap.also { clientIdentifiers = it }
            }
        }
    }

    /*fun getClientIdentifiers(dbHelper: AppSqliteHelper): Map<String, String> {

        Log.e("CLIENT_CACHE", ">>> ENTER getClientIdentifiers()")

        return clientIdentifiers ?: synchronized(this) {

            Log.e("CLIENT_CACHE", ">>> clientIdentifiers = $clientIdentifiers")

            clientIdentifiers ?: dbHelper.getAllClientIdentifiers().also {

                Log.e("CLIENT_CACHE", ">>> Loaded ${it.size} identifiers")

                clientIdentifiers = it
            }
        }
    }*/
    /*
    // ✅ 2. جلب جميع المعرفات من قاعدة البيانات عند أول طلب
    fun getClientIdentifiers(dbHelper: AppSqliteHelper): Map<String, String> {
        return clientIdentifiers ?: synchronized(this) {
            clientIdentifiers ?: dbHelper.getAllClientIdentifiers().also { clientIdentifiers = it }
        }
    }
    */

    // ✅ 3. دالة سريعة للبحث عن رقم العميل بواسطة المعرف/الاسم
    fun findPhoneByIdentifier(dbHelper: AppSqliteHelper, rawIdentifier: String): String? {

        Log.e("CLIENT_CACHE", "findPhoneByIdentifier() called")

        val cleanKey = normalizeText(rawIdentifier)
        Log.e("CLIENT_CACHE", "Search Key = '$cleanKey' length=${cleanKey.length}")

        val map = getClientIdentifiers(dbHelper)

        Log.e("CLIENT_CACHE", "Cache Size = ${map.size}")
        Log.e("CLIENT_CACHE", "========== CACHE CONTENT ==========")

        map.forEach { (k, v) ->
            Log.e(
                "CLIENT_CACHE",
                "KEY='$k' length=${k.length}  ---> PHONE=$v"
            )
        }

        val phone = map[cleanKey]

        Log.e("CLIENT_CACHE", "Lookup Result = $phone")
        Log.e("CLIENT_CACHE", "Raw Identifier = '$rawIdentifier'")

        return phone
    }
    /*fun findPhoneByIdentifier(dbHelper: AppSqliteHelper, rawIdentifier: String): String? {
        
        Log.e("CLIENT_CACHE", "findPhoneByIdentifier() called")
        val cleanKey = normalizeText(rawIdentifier)
        Log.e("CLIENT_CACHE", "Search Key = '$cleanKey'")
        
        val map = getClientIdentifiers(dbHelper)
        Log.e("CLIENT_CACHE", "Cache Size = ${map.size}")
        
        val phone = map[cleanKey]
        Log.e("CLIENT_CACHE", "Result = $phone")

        Log.e(
            "CLIENT_CACHE",
            "findPhoneByIdentifier called with: $rawIdentifier"
        )
        return map[cleanKey]
    }*/

    // ✅ 4. دالة لتحديث الكاش فورياً عند ربط معاملة معلقة جديدة
    @Synchronized
    fun updateIdentifierCache(rawIdentifier: String, phone: String) {
        Log.e("CLIENT_CACHE", "updateIdentifierCache()")
        val cleanKey = normalizeText(rawIdentifier)
        Log.e("CLIENT_CACHE", "key=$cleanKey phone=$phone")
        val currentMap = clientIdentifiers?.toMutableMap() ?: mutableMapOf()
        Log.e("CLIENT_CACHE", "Before Size=${currentMap.size}")
        currentMap[cleanKey] = phone
        clientIdentifiers = currentMap
        Log.e("CLIENT_CACHE", "After Size=${clientIdentifiers?.size}")
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
    // 🟢 1. غيّر Any إلى Any?
    @Volatile private var cachedKeywords: List<Map<String, Any?>>? = null
    //@Volatile private var cachedKeywords: List<Map<String, Any>>? = null
    @Volatile private var serviceEnabled: Boolean? = null
    @Volatile private var allowAllSenders: Boolean? = null
    @Volatile private var defaultReply: String? = null

    // 🟢 2. غيّر Any إلى Any? في نوع الإرجاع
    fun getKeywords(dbHelper: AppSqliteHelper): List<Map<String, Any?>> {
        return cachedKeywords ?: synchronized(this) {
            cachedKeywords ?: dbHelper.getAllActiveKeywords().also { cachedKeywords = it }
        }
    }
    /*fun getKeywords(dbHelper: AppSqliteHelper): List<Map<String, Any>> {
        return cachedKeywords ?: synchronized(this) {
            cachedKeywords ?: dbHelper.getAllActiveKeywords().also { cachedKeywords = it }
        }
    }*/

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