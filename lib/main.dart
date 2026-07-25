import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'DatabaseHelper.dart';
import 'HomeScreen.dart';
import 'NotificationHelper.dart';
import 'NotificationListener.dart';
import 'SmsReceiver.dart'; // تأكد من مطابقة اسم الملف لديك

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 1. تهيئة قاعدة البيانات والتأكد من تجهيز الجداول والتحديثات
  await DatabaseHelper.instance.database;

  // 2. تهيئة مستمع الـ SMS
  await SmsReceiver.initializeSmsListener();

  // 3.🔔 تهيئة خدمة الإشعارات المحلية هنا
  await NotificationHelper.init();

  // 4. تفعيل الاستماع للإشعارات
  await NotificationListenerManager.startListening();

  runApp(const MyApp());
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
