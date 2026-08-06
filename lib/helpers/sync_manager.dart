import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'device_utils.dart';
import 'secure_storage_helper.dart';

class SyncManager {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 1. التحقق الشامل من الترخيص (Firebase Online + Local Offline Failover)
  static Future<Map<String, dynamic>> checkAndSyncLicense() async {
    String deviceId = await DeviceUtils.getDeviceId();

    // فحص الاتصال بالإنترنت
    var connectivity = await Connectivity().checkConnectivity();
    bool isOnline = !connectivity.contains(ConnectivityResult.none);

    if (isOnline) {
      try {
        // أ) محاولة رفع التفعيل الأوفلاين إن وجد كود معلق
        await _uploadPendingOfflineActivation(deviceId);

        // ب) جلب بيانات الترخيص الحالية المحدثة من Firebase
        DocumentSnapshot doc =
            await _firestore.collection('licenses').doc(deviceId).get();

        if (doc.exists && doc.data() != null) {
          var data = doc.data() as Map<String, dynamic>;

          bool isActive = data['is_active'] ?? false;
          int expiryDateMs = data['expiry_date'] ?? 0;
          int vouchersLimit = data['vouchers_limit'] ?? -1;
          String planType = data['plan_type'] ?? 'trial';

          // جلب عدد القسائم المستخدمة محلياً أو من السيرفر
          var localData = await SecureStorageHelper.getLocalLicenseData();
          int vouchersUsed =
              int.tryParse(localData['vouchersUsed'] ?? '0') ?? 0;

          // ج) تحديث الذاكرة المحلية المشفرة بالبيانات الجديدة القادمة من السيرفر
          await SecureStorageHelper.saveLicenseData(
            deviceId: deviceId,
            planType: planType,
            expiryDateMs: expiryDateMs,
            vouchersLimit: vouchersLimit,
            vouchersUsed: vouchersUsed,
            needsSync: false,
          );

          // د) فحص الصلاحية فوراً بعد التحديث
          return await SecureStorageHelper.checkLocalLicenseValid();
        }
      } catch (e) {
        // في حال حدوث خطأ في الاتصال بالـ Firestore، نتحول تلقائياً للفحص المحلي
      }
    }

    // 2. إذا كان الجهاز Offline أو فشل الاتصال: الاعتماد الكلي على الذاكرة المحلية المشفرة
    return await SecureStorageHelper.checkLocalLicenseValid();
  }

  /// 2. رفع التفعيل الأوفلاين للفايربيس (Auto Sync Pending Activations)
  static Future<void> _uploadPendingOfflineActivation(String deviceId) async {
    bool needsSync = await SecureStorageHelper.checkIfNeedsSync();
    if (!needsSync) return;

    var localData = await SecureStorageHelper.getLocalLicenseData();
    if (localData['expiryDate'] == null) return;

    await _firestore.collection('licenses').doc(deviceId).set({
      'device_id': deviceId,
      'plan_type': localData['planType'],
      'expiry_date': int.parse(localData['expiryDate']!),
      'vouchers_limit': int.parse(localData['vouchersLimit'] ?? '-1'),
      'is_active': true,
      'last_activation_key': localData['appliedKey'],
      'activated_offline_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // إزالة علم التزامن المعلق بعد نجاح عملية الرفع
    await SecureStorageHelper.clearSyncFlag();
  }

  /// 3. تسجيل بيانات التجربة لأول مرة على Firebase عند فتح التطبيق أول مرة
  static Future<void> registerTrialOnline({
    required String clientName,
    required String phone,
    required String networkName,
    required int trialDays,
    required int trialVouchersLimit,
  }) async {
    String deviceId = await DeviceUtils.getDeviceId();
    DateTime now = DateTime.now();
    DateTime expiryDate = now.add(Duration(days: trialDays));

    // أ) حفظ البيانات محلياً
    await SecureStorageHelper.saveLicenseData(
      deviceId: deviceId,
      planType: 'trial',
      expiryDateMs: expiryDate.millisecondsSinceEpoch,
      vouchersLimit: trialVouchersLimit,
      vouchersUsed: 0,
      needsSync: true,
    );

    // ب) محاولة الحفظ على Firebase إن توفر الإنترنت
    try {
      await _firestore.collection('licenses').doc(deviceId).set({
        'device_id': deviceId,
        'client_name': clientName,
        'phone': phone,
        'network_name': networkName,
        'plan_type': 'trial',
        'is_active': true,
        'expiry_date': expiryDate.millisecondsSinceEpoch,
        'vouchers_limit': trialVouchersLimit,
        'created_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await SecureStorageHelper.clearSyncFlag();
    } catch (e) {
      // سيتكفل تابع _uploadPendingOfflineActivation برفعها لاحقاً عند الاتصال
    }
  }
}