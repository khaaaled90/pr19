import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../helpers/device_utils.dart';
import '../helpers/sync_manager.dart';
import '../helpers/secure_storage_helper.dart';

class RegistrationScreen extends StatefulWidget {
  final VoidCallback onRegistrationComplete;

  const RegistrationScreen({super.key, required this.onRegistrationComplete});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _networkController = TextEditingController();

  String _deviceId = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDeviceId();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _networkController.dispose();
    super.dispose();
  }

  Future<void> _loadDeviceId() async {
    String id = await DeviceUtils.getDeviceId();
    if (mounted) setState(() => _deviceId = id);
  }

  /// 🌐 دالة فحص الاتصال بالإنترنت
  Future<bool> _hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// 🚀 دالة معالجة زر التسجيل بعد المصادقة المباشرة مع الفايربيس
  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // 1. فحص توفر الاتصال بالإنترنت
    bool hasNetwork = await _hasInternetConnection();

    if (!hasNetwork) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يتوفر اتصال بالإنترنت. يرجى الاتصال ثم إعادة المحاولة.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      String deviceId = _deviceId.isNotEmpty ? _deviceId : await DeviceUtils.getDeviceId();

      // 2. التحقق المباشر من وجود المستند في الفايربيس بنفس الـ Device ID
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('licenses')
          .doc(deviceId)
          .get();

      if (doc.exists && doc.data() != null) {
        // 🎯 إذا كان الجهاز مسجلاً مسبقاً: نكتفي بسحب البيانات الأصلية وتخزينها محلياً دون تعديل الفايربيس
        Map<String, dynamic> licenseData = doc.data() as Map<String, dynamic>;
        await SecureStorageHelper.saveLicenseDataFromMap(licenseData);
      } else {
        // 🆕 إذا كان جهازاً جديداً وغير مسجل إطلاقاً: نرفع البيانات وتنشئ حسابه التجريبي لأول مرة
        await SyncManager.registerTrialOnline(
          clientName: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          networkName: _networkController.text.trim(),
          trialDays: 10,
          trialVouchersLimit: 200,
        );
      }

      if (mounted) {
        setState(() => _isLoading = false);
        // 3. الانتقال واستكمال بقية التطبيق
        widget.onRegistrationComplete();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء الاتصال بالخادم: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgMain = theme.scaffoldBackgroundColor;
    final cardBg = theme.cardColor;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextColor = isDark ? Colors.white60 : Colors.black54;
    final primaryColor = isDark ? const Color(0xFF38BDF8) : const Color(0xFF0EA5E9);

    return Scaffold(
      backgroundColor: bgMain,
      appBar: AppBar(
        centerTitle: true,
        title: const Column(
          children: [
            Text(
              'تسجيل الخدمة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            SizedBox(height: 2),
            Text(
              'تفعيل الفترة التجريبية المجانية',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 🌟 بطاقة الترحيب العصرية
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF0369A1), const Color(0xFF0F766E)]
                        : [const Color(0xFF0EA5E9), const Color(0xFF0D9488)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.app_registration_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'أهلاً بك معنا! 👋',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'أدخل بياناتك لبدء الفترة التجريبية (10 أيام / 200 قسيمة).',
                            style: TextStyle(fontSize: 12, color: Colors.white70, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 📝 كارت مدخلات البيانات
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'بيانات الحساب',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _nameController,
                      style: TextStyle(color: textColor),
                      decoration: _buildInputDecoration(
                        label: 'اسم العميل / المالِك',
                        icon: Icons.person_outline_rounded,
                        isDark: isDark,
                      ),
                      validator: (v) => v!.trim().isEmpty ? 'يرجى إدخال الاسم' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      style: TextStyle(color: textColor),
                      decoration: _buildInputDecoration(
                        label: 'رقم الهاتف',
                        icon: Icons.phone_android_rounded,
                        isDark: isDark,
                      ),
                      validator: (v) => v!.trim().isEmpty ? 'يرجى إدخال رقم الهاتف' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _networkController,
                      style: TextStyle(color: textColor),
                      decoration: _buildInputDecoration(
                        label: 'اسم الشبكة / الخدمة (مثل: شبكة اليمن)',
                        icon: Icons.wifi_rounded,
                        isDark: isDark,
                      ),
                      validator: (v) => v!.trim().isEmpty ? 'يرجى إدخال اسم الشبكة' : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 🆔 كارت معرف الجهاز
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.important_devices_rounded, size: 20, color: subTextColor),
                        const SizedBox(width: 8),
                        Text(
                          'معرف الجهاز:',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: subTextColor),
                        ),
                      ],
                    ),
                    SelectableText(
                      _deviceId.isEmpty ? 'جاري الجلب...' : _deviceId,
                      style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 🚀 زر البدء والتسجيل
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitRegistration,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'بدء استخدام الفترة التجريبية',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String label,
    required IconData icon,
    required bool isDark,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : Colors.black54),
      prefixIcon: Icon(icon, size: 20, color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0EA5E9)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      filled: true,
      fillColor: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0EA5E9), width: 1.5),
      ),
    );
  }
}
/*import 'dart:io';
import 'package:flutter/material.dart';
import '../helpers/device_utils.dart';
import '../helpers/sync_manager.dart';
import '../helpers/secure_storage_helper.dart';

class RegistrationScreen extends StatefulWidget {
  final VoidCallback onRegistrationComplete;

  const RegistrationScreen({super.key, required this.onRegistrationComplete});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _networkController = TextEditingController();

  String _deviceId = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDeviceId();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _networkController.dispose();
    super.dispose();
  }

  Future<void> _loadDeviceId() async {
    String id = await DeviceUtils.getDeviceId();
    if (mounted) setState(() => _deviceId = id);
  }

  /// 🌐 دالة فحص الاتصال بالإنترنت
  Future<bool> _hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// 🚀 دالة معالجة زر التسجيل بعد التعديل
  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // 1. فحص توفر الاتصال بالإنترنت
    bool hasNetwork = await _hasInternetConnection();

    if (!hasNetwork) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يتوفر اتصال بالإنترنت. يرجى الاتصال ثم إعادة المحاولة.'),
          backgroundColor: Colors.red,
        ),
      );
      return; // توقف عن إكمال العملية
    }

    // 2. إذا توفر إنترنت -> فحص ما إذا كان الجهاز مسجلاً مسبقاً في الفايربيس
    var validation = await SyncManager.checkAndSyncLicense();

    if (validation['licenseData'] != null) {
      // 🎯 إذا كان مسجلاً مسبقاً: تعبئة التخزين الآمن محلياً بالبيانات المجلوبة مباشرة
      await SecureStorageHelper.saveLicenseDataFromMap(
        validation['licenseData'] as Map<String, dynamic>,
      );
    } else {
      // 🆕 إذا كان جهازاً جديداً وغير مسجل: رفع البيانات للفايربيس وتخزينها
      await SyncManager.registerTrialOnline(
        clientName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        networkName: _networkController.text.trim(),
        trialDays: 10,
        trialVouchersLimit: 200,
      );
    }

    if (mounted) {
      setState(() => _isLoading = false);
      // 3. الانتقال واستكمال بقية التطبيق
      widget.onRegistrationComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgMain = theme.scaffoldBackgroundColor;
    final cardBg = theme.cardColor;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextColor = isDark ? Colors.white60 : Colors.black54;
    final primaryColor = isDark ? const Color(0xFF38BDF8) : const Color(0xFF0EA5E9);

    return Scaffold(
      backgroundColor: bgMain,
      appBar: AppBar(
        centerTitle: true,
        title: const Column(
          children: [
            Text(
              'تسجيل الخدمة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            SizedBox(height: 2),
            Text(
              'تفعيل الفترة التجريبية المجانية',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 🌟 بطاقة الترحيب العصرية
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF0369A1), const Color(0xFF0F766E)]
                        : [const Color(0xFF0EA5E9), const Color(0xFF0D9488)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.app_registration_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'أهلاً بك معنا! 👋',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'أدخل بياناتك لبدء الفترة التجريبية (10 أيام / 200 قسيمة).',
                            style: TextStyle(fontSize: 12, color: Colors.white70, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 📝 كارت مدخلات البيانات
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'بيانات الحساب',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _nameController,
                      style: TextStyle(color: textColor),
                      decoration: _buildInputDecoration(
                        label: 'اسم العميل / المالِك',
                        icon: Icons.person_outline_rounded,
                        isDark: isDark,
                      ),
                      validator: (v) => v!.trim().isEmpty ? 'يرجى إدخال الاسم' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      style: TextStyle(color: textColor),
                      decoration: _buildInputDecoration(
                        label: 'رقم الهاتف',
                        icon: Icons.phone_android_rounded,
                        isDark: isDark,
                      ),
                      validator: (v) => v!.trim().isEmpty ? 'يرجى إدخال رقم الهاتف' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _networkController,
                      style: TextStyle(color: textColor),
                      decoration: _buildInputDecoration(
                        label: 'اسم الشبكة / الخدمة (مثل: شبكة اليمن)',
                        icon: Icons.wifi_rounded,
                        isDark: isDark,
                      ),
                      validator: (v) => v!.trim().isEmpty ? 'يرجى إدخال اسم الشبكة' : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 🆔 كارت معرف الجهاز
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.important_devices_rounded, size: 20, color: subTextColor),
                        const SizedBox(width: 8),
                        Text(
                          'معرف الجهاز:',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: subTextColor),
                        ),
                      ],
                    ),
                    SelectableText(
                      _deviceId.isEmpty ? 'جاري الجلب...' : _deviceId,
                      style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 🚀 زر البدء والتسجيل
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitRegistration,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'بدء استخدام الفترة التجريبية',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String label,
    required IconData icon,
    required bool isDark,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : Colors.black54),
      prefixIcon: Icon(icon, size: 20, color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0EA5E9)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      filled: true,
      fillColor: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0EA5E9), width: 1.5),
      ),
    );
  }
}*/

