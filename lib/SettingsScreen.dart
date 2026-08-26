import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'DatabaseHelper.dart';
import 'service/native_service_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;

  bool _serviceEnabled = true;
  bool _notificationEnabled = true;
  bool _archiveEnabled = true;
  bool _offersEnabled = true;
  bool _stockAlertEnabled = true;

  final TextEditingController _ownerPhoneController = TextEditingController();
  final TextEditingController _warningThresholdController = TextEditingController();
  final TextEditingController _footerMessageController = TextEditingController();
  final TextEditingController _defaultReplyController = TextEditingController();

  List<Map<String, dynamic>> _stockStatusList = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettingsAndStock();
  }

  @override
  void dispose() {
    _ownerPhoneController.dispose();
    _warningThresholdController.dispose();
    _defaultReplyController.dispose();
    _footerMessageController.dispose();
    super.dispose();
  }

  Future<void> _loadSettingsAndStock() async {
    setState(() => _isLoading = true);
    try {
      String serviceVal = await _db.getSetting('service_enabled', 'true');
      String notiVal = await _db.getSetting('enable_notification', 'true');
      String archiveVal = await _db.getSetting('enable_archive', 'true');
      String offersVal = await _db.getSetting('offers_enabled', 'true');
      String stockAlertVal = await _db.getSetting('stock_alert_enabled', 'true');
      String ownerPhone = await _db.getSetting('owner_phone', '777777777');
      String threshold = await _db.getSetting('warning_threshold', '5');
      String footerMsg = await _db.getSetting('footer_message', '');
      String defaultReply = await _db.getSetting('default_reply', 'شكراً لتواصلك. رقمك الخاص هو:');

      _serviceEnabled = serviceVal == 'true';
      _notificationEnabled = notiVal == 'true';
      _archiveEnabled = archiveVal == 'true';
      _offersEnabled = offersVal == 'true';
      _stockAlertEnabled = stockAlertVal == 'true';

      _ownerPhoneController.text = ownerPhone;
      _warningThresholdController.text = threshold;
      _defaultReplyController.text = defaultReply;
      _footerMessageController.text = footerMsg;

      await _fetchStockStatus();
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('❌ خطأ أثناء تحميل الإعدادات: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchStockStatus() async {
    final keywords = await _db.getAllKeywords();
    final numbers = await _db.getAllNumbers();

    List<Map<String, dynamic>> stockList = [];

    for (var k in keywords) {
      int kId = k['id'];
      int avail = numbers.where((n) => n['keyword_id'] == kId && n['status'] == 'available').length;
      int used = numbers.where((n) => n['keyword_id'] == kId && n['status'] == 'used').length;

      stockList.add({
        'keyword': k['keyword'].toString(),
        'available': avail,
        'used': used,
      });
    }

    if (mounted) {
      setState(() {
        _stockStatusList = stockList;
      });
    }
  }

  Future<void> _saveAllSettings() async {
    setState(() => _isSaving = true);
    try {
      await _db.updateSetting('service_enabled', _serviceEnabled ? 'true' : 'false');
      await _db.updateSetting('enable_notification', _notificationEnabled ? 'true' : 'false');
      await _db.updateSetting('enable_archive', _archiveEnabled ? 'true' : 'false');
      await _db.updateSetting('offers_enabled', _offersEnabled ? 'true' : 'false');
      await _db.updateSetting('stock_alert_enabled', _stockAlertEnabled ? 'true' : 'false');
      await _db.updateSetting('owner_phone', _ownerPhoneController.text.trim());
      await _db.updateSetting('warning_threshold', _warningThresholdController.text.trim());
      await _db.updateSetting('default_reply', _defaultReplyController.text.trim());
      await _db.updateSetting('footer_message', _footerMessageController.text.trim());

      if (!mounted) return;
      _showSnackBar('✅ تم حفظ الإعدادات بنجاح');
      await _fetchStockStatus();
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('❌ فشل حفظ الإعدادات: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        duration: const Duration(milliseconds: 2000),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int threshold = int.tryParse(_warningThresholdController.text) ?? 5;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: const Text(
          'الإعدادات والتهيئات',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: theme.primaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100), // padding سفلي لعدم التغطية
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionCard(
                    context,
                    title: 'خيارات الرد التلقائي والنظام',
                    icon: Icons.tune_rounded,
                    child: Column(
                      children: [
                        _buildCustomSwitchTile(
                          title: 'الرد الآلي التلقائي',
                          subtitle: 'تفعيل أو إيقاف الخدمة بشكل كامل',
                          value: _serviceEnabled,
                          icon: Icons.smart_toy_outlined,
                          onChanged: (v) => setState(() => _serviceEnabled = v),
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        _buildCustomSwitchTile(
                          title: 'قراءة الإشعارات (إذن النظام)',
                          subtitle: 'مطلوب لاستلام رسائل المحافظ والبنوك تلقائياً',
                          value: _notificationEnabled,
                          icon: Icons.notifications_active_outlined,
                          onChanged: (v) async {
                            setState(() => _notificationEnabled = v);
                            if (v) {
                              await NativeServiceController.requestNotificationListenerPermission();
                            }
                          },
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: CircleAvatar(
                            backgroundColor: theme.primaryColor.withOpacity(0.1),
                            child: Icon(Icons.battery_saver_rounded, color: theme.primaryColor, size: 20),
                          ),
                          title: const Text(
                            'استثناء القيود على البطارية',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          subtitle: const Text('يمنع النظام من إيقاف الخدمة في الخلفية'),
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                          onTap: () async {
                            await NativeServiceController.requestIgnoreBatteryOptimizations();
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  _buildSectionCard(
                    context,
                    title: 'قوالب الرسائل النصية',
                    icon: Icons.message_rounded,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTextField(
                            controller: _defaultReplyController,
                            label: 'رسالة بداية الرد (مقدمة الرسالة)',
                            hint: 'مثال: شكراً لتواصلك. رقمك الخاص هو:',
                            icon: Icons.first_page_rounded,
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _footerMessageController,
                            label: 'رسالة نهاية الرد (خاتمة الرسالة)',
                            hint: 'مثال: شكراً لثقتكم بنا...',
                            icon: Icons.last_page_rounded,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  _buildSectionCard(
                    context,
                    title: 'تنبيهات نفاذ المخزون',
                    icon: Icons.inventory_2_rounded,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: _buildTextField(
                                  controller: _ownerPhoneController,
                                  label: 'رقم المدير للتنبيه',
                                  hint: '777777777',
                                  icon: Icons.phone_android_rounded,
                                  keyboardType: TextInputType.phone,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 1,
                                child: _buildTextField(
                                  controller: _warningThresholdController,
                                  label: 'الحد الأدنى',
                                  hint: '5',
                                  icon: Icons.warning_amber_rounded,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildCustomSwitchTile(
                            title: 'تفعيل إشعارات النفاذ',
                            subtitle: 'إرسال تنبيه عند وصول الفئات للحد الأدنى',
                            value: _stockAlertEnabled,
                            icon: Icons.add_alert_rounded,
                            onChanged: (v) => setState(() => _stockAlertEnabled = v),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'جدول حالة المخزون الحالية',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: theme.textTheme.titleMedium?.color,
                                ),
                              ),
                              IconButton(
                                onPressed: _fetchStockStatus,
                                icon: Icon(Icons.refresh_rounded, color: theme.primaryColor, size: 20),
                                tooltip: 'تحديث البيانات',
                              )
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildStockTable(context, threshold),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
      // تثبيت زر الحفظ دائماً أسفل الشاشة
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _isSaving ? null : _saveAllSettings,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded, color: Colors.white),
              label: Text(
                _isSaving ? 'جاري الحفظ...' : 'حفظ التغييرات',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    Function(String)? onChanged,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: theme.primaryColor),
        filled: true,
        fillColor: isDark ? Colors.black.withOpacity(0.2) : Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: theme.primaryColor, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildCustomSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required IconData icon,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      secondary: CircleAvatar(
        backgroundColor: theme.primaryColor.withOpacity(0.1),
        child: Icon(icon, color: theme.primaryColor, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color)),
      value: value,
      activeColor: const Color(0xFF10B981),
      onChanged: onChanged,
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(icon, color: theme.primaryColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.titleMedium?.color,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          child,
        ],
      ),
    );
  }

  Widget _buildStockTable(BuildContext context, int warningThreshold) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_stockStatusList.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(
          child: Text(
            '📭 لا توجد كلمات مفتاحية مضافة بعد',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
          ),
        ),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(2),
            1: FlexColumnWidth(1.2),
            2: FlexColumnWidth(1.2),
            3: FlexColumnWidth(1.8),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
              ),
              children: [
                _buildTableCell('الكلمة', isHeader: true),
                _buildTableCell('متاح', isHeader: true),
                _buildTableCell('مستخدم', isHeader: true),
                _buildTableCell('الحالة', isHeader: true),
              ],
            ),
            ..._stockStatusList.map((item) {
              int avail = item['available'];
              int used = item['used'];

              Color badgeColor = const Color(0xFF10B981);
              String statusText = 'متوفر';

              if (avail == 0) {
                badgeColor = const Color(0xFFEF4444);
                statusText = 'منفذ';
              } else if (avail <= warningThreshold) {
                badgeColor = const Color(0xFFF59E0B);
                statusText = 'منخفض';
              }

              return TableRow(
                children: [
                  _buildTableCell(item['keyword']),
                  _buildTableCell('$avail', textColor: const Color(0xFF10B981)),
                  _buildTableCell('$used', textColor: const Color(0xFFEF4444)),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                      decoration: BoxDecoration(
                        color: badgeColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        statusText,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: badgeColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTableCell(String text, {bool isHeader = false, Color? textColor}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isHeader ? FontWeight.bold : FontWeight.w600,
          color: textColor ?? (isHeader ? theme.textTheme.titleMedium?.color : theme.textTheme.bodyMedium?.color),
        ),
      ),
    );
  }
}
/*import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'DatabaseHelper.dart';
import 'service/native_service_controller.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;

  bool _serviceEnabled = true;
  bool _notificationEnabled = true;
  bool _archiveEnabled = true;
  bool _offersEnabled = true;
  bool _stockAlertEnabled = true;

  final TextEditingController _ownerPhoneController = TextEditingController();
  final TextEditingController _warningThresholdController = TextEditingController();
  final TextEditingController _footerMessageController = TextEditingController();
  final TextEditingController _defaultReplyController = TextEditingController();

  List<Map<String, dynamic>> _stockStatusList = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettingsAndStock();
  }

  @override
  void dispose() {
    _ownerPhoneController.dispose();
    _warningThresholdController.dispose();
    _defaultReplyController.dispose();
    _footerMessageController.dispose();
    super.dispose();
  }

  Future<void> _loadSettingsAndStock() async {
    setState(() => _isLoading = true);
    try {
      String serviceVal = await _db.getSetting('service_enabled', 'true');
      String notiVal = await _db.getSetting('enable_notification', 'true');
      String archiveVal = await _db.getSetting('enable_archive', 'true');
      String offersVal = await _db.getSetting('offers_enabled', 'true');
      String stockAlertVal = await _db.getSetting('stock_alert_enabled', 'true');
      String ownerPhone = await _db.getSetting('owner_phone', '777777777');
      String threshold = await _db.getSetting('warning_threshold', '5');
      String footerMsg = await _db.getSetting('footer_message', '');
      String defaultReply = await _db.getSetting('default_reply', 'شكراً لتواصلك. رقمك الخاص هو:');

      _serviceEnabled = serviceVal == 'true';
      _notificationEnabled = notiVal == 'true';
      _archiveEnabled = archiveVal == 'true';
      _offersEnabled = offersVal == 'true';
      _stockAlertEnabled = stockAlertVal == 'true';

      _ownerPhoneController.text = ownerPhone;
      _warningThresholdController.text = threshold;
      _defaultReplyController.text = defaultReply;
      _footerMessageController.text = footerMsg;

      await _fetchStockStatus();
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('❌ خطأ أثناء تحميل الإعدادات: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchStockStatus() async {
    final keywords = await _db.getAllKeywords();
    final numbers = await _db.getAllNumbers();

    List<Map<String, dynamic>> stockList = [];

    for (var k in keywords) {
      int kId = k['id'];
      int avail = numbers.where((n) => n['keyword_id'] == kId && n['status'] == 'available').length;
      int used = numbers.where((n) => n['keyword_id'] == kId && n['status'] == 'used').length;

      stockList.add({
        'keyword': k['keyword'].toString(),
        'available': avail,
        'used': used,
      });
    }

    if (mounted) {
      setState(() {
        _stockStatusList = stockList;
      });
    }
  }

  Future<void> _saveAllSettings() async {
    setState(() => _isSaving = true);
    try {
      await _db.updateSetting('service_enabled', _serviceEnabled ? 'true' : 'false');
      await _db.updateSetting('enable_notification', _notificationEnabled ? 'true' : 'false');
      await _db.updateSetting('enable_archive', _archiveEnabled ? 'true' : 'false');
      await _db.updateSetting('offers_enabled', _offersEnabled ? 'true' : 'false');
      await _db.updateSetting('stock_alert_enabled', _stockAlertEnabled ? 'true' : 'false');
      await _db.updateSetting('owner_phone', _ownerPhoneController.text.trim());
      await _db.updateSetting('warning_threshold', _warningThresholdController.text.trim());
      await _db.updateSetting('default_reply', _defaultReplyController.text.trim());
      await _db.updateSetting('footer_message', _footerMessageController.text.trim());

      if (!mounted) return;
      _showSnackBar('✅ تم حفظ الإعدادات بنجاح');
      await _fetchStockStatus();
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('❌ فشل حفظ الإعدادات: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF27AE60),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        duration: const Duration(milliseconds: 2000),
      ),
    );
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    _showSnackBar('✅ تم نسخ $label: $text');
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri url = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      }
    } catch (_) {
      _showSnackBar('❌ تعذر إجراء الاتصال تلقائياً', isError: true);
    }
  }

  Future<void> _openWhatsApp(String phoneNumber) async {
    final Uri url = Uri.parse("https://wa.me/967$phoneNumber");
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      _showSnackBar('❌ تعذر فتح تطبيق واتساب', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    int threshold = int.tryParse(_warningThresholdController.text) ?? 5;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: const Text('⚙️ الإعدادات والدعم الفني',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: theme.primaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionCard(
                    context,
                    title: '🔘 الإعدادات العامة وخيارات النظام',
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text('🤖 الرد الآلي',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          value: _serviceEnabled,
                          activeColor: const Color(0xFF27AE60),
                          onChanged: (v) => setState(() => _serviceEnabled = v),
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          title: const Text('🔔 قراءة الإشعارات (إذن النظام)',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          subtitle: const Text('مطلوب لاستلام رسائل المحافظ والبنوك تلقائياً'),
                          value: _notificationEnabled,
                          activeColor: const Color(0xFF27AE60),
                          onChanged: (v) async {
                            setState(() => _notificationEnabled = v);
                            if (v) {
                              await NativeServiceController.requestNotificationListenerPermission();
                            }
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          title: const Text('🔋 استثناء التطبيق من قيود البطارية',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          subtitle: const Text('يمنع الأندرويد من إيقاف الخدمة عند قفل الشاشة'),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () async {
                            await NativeServiceController.requestIgnoreBatteryOptimizations();
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildSectionCard(
                    context,
                    title: '💬 رسالة بداية الرد (مقدمة الرسالة)',
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextField(
                        controller: _defaultReplyController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'مثال: شكراً لتواصلك. رقمك الخاص هو:',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.all(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildSectionCard(
                    context,
                    title: '📝 رسالة نهاية الرد',
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextField(
                        controller: _footerMessageController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'مثال: شكراً لثقتكم بنا...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.all(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildSectionCard(
                    context,
                    title: '🚨 إشعارات نفاذ أرقام الباقات',
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: _ownerPhoneController,
                                  keyboardType: TextInputType.phone,
                                  decoration: InputDecoration(
                                    labelText: '📞 رقم المدير',
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 1,
                                child: TextField(
                                  controller: _warningThresholdController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  decoration: InputDecoration(
                                    labelText: '⚠️ الحد الأدنى',
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SwitchListTile(
                          title: const Text('🔔 تفعيل تنبيه النفاذ',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          value: _stockAlertEnabled,
                          activeColor: const Color(0xFF27AE60),
                          onChanged: (v) => setState(() => _stockAlertEnabled = v),
                        ),
                        const Divider(),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Text('جدول حالة المخزون الحالية',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                        _buildStockTable(context, threshold),
                        TextButton.icon(
                          onPressed: _fetchStockStatus,
                          icon: Icon(Icons.refresh, color: theme.colorScheme.primary),
                          label: Text('تحديث بيانات الجدول',
                              style: TextStyle(color: theme.colorScheme.primary)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF27AE60),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isSaving ? null : _saveAllSettings,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.save_rounded, color: Colors.white),
                      label: Text(
                        _isSaving ? 'جاري الحفظ...' : '💾 حفظ الإعدادات',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح الرابط')),
        );
      }
    }
  }

  Widget _buildSectionCard(BuildContext context, {required String title, required Widget child}) {
    final theme = Theme.of(context);
    return Card(
      elevation: theme.brightness == Brightness.dark ? 1 : 2,
      color: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.titleMedium?.color)),
            const Divider(),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildStockTable(BuildContext context, int warningThreshold) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_stockStatusList.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12.0),
        child: Center(child: Text('📭 لا توجد كلمات مفتاحية بعد')),
      );
    }

    return Table(
      border: TableBorder.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(8)),
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(1.2),
        2: FlexColumnWidth(1.2),
        3: FlexColumnWidth(2),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade800 : const Color(0xFF2C3E50)),
          children: const [
            Padding(
                padding: EdgeInsets.all(6.0),
                child: Text('🔑 الكلمة',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.white, fontSize: 11))),
            Padding(
                padding: EdgeInsets.all(6.0),
                child: Text('📥 متاح',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.white, fontSize: 11))),
            Padding(
                padding: EdgeInsets.all(6.0),
                child: Text('📤 مستخدم',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.white, fontSize: 11))),
            Padding(
                padding: EdgeInsets.all(6.0),
                child: Text('⚠️ الحالة',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.white, fontSize: 11))),
          ],
        ),
        ..._stockStatusList.map((item) {
          int avail = item['available'];
          int used = item['used'];

          Color badgeColor = const Color(0xFF27AE60);
          String statusText = '🟢 $avail';

          if (avail == 0) {
            badgeColor = const Color(0xFFE74C3C);
            statusText = '🔴 منفذ';
          } else if (avail <= warningThreshold) {
            badgeColor = const Color(0xFFFF9800);
            statusText = '🟠 $avail فقط';
          }

          return TableRow(
            children: [
              Padding(
                  padding: const EdgeInsets.all(6.0),
                  child: Text(item['keyword'],
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold))),
              Padding(
                  padding: const EdgeInsets.all(6.0),
                  child: Text('$avail',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Color(0xFF27AE60), fontWeight: FontWeight.bold))),
              Padding(
                  padding: const EdgeInsets.all(6.0),
                  child: Text('$used',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFE74C3C)))),
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                  decoration: BoxDecoration(
                      color: badgeColor, borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    statusText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildHelpAccordion(
      BuildContext context,
      {required String title, required IconData icon, required List<Widget> children}) {
    final theme = Theme.of(context);
    return Card(
      elevation: theme.brightness == Brightness.dark ? 1 : 1,
      color: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: Icon(icon, color: theme.iconTheme.color),
        title: Text(title,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.titleMedium?.color)),
        children: children,
      ),
    );
  }
}*/