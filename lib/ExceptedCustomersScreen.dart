import 'package:flutter/material.dart';
import 'DatabaseHelper.dart';

class ExceptedCustomersScreen extends StatefulWidget {
  const ExceptedCustomersScreen({Key? key}) : super(key: key);

  @override
  State<ExceptedCustomersScreen> createState() => _ExceptedCustomersScreenState();
}

class _ExceptedCustomersScreenState extends State<ExceptedCustomersScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  List<Map<String, dynamic>> _allCustomers = [];
  List<Map<String, dynamic>> _filteredCustomers = [];
  bool _isLoading = true;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ==========================================
  // 1. جلب البيانات والتصفية
  // ==========================================
  Future<void> _loadCustomers() async {
    setState(() => _isLoading = true);
    final db = await _dbHelper.database;
    final data = await db.query(
      DatabaseHelper.tableExceptedCustomers,
      orderBy: 'id DESC',
    );

    if (mounted) {
      setState(() {
        _allCustomers = data;
        _isLoading = false;
      });
      _filterCustomers(_searchController.text);
    }
  }

  void _filterCustomers(String query) {
    final term = query.trim().toLowerCase();
    setState(() {
      if (term.isEmpty) {
        _filteredCustomers = List.from(_allCustomers);
      } else {
        _filteredCustomers = _allCustomers.where((c) {
          final phone = (c['phone'] ?? '').toString().toLowerCase();
          final name = (c['name'] ?? '').toString().toLowerCase();
          return phone.contains(term) || name.contains(term);
        }).toList();
      }
    });
  }

  // ==========================================
  // 2. إضافة أو تعديل عميل مستثنى (Dialog)
  // ==========================================
  void _showCustomerDialog({Map<String, dynamic>? customerData}) {
    final isEdit = customerData != null;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final phoneController =
        TextEditingController(text: isEdit ? customerData['phone'] : '');
    final nameController =
        TextEditingController(text: isEdit ? (customerData['name'] ?? '') : '');
    final notesController =
        TextEditingController(text: isEdit ? (customerData['notes'] ?? '') : '');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: theme.dialogBackgroundColor,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isEdit ? Colors.orange : theme.primaryColor).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isEdit ? Icons.edit_rounded : Icons.person_off_rounded,
                  color: isEdit ? Colors.orange : theme.primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                isEdit ? 'تعديل بيانات الاستثناء' : 'إضافة عميل للقائمة',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                // رقم الهاتف
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'رقم هاتف العميل',
                    prefixIcon: const Icon(Icons.phone_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(height: 14),

                // الاسم (اختياري)
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'اسم العميل (اختياري)',
                    prefixIcon: const Icon(Icons.person_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(height: 14),

                // سبب الاستثناء / ملاحظات
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'سبب الاستثناء / ملاحظات',
                    prefixIcon: const Icon(Icons.note_alt_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إلغاء',
                  style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700])),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('حفظ'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final phone = phoneController.text.trim();
                final name = nameController.text.trim();
                final notes = notesController.text.trim();

                if (phone.isEmpty) {
                  _showSnackBar('الرجاء إدخال رقم الهاتف', isError: true);
                  return;
                }

                final db = await _dbHelper.database;
                try {
                  if (isEdit) {
                    await db.update(
                      DatabaseHelper.tableExceptedCustomers,
                      {
                        'phone': phone,
                        'name': name,
                        'notes': notes,
                      },
                      where: 'id = ?',
                      whereArgs: [customerData['id']],
                    );
                    _showSnackBar('تم تعديل بيانات العميل بنجاح');
                  } else {
                    await db.insert(
                      DatabaseHelper.tableExceptedCustomers,
                      {
                        'phone': phone,
                        'name': name,
                        'notes': notes,
                        'created_at': DateTime.now().millisecondsSinceEpoch,
                      },
                    );
                    _showSnackBar('تمت إضافة العميل إلى قائمة الاستثناء');
                  }
                  Navigator.pop(ctx);
                  _loadCustomers();
                } catch (e) {
                  _showSnackBar('هذا الرقم موجود مسبقاً في القائمة', isError: true);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 3. حذف عميل من قائمة الاستثناء
  // ==========================================
  void _showDeleteDialog(Map<String, dynamic> customer) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text('حذف من الاستثناء', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
              'هل تريد إزالة العميل "${customer['name']?.isNotEmpty == true ? customer['name'] : customer['phone']}" وإعادة السماح بإرسال القسائم له؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final db = await _dbHelper.database;
                await db.delete(
                  DatabaseHelper.tableExceptedCustomers,
                  where: 'id = ?',
                  whereArgs: [customer['id']],
                );
                Navigator.pop(ctx);
                _showSnackBar('تم إزالة العميل من قائمة الاستثناء');
                _loadCustomers();
              },
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ==========================================
  // 4. بناء الواجهة
  // ==========================================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('العملاء المستثنون من القسائم',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          centerTitle: true,
          elevation: 0,
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showCustomerDialog(),
          icon: const Icon(Icons.person_add_disabled_rounded),
          label: const Text('استثناء عميل', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. مربع البحث
                        Container(
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: _filterCustomers,
                            decoration: InputDecoration(
                              hintText: 'بحث برقم الهاتف أو الاسم...',
                              prefixIcon: Icon(Icons.search_rounded, color: theme.primaryColor),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded),
                                      onPressed: () {
                                        _searchController.clear();
                                        _filterCustomers('');
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 2. بطاقة توضيحية أعلى الشاشة
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.amber.withOpacity(0.4)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline_rounded, color: Colors.amber),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'العملاء المضافون في هذه القائمة لن يتم إرسال أي قسائم لهم حتى لو وردت مبالغ منهم عبر المحافظ المعتمدة.',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 3. القائمة
                        _filteredCustomers.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(40.0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.check_circle_outline_rounded,
                                        size: 64,
                                        color: isDark ? Colors.grey[700] : Colors.grey[400],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'لا يوجد عملاء مستثنون حالياً',
                                        style: TextStyle(
                                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _filteredCustomers.length,
                                itemBuilder: (ctx, index) {
                                  final customer = _filteredCustomers[index];

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    decoration: BoxDecoration(
                                      color: theme.cardColor,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isDark ? Colors.white10 : Colors.grey.shade200,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.02),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 6),
                                      leading: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.person_off_rounded,
                                          color: Colors.redAccent,
                                        ),
                                      ),
                                      title: Text(
                                        customer['name']?.isNotEmpty == true
                                            ? customer['name']
                                            : customer['phone'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (customer['name']?.isNotEmpty == true)
                                            Text(
                                              customer['phone'],
                                              style: TextStyle(
                                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                                                fontSize: 13,
                                              ),
                                            ),
                                          if (customer['notes']?.isNotEmpty == true)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 2.0),
                                              child: Text(
                                                '📝 ${customer['notes']}',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.amber,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                              Icons.edit_outlined,
                                              size: 20,
                                              color: Colors.blueAccent,
                                            ),
                                            onPressed: () =>
                                                _showCustomerDialog(customerData: customer),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.delete_outline_rounded,
                                              size: 20,
                                              color: Colors.redAccent,
                                            ),
                                            onPressed: () => _showDeleteDialog(customer),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                        const SizedBox(height: 60),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}