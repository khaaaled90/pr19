package com.example.pr19

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.util.Log

class AppSqliteHelper(context: Context) : SQLiteOpenHelper(context, DATABASE_NAME, null, DATABASE_VERSION) {

    companion object {
        private const val DATABASE_NAME = "smsqaiddb.db"
        private const val DATABASE_VERSION = 14 // ✅ رفع الإصدار إلى 13 لإضافة price

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
            CREATE TABLE keywords (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                keyword TEXT NOT NULL UNIQUE,
                description TEXT,
                price REAL DEFAULT 0.0,
                is_active INTEGER DEFAULT 1,
                is_offer INTEGER DEFAULT 0,
                target_count INTEGER DEFAULT 0,
                reward_keyword_id INTEGER,
                reward_qty INTEGER DEFAULT 1,
                created_at INTEGER,
                FOREIGN KEY(reward_keyword_id) REFERENCES keywords(id)
            )
        """);
    
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

        db?.execSQL("""
            CREATE TABLE IF NOT EXISTS client_identifiers (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                client_id INTEGER NOT NULL,
                identifier TEXT NOT NULL UNIQUE,
                FOREIGN KEY(client_id) REFERENCES customers(id) ON DELETE CASCADE
            )
        """)
        db?.execSQL("""
            CREATE TABLE settings (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                setting_key TEXT NOT NULL UNIQUE,
                setting_value TEXT,
                category TEXT DEFAULT 'general'
            )
        """)
        

        createIndexes(db)
    }

    private fun createIndexes(db: SQLiteDatabase?) {
        try {
            db?.execSQL("CREATE INDEX IF NOT EXISTS idx_customers_phone_wallet ON customers(phone, wallet_number)")
            db?.execSQL("CREATE INDEX IF NOT EXISTS idx_customers_name ON customers(name)")
            db?.execSQL("CREATE INDEX IF NOT EXISTS idx_numbers_pool_kw_status ON numbers_pool(keyword_id, status)")
            db?.execSQL("CREATE INDEX IF NOT EXISTS idx_keywords_active ON keywords(is_active)")
            db?.execSQL("CREATE INDEX IF NOT EXISTS idx_allowed_senders ON allowed_senders(is_active, sender)")
            db?.execSQL("CREATE INDEX IF NOT EXISTS idx_client_identifiers ON client_identifiers(identifier)")
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

        if (oldVersion < 12) {
            db?.execSQL("""
                CREATE TABLE IF NOT EXISTS client_identifiers (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    client_phone TEXT NOT NULL,
                    identifier TEXT NOT NULL UNIQUE
                )
            """)
        }

        // ✅ الترقية للـ Version 13: إضافة سعر الفئة ومبلغ الأرشيف
        if (oldVersion < 13) {
            try {
                db?.execSQL("ALTER TABLE keywords ADD COLUMN price REAL DEFAULT 0.0;")
                db?.execSQL("ALTER TABLE reply_log ADD COLUMN price REAL DEFAULT 0.0;")
            } catch (e: Exception) {
                Log.e("SQLite", "Error upgrading v13: ${e.message}")
            }
        }

        // ✅ الترقية للـ Version 14: إضافة جدول العملاء المستثنين
        if (oldVersion < 14) {
            try {
                db?.execSQL("""
                    CREATE TABLE IF NOT EXISTS excepted_customers (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        phone TEXT NOT NULL UNIQUE,
                        name TEXT,
                        notes TEXT,
                        created_at INTEGER NOT NULL
                    )
                """.trimIndent())
            } catch (e: Exception) {
                Log.e("SQLite", "Error upgrading v14: ${e.message}")
            }
        }

        createIndexes(db)
    }
    
    fun getAllClientIdentifiers(): Map<String, String> {
        Log.e("CLIENT_CACHE", "========== getAllClientIdentifiers START ==========")

        val map = mutableMapOf<String, String>()
        val db = readableDatabase

        val cursor = db.rawQuery("SELECT phone, name, wallet_number FROM customers", null)
        cursor.use { c ->
            val phoneIdx = c.getColumnIndex("phone")
            val nameIdx = c.getColumnIndex("name")
            val walletIdx = c.getColumnIndex("wallet_number")

            var customerCount = 0

            if (phoneIdx != -1) {
                while (c.moveToNext()) {
                    customerCount++
                    val phone = c.getString(phoneIdx) ?: continue
                    map[normalizeText(phone)] = phone

                    if (nameIdx != -1) {
                        val name = c.getString(nameIdx)
                        if (!name.isNullOrBlank()) {
                            map[normalizeText(name)] = phone
                        }
                    }

                    if (walletIdx != -1) {
                        val wallet = c.getString(walletIdx)
                        if (!wallet.isNullOrBlank()) {
                            map[normalizeText(wallet)] = phone
                        }
                    }
                }
            }
        }

        val extraQuery = """
            SELECT ci.identifier, c.phone
            FROM client_identifiers ci
            INNER JOIN customers c ON ci.client_id = c.id
        """.trimIndent()

        val extraCursor = db.rawQuery(extraQuery, null)

        extraCursor.use { c ->
            val idIdx = c.getColumnIndex("identifier")
            val phoneIdx = c.getColumnIndex("phone")

            if (idIdx != -1 && phoneIdx != -1) {
                while (c.moveToNext()) {
                    val identifier = c.getString(idIdx)
                    val phone = c.getString(phoneIdx)

                    if (!identifier.isNullOrBlank() && !phone.isNullOrBlank()) {
                        map[normalizeText(identifier)] = phone
                    }
                }
            }
        }

        Log.e("CLIENT_CACHE", "========== getAllClientIdentifiers END ==========")
        return map
    }

    private fun normalizeText(text: String): String {
        return text.trim()
            .replace(Regex("[أإآ]"), "ا")
            .replace("ة", "ه")
            .replace(Regex("\\s+"), " ")
            .lowercase()
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

    fun getAvailableNumbersCountByKeywordId(keywordId: Int): Int {
        val db = readableDatabase
        val cursor = db.rawQuery(
            "SELECT COUNT(*) FROM numbers_pool WHERE keyword_id = ? AND status = 'available'",
            arrayOf(keywordId.toString())
        )
        var count = 0
        if (cursor.moveToFirst()) {
            count = cursor.getInt(0)
        }
        cursor.close()
        return count
    }

    fun updateCustomerBalance(
        phone: String,
        newBalance: String,
        name: String? = null,
        walletNumber: String? = null
    ) {
        val db = writableDatabase
        val now = System.currentTimeMillis()

        db.beginTransaction()
        try {
            var clientId: Long? = null
            var currentName: String? = null

            db.rawQuery(
                "SELECT id, name FROM customers WHERE phone = ?",
                arrayOf(phone)
            ).use { c ->
                if (c.moveToFirst()) {
                    clientId = c.getLong(c.getColumnIndexOrThrow("id"))
                    currentName = c.getString(c.getColumnIndexOrThrow("name"))
                }
            }

            val cleanName = name?.takeIf { it.isNotBlank() }
            val cleanWallet = walletNumber?.takeIf { it.isNotBlank() }
            val cleanBalance = newBalance.takeIf { it.isNotBlank() }

            if (clientId == null) {
                val values = ContentValues().apply {
                    put("phone", phone)
                    put("name", cleanName)
                    put("wallet_number", cleanWallet)
                    put("last_balance", cleanBalance)
                    put("created_at", now)
                }
                clientId = db.insert("customers", null, values)
            } else {
                val values = ContentValues().apply {
                    if (cleanName != null && currentName.isNullOrBlank()) {
                        put("name", cleanName)
                    }
                    if (cleanWallet != null) {
                        put("wallet_number", cleanWallet)
                    }
                    if (cleanBalance != null) {
                        put("last_balance", cleanBalance)
                    }
                }

                if (values.size() > 0) {
                    db.update("customers", values, "phone = ?", arrayOf(phone))
                }
            }

            if (clientId != null && !cleanName.isNullOrEmpty()) {
                db.execSQL(
                    """
                    INSERT OR IGNORE INTO client_identifiers (client_id, identifier)
                    VALUES (?, ?)
                    """.trimIndent(),
                    arrayOf(clientId, cleanName)
                )
                AppCache.updateIdentifierCache(cleanName, phone)
            }

            db.setTransactionSuccessful()
        } catch (e: Exception) {
            Log.e("CLIENT_CACHE", "ERROR -> ${e.message}", e)
            throw e
        } finally {
            db.endTransaction()
        }
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

    /*fun getAllActiveKeywords(): List<Map<String, Any?>> {
        val list = mutableListOf<Map<String, Any?>>()
        try {
            val db = readableDatabase
            val cursor = db.rawQuery(
                "SELECT id, keyword, is_offer, target_count, reward_keyword_id, reward_qty, price FROM keywords WHERE is_active = 1", 
                null
            )
            
            // 🟢 استخدام .use لتأمين إغلاق الـ cursor تلقائياً
            cursor.use { c ->
                val idIdx = c.getColumnIndexOrThrow("id")
                val keywordIdx = c.getColumnIndexOrThrow("keyword")
                val isOfferIdx = c.getColumnIndexOrThrow("is_offer")
                val targetCountIdx = c.getColumnIndexOrThrow("target_count")
                val rewardKeywordIdIdx = c.getColumnIndexOrThrow("reward_keyword_id")
                val rewardQtyIdx = c.getColumnIndexOrThrow("reward_qty")
                val priceIdx = c.getColumnIndex("price")

                while (c.moveToNext()) {
                    val priceVal = if (priceIdx != -1 && !c.isNull(priceIdx)) c.getDouble(priceIdx) else 0.0
                    
                    // 🟢 قراءة reward_keyword_id مع التحقق من قيم NULL
                    val rewardKeywordId = if (!c.isNull(rewardKeywordIdIdx)) c.getLong(rewardKeywordIdIdx) else null

                    list.add(mapOf(
                        "id" to c.getLong(idIdx),
                        "keyword" to c.getString(keywordIdx),
                        "is_offer" to c.getInt(isOfferIdx),
                        "target_count" to c.getInt(targetCountIdx),
                        "reward_keyword_id" to rewardKeywordId,
                        "reward_qty" to c.getInt(rewardQtyIdx),
                        "price" to priceVal
                    ))
                }
            }
        } catch (e: Exception) {
            Log.e("AppSqliteHelper", "⚠️ تعذر قراءة keywords في التهيئة المبدئية: ${e.message}")
        }
        return list
    }*/

    // ✅ تم تعديل الاستعلام وقراءة حقل price
    fun getAllActiveKeywords(): List<Map<String, Any>> {
        val list = mutableListOf<Map<String, Any>>()
        try {
            val db = readableDatabase
            val cursor = db.rawQuery("SELECT id, keyword, is_offer, target_count, reward_keyword_id, reward_qty, price FROM keywords WHERE is_active = 1", null)
            
            while (cursor.moveToNext()) {
                val priceIdx = cursor.getColumnIndex("price")
                val priceVal = if (priceIdx != -1) cursor.getDouble(priceIdx) else 0.0

                list.add(mapOf(
                    "id" to cursor.getLong(cursor.getColumnIndexOrThrow("id")),
                    "keyword" to cursor.getString(cursor.getColumnIndexOrThrow("keyword")),
                    "is_offer" to cursor.getInt(cursor.getColumnIndexOrThrow("is_offer")),
                    "target_count" to cursor.getInt(cursor.getColumnIndexOrThrow("target_count")),
                    "reward_keyword_id" to cursor.getLong(cursor.getColumnIndexOrThrow("reward_keyword_id")),
                    "reward_qty" to cursor.getInt(cursor.getColumnIndexOrThrow("reward_qty")),
                    "price" to priceVal // 👈 السعر
                ))
            }
            cursor.close()
        } catch (e: Exception) {
            Log.e("AppSqliteHelper", "⚠️ تعذر قراءة keywords في التهيئة المبدئية: ${e.message}")
        }
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

    // ✅ إضافة تمرير وحفظ price عند الأرشفة
    fun addToArchive(
        sender: String,
        senderName: String?,
        receivedMessage: String,
        matchedKeyword: String?,
        sentNumber: String?,
        status: String,
        source: String = "Native_SMS",
        extraData: String? = null,
        price: Double = 0.0 // 👈 بارامتر السعر
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
            put("price", price) // 👈 حفظ السعر
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
    fun resolvePendingLog(
        logId: Long,
        customerPhone: String,
        customerName: String,
        voucherCode: String,
        price: Double = 0.0
    ): Boolean {
        val db = writableDatabase
        db.beginTransaction()
        return try {
            val poolValues = ContentValues().apply {
                put("status", "used")
                put("assigned_to", customerPhone)
                put("assigned_at", System.currentTimeMillis())
            }
            db.update("numbers_pool", poolValues, "number_code = ?", arrayOf(voucherCode))

            val logValues = ContentValues().apply {
                put("sender", customerPhone)
                put("sender_name", customerName)
                put("status", "sent_manual")
                put("sent_number", voucherCode)
                put("price", price) // 👈 حفظ السعر
            }
            db.update("reply_log", logValues, "id = ?", arrayOf(logId.toString()))

            db.setTransactionSuccessful()
            true
        } catch (e: Exception) {
            Log.e("SQLite", "Error resolving pending log: ${e.message}")
            false
        } finally {
            db.endTransaction()
        }
    }

    fun isSenderIgnored(phone: String): Boolean {
        val db = readableDatabase
        val cursor = db.rawQuery(
            "SELECT 1 FROM excepted_customers WHERE phone = ? LIMIT 1",
            arrayOf(phone)
        )
        val exists = cursor.count > 0
        cursor.close()
        return exists
    }
}
//******************************************************
/*package com.example.pr19

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.util.Log

class AppSqliteHelper(context: Context) : SQLiteOpenHelper(context, DATABASE_NAME, null, DATABASE_VERSION) {

    companion object {
        private const val DATABASE_NAME = "smsqaiddb.db"
        private const val DATABASE_VERSION = 12 // ✅ رفع رقم الإصدار

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

        // ✅ جدول اختياري للمعرفات الإضافية (مثل أسماء متعددة لنفس العميل)
        // في onCreate و onUpgrade:
        db?.execSQL("""
            CREATE TABLE IF NOT EXISTS client_identifiers (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                client_id INTEGER NOT NULL,
                identifier TEXT NOT NULL UNIQUE,
                FOREIGN KEY(client_id) REFERENCES customers(id) ON DELETE CASCADE
            )
        """)
        createIndexes(db)
    }

    private fun createIndexes(db: SQLiteDatabase?) {
        try {
            db?.execSQL("CREATE INDEX IF NOT EXISTS idx_customers_phone_wallet ON customers(phone, wallet_number)")
            db?.execSQL("CREATE INDEX IF NOT EXISTS idx_customers_name ON customers(name)")
            db?.execSQL("CREATE INDEX IF NOT EXISTS idx_numbers_pool_kw_status ON numbers_pool(keyword_id, status)")
            db?.execSQL("CREATE INDEX IF NOT EXISTS idx_keywords_active ON keywords(is_active)")
            db?.execSQL("CREATE INDEX IF NOT EXISTS idx_allowed_senders ON allowed_senders(is_active, sender)")
            db?.execSQL("CREATE INDEX IF NOT EXISTS idx_client_identifiers ON client_identifiers(identifier)")
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

        if (oldVersion < 12) {
            db?.execSQL("""
                CREATE TABLE IF NOT EXISTS client_identifiers (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    client_phone TEXT NOT NULL,
                    identifier TEXT NOT NULL UNIQUE
                )
            """)
        }

        createIndexes(db)
    }

    fun getAllClientIdentifiers(): Map<String, String> {

        //Log.d("CLIENT_CACHE", "clientIdentifiers == null ? ${clientIdentifiers == null}")

        //private const val TAG = "CLIENT_CACHE"
        Log.e("CLIENT_CACHE", "========== getAllClientIdentifiers START ==========")

        val map = mutableMapOf<String, String>()
        val db = readableDatabase

        Log.e("CLIENT_CACHE", "Loading customers table...")

        val cursor = db.rawQuery("SELECT phone, name, wallet_number FROM customers", null)
        cursor.use { c ->
            val phoneIdx = c.getColumnIndex("phone")
            val nameIdx = c.getColumnIndex("name")
            val walletIdx = c.getColumnIndex("wallet_number")

            Log.e(
                "CLIENT_CACHE",
                "Columns -> phone=$phoneIdx name=$nameIdx wallet=$walletIdx"
            )

            var customerCount = 0

            if (phoneIdx != -1) {
                while (c.moveToNext()) {

                    customerCount++

                    val phone = c.getString(phoneIdx) ?: continue

                    Log.e("CLIENT_CACHE", "Customer[$customerCount] phone=$phone")

                    map[normalizeText(phone)] = phone

                    if (nameIdx != -1) {
                        val name = c.getString(nameIdx)

                        if (!name.isNullOrBlank()) {
                            Log.e("CLIENT_CACHE", "  Name -> $name")
                            map[normalizeText(name)] = phone
                        } else {
                            Log.e("CLIENT_CACHE", "  Name -> EMPTY")
                        }
                    }

                    if (walletIdx != -1) {
                        val wallet = c.getString(walletIdx)

                        if (!wallet.isNullOrBlank()) {
                            Log.e("CLIENT_CACHE", "  Wallet -> $wallet")
                            map[normalizeText(wallet)] = phone
                        } else {
                            Log.e("CLIENT_CACHE", "  Wallet -> EMPTY")
                        }
                    }
                }
            }

            Log.e("CLIENT_CACHE", "Customers Loaded = $customerCount")
        }

        Log.e("CLIENT_CACHE", "Loading client_identifiers...")

        val extraQuery = """
            SELECT ci.identifier, c.phone
            FROM client_identifiers ci
            INNER JOIN customers c ON ci.client_id = c.id
        """.trimIndent()

        val extraCursor = db.rawQuery(extraQuery, null)

        extraCursor.use { c ->

            val idIdx = c.getColumnIndex("identifier")
            val phoneIdx = c.getColumnIndex("phone")

            Log.e(
                "CLIENT_CACHE",
                "Alias Columns -> identifier=$idIdx phone=$phoneIdx"
            )

            var aliasCount = 0

            if (idIdx != -1 && phoneIdx != -1) {

                while (c.moveToNext()) {

                    aliasCount++

                    val identifier = c.getString(idIdx)
                    val phone = c.getString(phoneIdx)

                    if (!identifier.isNullOrBlank() && !phone.isNullOrBlank()) {

                        Log.d(
                            "CLIENT_CACHE",
                            "Alias[$aliasCount] identifier='$identifier' -> phone=$phone"
                        )

                        map[normalizeText(identifier)] = phone

                    } else {

                        Log.w(
                            "CLIENT_CACHE",
                            "Alias[$aliasCount] skipped (identifier=$identifier phone=$phone)"
                        )
                    }
                }
            }

            Log.d("CLIENT_CACHE", "Aliases Loaded = $aliasCount")
        }

        Log.e("CLIENT_CACHE", "Total cache entries = ${map.size}")

        Log.e("CLIENT_CACHE", "========== getAllClientIdentifiers END ==========")

        return map
    }

    // ✅ دالة توحيد الحروف لمطابقة دقيقة وخالية من المشاكل
    private fun normalizeText(text: String): String {
        return text.trim()
            .replace(Regex("[أإآ]"), "ا")
            .replace("ة", "ه")
            .replace(Regex("\\s+"), " ")
            .lowercase()
    }

    fun isDuplicateBalance(identifier: String, currentBalance: String): Boolean {
        val tag = "DB_CHECK"
        Log.e(tag, "--- بدء دالة isDuplicateBalance ---")
        Log.e(tag, "المدخلات -> المعرف (identifier): '$identifier' | الرصيد الحالي (currentBalance): '$currentBalance'")
    
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
                
                Log.e(tag, "تم العثور على سجل للعميل. الرصيد المحفوظ سابقاً (last_balance): '$lastBalance'")
            
                if (lastBalance != null && lastBalance.trim() == currentBalance.trim()) {
                    Log.e(tag, "تطابق الرصيد! الرصيد السابق '$lastBalance' يساوي الرصيد الجديد '$currentBalance'")
                    isDuplicate = true
                }
            }
        }
        cursor.close()
        return isDuplicate
    }

    fun getAvailableNumbersCountByKeywordId(keywordId: Int): Int {
        val db = readableDatabase
        val cursor = db.rawQuery(
            "SELECT COUNT(*) FROM numbers_pool WHERE keyword_id = ? AND status = 'available'",
            arrayOf(keywordId.toString())
        )
        var count = 0
        if (cursor.moveToFirst()) {
            count = cursor.getInt(0)
        }
        cursor.close()
        return count
    }

    fun updateCustomerBalance(
        phone: String,
        newBalance: String,
        name: String? = null,
        walletNumber: String? = null
    ) {
        Log.d("CLIENT_CACHE", "updateCustomerBalance() ENTERED")
        Log.d("CLIENT_CACHE", "========== updateCustomerBalance START ==========")
        Log.d("CLIENT_CACHE", "Input -> phone=$phone, balance=$newBalance, name=$name, wallet=$walletNumber")

        val db = writableDatabase
        val now = System.currentTimeMillis()

        Log.d("CLIENT_CACHE", "Begin Transaction")
        db.beginTransaction()

        try {
            var clientId: Long? = null
            var currentName: String? = null

            Log.d("CLIENT_CACHE", "Searching customer by phone: $phone")

            db.rawQuery(
                "SELECT id, name FROM customers WHERE phone = ?",
                arrayOf(phone)
            ).use { c ->
                if (c.moveToFirst()) {
                    clientId = c.getLong(c.getColumnIndexOrThrow("id"))
                    currentName = c.getString(c.getColumnIndexOrThrow("name"))

                    Log.d("CLIENT_CACHE", "Customer Found -> id=$clientId, currentName=$currentName")
                } else {
                    Log.d("CLIENT_CACHE", "Customer NOT FOUND")
                }
            }

            val cleanName = name?.takeIf { it.isNotBlank() }
            val cleanWallet = walletNumber?.takeIf { it.isNotBlank() }
            val cleanBalance = newBalance.takeIf { it.isNotBlank() }

            Log.d("CLIENT_CACHE", "Clean Values -> name=$cleanName wallet=$cleanWallet balance=$cleanBalance")

            if (clientId == null) {

                Log.d("CLIENT_CACHE", "Creating NEW customer")

                val values = ContentValues().apply {
                    put("phone", phone)
                    put("name", cleanName)
                    put("wallet_number", cleanWallet)
                    put("last_balance", cleanBalance)
                    put("created_at", now)
                }

                clientId = db.insert("customers", null, values)

                Log.d("CLIENT_CACHE", "Customer Inserted -> clientId=$clientId")

            } else {

                Log.d("CLIENT_CACHE", "Updating Existing Customer")

                val values = ContentValues().apply {

                    if (cleanName != null && currentName.isNullOrBlank()) {
                        Log.d("CLIENT_CACHE", "Updating empty customer name -> $cleanName")
                        put("name", cleanName)
                    } else {
                        Log.d("CLIENT_CACHE", "Customer name NOT updated")
                    }

                    if (cleanWallet != null) {
                        Log.d("CLIENT_CACHE", "Updating wallet -> $cleanWallet")
                        put("wallet_number", cleanWallet)
                    }

                    if (cleanBalance != null) {
                        Log.d("CLIENT_CACHE", "Updating balance -> $cleanBalance")
                        put("last_balance", cleanBalance)
                    }
                }

                if (values.size() > 0) {

                    val rows = db.update(
                        "customers",
                        values,
                        "phone = ?",
                        arrayOf(phone)
                    )

                    Log.d("CLIENT_CACHE", "Customer Updated -> affectedRows=$rows")

                } else {

                    Log.d("CLIENT_CACHE", "Nothing to update")

                }
            }

            Log.e("CLIENT_CACHE", "Processing client_identifiers")

            Log.e("UPDATE_CUSTOMER", "clientId=$clientId")
            Log.e("UPDATE_CUSTOMER", "cleanName='$cleanName'")
            
            if (clientId != null && !cleanName.isNullOrEmpty()) {

                Log.e("CLIENT_CACHE", "Adding Identifier -> clientId=$clientId identifier=$cleanName")

                db.execSQL(
                    """
                    INSERT OR IGNORE INTO client_identifiers (client_id, identifier)
                    VALUES (?, ?)
                    """.trimIndent(),
                    arrayOf(clientId, cleanName)
                )

                Log.e("UPDATE_CUSTOMER", "Updating AppCache...")
                Log.e("CLIENT_CACHE", "Identifier INSERT OR IGNORE executed")

                AppCache.updateIdentifierCache(cleanName, phone)
                
                Log.e("UPDATE_CUSTOMER", "AppCache updated")
                Log.e("CLIENT_CACHE", "Cache Updated")

            } else {

                Log.e("CLIENT_CACHE", "Identifier skipped")

            }

            db.setTransactionSuccessful()

            Log.e("CLIENT_CACHE", "Transaction Successful")

        } catch (e: Exception) {

            Log.e("CLIENT_CACHE", "ERROR -> ${e.message}", e)
            throw e

        } finally {

            Log.e("CLIENT_CACHE", "End Transaction")

            db.endTransaction()

            Log.e("CLIENT_CACHE", "========== updateCustomerBalance END ==========")
        }
    }
    
    /*fun updateCustomerBalance(
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
    }*/

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
                "id" to cursor.getLong(cursor.getColumnIndexOrThrow("id")),
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
}*/
/*package com.example.pr19

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
}*/