import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'DatabaseHelper.dart';

// قنوات الاتصال المباشرة مع Kotlin
const MethodChannel _smsChannel = MethodChannel('com.example.app/sms');
const MethodChannel _nativeControlChannel = MethodChannel('com.example.pr19/native_control');
//const MethodChannel _nativeControlChannel = MethodChannel('com.example.pr19/native_control');

class PendingLogsScreen extends StatefulWidget {
  const PendingLogsScreen({super.key});

  @override
  State<PendingLogsScreen> createState() => _PendingLogsScreenState();
}

class _PendingLogsScreenState extends State<PendingLogsScreen> {
  List<Map<String, dynamic>> _pendingLogs = [];
  bool _isLoading = true;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadPendingLogs();
  }

  /// دالة تنبيه الـ Native لمتابعة مخزون الكروت
  Future<void> triggerManagerAlertNative(int keywordId, String keywordText) async {
    try {
      await _nativeControlChannel.invokeMethod('native_control', {
        'keywordId': keywordId,
        'keywordText': keywordText,
      });
    } catch (e) {
      debugPrint("⚠️ تعذر استدعاء دالة تنبيه المخزون في Kotlin: $e");
    }
  }

  /// دالة إرسال الـ SMS المباشرة عبر Kotlin
  Future<bool> _sendSmsNative(String phone, String message) async {
    try {
      final bool? result = await _smsChannel.invokeMethod('sendSms', {
        'phone': phone,
        'message': message,
      });
      return result ?? true;
    } on PlatformException catch (e) {
      debugPrint("فشل إرسال SMS عبر القناة: ${e.message}");
      return false;
    } catch (e) {
      debugPrint("خطأ أثناء إرسال SMS: $e");
      return false;
    }
  }

  /// تحميل العمليات المعلقة من قاعدة البيانات
  Future<void> _loadPendingLogs() async {
    setState(() => _isLoading = true);
    final logs = await DatabaseHelper.instance.getPendingLogs();
    if (mounted) {
      setState(() {
        _pendingLogs = logs;
        _isLoading = false;
      });
    }
  }

  Future<void> _checkAndAutoResolvePendingLogs() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);

    try {
      List<Map<String, dynamic>> currentLogs = await DatabaseHelper.instance.getPendingLogs();
      int resolvedCount = 0;
      String defaultReply = await DatabaseHelper.instance
          .getSetting('default_reply', 'شكراً لتواصلك. رقمك الخاص هو: ');

      for (var log in currentLogs) {
        String sender = log['sender'] ?? '';
        String sendername = log['sender_name'] ?? '';
        String phone = log['customer_phone'] ?? '';
        String messageBody = log['received_message'] ?? ''; // 👈 أضف هذا السطر لسحب نص الرسالة

        Map<String, dynamic>? customer;
        if (phone.isNotEmpty) {
          customer = await DatabaseHelper.instance.getCustomerByPhone(phone);
        }
        if (customer == null && sender.isNotEmpty) {
          customer = await DatabaseHelper.instance.getCustomerByNameOrIdentifier(sendername);
        }

        if (customer != null) {
          String matchedPhone = customer['phone'] ?? phone;
          String matchedName = customer['name'] ?? sender;
          String matchedKeyword = log['matched_keyword'] ?? '';

          String? voucherCode = await DatabaseHelper.instance
              .getAndUseVoucherByKeyword(matchedKeyword, matchedPhone);

          if (voucherCode != null && voucherCode.isNotEmpty) {
            await DatabaseHelper.instance.resolvePendingLog(
              logId: log['id'],
              customerPhone: matchedPhone,
              customerName: matchedName,
              voucherCode: voucherCode,
            );

            String? extractedBalance = _extractBalanceFromBody(messageBody);
            if (extractedBalance != null && extractedBalance.isNotEmpty) {
              await DatabaseHelper.instance.updateCustomerBalance(
                matchedPhone,
                extractedBalance,
              );
            }
            /*String? extractedBalance = _extractBalanceFromBody(messageBody);
            if (extractedBalance != null && extractedBalance.isNotEmpty) {
              await DatabaseHelper.instance.updateCustomerBalance(
                phone: matchedPhone,
                newBalance: extractedBalance,
              );
            }*/

            String fullMsg = "$defaultReply $voucherCode";
            await _sendSmsNative(matchedPhone, fullMsg);
            resolvedCount++;
          }
        }
      }

      await _loadPendingLogs();

      if (mounted) {
        if (resolvedCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("✨ تم حسم $resolvedCount عملية معلقة تلقائياً وتزويد العملاء بالقسائم!"),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("تحديث: لا توجد عمليات معلقة لعملاء مربوطين حالياً."),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("خطأ أثناء الفحص التلقائي للمعلقات: $e");
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  // 👈 أضف هذه الدالة المساندة لاستخراج الرصيد من النص
  String? _extractBalanceFromBody(String body) {
    final balanceRegex = RegExp(
      r'(?:رصيدك|الرصيد|رصيدكم|رصيد|متبقي|المتبقي|ر\.?ص|Balance|Bal)[\s:]*([\d,]+(?:\.\d+)?)',
      caseSensitive: false,
    );
    final match = balanceRegex.firstMatch(body);
    return match?.group(1)?.replaceAll(',', '');
  }

  /// نافذة الربط والإرسال المحدثة
  void _showResolveDialog(Map<String, dynamic> pendingLog) {
    final phoneController = TextEditingController();
    final nameController = TextEditingController(text: pendingLog['sender_name']);

    showDialog(
      context: context,
      builder: (dialogContext) {
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
                    style: TextStyle(color: Colors.amber.shade900, fontSize: 13),
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
              onPressed: () => Navigator.pop(dialogContext),
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
                String matchedKeyword = pendingLog['matched_keyword'] ?? '';
                int? keywordId = pendingLog['keyword_id'] as int?;

                if (phone.length >= 9) {
                  // 1. تحديث الكاش وقاعدة البيانات عبر Kotlin
                  try {
                    await _nativeControlChannel.invokeMethod("registerCustomer", {
                      "phone": phone,
                      "name": name,
                      "wallet": null,
                      "balance": "",
                    });
                  } catch (e) {
                    debugPrint("تنبيه: تعذر تحديث كاش العميل في جانب Kotlin: $e");
                  }

                  // 2. سحب قسيمة جديدة من قاعدة البيانات
                  String? voucherCode = await DatabaseHelper.instance
                      .getAndUseVoucherByKeyword(matchedKeyword, phone);

                  if (voucherCode == null || voucherCode.isEmpty) {
                    if (keywordId != null) {
                      await triggerManagerAlertNative(keywordId, matchedKeyword);
                    }
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("⚠️ نفدت القسائم المتوفرة لهذه الفئة! يرجى إضافة كروت جديدة أولاً."),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                    return;
                  }

                  //await triggerManagerAlertNative(keywordId, matchedKeyword);
                  if (keywordId != null) {
                    await triggerManagerAlertNative(keywordId, matchedKeyword);
                  }
                  // 3. تحديث حالة العملية المعلقة
                  await DatabaseHelper.instance.resolvePendingLog(
                    logId: pendingLog['id'],
                    customerPhone: phone,
                    customerName: name,
                    voucherCode: voucherCode,
                  );

                  // 4. إعداد وإرسال الـ SMS
                  String defaultReply = await DatabaseHelper.instance
                      .getSetting('default_reply', 'شكراً لتواصلك. رقمك الخاص هو: ');
                  String fullMsg = "$defaultReply $voucherCode";

                  bool isSent = await _sendSmsNative(phone, fullMsg);

                  if (mounted) {
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isSent
                            ? "تم ربط العميل وصرف القسيمة ($voucherCode) وإرسالها بنجاح"
                            : "تم ربط العميل وصرف القسيمة ولكن تعذر إرسال الـ SMS"),
                        backgroundColor: isSent ? Colors.green : Colors.orange,
                      ),
                    );
                    _loadPendingLogs();
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("يرجى إدخال رقم هاتف صحيح (9 أرقام)"),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
              child: const Text("تأكيد وصرف القسيمة"),
            ),
          ],
        );
      },
    ).then((_) {
      // تفريغ الـ Controllers تلقائياً بعد إغلاق الـ Dialog
      phoneController.dispose();
      nameController.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("العمليات المعلقة"),
        actions: [
          IconButton(
            icon: _isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.refresh),
            tooltip: "تحديث وحسم معلقات العملاء المربوطين",
            onPressed: _isSyncing ? null : _checkAndAutoResolvePendingLogs,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _checkAndAutoResolvePendingLogs,
              child: _pendingLogs.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 200),
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                size: 64,
                                color: Colors.green,
                              ),
                              SizedBox(height: 12),
                              Text(
                                "لا توجد عمليات معلقة حالياً",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
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
                              child: Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.white,
                              ),
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
            ),
    );
  }
}
/*import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'DatabaseHelper.dart';

// قناة الاتصال المباشرة مع Kotlin
const MethodChannel _smsChannel = MethodChannel('com.example.app/sms');

class PendingLogsScreen extends StatefulWidget {
  const PendingLogsScreen({super.key});

  @override
  State<PendingLogsScreen> createState() => _PendingLogsScreenState();
}

class _PendingLogsScreenState extends State<PendingLogsScreen> {
  List<Map<String, dynamic>> _pendingLogs = [];
  bool _isLoading = true;
  bool _isSyncing = false;

  Future<void> _checkAndAutoResolvePendingLogs() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);

    try {
      // 1. إعادة تحميل المعلقات الحالية
      List<Map<String, dynamic>> currentLogs = await DatabaseHelper.instance.getPendingLogs();
      
      int resolvedCount = 0;
      String defaultReply = await DatabaseHelper.instance
          .getSetting('default_reply', 'شكراً لتواصلك. رقمك الخاص هو: ');

      for (var log in currentLogs) {
        String sender = log['sender'] ?? '';
        String phone = log['customer_phone'] ?? '';

        // 2. البحث عن العميل في قاعدة البيانات لغرض التأكد هل تم ربطه ساباقاً
        Map<String, dynamic>? customer;
        if (phone.isNotEmpty) {
          customer = await DatabaseHelper.instance.getCustomerByPhone(phone);
        }
        if (customer == null && sender.isNotEmpty) {
          customer = await DatabaseHelper.instance.getCustomerByNameOrIdentifier(sender);
        }

        // 3. إذا كان العميل مربوطاً وموجوداً بالفعل في النظام
        if (customer != null) {
          String matchedPhone = customer['phone'] ?? phone;
          String matchedName = customer['name'] ?? sender;
          String matchedKeyword = log['matched_keyword'] ?? '';

          // أ) سحب قسيمة جديدة للمسألة المعلقة
          String? voucherCode = await DatabaseHelper.instance
              .getAndUseVoucherByKeyword(matchedKeyword, matchedPhone);

          if (voucherCode != null && voucherCode.isNotEmpty) {
            // ب) حسم السجل المعلق
            await DatabaseHelper.instance.resolvePendingLog(
              logId: log['id'],
              customerPhone: matchedPhone,
              customerName: matchedName,
              voucherCode: voucherCode,
            );

            // ج) إرسال الرسالة النصية
            String fullMsg = "$defaultReply $voucherCode";
            await _sendSmsNative(matchedPhone, fullMsg);
            resolvedCount++;
          }
        }
      }

      // 4. إعادة تحميل القائمة وإظهار إشعار بالنتيجة
      await _loadPendingLogs();

      if (mounted) {
        if (resolvedCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("✨ تم حسم $resolvedCount عملية معلقة تلقائياً وتزويد العملاء بالقسائم!"),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("تحديث: لا توجد عمليات معلقة لعملاء مربوطين حالياً."),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("خطأ أثناء الفحص التلقائي للمعلقات: $e");
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }
  
  @override
  void initState() {
    super.initState();
    _loadPendingLogs();
  }

  /// دالة إرسال الـ SMS المباشرة عبر Kotlin
  Future<bool> _sendSmsNative(String phone, String message) async {
    try {
      final bool? result = await _smsChannel.invokeMethod('sendSms', {
        'phone': phone,
        'message': message,
      });
      return result ?? true;
    } on PlatformException catch (e) {
      debugPrint("فشل إرسال SMS عبر القناة: ${e.message}");
      return false;
    } catch (e) {
      debugPrint("خطأ أثناء إرسال SMS: $e");
      return false;
    }
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
                String matchedKeyword = pendingLog['matched_keyword'] ?? '';
            
                if (phone.length >= 9) {
                  // 1. 🧠 [التعديل الرئيسي] تحديث قاعدة البيانات الأصيلة والكاش عبر Kotlin أولاً
                  try {
                    const platform = MethodChannel("com.example.pr19/native_control"); // استبدلها باسي اسم قناتك
                    await platform.invokeMethod("registerCustomer", {
                      "phone": phone,
                      "name": name,
                      "wallet": null, // أرسل رقم المحفظة إن وجد داخل pendingLog
                      "balance": "",
                    });
                  } catch (e) {
                    debugPrint("تنبيه: تعذر تحديث كاش العميل في جانب Kotlin: $e");
                  }
                  
                  // 1. 🎯 التعديل الأساسي: سحب قسيمة جديدة ديناميكياً من قاعدة البيانات
                  String? voucherCode = await DatabaseHelper.instance
                      .getAndUseVoucherByKeyword(matchedKeyword, phone);
            
                  // في حال نفاد المخزون لهذا الكرت
                  if (voucherCode == null || voucherCode.isEmpty) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("⚠️ نفدت القسائم المتوفرة لهذه الفئة! يرجى إضافة كروت جديدة أولاً."),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                    return;
                  }
            
                  // 2. 📝 تحديث بيانات العملية المعلقة مع إضافة رقم القسيمة وتغيير حالتها
                  await DatabaseHelper.instance.resolvePendingLog(
                    logId: pendingLog['id'],
                    customerPhone: phone,
                    customerName: name,
                    voucherCode: voucherCode,
                  );
            
                  // 3. ✉️ إعداد نص الرد التلقائي وقراءة الإعدادات
                  String defaultReply = await DatabaseHelper.instance
                      .getSetting('default_reply', 'شكراً لتواصلك. رقمك الخاص هو: ');
                  String fullMsg = "$defaultReply $voucherCode";
            
                  // 4. 🚀 إرسال القسيمة عبر SMS
                  bool isSent = await _sendSmsNative(phone, fullMsg);
            
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isSent
                            ? "تم ربط العميل وصرف القسيمة ($voucherCode) وإرسالها بنجاح"
                            : "تم ربط العميل وصرف القسيمة ولكن تعذر إرسال الـ SMS"),
                        backgroundColor: isSent ? Colors.green : Colors.orange,
                      ),
                    );
                    _loadPendingLogs();
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("يرجى إدخال رقم هاتف صحيح (9 أرقام)"),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
              child: const Text("تأكيد وصرف القسيمة"),
            )
            
            /*ElevatedButton(
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

                  // 2. إعداد نص الرسالة
                  String defaultReply = await DatabaseHelper.instance
                      .getSetting('default_reply', 'شكراً لتواصلك. رقمك هو: ');
                  String fullMsg = "$defaultReply $voucherCode";

                  // 3. إرسال القسيمة عبر SMS مباشرة عبر Kotlin MethodChannel
                  bool isSent = await _sendSmsNative(phone, fullMsg);

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isSent
                            ? "تم ربط العميل وإرسال القسيمة بنجاح"
                            : "تم ربط العميل لكن تعذر إرسال الرسالة عبر النظام"),
                        backgroundColor: isSent ? Colors.green : Colors.orange,
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
            ),*/
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
          // 🔘 زر التحديث وحسم المعلقات المربوطة مع مؤشر التحميل
          IconButton(
            icon: _isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.refresh),
            tooltip: "تحديث وحسم معلقات العملاء المربوطين",
            onPressed: _isSyncing ? null : _checkAndAutoResolvePendingLogs,
          ),
        ],
      ),
      // 🔄 ميزة السحب للأسفل لإعادة التحديث والفحص تلقائياً
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _checkAndAutoResolvePendingLogs,
              child: _pendingLogs.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 200),
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                size: 64,
                                color: Colors.green,
                              ),
                              SizedBox(height: 12),
                              Text(
                                "لا توجد عمليات معلقة حالياً",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
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
                              child: Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.white,
                              ),
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
            ),
    );
  }
  /*@override
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
  }*/
}
*/