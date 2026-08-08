import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionsScreen extends StatefulWidget {
  final VoidCallback onAllPermissionsGranted;

  const PermissionsScreen({Key? key, required this.onAllPermissionsGranted}) : super(key: key);

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> with WidgetsBindingObserver {
  static const MethodChannel _channel = MethodChannel('com.example.pr19/native_control');

  bool _smsGranted = false;
  bool _notificationGranted = false;
  bool _notificationListenerGranted = false;
  bool _batteryOptimizationGranted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAllPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // إعادة الفحص التلقائي بمجرد الرجوع من إعدادات النظام للتطبيق
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAllPermissions();
    }
  }

  Future<void> _checkAllPermissions() async {
    // 1. فحص أذونات الـ SMS
    final smsStatus = await Permission.sms.status;
    
    // 2. فحص إذن إشعارات النظام (أندرويد 13+)
    final notificationStatus = await Permission.notification.status;

    // 3. فحص إذن الوصول للإشعارات (Native Notification Listener)
    bool isNotificationListenerGranted = false;
    try {
      isNotificationListenerGranted = await _channel.invokeMethod('isNotificationListenerPermissionGranted') ?? false;
    } catch (_) {}

    // 4. فحص استثناء قيود البطارية
    final batteryStatus = await Permission.ignoreBatteryOptimizations.status;

    setState(() {
      _smsGranted = smsStatus.isGranted;
      _notificationGranted = notificationStatus.isGranted;
      _notificationListenerGranted = isNotificationListenerGranted;
      _batteryOptimizationGranted = batteryStatus.isGranted;
    });

    // الانتهاء والانتقال للواجهة الرئيسية فقط عند اكتمال كافة الصلاحيات
    if (_smsGranted && _notificationGranted && _notificationListenerGranted && _batteryOptimizationGranted) {
      widget.onAllPermissionsGranted();
    }
  }

  // 1. طلب أذونات الـ SMS والإشعارات القياسية
  Future<void> _requestStandardPermissions() async {
    await [
      Permission.sms,
      Permission.notification,
    ].request();
    _checkAllPermissions();
  }

  // 2. توجيه لإعدادات وصول الإشعارات
  Future<void> _openNotificationListenerSettings() async {
    await _channel.invokeMethod('openNotificationListenerSettings');
  }

  // 3. طلب استثناء البطارية
  Future<void> _requestBatteryOptimization() async {
    await _channel.invokeMethod('requestIgnoreBatteryOptimization');
    _checkAllPermissions();
  }

  // 4. توجيه لإعدادات التشغيل التلقائي ومعلومات التطبيق
  Future<void> _openAutoStartSettings() async {
    await _channel.invokeMethod('openAutoStartSettings');
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // حظر إغلاق الشاشة أو الرجوع للخلف حتى يكتمل إعطاء الصلاحيات
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("تهيئة وتفعيل الصلاحيات"),
          automaticallyImplyLeading: false,
          centerTitle: true,
        ),
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "لضمان قراءة الرسائل وتمرير الإشعارات بالخلفية بشكل آلي، يرجى تفعيل جميع الصلاحيات أدناه:",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              _buildPermissionCard(
                title: "1. قراءة وإرسال الرسائل SMS",
                subtitle: "استقبال ومعالجة قسائم المحافظ للعملاء",
                isGranted: _smsGranted && _notificationGranted,
                onTap: _requestStandardPermissions,
              ),

              _buildPermissionCard(
                title: "2. خدمة قراءة الإشعارات والرد عليها",
                subtitle: "تفعيل الوصول لخدمة Wallet Notification Listener",
                isGranted: _notificationListenerGranted,
                onTap: _openNotificationListenerSettings,
              ),

              _buildPermissionCard(
                title: "3. استثناء قيود تحسين البطارية",
                subtitle: "منع النظام من إيقاف الخدمة عند خمول الشاشة",
                isGranted: _batteryOptimizationGranted,
                onTap: _requestBatteryOptimization,
              ),

              _buildPermissionCard(
                title: "4. السماح بالتشغيل التلقائي (Auto-Start)",
                subtitle: "تفعيل البدء التلقائي وإتاحة العمل بدون قيود من إعدادات النظام",
                isGranted: false, // زر توجيه مستمر لإعدادات الجهاز
                onTap: _openAutoStartSettings,
              ),

              const Spacer(),

              ElevatedButton(
                onPressed: _checkAllPermissions,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blueAccent,
                ),
                child: const Text("إعادة الفحص والمتابعة", style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionCard({
    required String title,
    required String subtitle,
    required bool isGranted,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        trailing: isGranted
            ? const Icon(Icons.check_circle, color: Colors.green, size: 28)
            : ElevatedButton(
                onPressed: onTap,
                child: const Text("تفعيل"),
              ),
      ),
    );
  }
}