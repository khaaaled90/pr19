import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static const String _databaseName = "smsqaiddb.db";
  
  // رفع الإصدار إلى 11 لإضافة حقل last_balance الخاص بمنع التكرار لكل عميل
  static const int _databaseVersion = 11;

  // أسماء الجداول
  static const String tableKeywords = "keywords";
  static const String tableNumbersPool = "numbers_pool";
  static const String tableAllowedSenders = "allowed_senders";
  static const String tableReplyLog = "reply_log";
  static const String tableSettings = "settings";
  static const String tableOffers = "offers";
  static const String tableCustomerVouchersCount = "customer_vouchers_count";
  static const String tableCustomers = "customers";

  // نمط Singleton
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

  // ==========================================
  // 1. إنشاء الجداول (onCreate)
  // ==========================================
  Future<void> _onCreate(Database db, int version) async {
    // 1. جدول الكلمات المفتاحية
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

    // 2. جدول مخزون القسائم والأكواد
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

    // 3. جدول المرسلين المخولين (Whitelist)
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

    // 4. جدول أرشيف الردود
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

    // 5. جدول الإعدادات
    await db.execute('''
      CREATE TABLE $tableSettings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        setting_key TEXT NOT NULL UNIQUE,
        setting_value TEXT,
        category TEXT DEFAULT 'general'
      )
    ''');

    // 6. جدول العروض
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

    // 7. جدول عدادات المكافآت للعملاء
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

    // 8. جدول العملاء (يتضمن حقل last_balance لمنع التكرار)
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

    // إدخال الإعدادات والمرسلين الافتراضيين
    await _insertDefaultSettings(db);
  }

  Future<void> _insertDefaultSettings(Database db) async {
    final batch = db.batch();
    batch.insert(
        tableSettings,
        {
          'setting_key': 'offers_enabled',
          'setting_value': 'true',
          'category': 'general'
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    batch.insert(
        tableSettings,
        {
          'setting_key': 'service_enabled',
          'setting_value': 'true',
          'category': 'general'
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    batch.insert(
        tableSettings,
        {
          'setting_key': 'default_reply',
          'setting_value': 'شكراً لتواصلك. رقمك الخاص هو: ',
          'category': 'general'
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    batch.insert(
        tableSettings,
        {
          'setting_key': 'allow_all_senders',
          'setting_value': 'false',
          'category': 'security'
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);

    // المرسلين الافتراضيين
    batch.insert(
        tableAllowedSenders,
        {
          'sender': 'Jaib',
          'name': 'Jaib',
          'sender_type': 'name',
          'is_active': 1
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    batch.insert(
        tableAllowedSenders,
        {
          'sender': 'com.ahd.jaib',
          'name': 'Jaib إشعارات',
          'sender_type': 'name',
          'is_active': 1
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);

    await batch.commit(noResult: true);
  }

  // ==========================================
  // 2. ترقية قاعدة البيانات (onUpgrade)
  // ==========================================
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 8) {
      await db.execute(
          "ALTER TABLE $tableKeywords ADD COLUMN target_count INTEGER DEFAULT 0");
      await db.execute(
          "ALTER TABLE $tableKeywords ADD COLUMN reward_keyword_id INTEGER");
      await db.execute(
          "ALTER TABLE $tableKeywords ADD COLUMN reward_qty INTEGER DEFAULT 1");

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
      await db.execute(
          "ALTER TABLE $tableCustomers ADD COLUMN wallet_number TEXT;");
    }

    if (oldVersion < 11) {
      // إضافة حقل last_balance لجدول العملاء لمنع تكرار الإشعار لكل رقم
      await db.execute(
          "ALTER TABLE $tableCustomers ADD COLUMN last_balance TEXT;");
    }
  }

  // ==========================================
  // 3. دوال إدارة العملاء وآلية منع التكرار (Anti-Duplication)
  // ==========================================

  /// إضافة عميل جديد أو تحديث بياناته مع حفظ آخر رصيد (UPSERT)
  Future<void> saveOrUpdateCustomer(String phone,
      {String? name, String? walletNumber, String? lastBalance}) async {
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

  /// فحص ما إذا كان الرصيد مكرراً لنفس العميل (عبر رقم الهاتف أو المحفظة)
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
        return true; // العملية مكررة لنفس العميل
      }
    }
    return false; // رصيد جديد أو عميل غير مسجل سابقاً
  }

  /// تحديث رصيد العميل بعد معالجة العملية بنجاح (إنشاء العميل تلقائياً إن لم يوجد)
  Future<void> updateCustomerBalance(String phone, String newBalance,
      {String? name, String? walletNumber}) async {
    await saveOrUpdateCustomer(
      phone,
      name: name,
      walletNumber: walletNumber,
      lastBalance: newBalance,
    );
  }

  /// جلب قائمة جميع العملاء لعرضهم في الواجهات
  Future<List<Map<String, dynamic>>> getAllCustomers() async {
    final db = await database;
    return await db.query(tableCustomers, orderBy: 'id DESC');
  }

  /// البحث عن رقم هاتف العميل عبر اسمه أو رقم محفظته داخل نص الرسالة/الإشعار
  Future<String?> findCustomerPhoneByIdentifier(String textContent) async {
    final db = await database;
    List<Map<String, dynamic>> customers = await db.query(tableCustomers);

    for (var customer in customers) {
      String? customerName = customer['name'];
      String? walletNumber = customer['wallet_number'];

      // 1. الفحص باسم العميل
      if (customerName != null && customerName.trim().isNotEmpty) {
        if (textContent.toLowerCase().contains(customerName.toLowerCase())) {
          return customer['phone'] as String;
        }
      }

      // 2. الفحص برقم المحفظة
      if (walletNumber != null && walletNumber.trim().isNotEmpty) {
        if (textContent.contains(walletNumber.trim())) {
          return customer['phone'] as String;
        }
      }
    }
    return null; // لم يتم العثور على مطابقة
  }

  // ==========================================
  // 4. دوال نظام المكافآت والعدادات (Rewards)
  // ==========================================

  /// زيادة العداد وإرجاع القيمة الحالية
  Future<int> incrementCustomerCounter(
      String customerPhone, int keywordId) async {
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

  /// تصفير العداد بعد منح المكافأة
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

  // ==========================================
  // 5. دوال الكلمات المفتاحية والقواعد (Keywords)
  // ==========================================
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
    return result > 0;
  }

  Future<bool> deleteKeyword(int id) async {
    final db = await database;
    await db.delete(tableNumbersPool, where: 'keyword_id = ?', whereArgs: [id]);
    int result =
        await db.delete(tableKeywords, where: 'id = ?', whereArgs: [id]);
    return result > 0;
  }

  // ==========================================
  // 6. دوال إدارة الأرقام والقسائم (Numbers Pool)
  // ==========================================
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

  /// سحب قسيمة متاحة وتحديث حالتها فوراً لمستخدمة
  Future<Map<String, dynamic>?> getAndUseVoucher(
      int keywordId, String assignedToPhone) async {
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

  //==========================================================
  /// سحب أول قسيمة متاحة بناءً على النص (Keyword) وتحديث حالتها فوراً لمستخدمة
  //===========================================================
  Future<String?> getAndUseVoucherByKeyword(String keyword, String customerPhone) async {
    final db = await database;

    // 1. البحث عن ID الكلمة المفتاحية من جدول keywords
    List<Map<String, dynamic>> kwResult = await db.query(
      tableKeywords,
      columns: ['id'],
      where: 'keyword = ? AND is_active = 1',
      whereArgs: [keyword],
      limit: 1,
    );

    if (kwResult.isEmpty) return null; // الكلمة المفتاحية غير موجودة أو غير مفعلة

    int keywordId = kwResult.first['id'] as int;

    // 2. استخدام داللتك الجاهزة (getAndUseVoucher) لسحب الكرت وتعديل حالته إلى used
    Map<String, dynamic>? voucher = await getAndUseVoucher(keywordId, customerPhone);

    if (voucher != null) {
      return voucher['number_code'] as String; // إرجاع كود القسيمة
    }

    return null; // لا توجد قسائم متاحة لهذه الفئة
  }
  
  // ==========================================
  // 7. دوال المرسلين المسموحين والأرشيف
  // ==========================================
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
    return result != -1;
  }

  /// جلب كافة العمليات المعلقة التي تنتظر ربط رقم الهاتف
  Future<List<Map<String, dynamic>>> getPendingLogs() async {
    final db = await database;
    return await db.query(
      tableReplyLog,
      where: "status = 'manual_approval_required'",
      orderBy: 'timestamp DESC',
    );
  }

  /// إكمال العملية المعلقة: ربط الاسم أو رقم المحفظة بالرقم وإرسال القسيمة وتحديث السجل
  Future<bool> resolvePendingLog({
    required int logId,
    required String customerPhone,
    required String customerName,
    String? walletNumber,
    required String voucherCode,
  }) async {
    final db = await database;

    // 1. حفظ العميل الجديد أو تحديث بياناته ورقم محفظته
    await saveOrUpdateCustomer(
      customerPhone,
      name: customerName,
      walletNumber: walletNumber,
    );

    // 2. تحديث حالة القسيمة المسحوبة وتحديد من أخذها
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

    // 3. تحديث حالة الأرشيف إلى إرسال بنجاح
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
