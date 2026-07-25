import 'package:flutter/material.dart';
import 'DatabaseHelper.dart';
import 'SmsWorker.dart';

class PendingLogsScreen extends StatefulWidget {
  const PendingLogsScreen({super.key});

  @override
  State<PendingLogsScreen> createState() => _PendingLogsScreenState();
}

class _PendingLogsScreenState extends State<PendingLogsScreen> {
  List<Map<String, dynamic>> _pendingLogs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPendingLogs();
  }

  /// تحميل العمليات المعلقة من قاعدة البيانات
  Future<void> _loadPendingLogs() async {
    setState(() => _isLoading = true);
    final logs = await DatabaseHelper.instance.getPendingLogs();
    setState(() {
      _pendingLogs = logs;
      _isLoading = false;
    });
  }

  /// نافذة الربط والإرسال المحدثة
  void _showResolveDialog(Map<String, dynamic> pendingLog) {
    TextEditingController phoneController = TextEditingController();
    TextEditingController nameController =
        TextEditingController(text: pendingLog['sender_name']);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.link, color: Colors.blue),
              SizedBox(width: 8),
              Text("ربط العميل وإرسال القسيمة", style: TextStyle(fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Text(
                    "الرسالة المستلمة:\n${pendingLog['received_message']}",
                    style:
                        TextStyle(color: Colors.amber.shade900, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: "اسم العميل",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: "رقم الهاتف (مثال: 771234567)",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "القسيمة المحجوزة: ${pendingLog['sent_number']}",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("إلغاء"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                String phone = phoneController.text.trim();
                String name = nameController.text.trim();
                String voucherCode = pendingLog['sent_number'];

                if (phone.length >= 9) {
                  // 1. ربط العميل وحفظ بياناته في قاعدة البيانات
                  await DatabaseHelper.instance.resolvePendingLog(
                    logId: pendingLog['id'],
                    customerPhone: phone,
                    customerName: name,
                    voucherCode: voucherCode,
                  );

                  // 2. إرسال القسيمة عبر SMS
                  String defaultReply = await DatabaseHelper.instance
                      .getSetting('default_reply', 'شكراً لتواصلك. رقمك هو: ');

                  await SmsWorker.telephony.sendSms(
                    to: phone,
                    message: "$defaultReply $voucherCode",
                    isMultipart: true,
                  );

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("تم ربط العميل وإرسال القسيمة بنجاح"),
                        backgroundColor: Colors.green,
                      ),
                    );
                    // إعادة تحميل القائمة لإخفاء العملية المكتملة
                    _loadPendingLogs();
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text("يرجى إدخال رقم هاتف صحيح مع تفاصيل الدولة"),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
              child: const Text("تأكيد وإرسال"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("العمليات المعلقة"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPendingLogs,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pendingLogs.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 64, color: Colors.green),
                      SizedBox(height: 12),
                      Text(
                        "لا توجد عمليات معلقة حالياً",
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _pendingLogs.length,
                  itemBuilder: (context, index) {
                    final item = _pendingLogs[index];
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: const CircleAvatar(
                          backgroundColor: Colors.amber,
                          child: Icon(Icons.warning_amber_rounded,
                              color: Colors.white),
                        ),
                        title: Text(
                          item['sender_name'] ?? 'عميل غير معروف',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              item['received_message'] ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "الفئة المطابقة: ${item['matched_keyword']} | القسيمة: ${item['sent_number']}",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        trailing: ElevatedButton(
                          onPressed: () => _showResolveDialog(item),
                          child: const Text("ربط وإرسال"),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
