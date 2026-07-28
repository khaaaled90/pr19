package com.example.pr19

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

class AppSqliteHelper(context: Context) : SQLiteOpenHelper(context, DATABASE_NAME, null, DATABASE_VERSION) {

    companion object {
        private const val DATABASE_NAME = "smsqaiddb.db"
        private const val DATABASE_VERSION = 10

        @Volatile
        private var instance: AppSqliteHelper? = null

        fun getInstance(context: Context): AppSqliteHelper {
            return instance ?: synchronized(this) {
                instance ?: AppSqliteHelper(context.applicationContext).also { instance = it }
            }
        }
    }

    override fun onCreate(db: SQLiteDatabase?) {}
    override fun onUpgrade(db: SQLiteDatabase?, oldVersion: Int, newVersion: Int) {}

    fun isSenderAllowed(sender: String): Boolean {
        val db = readableDatabase
        val cleanSender = sender.replace(Regex("[^0-9]"), "")
        val cursor = db.rawQuery(
            "SELECT 1 FROM allowed_senders WHERE is_active = 1 AND (sender = ? OR REPLACE(REPLACE(sender, '+', ''), '-', '') = ?)",
            arrayOf(sender, cleanSender)
        )
        val allowed = cursor.count > 0
        cursor.close()
        return allowed
    }

    fun matchKeyword(messageBody: String): Map<String, Any>? {
        val db = readableDatabase
        val cursor = db.rawQuery("SELECT id, keyword, is_offer, target_count, reward_keyword_id, reward_qty FROM keywords WHERE is_active = 1", null)
        
        var matchedKeyword: Map<String, Any>? = null
        while (cursor.moveToNext()) {
            val kwText = cursor.getString(cursor.getColumnIndexOrThrow("keyword"))
            if (messageBody.contains(kwText, ignoreCase = true)) {
                matchedKeyword = mapOf(
                    "id" to cursor.getInt(cursor.getColumnIndexOrThrow("id")),
                    "keyword" to kwText,
                    "is_offer" to cursor.getInt(cursor.getColumnIndexOrThrow("is_offer")),
                    "target_count" to cursor.getInt(cursor.getColumnIndexOrThrow("target_count")),
                    "reward_keyword_id" to cursor.getInt(cursor.getColumnIndexOrThrow("reward_keyword_id")),
                    "reward_qty" to cursor.getInt(cursor.getColumnIndexOrThrow("reward_qty"))
                )
                break
            }
        }
        cursor.close()
        return matchedKeyword
    }

    fun findCustomerPhoneByIdentifier(textContent: String): String? {
        val db = readableDatabase
        val cursor = db.rawQuery("SELECT phone, name, wallet_number FROM customers", null)

        var foundPhone: String? = null
        while (cursor.moveToNext()) {
            val name = cursor.getString(cursor.getColumnIndexOrThrow("name"))
            val wallet = cursor.getString(cursor.getColumnIndexOrThrow("wallet_number"))
            val phone = cursor.getString(cursor.getColumnIndexOrThrow("phone"))

            if (!name.isNullOrEmpty() && textContent.contains(name, ignoreCase = true)) {
                foundPhone = phone
                break
            }
            if (!wallet.isNullOrEmpty() && textContent.contains(wallet.trim())) {
                foundPhone = phone
                break
            }
        }
        cursor.close()
        return foundPhone
    }

    @Synchronized
    fun getAndUseVoucher(keywordId: Int, assignedPhone: String): String? {
        val db = writableDatabase
        db.beginTransaction()
        var voucherCode: String? = null
        try {
            val cursor = db.rawQuery(
                "SELECT id, number_code FROM numbers_pool WHERE keyword_id = ? AND status = 'available' LIMIT 1",
                arrayOf(keywordId.toString())
            )

            if (cursor.moveToFirst()) {
                val voucherId = cursor.getInt(cursor.getColumnIndexOrThrow("id"))
                voucherCode = cursor.getString(cursor.getColumnIndexOrThrow("number_code"))

                val values = ContentValues().apply {
                    put("status", "used")
                    put("assigned_to", assignedPhone)
                    put("assigned_at", System.currentTimeMillis())
                }
                db.update("numbers_pool", values, "id = ?", arrayOf(voucherId.toString()))
            }
            cursor.close()
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
        return voucherCode
    }

    fun addToArchive(
        sender: String,
        senderName: String?,
        receivedMessage: String,
        matchedKeyword: String?,
        sentNumber: String?,
        status: String,
        source: String = "Native_SMS",
        extraData: String? = null
    ): Long {
        val db = writableDatabase
        val values = ContentValues().apply {
            put("sender", sender)
            put("sender_name", senderName ?: "")
            put("received_message", receivedMessage)
            put("matched_keyword", matchedKeyword ?: "")
            put("sent_number", sentNumber ?: "")
            put("source", source)
            put("extra_data", extraData ?: "")
            put("status", status)
            put("timestamp", System.currentTimeMillis())
            put("is_deleted", 0)
        }
        return db.insert("reply_log", null, values)
    }

    fun getSetting(key: String, defaultValue: String): String {
        val db = readableDatabase
        val cursor = db.query("settings", arrayOf("setting_value"), "setting_key = ?", arrayOf(key), null, null, null)
        var value = defaultValue
        if (cursor.moveToFirst()) {
            value = cursor.getString(cursor.getColumnIndexOrThrow("setting_value")) ?: defaultValue
        }
        cursor.close()
        return value
    }
}
