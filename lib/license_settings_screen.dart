import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../helpers/device_utils.dart';
import '../helpers/license_key_manager.dart';
import '../helpers/sync_manager.dart';

class LicenseSettingsScreen extends StatefulWidget {
  const LicenseSettingsScreen({super.key});

  @override
  State<LicenseSettingsScreen> createState() => _LicenseSettingsScreenState();
}

class _LicenseSettingsScreenState extends State<LicenseSettingsScreen> {
  final _codeController = TextEditingController();
  String _deviceId = '';
  String _licenseType = 'جاري التحميل...';
  String _expiryInfo = '';
  bool _isChecking = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadLicenseDetails();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadLicenseDetails() async {
    String id = await DeviceUtils.getDeviceId();
    var info = await LicenseKeyManager.getLicenseDetails();

    if (mounted) {
      setState(() {
        _deviceId = id;
        _licenseType = info['type'] ?? 'غير معروف';
        _expiryInfo = info['expiry'] ?? '';
      });
    }
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
        _codeController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تجديد وتحديث الترخيص بنجاح!')),
        );
        _loadLicenseDetails();
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم التحديث والمزامنة أونلاين بنجاح!')),
        );
        _loadLicenseDetails();
      } else {
        setState(() => _errorMessage = 'لم يتم العثور على تجديد جديد أونلاين.');
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
        title: const Text(
          'معلومات الترخيص والتجديد',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 💳 كارت تفاصيل الترخيص الحالي
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF0F766E), const Color(0xFF115E59)]
                      : [const Color(0xFF0D9488), const Color(0xFF0F766E)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.teal.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.verified_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'الترخيص الحالي',
                              style: TextStyle(fontSize: 12, color: Colors.white70),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _licenseType,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_expiryInfo.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(color: Colors.white24, height: 1),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded, color: Colors.white70, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          _expiryInfo,
                          style: const TextStyle(fontSize: 13, color: Colors.white),
                        ),
                      ],
                    ),
                  ],
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.fingerprint_rounded, size: 20, color: subTextColor),
                      const SizedBox(width: 8),
                      Text(
                        'معرف الجهاز (Device ID):',
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

            // 🔑 كارت التجديد بالكود أو أونلاين
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
                      labelText: 'تجديد كود التفعيل',
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

                  SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _isChecking ? null : _activateWithCode,
                      icon: const Icon(Icons.published_with_changes_rounded, size: 18, color: Colors.white),
                      label: const Text(
                        'تحديث الترخيص بالرمز',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _isChecking ? null : _checkOnlineRenewal,
                      icon: Icon(Icons.sync_rounded, size: 18, color: textColor),
                      label: Text(
                        'فحص التجديد أونلاين',
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
    );
  }
}