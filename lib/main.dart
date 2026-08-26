import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// 🔑 استيراد الفايربيس وإعداداته
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// 🛠️ استيراد الهيلبرز والشاشات الخاصة بالتراخيص
import 'helpers/secure_storage_helper.dart';
import 'helpers/sync_manager.dart';
import 'screens/registration_screen.dart';
import 'screens/license_lock_screen.dart';
import 'PermissionGuardScreen.dart';
import 'DatabaseHelper.dart';
import 'HomeScreen.dart';
import 'NotificationHelper.dart';
import 'NotificationListener.dart';
import 'SmsReceiver.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // 👈 أضف الاستيراد

const MethodChannel _nativeChannel = MethodChannel('com.example.pr19/native_control');

// 1. معالج خلفية الإشعارات
/*@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // 👈 إضافة الحفظ في قاعدة البيانات أثناء وجود التطبيق في الخلفية أو الإغلاق
  if (message.notification != null) {
    await DatabaseHelper.instance.insertNotification(
      message.notification!.title ?? '',
      message.notification!.body ?? '',
    );
  }
}*/
// 1. معالج خلفية الإشعارات
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  /*try {
    String title = message.notification?.title ?? message.data['title'] ?? 'إشعار جديد';
    String body = message.notification?.body ?? message.data['body'] ?? '';

    if (title.isNotEmpty || body.isNotEmpty) {
      await DatabaseHelper.instance.insertNotification(title, body);
      debugPrint("✅ تم حفظ إشعار الخلفية بنجاح: $title");
    }
  } catch (e) {
    debugPrint("❌ خطأ أثناء حفظ إشعار الخلفية: $e");
  }*/
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initializeServices();

  try {
    await _nativeChannel.invokeMethod('warmupCache');
    debugPrint("تم إرسال أمر إحماء الكاش بنجاح");
  } catch (e) {
    debugPrint("خطأ أثناء استدعاء الكاش: $e");
  }

  runApp(const MyApp());
}

Future<void> _initializeServices() async {
  try {
    // ⚡ تهيئة Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // 🔔 👈 التعديل هنا: استخدام onBackgroundMessage بدلاً من onBackgroundMessageHandler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // طلب الصلاحيات
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // الاشتراك في الـ Topic
    await messaging.subscribeToTopic('all_users');

    // إعداد إظهار التنبيهات أثناء فتح التطبيق
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    // 👈 أضف هذا الجزء هنا: حفظ الإشعار فور وصوله والتطبيق مفتوح أمام المستخدم
    /*FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      if (message.notification != null) {
        await DatabaseHelper.instance.insertNotification(
          message.notification!.title ?? '',
          message.notification!.body ?? '',
        );
      }
    });*/

    // 2. داخل دالة _initializeServices()
    /*FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      try {
        String title = message.notification?.title ?? message.data['title'] ?? 'إشعار جديد';
        String body = message.notification?.body ?? message.data['body'] ?? '';

        if (title.isNotEmpty || body.isNotEmpty) {
          await DatabaseHelper.instance.insertNotification(title, body);
          debugPrint("✅ تم حفظ إشعار الأمامية بنجاح: $title");
        }
      } catch (e) {
        debugPrint("❌ خطأ أثناء حفظ إشعار الأمامية: $e");
      }
    });

    // التعامل مع الإشعارات عند الضغط عليها وفتح التطبيق
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      String title = message.notification?.title ?? message.data['title'] ?? 'إشعار جديد';
      String body = message.notification?.body ?? message.data['body'] ?? '';

      if (title.isNotEmpty || body.isNotEmpty) {
        await DatabaseHelper.instance.insertNotification(title, body);
      }
    });*/

    await DatabaseHelper.instance.database;
    await NotificationHelper.init();
    SmsReceiver.initializeSmsListener();
    await NotificationListenerManager.startListening();
  } catch (e) {
    debugPrint("⚠️ خطأ أثناء تهيئة خدمات الخلفية: $e");
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CardPay',
      debugShowCheckedModeBanner: false,

      // 🌍 إعدادات اللغة العربية
      locale: const Locale('ar', ''),
      supportedLocales: const [Locale('ar', '')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // 🎯 التكيف التلقائي مع نظام الهاتف (Dark / Light)
      themeMode: ThemeMode.system,

      // ☀️ الثيم الفاتح (Light Theme)
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        primaryColor: const Color(0xFF0284C7),
        scaffoldBackgroundColor: const Color(0xFFF2F4F8),
        cardColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0284C7),
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0284C7),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        fontFamily: 'Cairo',
      ),

      // 🌙 الثيم الداكن (Dark Theme)
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF0D9488),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        cardColor: const Color(0xFF1E293B),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D9488),
          brightness: Brightness.dark,
          surface: const Color(0xFF1E293B),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E293B),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        fontFamily: 'Cairo',
      ),

      // 🎯 1. البدء بمتحكم الأذونات أولاً
      home: const MainController(),
    );
  }
}

