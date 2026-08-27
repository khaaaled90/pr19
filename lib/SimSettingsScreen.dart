import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class SimSettingsScreen extends StatefulWidget {
  const SimSettingsScreen({Key? key}) : super(key: key);

  @override
  State<SimSettingsScreen> createState() => _SimSettingsScreenState();
}

class _SimSettingsScreenState extends State<SimSettingsScreen> {
  static const MethodChannel _nativeChannel =
      MethodChannel('com.example.pr19/native_control');

  List<Map<String, dynamic>> _simCards = [];
  int _selectedSubId = -1;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSimData();
  }

  Future<void> _loadSimData() async {
    // 1. طلب صلاحيات الهاتف
    /*var status = await Permission.phone.request();
    if (!status.isGranted) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى منح إذن قراءة حالة الهاتف لقراءة الشرائح')),
        );
      }
      return;
    }*/
    // 1. طلب صلاحيات الهاتف والرسائل معا
    Map<Permission, PermissionStatus> statuses = await [
        Permission.phone,
        Permission.sms,
    ].request();

    if (statuses[Permission.phone] != PermissionStatus.granted) {
        if (mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('يرجى منح إذن قراءة حالة الهاتف لقراءة الشرائح')),
            );
        }
        return;
    }

    try {
      // 2. جلب قائمة الشرائح والشريحة المحفوظة سابقاً
      final List<dynamic>? rawSims =
          await _nativeChannel.invokeMethod('getAvailableSims');
      final int savedSubId =
          await _nativeChannel.invokeMethod('getSelectedSim');

      if (mounted) {
        setState(() {
          _simCards = rawSims != null
              ? List<Map<String, dynamic>>.from(
                  rawSims.map((e) => Map<String, dynamic>.from(e)))
              : [];
          _selectedSubId = savedSubId;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("خطأ أثناء تحميل بيانات الشرائح: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSelectedSim(int subId) async {
    try {
      await _nativeChannel.invokeMethod('setSelectedSim', {'subId': subId});
      setState(() => _selectedSubId = subId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم حفظ شريحة إرسال القسائم بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint("خطأ في حفظ الشريحة: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات شريحة الإرسال'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.blue.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.sim_card_rounded,
                            color: theme.primaryColor, size: 28),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'حدد الشريحة التي سيتم استخدامها لإرسال كروت وقسائم الرد الآلي للزبائن.',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'الشرائح المتاحة على الجهاز:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  if (_simCards.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 30),
                        child: Text('لم يتم التعرف على أي شريحة مفعّلة'),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: _simCards.length,
                        itemBuilder: (context, index) {
                          //final sim = _simCards[index];
                          //final int subId = sim['subId'];
                          //final String displayName = sim['displayName'];
                          //final String carrierName = sim['carrierName'];
                          //final int slotIndex = sim['slotIndex'];
                          final sim = _simCards[index];
                          final int subId = (sim['subId'] as num).toInt();
                          final String displayName = sim['displayName']?.toString() ?? '';
                          final String carrierName = sim['carrierName']?.toString() ?? '';
                          final int slotIndex = (sim['slotIndex'] as num).toInt();
                          final bool isSelected = _selectedSubId == subId;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? theme.primaryColor
                                    : (isDark
                                        ? Colors.white10
                                        : Colors.grey.shade300),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: RadioListTile<int>(
                              value: subId,
                              groupValue: _selectedSubId,
                              activeColor: theme.primaryColor,
                              title: Text(
                                '$displayName ${carrierName.isNotEmpty ? "($carrierName)" : ""}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text('المنفذ: SIM ${slotIndex + 1}'),
                              onChanged: (val) {
                                if (val != null) {
                                  _saveSelectedSim(val);
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}