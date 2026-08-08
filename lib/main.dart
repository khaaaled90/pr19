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

const MethodChannel _nativeChannel = MethodChannel('com.example.pr19/native_control');

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

    await DatabaseHelper.instance.database;
    await NotificationHelper.init();
    SmsReceiver.initializeSmsListener();
    await NotificationListenerManager.startListening();
  } catch (e) {
    debugPrint("⚠️ خطأ أثناء تهيئة خدمات الخلفية: $e");
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // الشاشة المبدئية أثناء فحص حالة الترخيص
  Widget _currentScreen = const Scaffold(
    body: Center(child: CircularProgressIndicator()),
  );

  @override
  void initState() {
    super.initState();
    _checkAppLicenseStatus();
  }

  Future<void> _checkAppLicenseStatus() async {
    // 1. إجراء عملية الفحص والمزامنة مباشرة عبر السيرفر/الفايربيس بواسطة رقم الهاردوير
    var validation = await SyncManager.checkAndSyncLicense();

    // 2. تعبئة وتحديث التخزين الآمن محلياً ببيانات الفايربيس المسترجعة (إن وجدت)
    /*if (validation['licenseData'] != null) {
      await SecureStorageHelper.saveLicenseData(validation['licenseData']);
    }*/
    // في ملف main.dart عند خطوة المزامنة:
    if (validation['licenseData'] != null) {
      await SecureStorageHelper.saveLicenseDataFromMap(
        validation['licenseData'] as Map<String, dynamic>,
      );
    }

    // 3. إذا كان الجهاز غير مسجل إطلاقاً لا على السيرفر ولا محلياً -> شاشة التسجيل
    if (validation['reason'] == 'NOT_REGISTERED' || validation['reason'] == 'NO_LICENSE') {
      setState(() {
        _currentScreen = RegistrationScreen(
          onRegistrationComplete: _checkAppLicenseStatus,
        );
      });
      return;
    }

    // 4. إذا كان الترخيص صالحاً -> ننتقل إلى متحكم الأذونات MainController
    if (validation['isValid'] == true) {
      setState(() {
        _currentScreen = const MainController();
      });
    } else {
      // 5. إذا انتهت الأيام أو كمية القسائم التجريبية/الاشتراك -> شاشة القفل والتفعيل
      setState(() {
        _currentScreen = LicenseLockScreen(
          lockReason: validation['reason'] ?? 'EXPIRED',
          onUnlocked: _checkAppLicenseStatus,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'كرت شبكة',
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

      // 🎯 عرض الشاشة الديناميكية الموجهة حسب حالة الترخيص
      home: _currentScreen,
    );
  }
}

/// 🛡️ متحكم الأذونات: يختبر الأذونات أولاً، وعند منحها يفتح الشاشة الرئيسية للتطبيق
class MainController extends StatefulWidget {
  const MainController({Key? key}) : super(key: key);

  @override
  State<MainController> createState() => _MainControllerState();
}

class _MainControllerState extends State<MainController> {
  bool _hasAllPermissions = false;

  @override
  Widget build(BuildContext context) {
    if (!_hasAllPermissions) {
      return PermissionsScreen(
        onAllPermissionsGranted: () {
          setState(() {
            _hasAllPermissions = true;
          });
        },
      );
    }

    // الواجهة الرئيسية للتطبيق بعد التأكد من الترخيص والأذونات
    return const MainNavigationScreen(); 
  }
}
/*const MethodChannel _nativeChannel = MethodChannel('com.example.pr19/native_control');

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

    await DatabaseHelper.instance.database;
    await NotificationHelper.init();
    SmsReceiver.initializeSmsListener();
    await NotificationListenerManager.startListening();
  } catch (e) {
    debugPrint("⚠️ خطأ أثناء تهيئة خدمات الخلفية: $e");
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // الشاشة المبدئية أثناء فحص حالة الترخيص
  Widget _currentScreen = const Scaffold(
    body: Center(child: CircularProgressIndicator()),
  );

  @override
  void initState() {
    super.initState();
    _checkAppLicenseStatus();
  }

  Future<void> _checkAppLicenseStatus() async {
    // 1. فحص هل سجل العميل بياناته سابقاً أم أن التطبيق يفتح لأول مرة؟
    var localData = await SecureStorageHelper.getLocalLicenseData();

    if (localData['deviceId'] == null) {
      // فتح لأول مرة -> التوجه إلى شاشة التسجيل
      setState(() {
        _currentScreen = RegistrationScreen(
          onRegistrationComplete: _checkAppLicenseStatus,
        );
      });
      return;
    }

    // 2. فحص صلاحية الترخيص (أونلاين مع الفايربيس أو أوفلاين)
    var validation = await SyncManager.checkAndSyncLicense();

    if (validation['isValid'] == true) {
      // الترخيص صالح -> التوجه للشاشة الرئيسية للتطبيق
      setState(() {
        _currentScreen = const MainNavigationScreen();
      });
    } else {
      // الترخيص منتهي أو غير صالح -> التوجه لشاشة القفل والتفعيل
      setState(() {
        _currentScreen = LicenseLockScreen(
          lockReason: validation['reason'] ?? 'NO_LICENSE',
          onUnlocked: _checkAppLicenseStatus,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'كرت شبكة',
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

      // 🎯 عرض الشاشة الديناميكية الموجهة حسب حالة الترخيص
      home: _currentScreen,
    );
  }
}*/
/*import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'DatabaseHelper.dart';
import 'HomeScreen.dart';
import 'NotificationHelper.dart';
import 'NotificationListener.dart';
import 'SmsReceiver.dart';

const MethodChannel _nativeChannel = MethodChannel('com.example.pr19/native_control');
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
      title: 'كرت شبكة',
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

      home: const MainNavigationScreen(),
    );
  }
}*/

/*import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'DatabaseHelper.dart';
import 'HomeScreen.dart';
import 'NotificationHelper.dart';
import 'NotificationListener.dart';
import 'SmsReceiver.dart';

void main() async {
  // 1. ضمان تهيئة المحرك لضمان ربط الـ Native MethodChannels
  WidgetsFlutterBinding.ensureInitialized();

  // 2. تهيئة الخدمات وقواعد البيانات أولاً
  await _initializeServices();

  // 3. تشغيل التطبيق والواجهة الرئيسية
  runApp(const MyApp());
}

/// دالة تهيئة خدمات الخلفية وقاعدة البيانات
Future<void> _initializeServices() async {
  try {
    // أ. تهيئة قاعدة البيانات المحلية
    await DatabaseHelper.instance.database;

    // ب. تهيئة نظام التنبيهات المحلية
    await NotificationHelper.init();

    // ج. تهيئة مستمع الـ SMS عبر Native Kotlin
    SmsReceiver.initializeSmsListener();

    // د. تشغيل مستمع إشعارات التطبيقات الأخرى
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
      title: 'كرت شبكة',
      debugShowCheckedModeBanner: false,

      // إعدادات اللغة العربية والاتجاه من اليمين لليسار (RTL)
      locale: const Locale('ar', ''),
      supportedLocales: const [
        Locale('ar', ''),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // الثيم العام للتطبيق
      theme: ThemeData(
        useMaterial3: true,
        primarySwatch: Colors.blue,
        fontFamily: 'Cairo',
        scaffoldBackgroundColor: const Color(0xFFF2F4F8),
      ),

      // الواجهة الرئيسية تصبح الآن التنقل العام MainNavigationScreen
      home: const MainNavigationScreen(),
    );
  }
}*/
/*import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'DatabaseHelper.dart';
import 'HomeScreen.dart';
import 'NotificationHelper.dart';
import 'NotificationListener.dart';
import 'SmsReceiver.dart';

void main() async {
  // 1. ضمان تهيئة المحرك لضمان ربط الـ Native MethodChannels
  WidgetsFlutterBinding.ensureInitialized();

  // 2. تهيئة الخدمات وقواعد البيانات أولاً
  await _initializeServices();

  // 3. تشغيل التطبيق والواجهة الرئيسية
  runApp(const MyApp());
}

/// دالة تهيئة خدمات الخلفية وقاعدة البيانات
Future<void> _initializeServices() async {
  try {
    // أ. تهيئة قاعدة البيانات المحلية
    await DatabaseHelper.instance.database;

    // ب. تهيئة نظام التنبيهات المحلية
    await NotificationHelper.init();

    // ج. تهيئة مستمع الـ SMS عبر Native Kotlin
    SmsReceiver.initializeSmsListener();

    // د. تشغيل مستمع إشعارات التطبيقات الأخرى
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
      title: 'كرت شبكة',
      debugShowCheckedModeBanner: false,

      // إعدادات اللغة العربية والاتجاه من اليمين لليسار (RTL)
      locale: const Locale('ar', ''),
      supportedLocales: const [
        Locale('ar', ''),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // الثيم العام للتطبيق
      theme: ThemeData(
        useMaterial3: true,
        primarySwatch: Colors.blue,
        fontFamily: 'Cairo',
        scaffoldBackgroundColor: const Color(0xFFF2F4F8),
      ),

      // الواجهة الرئيسية
      home: const HomeScreen(),
    );
  }
}
*/