/// 🛡️ متحكم الأذونات والترخيص
class MainController extends StatefulWidget {
  const MainController({Key? key}) : super(key: key);

  @override
  State<MainController> createState() => _MainControllerState();
}

class _MainControllerState extends State<MainController> {
  bool _hasAllPermissions = false;
  // ➕1. إضافة متغير لمعرفة حالة التحميل
  bool _isLoading = true;

  Widget _currentScreen = const Scaffold(
    body: Center(child: CircularProgressIndicator()),
  );

  // ➕2. إضافة initState للبدء بالفحص فوراً
  @override
  void initState() {
    super.initState();
    //_checkAppLicenseStatus();
    _initAppFlow(); // 👈 الاستدعاء الجديد بدلاً من _checkAppLicenseStatus مباشرة
  }

  @override
  Widget build(BuildContext context) {
    // 1️⃣ أثناء فحص السيرفر والترخيص المحلي أولاً
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 2️⃣ استثناء خاص: إذا كان الترخيص منتهياً، اعرض شاشة القفل فوراً دون المرور بالأذونات
    if (_currentScreen is LicenseLockScreen) {
      return _currentScreen;
    }

    // 3️⃣ للتثبيت الجديد أو الترخيص الصالح: تأكد من الأذونات أولاً
    // ✋ 1. إذا لم تُمنح الأذونات بعد -> عرض شاشة الأذونات
    if (!_hasAllPermissions) {
      return PermissionsScreen(
        onAllPermissionsGranted: () {
          setState(() {
            _hasAllPermissions = true;
          });
          // بعد أخذ الأذونات -> ابدأ فحص الترخيص والشبكة
          //_checkAppLicenseStatus();
          _initAppFlow();
        },
      );
    }

    // 2. بعد الأذونات -> عرض الشاشة الموجهة (التسجيل / الرئيسية / القفل)
    return _currentScreen;
  }
  Future<void> _initAppFlow() async {
    setState(() {
      _isLoading = true;
    });

    // 1️⃣ فحص هل الأذونات ممنوحة بالفعل في النظام؟
    bool granted = await _checkIfPermissionsGranted();

    if (!granted) {
      if (!mounted) return;
      setState(() {
        _hasAllPermissions = false;
        _isLoading = false; // لإخفاء مؤشر التحميل وعرض شاشة الأذونات
      });
      return;
    }

    // 2️⃣ الأذونات ممنوحة مسبقاً -> تعيينها كـ true ومتابعة فحص الترخيص
    _hasAllPermissions = true;
    await _checkAppLicenseStatus();
  }
  Future<bool> _checkIfPermissionsGranted() async {
    // افحص الأذونات الخاصة بتطبيقك (إشعارات، SMS، إلخ)
    // مثال باستخدام مكتبات الأذونات المعتمدة لديك:
    bool isSmsGranted = await SmsReceiver.isPermissionGranted(); // أو الاستدعاء الخاص بك
    return isSmsGranted;
  }
  Future<void> _checkAppLicenseStatus() async {
    setState(() {
      _isLoading = true;
    });
    
    // 1. فحص الترخيص المحلي المخزن أولاً (يعمل أوفلاين بنجاح)
    var localCheck = await SecureStorageHelper.checkLocalLicenseValid();

    // 🟢 إذا كان الجهاز مسجلاً ولديه ترخيص محلي صالح
    if (localCheck['isValid'] == true) {
      if (!mounted) return;
      setState(() {
        _isLoading = false; // 👈 إيقاف التحميل
        _currentScreen = const MainNavigationScreen();
      });

      // إجراء مزامنة خلفية هادئة إن توفر إنترنت لاحقاً
      _hasInternetConnection().then((hasNet) {
        if (hasNet) SyncManager.checkAndSyncLicense();
      });
      return;
    }

    // 2. إذا لم يوجد ترخيص محلي valid (جهاز جديد / تم مسح البيانات / انتهت الصلاحية)
    bool hasNetwork = await _hasInternetConnection();

    // 🌐 لا يوجد إنترنت والجهاز ليس لديه ترخيص محلي -> شاشة التسجيل
    if (!hasNetwork) {
      if (!mounted) return;
      setState(() {
        _isLoading = false; // 👈 إيقاف التحميل
        _currentScreen = RegistrationScreen(
          onRegistrationComplete: _checkAppLicenseStatus,
        );
      });
      return;
    }

    // 🔄 3. توفر إنترنت + عدم وجود ترخيص محلي -> استعلام وتنزيل من الفايربيس
    var validation = await SyncManager.checkAndSyncLicense();

    //setState(() => _isLoading = true);

    // إذا تم العثور على وثيقة الجهاز في الفايربيس
    if (validation['isValid'] == true) {
      // 💾 حفظ البيانات المجلوبة محلياً للتأكد من عملها أوفلاين في المرات القادمة
      if (validation['licenseData'] != null) {
        await SecureStorageHelper.saveLicenseDataFromMap(
          validation['licenseData'] as Map<String, dynamic>,
        );
      }

      if (!mounted) return;
      setState(() {
        _isLoading = false; // 👈 إيقاف التحميل
        _currentScreen = const MainNavigationScreen();
      });
    } else if (validation['reason'] == 'EXPIRED' || validation['reason'] == 'LIMIT_REACHED') {
      if (!mounted) return;
      setState(() {
        _isLoading = false; // 👈 إيقاف التحميل
        _currentScreen = LicenseLockScreen(
          lockReason: validation['reason'] ?? 'EXPIRED',
          onUnlocked: _checkAppLicenseStatus,
        );
      });
    } else {
      // الجهاز غير مسجل إطلاقاً على الفايربيس
      if (!mounted) return;
      setState(() {
        _isLoading = false; // 👈 إيقاف التحميل
        _currentScreen = RegistrationScreen(
          onRegistrationComplete: _checkAppLicenseStatus,
        );
      });
    }
  }
  

