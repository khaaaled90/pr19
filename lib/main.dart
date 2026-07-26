import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'DatabaseHelper.dart';
import 'HomeScreen.dart';
import 'NotificationHelper.dart';
import 'NotificationListener.dart';
import 'SmsReceiver.dart'; // تأكد من مطابقة اسم الملف لديك

void main() async {
  // 1. ضمان تهيئة Flutter المحرك
  WidgetsFlutterBinding.ensureInitialized();

  // 2. تشغيل الواجهة فوراً للتخلص من الشاشة السوداء
  runApp(const MyApp());

  // 3. تهيئة الخدمات وقاعدة البيانات في الخلفية بدون تعطيل رسم الواجهة
  _initializeServices();
}

/// دالة منفصلة لتهيئة خدمات الخلفية بشكل متوازٍ
Future<void> _initializeServices() async {
  try {
    // أ. تهيئة قاعدة البيانات أولاً
    await DatabaseHelper.instance.database;

    // ب. تهيئة خدمة الإشعارات المحلية
    await NotificationHelper.init();

    // ج. تهيئة مستمع الـ SMS والاستماع للإشعارات في الخلفية
    SmsReceiver.initializeSmsListener();
    NotificationListenerManager.startListening();
  } catch (e) {
    print("خطأ أثناء تهيئة خدمات الخلفية: $e");
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
        fontFamily: 'Cairo', // يمكنك تغيير الخط إذا كنت تستخدم خطاً معيناً
        scaffoldBackgroundColor: const Color(0xFFF2F4F8),
      ),

      // الواجهة الرئيسية
      home: const HomeScreen(),
    );
  }
}
