import 'dart:convert';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'device_utils.dart';
import 'secure_storage_helper.dart';
import 'dart:typed_data';

class LicenseKeyManager {
  // 🔑 المفتاح السري الخاص بك فقط (يجب أن يكون من 32 حرفاً بالضبط)
  // ⚠️ تحذير: لا تغير هذا المفتاح بعد نشر التطبيق وإلا ستلغى الأكواد القديمة
  static const String _secretKey = "MY_SUPER_SECRET_KEY_32_CHARS_!!!";

  /// 1. فك كود الترخيص وتفعيله محلياً أوفلاين (تُنفّذ داخل تطبيق العميل)
  static Future<Map<String, dynamic>> activateWithCode(String inputCode) async {
    try {
      final currentDeviceId = await DeviceUtils.getDeviceId();

      final key = encrypt.Key.fromUtf8(_secretKey);
      //final iv = encrypt.IV.fromLength(16);
      final iv = encrypt.IV(Uint8List(16));
      final encrypter = encrypt.Encrypter(
        encrypt.AES(
          key,
          mode: encrypt.AESMode.cbc,
        ),
      );
      final decrypted = encrypter.decrypt64(
        inputCode.trim(),
        iv: iv,
      );
      // فك تشفير الكود باستخدام مفتاح AES
      /*final key = encrypt.Key.fromUtf8(_secretKey);
      final iv = encrypt.IV.fromLength(16);
      final encrypter = encrypt.Encrypter(encrypt.AES(key));

      // فك الشفرة من Base64
      String decrypted = encrypter.decrypt64(inputCode.trim(), iv: iv);
      */
      // القيمة المفكوكة تكون بهذا الشكل: "A1B2-C3D4-E5F6-7890|2027-08-05|monthly"

      List<String> parts = decrypted.split('|');
      if (parts.length < 3) {
        return {'success': false, 'message': 'كود التفعيل غير صالح'};
      }

      String codeDeviceId = parts[0];
      String expiryDateStr = parts[1];
      String planType = parts[2];

      // أ) التحقق من مطابقة معرّف الجهاز
      if (codeDeviceId != currentDeviceId) {
        return {'success': false, 'message': 'هذا الكود مخصص لجهاز آخر!'};
        //return {'success': false, 'message': '$codeDeviceId:$currentDeviceId:'};
      }

      // ب) التحقق من تاريخ الانتهاء
      DateTime expiryDate = DateTime.parse(expiryDateStr);
      if (DateTime.now().isAfter(expiryDate)) {
        return {'success': false, 'message': 'كود التفعيل منتهي الصلاحية!'};
      }

      // ج) حفظ التفعيل في الذاكرة المحلية المشفرة ووضع علامة "يحتاج تزامن مع Firebase"
      await SecureStorageHelper.saveLicenseData(
        deviceId: currentDeviceId,
        planType: planType,
        expiryDateMs: expiryDate.millisecondsSinceEpoch,
        vouchersLimit: -1, // فتح الاستخدام غير المحدود عند التفعيل بكود
        vouchersUsed: 0,
        needsSync: true, // 🚩 وضع علامة لرفعه لـ Firebase بمجرد توفر الإنترنت
        appliedKey: inputCode,
      );

      return {
        'success': true,
        'message': 'تم تفعيل الترخيص بنجاح',
        'planType': planType,
        'expiryDate': expiryDate,
      };
    } catch (e) {
      return {'success': false, 'message': 'كود التفعيل غير صحيح أو تالف'};
    }
    /*} catch (e, stackTrace) {
      print('================ LICENSE ERROR ================');
      print('ERROR: $e');
      print('STACK: $stackTrace');
      print('===============================================');

      return {
        'success': false,
        'message': 'خطأ: $e',
      };
    }*/
  }

  /// 2. توليد كود الترخيص للعميل (تُنفّذ في برنامج الأدمن/المطور لديك)
  static String generateLicenseKey({
    required String clientDeviceId,
    required DateTime expiryDate,
    required String planType, // 'monthly', 'semi_annual', 'annual', 'lifetime'
  }) {
    final key = encrypt.Key.fromUtf8(_secretKey);
    //final iv = encrypt.IV.fromLength(16);
    final iv = encrypt.IV(Uint8List(16));
    final encrypter = encrypt.Encrypter(encrypt.AES(key));

    String dateStr = expiryDate.toIso8601String().split('T')[0]; // صيغة: "2027-08-05"
    String rawData = "$clientDeviceId|$dateStr|$planType";

    final encrypted = encrypter.encrypt(rawData, iv: iv);
    return encrypted.base64; // هذا الكود النصي الذي ترسله للعميل عبر الواتساب/SMS
  }

  /// 3. جلب تفاصيل الترخيص الحالي لاستعراضها في الواجهة
  static Future<Map<String, String>> getLicenseDetails() async {
    try {
      final details = await SecureStorageHelper.getLicenseDetailsForUI();

      String planType = details['planType'] ?? 'trial';
      int remainingDays = details['remainingDays'] ?? 0;

      // 🟢 ترجمة نوع الخطة
      String formattedType;
      switch (planType) {
        case 'monthly':
          formattedType = 'اشتراك شهري';
          break;
        case 'semi_annual':
          formattedType = 'اشتراك نصف سنوي';
          break;
        case 'annual':
          formattedType = 'اشتراك سنوي';
          break;
        case 'lifetime':
          formattedType = 'ترخيص مدى الحياة';
          break;
        case 'trial':
          formattedType = 'نسخة تجريبية';
          break;
        default:
          formattedType = planType;
      }

      // 🟢 تنسيق معلومات انتهاء الصلاحية
      String formattedExpiry;
      if (planType == 'lifetime') {
        formattedExpiry = 'غير محدود (صلاحية دائمة)';
      } else if (remainingDays > 0) {
        formattedExpiry = 'متبقي على الانتهاء: $remainingDays يوم';
      } else {
        formattedExpiry = 'الاشتراك منتهي';
      }

      return {
        'type': formattedType,
        'expiry': formattedExpiry,
      };
    } catch (e) {
      return {
        'type': 'غير معروف',
        'expiry': 'خطأ في قراءة الترخيص',
      };
    }
  }
}