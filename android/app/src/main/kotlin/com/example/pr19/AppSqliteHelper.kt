package com.example.pr19

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.util.Log

class AppSqliteHelper(context: Context) : SQLiteOpenHelper(context, DATABASE_NAME, null, DATABASE_VERSION) {

    companion object {
        private const val DATABASE_NAME = "smsqaiddb.db"
        private const val DATABASE_VERSION = 11

        @Volatile
        private var instance: AppSqliteHelper? = null

        fun getInstance(context: Context): AppSqliteHelper {
            return instance ?: synchronized(this) {
                instance ?: AppSqliteHelper(context.applicationContext).also { instance = it }
            }
        }
    }

    override fun onCreate(db: SQLiteDatabase?) {
        db?.execSQL("""
            CREATE TABLE IF NOT EXISTS customers (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                phone TEXT NOT NULL UNIQUE,
                name TEXT,
                wallet_number TEXT,
                last_balance TEXT,
                created_at INTEGER
            )
        """)

        db?.execSQL("""
            CREATE TABLE IF NOT EXISTS customer_vouchers_count (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                customer_phone TEXT NOT NULL,
                keyword_id INTEGER NOT NULL,
                received_count INTEGER DEFAULT 0,
                last_updated INTEGER,
                UNIQUE(customer_phone, keyword_id)
            )
        """)
        createIndexes(db)
    }

    private fun createIndexes(db: SQLiteDatabase?) {
        try {
            db?.execSQL("CREATE INDEX IF NOT EXISTS idx_customers_phone_wallet ON customers(phone, wallet_number)")
            db?.execSQL("CREATE INDEX IF NOT EXISTS idx_numbers_pool_kw_status ON numbers_pool(keyword_id, status)")
            db?.execSQL("CREATE INDEX IF NOT EXISTS idx_keywords_active ON keywords(is_active)")
            db?.execSQL("CREATE INDEX IF NOT EXISTS idx_allowed_senders ON allowed_senders(is_active, sender)")
        } catch (e: Exception) {
            Log.e("SQLite", "Error creating indexes: ${e.message}")
        }
    }

    override fun onUpgrade(db: SQLiteDatabase?, oldVersion: Int, newVersion: Int) {
        if (oldVersion < 8) {
            try {
                db?.execSQL("ALTER TABLE keywords ADD COLUMN target_count INTEGER DEFAULT 0")
                db?.execSQL("ALTER TABLE keywords ADD COLUMN reward_keyword_id INTEGER")
                db?.execSQL("ALTER TABLE keywords ADD COLUMN reward_qty INTEGER DEFAULT 1")
            } catch (e: Exception) {
                Log.e("SQLite", "Error upgrading v8: ${e.message}")
            }

            db?.execSQL("""
                CREATE TABLE IF NOT EXISTS customer_vouchers_count (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    customer_phone TEXT NOT NULL,
                    keyword_id INTEGER NOT NULL,
                    received_count INTEGER DEFAULT 0,
                    last_updated INTEGER,
                    UNIQUE(customer_phone, keyword_id)
                )
            """)
        }

        if (oldVersion < 9) {
            db?.execSQL("""
                CREATE TABLE IF NOT EXISTS customers (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    phone TEXT NOT NULL UNIQUE,
                    name TEXT,
                    created_at INTEGER
                )
            """)
        }

        if (oldVersion < 10) {
            try {
                db?.execSQL("ALTER TABLE customers ADD COLUMN wallet_number TEXT;")
            } catch (e: Exception) {
                Log.e("SQLite", "Error upgrading v10: ${e.message}")
            }
        }

        if (oldVersion < 11) {
            try {
                db?.execSQL("ALTER TABLE customers ADD COLUMN last_balance TEXT;")
            } catch (e: Exception) {
                Log.e("SQLite", "Error upgrading v11: ${e.message}")
            }
        }
        createIndexes(db)
    }

    fun isDuplicateBalance(identifier: String, currentBalance: String): Boolean {
        val db = readableDatabase
        val cursor = db.rawQuery(
            "SELECT last_balance FROM customers WHERE phone = ? OR wallet_number = ? LIMIT 1",
            arrayOf(identifier, identifier)
        )
        
        var isDuplicate = false
        if (cursor.moveToFirst()) {
            val lastBalanceIndex = cursor.getColumnIndex("last_balance")
            if (lastBalanceIndex != -1) {
                val lastBalance = cursor.getString(lastBalanceIndex)
                if (lastBalance != null && lastBalance.trim() == currentBalance.trim()) {
                    isDuplicate = true
                }
            }
        }
        cursor.close()
        return isDuplicate
    }

