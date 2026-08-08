import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageHelper {
    // 🌟 إجبار المكتبة على استخدام EncryptedSharedPreferences
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      sharedPreferencesName: 'FlutterEncryptedStorage', // ضمان القراءة من نفس الملف المحدد في Kotlin
      preferencesKeyPrefix: 'VGhpcyBpcyB0aGUga2V5IGZvciBhIHNlY3VyZSBzdG9yYWdl', // تثبيت البادئة
    ),
  );
  //static const _storage = FlutterSecureStorage();

  // المفاتيح المخصصة لحفظ البيانات المشفرة
  static const String _keyDeviceId = 'device_id';
  static const String _keyPlanType = 'plan_type';
  static const String _keyExpiryDate = 'expiry_date';
  static const String _keyVouchersLimit = 'vouchers_limit';
  static const String _keyVouchersUsed = 'vouchers_used';
  static const String _keyLastKnownTime = 'last_known_time';
  static const String _keyNeedsSync = 'needs_sync';
  static const String _keyAppliedKey = 'applied_key';

  /// 1. حفظ بيانات الترخيص محلياً (تُستدعى عند التفعيل أونلاين أو أوفلاين)
  static Future<void> saveLicenseData({
    required String deviceId,
    required String planType,
    required int expiryDateMs,
    int vouchersLimit = -1,
    int vouchersUsed = 0,
    bool needsSync = false,
    String? appliedKey,
  }) async {
    await _storage.write(key: _keyDeviceId, value: deviceId);
    await _storage.write(key: _keyPlanType, value: planType);
    await _storage.write(key: _keyExpiryDate, value: expiryDateMs.toString());
    await _storage.write(key: _keyVouchersLimit, value: vouchersLimit.toString());
    await _storage.write(key: _keyVouchersUsed, value: vouchersUsed.toString());
    
    // حفظ وقت آمن ابتدائي
    int now = DateTime.now().millisecondsSinceEpoch;
    await _storage.write(key: _keyLastKnownTime, value: now.toString());
    
    await _storage.write(key: _keyNeedsSync, value: needsSync.toString());
    if (appliedKey != null) {
      await _storage.write(key: _keyAppliedKey, value: appliedKey);
    }
  }

  /// 7. جلب بيانات الترخيص جاهزة للعرض في الواجهة (Dashboard)
  static Future<Map<String, dynamic>> getLicenseDetailsForUI() async {
    final deviceId = await _storage.read(key: _keyDeviceId) ?? 'غير معروف';
    final planType = await _storage.read(key: _keyPlanType) ?? 'trial';
    final expiryStr = await _storage.read(key: _keyExpiryDate);
    final limitStr = await _storage.read(key: _keyVouchersLimit);
    final usedStr = await _storage.read(key: _keyVouchersUsed);

    // حساب الأيام المتبقية
    int remainingDays = 0;
    if (expiryStr != null) {
        int expiryMs = int.tryParse(expiryStr) ?? 0;
        int nowMs = DateTime.now().millisecondsSinceEpoch;
        if (expiryMs > nowMs) {
        remainingDays = ((expiryMs - nowMs) / (1000 * 60 * 60 * 24)).ceil();
        }
    }

    // حساب القسائم / الرسائل المتبقية
    int limit = int.tryParse(limitStr ?? '-1') ?? -1;
    int used = int.tryParse(usedStr ?? '0') ?? 0;
    
    // إذا كان الحد -1 يعبر عن غير محدود (دائم/غير محدود)
    int remainingVouchers = (limit == -1) ? -1 : (limit - used).clamp(0, limit);

    return {
        'deviceId': deviceId,
        'planType': planType,
        'remainingDays': remainingDays,
        'remainingVouchers': remainingVouchers,
        'isTrial': planType == 'trial',
    };
  }
  /// 2. زيادة عداد القسائم المستهلكة بمقدار 1 عند كل عملية بيع/طباعة
  static Future<void> incrementVouchersUsed() async {
    String? usedStr = await _storage.read(key: _keyVouchersUsed);
    int current = int.tryParse(usedStr ?? '0') ?? 0;
    await _storage.write(key: _keyVouchersUsed, value: (current + 1).toString());
  }

  /// 3. التحقق المحلي الشامل من صلاحية الترخيص (Offline Validation)
  static Future<Map<String, dynamic>> checkLocalLicenseValid() async {
    String? expiryStr = await _storage.read(key: _keyExpiryDate);
    String? lastTimeStr = await _storage.read(key: _keyLastKnownTime);
    String? limitStr = await _storage.read(key: _keyVouchersLimit);
    String? usedStr = await _storage.read(key: _keyVouchersUsed);

    // إذا لم تكن هناك بيانات ترخيص محفوظة سابقاً
    if (expiryStr == null) {
      return {'isValid': false, 'reason': 'NO_LICENSE'};
    }

    int expiryDate = int.parse(expiryStr);
    int lastKnownTime = int.parse(lastTimeStr ?? '0');
    int limit = int.parse(limitStr ?? '-1');
    int used = int.parse(usedStr ?? '0');

    int now = DateTime.now().millisecondsSinceEpoch;

    // 🔒 أ) فحص محاولة التلاعب بالوقت (إرجاع تاريخ الجوال للخلف)
    if (now < lastKnownTime) {
      return {'isValid': false, 'reason': 'TIME_TAMPERED'};
    }

    // 🔒 ب) فحص تاريخ الانتهاء
    if (now > expiryDate) {
      return {'isValid': false, 'reason': 'EXPIRED'};
    }

    // 🔒 ج) فحص استهلاك القسائم (إن وجد حد مثل التجريبي)
    if (limit != -1 && used >= limit) {
      return {'isValid': false, 'reason': 'LIMIT_REACHED'};
    }

    // 🟢 الترخيص ساري والوقت طبيعي -> تحديث الوقت المرجعي بالوقت الحالي
    await _storage.write(key: _keyLastKnownTime, value: now.toString());

    return {
      'isValid': true,
      'reason': 'VALID',
      'vouchersLeft': limit == -1 ? -1 : (limit - used),
      'expiryDate': DateTime.fromMillisecondsSinceEpoch(expiryDate),
    };
  }

  /// 4. قراءة هل يوجد بيانات بحاجة للتزامن مع Firebase
  static Future<bool> checkIfNeedsSync() async {
    String? sync = await _storage.read(key: _keyNeedsSync);
    return sync == 'true';
  }

  /// 5. إلغاء علامة التزامن بعد نجاح الرفع لـ Firebase
  static Future<void> clearSyncFlag() async {
    await _storage.write(key: _keyNeedsSync, value: 'false');
  }

  /// 6. جلب بيانات الترخيص المسجلة محلياً (لغرض رفعها أثناء التزامن)
  static Future<Map<String, String?>> getLocalLicenseData() async {
    return {
      'deviceId': await _storage.read(key: _keyDeviceId),
      'planType': await _storage.read(key: _keyPlanType),
      'expiryDate': await _storage.read(key: _keyExpiryDate),
      'vouchersLimit': await _storage.read(key: _keyVouchersLimit),
      'vouchersUsed': await _storage.read(key: _keyVouchersUsed),
      'appliedKey': await _storage.read(key: _keyAppliedKey),
    };
  }
  /// 1.ب حفظ بيانات الترخيص من Map مباشرة (قادمة من الفايربيس أو SyncManager)
  /*static Future<void> saveLicenseDataFromMap(Map<String, dynamic> data) async {
    await saveLicenseData(
      deviceId: data['deviceId']?.toString() ?? '',
      planType: data['planType']?.toString() ?? 'trial',
      expiryDateMs: int.tryParse(data['expiryDate']?.toString() ?? '0') ?? 0,
      vouchersLimit: int.tryParse(data['vouchersLimit']?.toString() ?? '-1') ?? -1,
      vouchersUsed: int.tryParse(data['vouchersUsed']?.toString() ?? '0') ?? 0,
      needsSync: data['needsSync'] == true || data['needsSync'] == 'true',
      appliedKey: data['appliedKey']?.toString(),
    );
  }*/
  static Future<void> saveLicenseDataFromMap(Map<String, dynamic> data) async {
    // 1. قراءة القيم الآتية من فيربيس
    int rawLimit = int.tryParse(data['vouchersLimit']?.toString() ?? '-1') ?? -1;
    int rawUsed = int.tryParse(data['vouchersUsed']?.toString() ?? '0') ?? 0;

    // 2. حساب المتبقي الفعلي (إذا لم تكن الخطة غير محدودة -1)
    int calculatedLimit = rawLimit;
    if (rawLimit > -1) {
      calculatedLimit = rawLimit - rawUsed;
      if (calculatedLimit < 0) calculatedLimit = 0; // حماية من القيم السالبة
    }

    // 3. التمرير للدالة الحافظة
    await saveLicenseData(
      deviceId: data['deviceId']?.toString() ?? '',
      planType: data['planType']?.toString() ?? 'trial',
      expiryDateMs: int.tryParse(data['expiryDate']?.toString() ?? '0') ?? 0,
      vouchersLimit: calculatedLimit, // هنا سينتقل الرقم 199
      vouchersUsed: 0, // تصفير المستهلك المحلي لأن الحد أصبح يتضمن المتبقي فقط
      needsSync: data['needsSync'] == true || data['needsSync'] == 'true',
      appliedKey: data['appliedKey']?.toString(),
    );
  }
}