  Future<bool> _hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}

/*Future<void> _checkAppLicenseStatus() async {
    bool hasNetwork = await _hasInternetConnection();

    // 🌐 إذا لم يوجد إنترنت -> التوجه فوراً لشاشة التسجيل
    if (!hasNetwork) {
      if (!mounted) return;
      setState(() {
        _currentScreen = RegistrationScreen(
          onRegistrationComplete: _checkAppLicenseStatus,
        );
      });
      return;
    }

    // 🔄 إذا وجد إنترنت -> إجراء فحص المزامنة والترخيص من السيرفر/الفايربيس
    var validation = await SyncManager.checkAndSyncLicense();

    if (validation['licenseData'] != null) {
      await SecureStorageHelper.saveLicenseDataFromMap(
        validation['licenseData'] as Map<String, dynamic>,
      );
    }

    // إذا كان الجهاز غير مسجل إطلاقاً -> شاشة التسجيل
    if (validation['reason'] == 'NOT_REGISTERED' || validation['reason'] == 'NO_LICENSE') {
      if (!mounted) return;
      setState(() {
        _currentScreen = RegistrationScreen(
          onRegistrationComplete: _checkAppLicenseStatus,
        );
      });
      return;
    }

    // إذا كان الترخيص صالحاً -> الانتقال للواجهة الرئيسية
    if (validation['isValid'] == true) {
      if (!mounted) return;
      setState(() {
        _currentScreen = const MainNavigationScreen();
      });
    } else {
      // إذا انتهى الترخيص -> شاشة القفل والتفعيل
      if (!mounted) return;
      setState(() {
        _currentScreen = LicenseLockScreen(
          lockReason: validation['reason'] ?? 'EXPIRED',
          onUnlocked: _checkAppLicenseStatus,
        );
      });
    }
  }*/