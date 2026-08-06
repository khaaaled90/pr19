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
}