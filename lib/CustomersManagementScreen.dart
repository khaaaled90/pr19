import 'package:flutter/material.dart';
import 'DatabaseHelper.dart';

class CustomersManagementScreen extends StatefulWidget {
  const CustomersManagementScreen({super.key});

  @override
  State<CustomersManagementScreen> createState() => _CustomersManagementScreenState();
}

class _CustomersManagementScreenState extends State<CustomersManagementScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<Map<String, dynamic>> _customers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final data = await _dbHelper.getCustomersWithIdentifiers();
      if (!mounted) return;
      setState(() {
        _customers = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء تحميل البيانات: $e')),
      );
    }
  }

  // ==========================================
  // 1. نافذة تعديل بيانات العميل الأساسية
  // ==========================================
  void _showEditCustomerDialog(
    int oldCustomerId,
    String currentName,
    String currentPhone,
    bool isDark,
    Color cardBg,
    Color textColor,
  ) {
    final nameController = TextEditingController(text: currentName == 'عميل غير مسمى' ? '' : currentName);
    final phoneController = TextEditingController(text: currentPhone);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
            ),
          ),
          title: Row(
            children: [
              Icon(
                Icons.person_outline_rounded,
                color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0F172A),
              ),
              const SizedBox(width: 8),
              Text(
                'تعديل بيانات العميل',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  style: TextStyle(color: textColor, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'اسم العميل',
                    labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 13),
                    filled: true,
                    fillColor: isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0F172A),
                      ),
                    ),
                    prefixIcon: Icon(
                      Icons.person_rounded,
                      color: isDark ? const Color(0xFF38BDF8) : Colors.grey.shade700,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(color: textColor, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'رقم الهاتف',
                    labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 13),
                    filled: true,
                    fillColor: isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0F172A),
                      ),
                    ),
                    prefixIcon: Icon(
                      Icons.phone_android_rounded,
                      color: isDark ? const Color(0xFF38BDF8) : Colors.grey.shade700,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'يرجى إدخال رقم الهاتف';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey, fontSize: 13)),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.save_rounded, size: 16, color: Colors.white),
              label: const Text('حفظ التعديل', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF047857) : const Color(0xFF10B981),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final newPhone = phoneController.text.trim();
                  final newName = nameController.text.trim();
                  Navigator.pop(dialogContext);

                  setState(() => _isLoading = true);

                  await _dbHelper.updateCustomerPhoneWithSeparation(
                    oldCustomerId: oldCustomerId,
                    oldPhone: currentPhone,
                    newPhone: newPhone,
                    customerName: newName,
                  );

                  await _loadData();

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم تحديث بيانات العميل بنجاح'),
                        backgroundColor: Color(0xFF10B981),
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 2. نافذة نقل وتعديل المعرف
  // ==========================================
  void _showEditIdentifierDialog(
    int identifierId,
    String currentIdentifier,
    String currentPhone,
    bool isDark,
    Color cardBg,
    Color textColor,
  ) {
    final phoneController = TextEditingController(text: currentPhone);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
            ),
          ),
          title: Row(
            children: [
              Icon(
                Icons.swap_horiz_rounded,
                color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0F172A),
              ),
              const SizedBox(width: 8),
              Text(
                'نقل المعرف إلى رقم آخر',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.black.withOpacity(0.03),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.label_outlined,
                        size: 18,
                        color: isDark ? const Color(0xFF38BDF8) : Colors.grey.shade700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          currentIdentifier,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: textColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  autofocus: true,
                  style: TextStyle(color: textColor, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'رقم الهاتف الجديد للمعرف',
                    labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 13),
                    hintText: 'أدخل رقم الهاتف المراد النقل إليه',
                    hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                    filled: true,
                    fillColor: isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0F172A),
                      ),
                    ),
                    prefixIcon: Icon(
                      Icons.phone_android_rounded,
                      color: isDark ? const Color(0xFF38BDF8) : Colors.grey.shade700,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'يرجى إدخال رقم الهاتف';
                    }
                    if (value.trim() == currentPhone) {
                      return 'الرقم المدخل هو نفس الرقم الحالي';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey, fontSize: 13)),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.save_rounded, size: 16, color: Colors.white),
              label: const Text('حفظ ونقل', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF047857) : const Color(0xFF10B981),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final newPhone = phoneController.text.trim();
                  Navigator.pop(dialogContext);

                  setState(() => _isLoading = true);

                  await _dbHelper.updateIdentifierPhoneAndTransfer(
                    identifierId: identifierId,
                    newPhone: newPhone,
                  );

                  await _loadData();

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('تم نقل المعرف "$currentIdentifier" إلى الرقم $newPhone بنجاح'),
                        backgroundColor: const Color(0xFF10B981),
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = theme.cardColor;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          centerTitle: true,
          title: const Text(
            'إدارة العملاء والمعرفات',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: _loadData,
            )
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // كارت الإحصائيات العلوي
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isDark
                                    ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                                    : [const Color(0xFF1E293B), const Color(0xFF0F172A)],
                              ),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(
                                  children: [
                                    const Text('إجمالي العملاء', style: TextStyle(fontSize: 11, color: Colors.white70)),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_customers.length} عميل',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                  ],
                                ),
                                Container(height: 24, width: 1, color: Colors.white24),
                                Column(
                                  children: [
                                    const Text('الحالة', style: TextStyle(fontSize: 11, color: Colors.white70)),
                                    const SizedBox(height: 2),
                                    Text(
                                      'نشط',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF10B981),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // قائمة العملاء والمعرفات
                          _customers.isEmpty
                              ? Container(
                                  padding: const EdgeInsets.all(32),
                                  decoration: BoxDecoration(
                                    color: cardBg,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
                                    ),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'لا يوجد عملاء مسجلين حالياً',
                                      style: TextStyle(fontSize: 13, color: Colors.grey),
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _customers.length,
                                  itemBuilder: (context, index) {
                                    final customer = _customers[index];
                                    final customerId = customer['customer_id'] as int;
                                    final rawIdentifiers = customer['identifiers'] as String?;
                                    List<Map<String, String>> identifierList = [];

                                    if (rawIdentifiers != null && rawIdentifiers.isNotEmpty) {
                                      for (var item in rawIdentifiers.split('||')) {
                                        final parts = item.split(':');
                                        if (parts.length >= 2) {
                                          identifierList.add({
                                            'id': parts[0],
                                            'identifier': parts.sublist(1).join(':'),
                                          });
                                        }
                                      }
                                    }

                                    final String customerName = (customer['customer_name'] != null &&
                                            customer['customer_name'].toString().trim().isNotEmpty)
                                        ? customer['customer_name']
                                        : 'عميل غير مسمى';

                                    final String customerPhone = customer['customer_phone'] ?? '';

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      decoration: BoxDecoration(
                                        color: cardBg,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
                                        ),
                                      ),
                                      child: Theme(
                                        data: theme.copyWith(dividerColor: Colors.transparent),
                                        child: ExpansionTile(
                                          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                          leading: CircleAvatar(
                                            backgroundColor: isDark
                                                ? const Color(0xFF38BDF8).withOpacity(0.15)
                                                : const Color(0xFF0F172A).withOpacity(0.08),
                                            child: Text(
                                              customerName.substring(0, 1),
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0F172A),
                                              ),
                                            ),
                                          ),
                                          title: Text(
                                            customerName,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: textColor,
                                            ),
                                          ),
                                          subtitle: Row(
                                            children: [
                                              Icon(Icons.phone_outlined, size: 13, color: isDark ? Colors.white54 : Colors.grey.shade600),
                                              const SizedBox(width: 4),
                                              Text(
                                                customerPhone,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: isDark ? Colors.white70 : Colors.black87,
                                                ),
                                              ),
                                            ],
                                          ),
                                          // زر تعديل العميل الرئيسي
                                          trailing: IconButton(
                                            icon: Icon(
                                              Icons.edit_note_rounded,
                                              color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0F172A),
                                              size: 22,
                                            ),
                                            tooltip: 'تعديل بيانات العميل',
                                            onPressed: () {
                                              _showEditCustomerDialog(
                                                customerId,
                                                customerName,
                                                customerPhone,
                                                isDark,
                                                cardBg,
                                                textColor,
                                              );
                                            },
                                          ),
                                          children: [
                                            Divider(
                                              height: 1,
                                              color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                              color: isDark ? Colors.white.withOpacity(0.02) : const Color(0xFFF8FAFC),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.format_list_bulleted_rounded,
                                                    size: 15,
                                                    color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0F172A),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    'المعرفات المرتبطة (${identifierList.length}):',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0F172A),
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (identifierList.isEmpty)
                                              const Padding(
                                                padding: EdgeInsets.all(14.0),
                                                child: Text(
                                                  'لا توجد معرفات مرتبطة بهذا الرقم',
                                                  style: TextStyle(color: Colors.grey, fontSize: 12),
                                                ),
                                              )
                                            else
                                              ListView.separated(
                                                shrinkWrap: true,
                                                physics: const NeverScrollableScrollPhysics(),
                                                itemCount: identifierList.length,
                                                separatorBuilder: (context, index) => Divider(
                                                  height: 1,
                                                  color: isDark ? Colors.white10 : Colors.black.withOpacity(0.03),
                                                  indent: 14,
                                                  endIndent: 14,
                                                ),
                                                itemBuilder: (context, idIndex) {
                                                  final idMap = identifierList[idIndex];
                                                  final identifierId = int.parse(idMap['id']!);
                                                  final identifierText = idMap['identifier']!;

                                                  return ListTile(
                                                    dense: true,
                                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                                                    title: Text(
                                                      identifierText,
                                                      style: TextStyle(fontSize: 13, color: textColor),
                                                    ),
                                                    // زر تعديل المعرف وتغيير مالكه
                                                    trailing: IconButton(
                                                      icon: Icon(
                                                        Icons.swap_horiz_rounded,
                                                        color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                                                        size: 20,
                                                      ),
                                                      tooltip: 'نقل المعرف إلى رقم آخر',
                                                      onPressed: () {
                                                        _showEditIdentifierDialog(
                                                          identifierId,
                                                          identifierText,
                                                          customerPhone,
                                                          isDark,
                                                          cardBg,
                                                          textColor,
                                                        );
                                                      },
                                                    ),
                                                  );
                                                },
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
/*import 'package:flutter/material.dart';
import 'DatabaseHelper.dart';

class CustomersManagementScreen extends StatefulWidget {
  const CustomersManagementScreen({super.key});

  @override
  State<CustomersManagementScreen> createState() => _CustomersManagementScreenState();
}

class _CustomersManagementScreenState extends State<CustomersManagementScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<Map<String, dynamic>> _customers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final data = await _dbHelper.getCustomersWithIdentifiers();
      if (!mounted) return;
      setState(() {
        _customers = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء تحميل البيانات: $e')),
      );
    }
  }

  void _showEditIdentifierDialog(
    int identifierId,
    String currentIdentifier,
    String currentPhone,
    bool isDark,
    Color cardBg,
    Color textColor,
  ) {
    final phoneController = TextEditingController(text: currentPhone);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
            ),
          ),
          title: Row(
            children: [
              Icon(
                Icons.swap_horiz_rounded,
                color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0F172A),
              ),
              const SizedBox(width: 8),
              Text(
                'نقل المعرف إلى رقم آخر',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.black.withOpacity(0.03),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.label_outlined,
                        size: 18,
                        color: isDark ? const Color(0xFF38BDF8) : Colors.grey.shade700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          currentIdentifier,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: textColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  autofocus: true,
                  style: TextStyle(color: textColor, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'رقم الهاتف الجديد',
                    labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 13),
                    hintText: 'أدخل رقم الهاتف المراد النقل إليه',
                    hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                    filled: true,
                    fillColor: isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0F172A),
                      ),
                    ),
                    prefixIcon: Icon(
                      Icons.phone_android_rounded,
                      color: isDark ? const Color(0xFF38BDF8) : Colors.grey.shade700,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'يرجى إدخال رقم الهاتف';
                    }
                    if (value.trim() == currentPhone) {
                      return 'الرقم المدخل هو نفس الرقم الحالي';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey, fontSize: 13)),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.save_rounded, size: 16, color: Colors.white),
              label: const Text('حفظ ونقل', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF047857) : const Color(0xFF10B981),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final newPhone = phoneController.text.trim();
                  Navigator.pop(dialogContext);

                  setState(() => _isLoading = true);

                  await _dbHelper.updateIdentifierPhoneAndTransfer(
                    identifierId: identifierId,
                    newPhone: newPhone,
                  );

                  await _loadData();

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('تم نقل المعرف "$currentIdentifier" إلى الرقم $newPhone بنجاح'),
                        backgroundColor: const Color(0xFF10B981),
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = theme.cardColor;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          centerTitle: true,
          title: const Text(
            'إدارة العملاء والمعرفات',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: _loadData,
            )
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // كارت إحصائي علوي متناسق مع كارت المبيعات
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isDark
                                    ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                                    : [const Color(0xFF1E293B), const Color(0xFF0F172A)],
                              ),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(
                                  children: [
                                    const Text('إجمالي العملاء', style: TextStyle(fontSize: 11, color: Colors.white70)),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_customers.length} عميل',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                  ],
                                ),
                                Container(height: 24, width: 1, color: Colors.white24),
                                Column(
                                  children: [
                                    const Text('الحالة', style: TextStyle(fontSize: 11, color: Colors.white70)),
                                    const SizedBox(height: 2),
                                    Text(
                                      'نشط',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF10B981),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // قائمة العملاء والمعرفات
                          _customers.isEmpty
                              ? Container(
                                  padding: const EdgeInsets.all(32),
                                  decoration: BoxDecoration(
                                    color: cardBg,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
                                    ),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'لا يوجد عملاء مسجلين حالياً',
                                      style: TextStyle(fontSize: 13, color: Colors.grey),
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _customers.length,
                                  itemBuilder: (context, index) {
                                    final customer = _customers[index];
                                    final rawIdentifiers = customer['identifiers'] as String?;
                                    List<Map<String, String>> identifierList = [];

                                    if (rawIdentifiers != null && rawIdentifiers.isNotEmpty) {
                                      for (var item in rawIdentifiers.split('||')) {
                                        final parts = item.split(':');
                                        if (parts.length >= 2) {
                                          identifierList.add({
                                            'id': parts[0],
                                            'identifier': parts.sublist(1).join(':'),
                                          });
                                        }
                                      }
                                    }

                                    final String customerName = (customer['customer_name'] != null &&
                                            customer['customer_name'].toString().trim().isNotEmpty)
                                        ? customer['customer_name']
                                        : 'عميل غير مسمى';

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      decoration: BoxDecoration(
                                        color: cardBg,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
                                        ),
                                      ),
                                      child: Theme(
                                        data: theme.copyWith(dividerColor: Colors.transparent),
                                        child: ExpansionTile(
                                          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                          leading: CircleAvatar(
                                            backgroundColor: isDark
                                                ? const Color(0xFF38BDF8).withOpacity(0.15)
                                                : const Color(0xFF0F172A).withOpacity(0.08),
                                            child: Text(
                                              customerName.substring(0, 1),
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0F172A),
                                              ),
                                            ),
                                          ),
                                          title: Text(
                                            customerName,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: textColor,
                                            ),
                                          ),
                                          subtitle: Row(
                                            children: [
                                              Icon(Icons.phone_outlined, size: 13, color: isDark ? Colors.white54 : Colors.grey.shade600),
                                              const SizedBox(width: 4),
                                              Text(
                                                customer['customer_phone'] ?? '',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: isDark ? Colors.white70 : Colors.black87,
                                                ),
                                              ),
                                            ],
                                          ),
                                          children: [
                                            Divider(
                                              height: 1,
                                              color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                              color: isDark ? Colors.white.withOpacity(0.02) : const Color(0xFFF8FAFC),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.format_list_bulleted_rounded,
                                                    size: 15,
                                                    color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0F172A),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    'المعرفات المرتبطة (${identifierList.length}):',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0F172A),
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (identifierList.isEmpty)
                                              const Padding(
                                                padding: EdgeInsets.all(14.0),
                                                child: Text(
                                                  'لا توجد معرفات مرتبطة بهذا الرقم',
                                                  style: TextStyle(color: Colors.grey, fontSize: 12),
                                                ),
                                              )
                                            else
                                              ListView.separated(
                                                shrinkWrap: true,
                                                physics: const NeverScrollableScrollPhysics(),
                                                itemCount: identifierList.length,
                                                separatorBuilder: (context, index) => Divider(
                                                  height: 1,
                                                  color: isDark ? Colors.white10 : Colors.black.withOpacity(0.03),
                                                  indent: 14,
                                                  endIndent: 14,
                                                ),
                                                itemBuilder: (context, idIndex) {
                                                  final idMap = identifierList[idIndex];
                                                  final identifierId = int.parse(idMap['id']!);
                                                  final identifierText = idMap['identifier']!;

                                                  return ListTile(
                                                    dense: true,
                                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                                                    title: Text(
                                                      identifierText,
                                                      style: TextStyle(fontSize: 13, color: textColor),
                                                    ),
                                                    trailing: IconButton(
                                                      icon: Icon(
                                                        Icons.edit_outlined,
                                                        color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                                                        size: 18,
                                                      ),
                                                      tooltip: 'تغيير الرقم ونقل المعرف',
                                                      onPressed: () {
                                                        _showEditIdentifierDialog(
                                                          identifierId,
                                                          identifierText,
                                                          customer['customer_phone'],
                                                          isDark,
                                                          cardBg,
                                                          textColor,
                                                        );
                                                      },
                                                    ),
                                                  );
                                                },
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}*/