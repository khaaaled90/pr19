import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'DatabaseHelper.dart';
import 'service/native_service_controller.dart'; // ✅ الكنترولر المسؤول عن طلب أذونات كوتلن

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

      _serviceEnabled = serviceVal == 'true';
      _notificationEnabled = notiVal == 'true';
      _archiveEnabled = archiveVal == 'true';
      _offersEnabled = offersVal == 'true';
      _stockAlertEnabled = stockAlertVal == 'true';

      _ownerPhoneController.text = ownerPhone;
      _warningThresholdController.text = threshold;
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
        backgroundColor: isError ? const Color(0xFFE74C3C) : const Color(0xFF27AE60),
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

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C3E50),
        elevation: 0,
        centerTitle: true,
        title: const Text('⚙️ الإعدادات والدعم الفني',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF27AE60)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionCard(
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
                        const Divider(height: 1),
                        SwitchListTile(
                          title: const Text('📋 الأرشفة',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          value: _archiveEnabled,
                          activeColor: const Color(0xFF27AE60),
                          onChanged: (v) => setState(() => _archiveEnabled = v),
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          title: const Text('🎁 العروض والمكافآت',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          value: _offersEnabled,
                          activeColor: const Color(0xFF27AE60),
                          onChanged: (v) => setState(() => _offersEnabled = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildSectionCard(
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
                        _buildStockTable(threshold),
                        TextButton.icon(
                          onPressed: _fetchStockStatus,
                          icon: const Icon(Icons.refresh, color: Color(0xFF3498DB)),
                          label: const Text('تحديث بيانات الجدول',
                              style: TextStyle(color: Color(0xFF3498DB))),
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
                  const SizedBox(height: 20),
                  _buildHelpAccordion(
                    title: '📞 معلومات الاتصال والدعم',
                    icon: Icons.contact_support_rounded,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.person, color: Color(0xFF3498DB)),
                        title: const Text('الدعم الفني'),
                        subtitle: const Text('773779585 (اضغط للنسخ)'),
                        onTap: () => _copyToClipboard('773779585', 'رقم الدعم الفني'),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF25D366)),
                                onPressed: () => _openWhatsApp('773779585'),
                                icon: const Icon(Icons.chat, color: Colors.white, size: 18),
                                label: const Text('واتساب',
                                    style: TextStyle(color: Colors.white)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF3498DB)),
                                onPressed: () => _makePhoneCall('773779585'),
                                icon: const Icon(Icons.phone, color: Colors.white, size: 18),
                                label: const Text('اتصال',
                                    style: TextStyle(color: Colors.white)),
                              ),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
            const Divider(),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildStockTable(int warningThreshold) {
    if (_stockStatusList.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12.0),
        child: Center(child: Text('📭 لا توجد كلمات مفتاحية بعد')),
      );
    }

    return Table(
      border: TableBorder.all(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)),
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(1.2),
        2: FlexColumnWidth(1.2),
        3: FlexColumnWidth(2),
      },
      children: [
        const TableRow(
          decoration: BoxDecoration(color: Color(0xFF2C3E50)),
          children: [
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
      {required String title, required IconData icon, required List<Widget> children}) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: Icon(icon, color: const Color(0xFF2C3E50)),
        title: Text(title,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
        children: children,
      ),
    );
  }
}
