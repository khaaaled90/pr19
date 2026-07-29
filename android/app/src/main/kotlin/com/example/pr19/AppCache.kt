package com.example.pr19

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
}