//*************************************** */
/*import 'package:flutter/material.dart';
import '../helpers/device_utils.dart';
import '../helpers/sync_manager.dart';

class RegistrationScreen extends StatefulWidget {
  final VoidCallback onRegistrationComplete;

  const RegistrationScreen({super.key, required this.onRegistrationComplete});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _networkController = TextEditingController();

  String _deviceId = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDeviceId();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _networkController.dispose();
    super.dispose();
  }

  Future<void> _loadDeviceId() async {
    String id = await DeviceUtils.getDeviceId();
    if (mounted) setState(() => _deviceId = id);
  }

  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    await SyncManager.registerTrialOnline(
      clientName: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      networkName: _networkController.text.trim(),
      trialDays: 10,
      trialVouchersLimit: 200,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      widget.onRegistrationComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgMain = theme.scaffoldBackgroundColor;
    final cardBg = theme.cardColor;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextColor = isDark ? Colors.white60 : Colors.black54;
    final primaryColor = isDark ? const Color(0xFF38BDF8) : const Color(0xFF0EA5E9);

    return Scaffold(
      backgroundColor: bgMain,
      appBar: AppBar(
        centerTitle: true,
        title: const Column(
          children: [
            Text(
              'تسجيل الخدمة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            SizedBox(height: 2),
            Text(
              'تفعيل الفترة التجريبية المجانية',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 🌟 بطاقة الترحيب العصرية بالتدرج
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF0369A1), const Color(0xFF0F766E)]
                        : [const Color(0xFF0EA5E9), const Color(0xFF0D9488)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.app_registration_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'أهلاً بك معنا! 👋',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'أدخل بياناتك لبدء الفترة التجريبية (10 أيام / 200 قسيمة).',
                            style: TextStyle(fontSize: 12, color: Colors.white70, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 📝 كارت مدخلات البيانات
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'بيانات الحساب',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _nameController,
                      style: TextStyle(color: textColor),
                      decoration: _buildInputDecoration(
                        label: 'اسم العميل / المالِك',
                        icon: Icons.person_outline_rounded,
                        isDark: isDark,
                      ),
                      validator: (v) => v!.trim().isEmpty ? 'يرجى إدخال الاسم' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      style: TextStyle(color: textColor),
                      decoration: _buildInputDecoration(
                        label: 'رقم الهاتف',
                        icon: Icons.phone_android_rounded,
                        isDark: isDark,
                      ),
                      validator: (v) => v!.trim().isEmpty ? 'يرجى إدخال رقم الهاتف' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _networkController,
                      style: TextStyle(color: textColor),
                      decoration: _buildInputDecoration(
                        label: 'اسم الشبكة / الخدمة (مثل: شبكة اليمن)',
                        icon: Icons.wifi_rounded,
                        isDark: isDark,
                      ),
                      validator: (v) => v!.trim().isEmpty ? 'يرجى إدخال اسم الشبكة' : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 🆔 كارت معرف الجهاز
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.important_devices_rounded, size: 20, color: subTextColor),
                        const SizedBox(width: 8),
                        Text(
                          'معرف الجهاز:',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: subTextColor),
                        ),
                      ],
                    ),
                    SelectableText(
                      _deviceId.isEmpty ? 'جاري الجلب...' : _deviceId,
                      style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 🚀 زر البدء
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitRegistration,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'بدء استخدام الفترة التجريبية',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String label,
    required IconData icon,
    required bool isDark,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : Colors.black54),
      prefixIcon: Icon(icon, size: 20, color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0EA5E9)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      filled: true,
      fillColor: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0EA5E9), width: 1.5),
      ),
    );
  }
}*/

