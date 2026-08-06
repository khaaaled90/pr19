import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../helpers/device_utils.dart';
import '../helpers/license_key_manager.dart';
import '../helpers/sync_manager.dart';

class LicenseLockScreen extends StatefulWidget {
  final String lockReason;
  final VoidCallback onUnlocked;

  const LicenseLockScreen({
    super.key,
    required this.lockReason,
    required this.onUnlocked,
  });

  @override
  State<LicenseLockScreen> createState() => _LicenseLockScreenState();
}

class _LicenseLockScreenState extends State<LicenseLockScreen> {
  final _codeController = TextEditingController();
  String _deviceId = '';
  bool _isChecking = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDeviceId();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadDeviceId() async {
    String id = await DeviceUtils.getDeviceId();
    if (mounted) setState(() => _deviceId = id);
  }

  Future<void> _activateWithCode() async {
    String code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _isChecking = true;
      _errorMessage = null;
    });

    var result = await LicenseKeyManager.activateWithCode(code);

    if (mounted) {
      setState(() => _isChecking = false);

      if (result['success'] == true) {
        widget.onUnlocked();
      } else {
        setState(() => _errorMessage = result['message']);
      }
    }
  }

  Future<void> _checkOnlineRenewal() async {
    setState(() {
      _isChecking = true;
      _errorMessage = null;
    });

    var result = await SyncManager.checkAndSyncLicense();

    if (mounted) {
      setState(() => _isChecking = false);

      if (result['isValid'] == true) {
        widget.onUnlocked();
      } else {
        setState(() => _errorMessage = 'لم يتم العثور على تجديد أونلاين بعد، أعد المحاولة أو أدخل الكود.');
      }
    }
  }

  String _getReasonMessage() {
    switch (widget.lockReason) {
      case 'EXPIRED':
        return 'انتهت فترة الاشتراك الخاصة بك.';
      case 'LIMIT_REACHED':
        return 'تم استهلاك جميع القسائم المتاحة في التجربة.';
      case 'TIME_TAMPERED':
        return 'تم كشف تلاعب بتاريخ ووقت الجهاز! يرجى ضبط الساعة للوقت الصحيح.';
      default:
        return 'التطبيق غير مفعل، يرجى التفعيل للمتابعة.';
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
        title: const Text(
          'تفعيل الترخيص',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 🔒 كارت رأس الصفحة للتنبيه بقفل التطبيق
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF881337), const Color(0xFF4C0519)]
                        : [const Color(0xFFE11D48), const Color(0xFF9F1239)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.2),
                      blurRadius: 12,
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
                        color: Colors.white.withOpacity(0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_reset_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'التطبيق مقفل',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getReasonMessage(),
                            style: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 🆔 كارت معرف الجهاز والنسخ
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
                  children: [
                    Row(
                      children: [
                        Icon(Icons.fingerprint_rounded, size: 20, color: subTextColor),
                        const SizedBox(width: 8),
                        Text(
                          'معرف الجهاز الخاص بك (Device ID):',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: subTextColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: SelectableText(
                              _deviceId.isEmpty ? 'جاري الجلب...' : _deviceId,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.copy_rounded, color: primaryColor, size: 20),
                            tooltip: 'نسخ المعرف',
                            onPressed: () {
                              if (_deviceId.isNotEmpty) {
                                Clipboard.setData(ClipboardData(text: _deviceId));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('تم نسخ معرف الجهاز!')),
                                );
                              }
                            },
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 🔑 كارت إدخال كود التفعيل
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _codeController,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: 'أدخل كود التفعيل (أوفلاين)',
                        labelStyle: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : Colors.black54),
                        prefixIcon: Icon(Icons.key_rounded, size: 20, color: primaryColor),
                        errorText: _errorMessage,
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
                          borderSide: BorderSide(color: primaryColor, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // زر التفعيل بكود
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _isChecking ? null : _activateWithCode,
                        icon: const Icon(Icons.verified_user_rounded, size: 18, color: Colors.white),
                        label: const Text(
                          'تفعيل باستخدام الكود',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // زر الفحص أونلاين
                    SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _isChecking ? null : _checkOnlineRenewal,
                        icon: Icon(Icons.sync_rounded, size: 18, color: textColor),
                        label: Text(
                          'التحقق من التجديد أونلاين',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: isDark ? Colors.white24 : Colors.black26),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (_isChecking) ...[
                const SizedBox(height: 20),
                const Center(child: CircularProgressIndicator()),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
/*import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../helpers/device_utils.dart';
import '../helpers/license_key_manager.dart';
import '../helpers/sync_manager.dart';

class LicenseLockScreen extends StatefulWidget {
  final String lockReason;
  final VoidCallback onUnlocked;

  const LicenseLockScreen({
    super.key,
    required this.lockReason,
    required this.onUnlocked,
  });

  @override
  State<LicenseLockScreen> createState() => _LicenseLockScreenState();
}

class _LicenseLockScreenState extends State<LicenseLockScreen> {
  final _codeController = TextEditingController();
  String _deviceId = '';
  bool _isChecking = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDeviceId();
  }

  Future<void> _loadDeviceId() async {
    String id = await DeviceUtils.getDeviceId();
    setState(() => _deviceId = id);
  }

  // أ) التفعيل عبر كود أوفلاين
  Future<void> _activateWithCode() async {
    String code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _isChecking = true;
      _errorMessage = null;
    });

    var result = await LicenseKeyManager.activateWithCode(code);

    setState(() => _isChecking = false);

    if (result['success'] == true) {
      widget.onUnlocked();
    } else {
      setState(() => _errorMessage = result['message']);
    }
  }

  // ب) فحص التجديد المباشر عبر النت من Firebase
  Future<void> _checkOnlineRenewal() async {
    setState(() {
      _isChecking = true;
      _errorMessage = null;
    });

    var result = await SyncManager.checkAndSyncLicense();

    setState(() => _isChecking = false);

    if (result['isValid'] == true) {
      widget.onUnlocked();
    } else {
      setState(() => _errorMessage = 'لم يتم العثور على تجديد أونلاين بعد، أعد المحاولة أو أدخل الكود.');
    }
  }

  String _getReasonMessage() {
    switch (widget.lockReason) {
      case 'EXPIRED':
        return 'انتهت فترة الاشتراك الخاصة بك.';
      case 'LIMIT_REACHED':
        return 'تم استهلاك جميع القسائم المتاحة في التجربة.';
      case 'TIME_TAMPERED':
        return 'تم كشف تلاعب بتاريخ ووقت الجهاز! يرجى ضبط الساعة للوقت الصحيح.';
      default:
        return 'التطبيق غير مفعل، يرجى التفعيل للمتابعة.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 90, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'التطبيق مقفل',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _getReasonMessage(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text('معرف الجهاز الخاص بك (Device ID):'),
                      const SizedBox(height: 8),
                      SelectableText(
                        _deviceId,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _deviceId));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم نسخ المعرف!')),
                          );
                        },
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _codeController,
                decoration: InputDecoration(
                  labelText: 'أدخل كود التفعيل (أوفلاين)',
                  border: const OutlineInputBorder(),
                  errorText: _errorMessage,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.check_circle, color: Colors.green),
                    onPressed: _isChecking ? null : _activateWithCode,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _isChecking ? null : _activateWithCode,
                icon: const Icon(Icons.key),
                label: const Text('تفعيل باستخدام الكود'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _isChecking ? null : _checkOnlineRenewal,
                icon: const Icon(Icons.sync),
                label: const Text('التحقق من التجديد أونلاين (Firebase)'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}*/