    fun updateCustomerBalance(
        phone: String, 
        newBalance: String, 
        name: String? = null, 
        walletNumber: String? = null
    ) {
        val db = writableDatabase
        val now = System.currentTimeMillis()
    
        val sql = """
            INSERT INTO customers (phone, name, wallet_number, last_balance, created_at)
            VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(phone) DO UPDATE SET
              name = COALESCE(EXCLUDED.name, customers.name),
              wallet_number = COALESCE(EXCLUDED.wallet_number, customers.wallet_number),
              last_balance = CASE 
                WHEN EXCLUDED.last_balance IS NOT NULL AND EXCLUDED.last_balance != '' 
                THEN EXCLUDED.last_balance 
                ELSE customers.last_balance 
              END
        """.trimIndent()
    
        val stmt = db.compileStatement(sql)
        stmt.bindString(1, phone)
        
        if (!name.isNullOrBlank()) stmt.bindString(2, name) else stmt.bindNull(2)
        if (!walletNumber.isNullOrBlank()) stmt.bindString(3, walletNumber) else stmt.bindNull(3)
        stmt.bindString(4, newBalance)
        stmt.bindLong(5, now)
    
        stmt.execute()
        stmt.close()
    }

    fun incrementCustomerCounter(customerPhone: String, keywordId: Int): Int {
        val db = writableDatabase
        val now = System.currentTimeMillis()

        val sql = """
            INSERT INTO customer_vouchers_count (customer_phone, keyword_id, received_count, last_updated)
            VALUES (?, ?, 1, ?)
            ON CONFLICT(customer_phone, keyword_id) DO UPDATE SET
              received_count = received_count + 1,
              last_updated = ?
        """.trimIndent()

        val stmt = db.compileStatement(sql)
        stmt.bindString(1, customerPhone)
        stmt.bindLong(2, keywordId.toLong())
        stmt.bindLong(3, now)
        stmt.bindLong(4, now)
        stmt.execute()
        stmt.close()

        var count = 1
        val cursor = db.rawQuery(
            "SELECT received_count FROM customer_vouchers_count WHERE customer_phone = ? AND keyword_id = ?",
            arrayOf(customerPhone, keywordId.toString())
        )
        if (cursor.moveToFirst()) {
            count = cursor.getInt(cursor.getColumnIndexOrThrow("received_count"))
        }
        cursor.close()
        return count
    }

    fun resetCustomerCounter(customerPhone: String, keywordId: Int) {
        val db = writableDatabase
        val values = ContentValues().apply {
            put("received_count", 0)
            put("last_updated", System.currentTimeMillis())
        }
        db.update(
            "customer_vouchers_count",
            values,
            "customer_phone = ? AND keyword_id = ?",
            arrayOf(customerPhone, keywordId.toString())
        )
    }

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

    fun getAllActiveKeywords(): List<Map<String, Any>> {
        val db = readableDatabase
        val cursor = db.rawQuery("SELECT id, keyword, is_offer, target_count, reward_keyword_id, reward_qty FROM keywords WHERE is_active = 1", null)
        val list = mutableListOf<Map<String, Any>>()
        while (cursor.moveToNext()) {
            list.add(mapOf(
                "id" to cursor.getLong(cursor.getColumnIndexOrThrow("id")), // تخزين صريح كـ Long لتفادي Cast Exception
                "keyword" to cursor.getString(cursor.getColumnIndexOrThrow("keyword")),
                "is_offer" to cursor.getInt(cursor.getColumnIndexOrThrow("is_offer")),
                "target_count" to cursor.getInt(cursor.getColumnIndexOrThrow("target_count")),
                "reward_keyword_id" to cursor.getLong(cursor.getColumnIndexOrThrow("reward_keyword_id")),
                "reward_qty" to cursor.getInt(cursor.getColumnIndexOrThrow("reward_qty"))
            ))
        }
        cursor.close()
        return list
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