/*import 'package:flutter/material.dart';
import '../helpers/device_utils.dart';
import '../helpers/sync_manager.dart';

class RegistrationScreen extends StatefulWidget {
  final VoidCallback onRegistrationComplete;

  const RegistrationScreen({super.key, required onRegistrationComplete})
      : onRegistrationComplete = onRegistrationComplete;

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _networkController = TextEditingController();

  String _deviceId = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDeviceId();
  }

  Future<void> _loadDeviceId() async {
    String id = await DeviceUtils.getDeviceId();
    setState(() => _deviceId = id);
  }

  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // تسجيل الفترة التجريبية (10 أيام و 200 قسيمة)
    await SyncManager.registerTrialOnline(
      clientName: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      networkName: _networkController.text.trim(),
      trialDays: 10,
      trialVouchersLimit: 200,
    );

    setState(() => _isLoading = false);
    widget.onRegistrationComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل بيانات الخدمة')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.app_registration, size: 80, color: Colors.blue),
                const SizedBox(height: 16),
                const Text(
                  'أهلاً بك! يرجى إدخال البيانات لبدء الفترة التجريبية المجانية (10 أيام / 200 قسيمة)',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'اسم العميل / المالِك',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (v) => v!.isEmpty ? 'يرجى إدخال الاسم' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'رقم الهاتف',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  validator: (v) => v!.isEmpty ? 'يرجى إدخال رقم الهاتف' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _networkController,
                  decoration: const InputDecoration(
                    labelText: 'اسم الشبكة / الخدمة (مثل: شبكة اليمن)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.wifi),
                  ),
                  validator: (v) => v!.isEmpty ? 'يرجى إدخال اسم الشبكة' : null,
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('معرف الجهاز:', style: TextStyle(fontWeight: FontWeight.bold)),
                      SelectableText(_deviceId, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitRegistration,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('بدء استخدام الفترة التجريبية', style: TextStyle(fontSize: 18)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}*/