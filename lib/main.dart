import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'DatabaseHelper.dart';
import 'HomeScreen.dart';
import 'NotificationHelper.dart';
import 'NotificationListener.dart';
import 'SmsReceiver.dart';

const MethodChannel _nativeChannel = MethodChannel('com.example.pr19/native_control');
void main() async {
  // 1. ضمان تهيئة المحرك لضمان ربط الـ Native MethodChannels
  WidgetsFlutterBinding.ensureInitialized();

  // 2. تهيئة الخدمات وقواعد البيانات أولاً
  await _initializeServices();

  // 3. تشغيل التطبيق والواجهة الرئيسية
  // 🚀 استدعاء إحماء الكاش تلقائياً عند فتح التطبيق
  try {
    await _nativeChannel.invokeMethod('warmupCache');
    print("تم إرسال أمر إحماء الكاش بنجاح");
  } catch (e) {
    print("خطأ أثناء استدعاء الكاش: $e");
  }
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
}
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