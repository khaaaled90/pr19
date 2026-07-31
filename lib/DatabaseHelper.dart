import 'dart:async';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static const String _databaseName = "smsqaiddb.db";
  static const int _databaseVersion = 12; // ✅ تم الرفع إلى 12 لتطبيق التحديثات
  static const MethodChannel _nativeChannel = MethodChannel('com.example.pr19/cache');

  static const String tableKeywords = "keywords";
  static const String tableNumbersPool = "numbers_pool";
  static const String tableAllowedSenders = "allowed_senders";
  static const String tableReplyLog = "reply_log";
  static const String tableSettings = "settings";
  static const String tableOffers = "offers";
  static const String tableCustomerVouchersCount = "customer_vouchers_count";
  static const String tableCustomers = "customers";
  static const String tableClientIdentifiers = "client_identifiers"; // ✅ المتغير المضاف

  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;
  
  /// ✅ إغلاق قاعدة البيانات بأمان لإجراء عمليات النسخ الاحتياطي أو الاستعادة
  Future<void> closeDatabase() async {
    try {
      final db = _database;
      if (db != null && db.isOpen) {
        await db.close();
        _database = null; // إعادة تعيين المتغير ليعاد فتحها عند طلب `database` من جديد
      }
    } catch (e) {
      // تسجيل الخطأ إن وجد
      _database = null;
    }
  }
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  /// ⭐ إخطار كود Kotlin لتصفير AppCache فور تحديث أي إعداد أو كلمة مفتاحية أو معرف جديد من Flutter
  Future<void> clearNativeCache() async {
    try {
      await _nativeChannel.invokeMethod('clearCache');
    } catch (_) {}
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  } 
  
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableKeywords (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        keyword TEXT NOT NULL UNIQUE,
        description TEXT,
        is_active INTEGER DEFAULT 1,
        is_offer INTEGER DEFAULT 0,
        target_count INTEGER DEFAULT 0,
        reward_keyword_id INTEGER,
        reward_qty INTEGER DEFAULT 1,
        created_at INTEGER,
        FOREIGN KEY(reward_keyword_id) REFERENCES $tableKeywords(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableNumbersPool (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        keyword_id INTEGER NOT NULL,
        number_code TEXT NOT NULL UNIQUE,
        status TEXT DEFAULT 'available',
        assigned_to TEXT,
        assigned_at INTEGER,
        FOREIGN KEY(keyword_id) REFERENCES $tableKeywords(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableAllowedSenders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sender TEXT NOT NULL UNIQUE,
        name TEXT,
        sender_type TEXT DEFAULT 'phone',
        is_active INTEGER DEFAULT 1,
        created_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableReplyLog (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sender TEXT,
        sender_name TEXT,
        received_message TEXT,
        matched_keyword TEXT,
        sent_number TEXT,
        source TEXT DEFAULT 'Noti',
        extra_data TEXT,
        status TEXT,
        timestamp INTEGER,
        is_deleted INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableSettings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        setting_key TEXT NOT NULL UNIQUE,
        setting_value TEXT,
        category TEXT DEFAULT 'general'
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableOffers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        offer_keyword_id INTEGER NOT NULL,
        linked_keyword_id INTEGER NOT NULL,
        is_active INTEGER DEFAULT 1,
        FOREIGN KEY(offer_keyword_id) REFERENCES $tableKeywords(id),
        FOREIGN KEY(linked_keyword_id) REFERENCES $tableKeywords(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableCustomerVouchersCount (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_phone TEXT NOT NULL,
        keyword_id INTEGER NOT NULL,
        received_count INTEGER DEFAULT 0,
        last_updated INTEGER,
        FOREIGN KEY(keyword_id) REFERENCES $tableKeywords(id) ON DELETE CASCADE,
        UNIQUE(customer_phone, keyword_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableCustomers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        phone TEXT NOT NULL UNIQUE,
        name TEXT,
        wallet_number TEXT,
        last_balance TEXT,
        created_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableClientIdentifiers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        client_id INTEGER NOT NULL,
        identifier TEXT NOT NULL UNIQUE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (client_id) REFERENCES $tableCustomers (id) ON DELETE CASCADE
      )
    ''');

    await _createIndexes(db);
    await _insertDefaultSettings(db);
  }

  Future<void> _createIndexes(Database db) async {
    await db.execute("CREATE INDEX IF NOT EXISTS idx_customers_phone_wallet ON $tableCustomers(phone, wallet_number)");
    await db.execute("CREATE INDEX IF NOT EXISTS idx_numbers_pool_kw_status ON $tableNumbersPool(keyword_id, status)");
    await db.execute("CREATE INDEX IF NOT EXISTS idx_keywords_active ON $tableKeywords(is_active)");
    await db.execute("CREATE INDEX IF NOT EXISTS idx_allowed_senders ON $tableAllowedSenders(is_active, sender)");
    await db.execute("CREATE INDEX IF NOT EXISTS idx_identifier ON $tableClientIdentifiers(identifier)");
  }

  Future<void> _insertDefaultSettings(Database db) async {
    final batch = db.batch();
    batch.insert(tableSettings, {'setting_key': 'offers_enabled', 'setting_value': 'true', 'category': 'general'}, conflictAlgorithm: ConflictAlgorithm.ignore);
    batch.insert(tableSettings, {'setting_key': 'service_enabled', 'setting_value': 'true', 'category': 'general'}, conflictAlgorithm: ConflictAlgorithm.ignore);
    batch.insert(tableSettings, {'setting_key': 'default_reply', 'setting_value': 'شكراً لتواصلك. رقمك الخاص هو: ', 'category': 'general'}, conflictAlgorithm: ConflictAlgorithm.ignore);
    batch.insert(tableSettings, {'setting_key': 'allow_all_senders', 'setting_value': 'false', 'category': 'security'}, conflictAlgorithm: ConflictAlgorithm.ignore);
    batch.insert(tableAllowedSenders, {'sender': 'Jaib', 'name': 'Jaib', 'sender_type': 'name', 'is_active': 1}, conflictAlgorithm: ConflictAlgorithm.ignore);
    batch.insert(tableAllowedSenders, {'sender': 'com.ahd.jaib', 'name': 'Jaib إشعارات', 'sender_type': 'name', 'is_active': 1}, conflictAlgorithm: ConflictAlgorithm.ignore);

    await batch.commit(noResult: true);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 8) {
      await db.execute("ALTER TABLE $tableKeywords ADD COLUMN target_count INTEGER DEFAULT 0");
      await db.execute("ALTER TABLE $tableKeywords ADD COLUMN reward_keyword_id INTEGER");
      await db.execute("ALTER TABLE $tableKeywords ADD COLUMN reward_qty INTEGER DEFAULT 1");

      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableCustomerVouchersCount (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          customer_phone TEXT NOT NULL,
          keyword_id INTEGER NOT NULL,
          received_count INTEGER DEFAULT 0,
          last_updated INTEGER,
          FOREIGN KEY(keyword_id) REFERENCES $tableKeywords(id) ON DELETE CASCADE,
          UNIQUE(customer_phone, keyword_id)
        )
      ''');
    }

    if (oldVersion < 9) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableCustomers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          phone TEXT NOT NULL UNIQUE,
          name TEXT,
          created_at INTEGER
        )
      ''');
    }

    if (oldVersion < 10) {
      await db.execute("ALTER TABLE $tableCustomers ADD COLUMN wallet_number TEXT;");
    }

    if (oldVersion < 11) {
      await db.execute("ALTER TABLE $tableCustomers ADD COLUMN last_balance TEXT;");
    }

    // ✅ الترقية للإصدار 12: إضافة جدول المعرفات client_identifiers للنسخ القديمة
    if (oldVersion < 12) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableClientIdentifiers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          client_id INTEGER NOT NULL,
          identifier TEXT NOT NULL UNIQUE,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (client_id) REFERENCES $tableCustomers (id) ON DELETE CASCADE
        )
      ''');
    }

    await _createIndexes(db);
  }

  /// ✅ دالة معالجة المعاملة المعلقة وربط معرف العميل الجديد ورقم هاتفه
  Future<void> resolvePendingTransaction({
    required String rawIdentifier,
    required String phoneInput,
  }) async {
    final db = await database;
    String cleanPhone = phoneInput.trim();
    String cleanIdentifier = normalizeText(rawIdentifier);

    if (cleanPhone.isEmpty || cleanIdentifier.isEmpty) return;

    // 1. فحص هل رقم الهاتف موجود في جدول العملاء؟
    List<Map<String, dynamic>> existingClient = await db.query(
      tableCustomers,
      where: 'phone = ?',
      whereArgs: [cleanPhone],
      limit: 1,
    );

    int clientId;
    if (existingClient.isNotEmpty) {
      clientId = existingClient.first['id'] as int;
    } else {
      clientId = await db.insert(tableCustomers, {
        'phone': cleanPhone,
        'name': rawIdentifier,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
    }

    // 2. ربط المعرف الجديد بـ client_id في جدول المعرفات
    await db.insert(
      tableClientIdentifiers,
      {
        'client_id': clientId,
        'identifier': cleanIdentifier,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    // 3. مسح كاش الناتيف لإجبار Kotlin على إعادة التحميل الشامل للمعرفات الجديدة
    await clearNativeCache();
  }

  /// ✅ دالة توحيد وتنظيف النصوص
  static String normalizeText(String text) {
    return text
        .trim()
        .replaceAll(RegExp(r'[أإآ]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll(RegExp(r'\s+'), ' ')
        .toLowerCase();
  }

  Future<void> saveOrUpdateCustomer(String phone, {String? name, String? walletNumber, String? lastBalance}) async {
    final db = await database;
    int now = DateTime.now().millisecondsSinceEpoch;

    await db.rawInsert('''
      INSERT INTO $tableCustomers (phone, name, wallet_number, last_balance, created_at)
      VALUES (?, ?, ?, ?, ?)
      ON CONFLICT(phone) DO UPDATE SET
        name = COALESCE(EXCLUDED.name, name),
        wallet_number = COALESCE(EXCLUDED.wallet_number, wallet_number),
        last_balance = COALESCE(EXCLUDED.last_balance, last_balance)
    ''', [phone, name ?? 'عميل جديد', walletNumber, lastBalance, now]);
  }

  Future<bool> isDuplicateBalance(String identifier, String currentBalance) async {
    final db = await database;
    
    List<Map<String, dynamic>> result = await db.query(
      tableCustomers,
      columns: ['last_balance'],
      where: 'phone = ? OR wallet_number = ?',
      whereArgs: [identifier, identifier],
      limit: 1,
    );

    if (result.isNotEmpty) {
      String? lastBalance = result.first['last_balance'] as String?;
      if (lastBalance != null && lastBalance.trim() == currentBalance.trim()) {
        return true;
      }
    }
    return false;
  }

  Future<void> updateCustomerBalance(String phone, String newBalance, {String? name, String? walletNumber}) async {
    await saveOrUpdateCustomer(
      phone,
      name: name,
      walletNumber: walletNumber,
      lastBalance: newBalance,
    );
  }

  Future<List<Map<String, dynamic>>> getAllCustomers() async {
    final db = await database;
    return await db.query(tableCustomers, orderBy: 'id DESC');
  }

  Future<String?> findCustomerPhoneByIdentifier(String textContent) async {
    final db = await database;
    List<Map<String, dynamic>> customers = await db.query(tableCustomers);

    for (var customer in customers) {
      String? customerName = customer['name'];
      String? walletNumber = customer['wallet_number'];

      if (customerName != null && customerName.trim().isNotEmpty) {
        if (textContent.toLowerCase().contains(customerName.toLowerCase())) {
          return customer['phone'] as String;
        }
      }

      if (walletNumber != null && walletNumber.trim().isNotEmpty) {
        if (textContent.contains(walletNumber.trim())) {
          return customer['phone'] as String;
        }
      }
    }
    return null;
  }

  Future<int> incrementCustomerCounter(String customerPhone, int keywordId) async {
    final db = await database;
    int now = DateTime.now().millisecondsSinceEpoch;

    await db.rawInsert('''
      INSERT INTO $tableCustomerVouchersCount (customer_phone, keyword_id, received_count, last_updated)
      VALUES (?, ?, 1, ?)
      ON CONFLICT(customer_phone, keyword_id) DO UPDATE SET
        received_count = received_count + 1,
        last_updated = ?
    ''', [customerPhone, keywordId, now, now]);

    List<Map<String, dynamic>> result = await db.query(
      tableCustomerVouchersCount,
      columns: ['received_count'],
      where: 'customer_phone = ? AND keyword_id = ?',
      whereArgs: [customerPhone, keywordId],
    );

    return result.first['received_count'] as int;
  }

  Future<void> resetCustomerCounter(String customerPhone, int keywordId) async {
    final db = await database;
    await db.update(
      tableCustomerVouchersCount,
      {
        'received_count': 0,
        'last_updated': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'customer_phone = ? AND keyword_id = ?',
      whereArgs: [customerPhone, keywordId],
    );
  }

  Future<List<Map<String, dynamic>>> getAllKeywords() async {
    final db = await database;
    return await db.query(tableKeywords, orderBy: 'id DESC');
  }

  Future<bool> addKeyword({
    required String keyword,
    String? description,
    int isOffer = 0,
    int targetCount = 0,
    int? rewardKeywordId,
    int rewardQty = 1,
  }) async {
    final db = await database;
    int result = await db.insert(tableKeywords, {
      'keyword': keyword,
      'description': description,
      'is_offer': isOffer,
      'target_count': targetCount,
      'reward_keyword_id': rewardKeywordId,
      'reward_qty': rewardQty,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    await clearNativeCache();
    return result != -1;
  }

  Future<bool> updateKeyword({
    required int id,
    required String keyword,
    String? description,
    required int isActive,
    int targetCount = 0,
    int? rewardKeywordId,
    int rewardQty = 1,
  }) async {
    final db = await database;
    int result = await db.update(
      tableKeywords,
      {
        'keyword': keyword,
        'description': description,
        'is_active': isActive,
        'target_count': targetCount,
        'reward_keyword_id': rewardKeywordId,
        'reward_qty': rewardQty,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    await clearNativeCache();
    return result > 0;
  }

  Future<bool> deleteKeyword(int id) async {
    final db = await database;
    await db.delete(tableNumbersPool, where: 'keyword_id = ?', whereArgs: [id]);
    int result = await db.delete(tableKeywords, where: 'id = ?', whereArgs: [id]);
    await clearNativeCache();
    return result > 0;
  }

  Future<List<Map<String, dynamic>>> getAllNumbers() async {
    final db = await database;
    return await db.query(tableNumbersPool, orderBy: 'id DESC');
  }

  Future<bool> addNumber(int keywordId, String numberCode) async {
    final db = await database;
    int result = await db.insert(
      tableNumbersPool,
      {
        'keyword_id': keywordId,
        'number_code': numberCode,
        'status': 'available',
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    return result != -1;
  }

  Future<Map<String, dynamic>?> getAndUseVoucher(int keywordId, String assignedToPhone) async {
    final db = await database;

    List<Map<String, dynamic>> results = await db.query(
      tableNumbersPool,
      where: 'keyword_id = ? AND status = ?',
      whereArgs: [keywordId, 'available'],
      limit: 1,
    );

    if (results.isEmpty) return null;

    Map<String, dynamic> voucher = results.first;
    int voucherId = voucher['id'];

    await db.update(
      tableNumbersPool,
      {
        'status': 'used',
        'assigned_to': assignedToPhone,
        'assigned_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [voucherId],
    );

    return voucher;
  }

  Future<String?> getAndUseVoucherByKeyword(String keyword, String customerPhone) async {
    final db = await database;

    List<Map<String, dynamic>> kwResult = await db.query(
      tableKeywords,
      columns: ['id'],
      where: 'keyword = ? AND is_active = 1',
      whereArgs: [keyword],
      limit: 1,
    );

    if (kwResult.isEmpty) return null;

    int keywordId = kwResult.first['id'] as int;
    Map<String, dynamic>? voucher = await getAndUseVoucher(keywordId, customerPhone);

    if (voucher != null) {
      return voucher['number_code'] as String;
    }

    return null;
  }

  Future<bool> isSenderAllowed(String sender) async {
    final db = await database;
    String cleanSender = sender.replaceAll(RegExp(r'[^0-9]'), '');

    List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT 1 FROM $tableAllowedSenders 
      WHERE is_active = 1 AND (sender = ? OR REPLACE(REPLACE(sender, '+', ''), '-', '') = ?)
    ''', [sender, cleanSender]);

    return result.isNotEmpty;
  }

  Future<bool> addSender(String sender, String? name, String senderType) async {
    final db = await database;
    int result = await db.insert(tableAllowedSenders, {
      'sender': sender,
      'name': name ?? sender,
      'sender_type': senderType,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    await clearNativeCache();
    return result != -1;
  }

  Future<bool> addToArchive({
    required String sender,
    String? senderName,
    required String receivedMessage,
    String? matchedKeyword,
    String? sentNumber,
    String status = 'sent',
    String source = 'Noti',
    String? extraData,
  }) async {
    final db = await database;
    int result = await db.insert(tableReplyLog, {
      'sender': sender,
      'sender_name': senderName ?? '',
      'received_message': receivedMessage,
      'matched_keyword': matchedKeyword ?? '',
      'sent_number': sentNumber ?? '',
      'source': source,
      'extra_data': extraData ?? '',
      'status': status,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    return result != -1;
  }

  Future<String> getSetting(String key, String defaultValue) async {
    final db = await database;
    List<Map<String, dynamic>> result = await db.query(
      tableSettings,
      columns: ['setting_value'],
      where: 'setting_key = ?',
      whereArgs: [key],
    );
    if (result.isNotEmpty) {
      return result.first['setting_value'] ?? defaultValue;
    }
    return defaultValue;
  }

  Future<bool> updateSetting(String key, String value) async {
    final db = await database;
    int result = await db.insert(
      tableSettings,
      {'setting_key': key, 'setting_value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await clearNativeCache();
    return result != -1;
  }

  Future<List<Map<String, dynamic>>> getPendingLogs() async {
    final db = await database;
    return await db.query(
      tableReplyLog,
      where: "status = 'manual_approval_required'",
      orderBy: 'timestamp DESC',
    );
  }

  Future<Map<String, dynamic>?> getCustomerByPhone(String phone) async {
    final db = await database;

    // 1. البحث أولاً في جدول العملاء الرئيسي بواسطة رقم الهاتف
    final mainResult = await db.query(
      'customers',
      where: 'phone = ?',
      whereArgs: [phone],
      limit: 1,
    );

    if (mainResult.isNotEmpty) {
      return mainResult.first;
    }

    // 2. إذا لم يوجد، نبحث في جدول المعرفات (client_identifiers)
    final identifierResult = await db.rawQuery('''
      SELECT c.* FROM customers c
      INNER JOIN client_identifiers ci ON c.id = ci.client_id
      WHERE ci.identifier = ?
      LIMIT 1
    ''', [phone]);

    if (identifierResult.isNotEmpty) {
      return identifierResult.first;
    }

    return null;
  }

  /// البحث عن عميل بواسطة الاسم أو المعرف (في جدول العملاء أو جدول المعرفات)
  Future<Map<String, dynamic>?> getCustomerByNameOrIdentifier(String nameOrIdentifier) async {
    final db = await database;

    // 1. البحث أولاً في جدول العملاء الرئيسي (بالاسم أو الهاتف)
    final mainResult = await db.query(
      'customers',
      where: 'name = ? OR phone = ?',
      whereArgs: [nameOrIdentifier, nameOrIdentifier],
      limit: 1,
    );

    if (mainResult.isNotEmpty) {
      return mainResult.first;
    }

    // 2. إذا لم يوجد، نلجأ للبحث في جدول المعرفات (client_identifiers)
    final identifierResult = await db.rawQuery('''
      SELECT c.* FROM customers c
      INNER JOIN client_identifiers ci ON c.id = ci.client_id
      WHERE ci.identifier = ?
      LIMIT 1
    ''', [nameOrIdentifier]);

    if (identifierResult.isNotEmpty) {
      return identifierResult.first;
    }

    return null;
  }
  
  Future<bool> resolvePendingLog({
    required int logId,
    required String customerPhone,
    required String customerName,
    String? walletNumber,
    required String voucherCode,
  }) async {
    final db = await database;

  

    /*await saveOrUpdateCustomer(
      customerPhone,
      name: customerName,
      walletNumber: walletNumber,
    );*/

    await db.update(
      tableNumbersPool,
      {
        'status': 'used',
        'assigned_to': customerPhone,
        'assigned_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'number_code = ?',
      whereArgs: [voucherCode],
    );

    await db.update(
      tableReplyLog,
      {
        'sender': customerPhone,
        'sender_name': customerName,
        'status': 'sent_manual',
      },
      where: 'id = ?',
      whereArgs: [logId],
    );

    return true;
  }
}
/*import 'dart:async';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static const String _databaseName = "smsqaiddb.db";
  static const int _databaseVersion = 11;
  static const MethodChannel _nativeChannel = MethodChannel('com.example.pr19/cache');

  static const String tableKeywords = "keywords";
  static const String tableNumbersPool = "numbers_pool";
  static const String tableAllowedSenders = "allowed_senders";
  static const String tableReplyLog = "reply_log";
  static const String tableSettings = "settings";
  static const String tableOffers = "offers";
  static const String tableCustomerVouchersCount = "customer_vouchers_count";
  static const String tableCustomers = "customers";

  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// ⭐ إخطار كود Kotlin لتصفير AppCache فور تحديث أي إعداد أو كلمة مفتاحية من Flutter
  Future<void> clearNativeCache() async {
    try {
      await _nativeChannel.invokeMethod('clearCache');
    } catch (_) {}
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  } 

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableKeywords (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        keyword TEXT NOT NULL UNIQUE,
        description TEXT,
        is_active INTEGER DEFAULT 1,
        is_offer INTEGER DEFAULT 0,
        target_count INTEGER DEFAULT 0,
        reward_keyword_id INTEGER,
        reward_qty INTEGER DEFAULT 1,
        created_at INTEGER,
        FOREIGN KEY(reward_keyword_id) REFERENCES $tableKeywords(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableNumbersPool (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        keyword_id INTEGER NOT NULL,
        number_code TEXT NOT NULL UNIQUE,
        status TEXT DEFAULT 'available',
        assigned_to TEXT,
        assigned_at INTEGER,
        FOREIGN KEY(keyword_id) REFERENCES $tableKeywords(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableAllowedSenders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sender TEXT NOT NULL UNIQUE,
        name TEXT,
        sender_type TEXT DEFAULT 'phone',
        is_active INTEGER DEFAULT 1,
        created_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableReplyLog (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sender TEXT,
        sender_name TEXT,
        received_message TEXT,
        matched_keyword TEXT,
        sent_number TEXT,
        source TEXT DEFAULT 'Noti',
        extra_data TEXT,
        status TEXT,
        timestamp INTEGER,
        is_deleted INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableSettings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        setting_key TEXT NOT NULL UNIQUE,
        setting_value TEXT,
        category TEXT DEFAULT 'general'
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableOffers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        offer_keyword_id INTEGER NOT NULL,
        linked_keyword_id INTEGER NOT NULL,
        is_active INTEGER DEFAULT 1,
        FOREIGN KEY(offer_keyword_id) REFERENCES $tableKeywords(id),
        FOREIGN KEY(linked_keyword_id) REFERENCES $tableKeywords(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableCustomerVouchersCount (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_phone TEXT NOT NULL,
        keyword_id INTEGER NOT NULL,
        received_count INTEGER DEFAULT 0,
        last_updated INTEGER,
        FOREIGN KEY(keyword_id) REFERENCES $tableKeywords(id) ON DELETE CASCADE,
        UNIQUE(customer_phone, keyword_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableCustomers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        phone TEXT NOT NULL UNIQUE,
        name TEXT,
        wallet_number TEXT,
        last_balance TEXT,
        created_at INTEGER
      )
    ''');

    // ✅ تم تعديل اسم جدول العملاء ليستخدم المتغير $tableCustomers
    await db.execute('''
      CREATE TABLE IF NOT EXISTS client_identifiers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        client_id INTEGER NOT NULL,
        identifier TEXT NOT NULL UNIQUE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (client_id) REFERENCES $tableCustomers (id) ON DELETE CASCADE
      );
    ''');
    

    await _createIndexes(db);
    await _insertDefaultSettings(db);
  }

  Future<void> _createIndexes(Database db) async {
    await db.execute("CREATE INDEX IF NOT EXISTS idx_customers_phone_wallet ON $tableCustomers(phone, wallet_number)");
    await db.execute("CREATE INDEX IF NOT EXISTS idx_numbers_pool_kw_status ON $tableNumbersPool(keyword_id, status)");
    await db.execute("CREATE INDEX IF NOT EXISTS idx_keywords_active ON $tableKeywords(is_active)");
    await db.execute("CREATE INDEX IF NOT EXISTS idx_allowed_senders ON $tableAllowedSenders(is_active, sender)");
    // إنشاء Index فائق السرعة للبحث عن النص
    await db.execute('CREATE INDEX IF NOT EXISTS idx_identifier ON client_identifiers(identifier);');

  }

  Future<void> _insertDefaultSettings(Database db) async {
    final batch = db.batch();
    batch.insert(tableSettings, {'setting_key': 'offers_enabled', 'setting_value': 'true', 'category': 'general'}, conflictAlgorithm: ConflictAlgorithm.ignore);
    batch.insert(tableSettings, {'setting_key': 'service_enabled', 'setting_value': 'true', 'category': 'general'}, conflictAlgorithm: ConflictAlgorithm.ignore);
    batch.insert(tableSettings, {'setting_key': 'default_reply', 'setting_value': 'شكراً لتواصلك. رقمك الخاص هو: ', 'category': 'general'}, conflictAlgorithm: ConflictAlgorithm.ignore);
    batch.insert(tableSettings, {'setting_key': 'allow_all_senders', 'setting_value': 'false', 'category': 'security'}, conflictAlgorithm: ConflictAlgorithm.ignore);
    batch.insert(tableAllowedSenders, {'sender': 'Jaib', 'name': 'Jaib', 'sender_type': 'name', 'is_active': 1}, conflictAlgorithm: ConflictAlgorithm.ignore);
    batch.insert(tableAllowedSenders, {'sender': 'com.ahd.jaib', 'name': 'Jaib إشعارات', 'sender_type': 'name', 'is_active': 1}, conflictAlgorithm: ConflictAlgorithm.ignore);

    await batch.commit(noResult: true);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 8) {
      await db.execute("ALTER TABLE $tableKeywords ADD COLUMN target_count INTEGER DEFAULT 0");
      await db.execute("ALTER TABLE $tableKeywords ADD COLUMN reward_keyword_id INTEGER");
      await db.execute("ALTER TABLE $tableKeywords ADD COLUMN reward_qty INTEGER DEFAULT 1");

      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableCustomerVouchersCount (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          customer_phone TEXT NOT NULL,
          keyword_id INTEGER NOT NULL,
          received_count INTEGER DEFAULT 0,
          last_updated INTEGER,
          FOREIGN KEY(keyword_id) REFERENCES $tableKeywords(id) ON DELETE CASCADE,
          UNIQUE(customer_phone, keyword_id)
        )
      ''');
    }

    if (oldVersion < 9) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableCustomers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          phone TEXT NOT NULL UNIQUE,
          name TEXT,
          created_at INTEGER
        )
      ''');
    }

    if (oldVersion < 10) {
      await db.execute("ALTER TABLE $tableCustomers ADD COLUMN wallet_number TEXT;");
    }

    if (oldVersion < 11) {
      await db.execute("ALTER TABLE $tableCustomers ADD COLUMN last_balance TEXT;");
    }

    await _createIndexes(db);
  }

  Future<void> saveOrUpdateCustomer(String phone, {String? name, String? walletNumber, String? lastBalance}) async {
    final db = await database;
    int now = DateTime.now().millisecondsSinceEpoch;

    await db.rawInsert('''
      INSERT INTO $tableCustomers (phone, name, wallet_number, last_balance, created_at)
      VALUES (?, ?, ?, ?, ?)
      ON CONFLICT(phone) DO UPDATE SET
        name = COALESCE(EXCLUDED.name, name),
        wallet_number = COALESCE(EXCLUDED.wallet_number, wallet_number),
        last_balance = COALESCE(EXCLUDED.last_balance, last_balance)
    ''', [phone, name ?? 'عميل جديد', walletNumber, lastBalance, now]);
  }

  Future<bool> isDuplicateBalance(String identifier, String currentBalance) async {
    final db = await database;
    
    List<Map<String, dynamic>> result = await db.query(
      tableCustomers,
      columns: ['last_balance'],
      where: 'phone = ? OR wallet_number = ?',
      whereArgs: [identifier, identifier],
      limit: 1,
    );

    if (result.isNotEmpty) {
      String? lastBalance = result.first['last_balance'] as String?;
      if (lastBalance != null && lastBalance.trim() == currentBalance.trim()) {
        return true;
      }
    }
    return false;
  }

  Future<void> updateCustomerBalance(String phone, String newBalance, {String? name, String? walletNumber}) async {
    await saveOrUpdateCustomer(
      phone,
      name: name,
      walletNumber: walletNumber,
      lastBalance: newBalance,
    );
  }

  Future<List<Map<String, dynamic>>> getAllCustomers() async {
    final db = await database;
    return await db.query(tableCustomers, orderBy: 'id DESC');
  }

  Future<String?> findCustomerPhoneByIdentifier(String textContent) async {
    final db = await database;
    List<Map<String, dynamic>> customers = await db.query(tableCustomers);

    for (var customer in customers) {
      String? customerName = customer['name'];
      String? walletNumber = customer['wallet_number'];

      if (customerName != null && customerName.trim().isNotEmpty) {
        if (textContent.toLowerCase().contains(customerName.toLowerCase())) {
          return customer['phone'] as String;
        }
      }

      if (walletNumber != null && walletNumber.trim().isNotEmpty) {
        if (textContent.contains(walletNumber.trim())) {
          return customer['phone'] as String;
        }
      }
    }
    return null;
  }

  Future<int> incrementCustomerCounter(String customerPhone, int keywordId) async {
    final db = await database;
    int now = DateTime.now().millisecondsSinceEpoch;

    await db.rawInsert('''
      INSERT INTO $tableCustomerVouchersCount (customer_phone, keyword_id, received_count, last_updated)
      VALUES (?, ?, 1, ?)
      ON CONFLICT(customer_phone, keyword_id) DO UPDATE SET
        received_count = received_count + 1,
        last_updated = ?
    ''', [customerPhone, keywordId, now, now]);

    List<Map<String, dynamic>> result = await db.query(
      tableCustomerVouchersCount,
      columns: ['received_count'],
      where: 'customer_phone = ? AND keyword_id = ?',
      whereArgs: [customerPhone, keywordId],
    );

    return result.first['received_count'] as int;
  }

  Future<void> resetCustomerCounter(String customerPhone, int keywordId) async {
    final db = await database;
    await db.update(
      tableCustomerVouchersCount,
      {
        'received_count': 0,
        'last_updated': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'customer_phone = ? AND keyword_id = ?',
      whereArgs: [customerPhone, keywordId],
    );
  }

  Future<List<Map<String, dynamic>>> getAllKeywords() async {
    final db = await database;
    return await db.query(tableKeywords, orderBy: 'id DESC');
  }

  Future<bool> addKeyword({
    required String keyword,
    String? description,
    int isOffer = 0,
    int targetCount = 0,
    int? rewardKeywordId,
    int rewardQty = 1,
  }) async {
    final db = await database;
    int result = await db.insert(tableKeywords, {
      'keyword': keyword,
      'description': description,
      'is_offer': isOffer,
      'target_count': targetCount,
      'reward_keyword_id': rewardKeywordId,
      'reward_qty': rewardQty,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    await clearNativeCache();
    return result != -1;
  }

  Future<bool> updateKeyword({
    required int id,
    required String keyword,
    String? description,
    required int isActive,
    int targetCount = 0,
    int? rewardKeywordId,
    int rewardQty = 1,
  }) async {
    final db = await database;
    int result = await db.update(
      tableKeywords,
      {
        'keyword': keyword,
        'description': description,
        'is_active': isActive,
        'target_count': targetCount,
        'reward_keyword_id': rewardKeywordId,
        'reward_qty': rewardQty,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    await clearNativeCache();
    return result > 0;
  }

  Future<bool> deleteKeyword(int id) async {
    final db = await database;
    await db.delete(tableNumbersPool, where: 'keyword_id = ?', whereArgs: [id]);
    int result = await db.delete(tableKeywords, where: 'id = ?', whereArgs: [id]);
    await clearNativeCache();
    return result > 0;
  }

  Future<List<Map<String, dynamic>>> getAllNumbers() async {
    final db = await database;
    return await db.query(tableNumbersPool, orderBy: 'id DESC');
  }

  Future<bool> addNumber(int keywordId, String numberCode) async {
    final db = await database;
    int result = await db.insert(
      tableNumbersPool,
      {
        'keyword_id': keywordId,
        'number_code': numberCode,
        'status': 'available',
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    return result != -1;
  }

  Future<Map<String, dynamic>?> getAndUseVoucher(int keywordId, String assignedToPhone) async {
    final db = await database;

    List<Map<String, dynamic>> results = await db.query(
      tableNumbersPool,
      where: 'keyword_id = ? AND status = ?',
      whereArgs: [keywordId, 'available'],
      limit: 1,
    );

    if (results.isEmpty) return null;

    Map<String, dynamic> voucher = results.first;
    int voucherId = voucher['id'];

    await db.update(
      tableNumbersPool,
      {
        'status': 'used',
        'assigned_to': assignedToPhone,
        'assigned_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [voucherId],
    );

    return voucher;
  }

  Future<String?> getAndUseVoucherByKeyword(String keyword, String customerPhone) async {
    final db = await database;

    List<Map<String, dynamic>> kwResult = await db.query(
      tableKeywords,
      columns: ['id'],
      where: 'keyword = ? AND is_active = 1',
      whereArgs: [keyword],
      limit: 1,
    );

    if (kwResult.isEmpty) return null;

    int keywordId = kwResult.first['id'] as int;
    Map<String, dynamic>? voucher = await getAndUseVoucher(keywordId, customerPhone);

    if (voucher != null) {
      return voucher['number_code'] as String;
    }

    return null;
  }
  
  Future<bool> isSenderAllowed(String sender) async {
    final db = await database;
    String cleanSender = sender.replaceAll(RegExp(r'[^0-9]'), '');

    List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT 1 FROM $tableAllowedSenders 
      WHERE is_active = 1 AND (sender = ? OR REPLACE(REPLACE(sender, '+', ''), '-', '') = ?)
    ''', [sender, cleanSender]);

    return result.isNotEmpty;
  }

  Future<bool> addSender(String sender, String? name, String senderType) async {
    final db = await database;
    int result = await db.insert(tableAllowedSenders, {
      'sender': sender,
      'name': name ?? sender,
      'sender_type': senderType,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    await clearNativeCache();
    return result != -1;
  }

  Future<bool> addToArchive({
    required String sender,
    String? senderName,
    required String receivedMessage,
    String? matchedKeyword,
    String? sentNumber,
    String status = 'sent',
    String source = 'Noti',
    String? extraData,
  }) async {
    final db = await database;
    int result = await db.insert(tableReplyLog, {
      'sender': sender,
      'sender_name': senderName ?? '',
      'received_message': receivedMessage,
      'matched_keyword': matchedKeyword ?? '',
      'sent_number': sentNumber ?? '',
      'source': source,
      'extra_data': extraData ?? '',
      'status': status,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    return result != -1;
  }

  Future<String> getSetting(String key, String defaultValue) async {
    final db = await database;
    List<Map<String, dynamic>> result = await db.query(
      tableSettings,
      columns: ['setting_value'],
      where: 'setting_key = ?',
      whereArgs: [key],
    );
    if (result.isNotEmpty) {
      return result.first['setting_value'] ?? defaultValue;
    }
    return defaultValue;
  }

  Future<bool> updateSetting(String key, String value) async {
    final db = await database;
    int result = await db.insert(
      tableSettings,
      {'setting_key': key, 'setting_value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await clearNativeCache();
    return result != -1;
  }

  Future<List<Map<String, dynamic>>> getPendingLogs() async {
    final db = await database;
    return await db.query(
      tableReplyLog,
      where: "status = 'manual_approval_required'",
      orderBy: 'timestamp DESC',
    );
  }

  Future<bool> resolvePendingLog({
    required int logId,
    required String customerPhone,
    required String customerName,
    String? walletNumber,
    required String voucherCode,
  }) async {
    final db = await database;

    await saveOrUpdateCustomer(
      customerPhone,
      name: customerName,
      walletNumber: walletNumber,
    );

    await db.update(
      tableNumbersPool,
      {
        'status': 'used',
        'assigned_to': customerPhone,
        'assigned_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'number_code = ?',
      whereArgs: [voucherCode],
    );

    await db.update(
      tableReplyLog,
      {
        'sender': customerPhone,
        'sender_name': customerName,
        'status': 'sent_manual',
      },
      where: 'id = ?',
      whereArgs: [logId],
    );

    return true;
  }
}*/