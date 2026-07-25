import 'package:flutter/material.dart';
import 'DatabaseHelper.dart';

class AllowedSendersScreen extends StatefulWidget {
  const AllowedSendersScreen({Key? key}) : super(key: key);

  @override
  State<AllowedSendersScreen> createState() => _AllowedSendersScreenState();
}

class _AllowedSendersScreenState extends State<AllowedSendersScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  List<Map<String, dynamic>> _allSenders = [];
  List<Map<String, dynamic>> _filteredSenders = [];
  bool _isLoading = true;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSenders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ==========================================
  // 1. جلب البيانات والتصفية
  // ==========================================
  Future<void> _loadSenders() async {
    setState(() => _isLoading = true);
    final db = await _dbHelper.database;
    final data = await db.query(
      DatabaseHelper.tableAllowedSenders,
      orderBy: 'id DESC',
    );

    setState(() {
      _allSenders = data;
      _isLoading = false;
    });

    _filterSenders(_searchController.text);
  }

  void _filterSenders(String query) {
    final term = query.trim().toLowerCase();
    setState(() {
      if (term.isEmpty) {
        _filteredSenders = List.from(_allSenders);
      } else {
        _filteredSenders = _allSenders.where((s) {
          final name = (s['name'] ?? '').toString().toLowerCase();
          final sender = (s['sender'] ?? '').toString().toLowerCase();
          return name.contains(term) || sender.contains(term);
        }).toList();
      }
    });
  }

  // ==========================================
  // 2. إضافة أو تعديل مرسل (Dialog)
  // ==========================================
  void _showSenderDialog({Map<String, dynamic>? senderData}) {
    final isEdit = senderData != null;

    final valueController =
        TextEditingController(text: isEdit ? senderData['sender'] : '');
    final nameController =
        TextEditingController(text: isEdit ? (senderData['name'] ?? '') : '');
    String selectedType =
        isEdit ? (senderData['sender_type'] ?? 'phone') : 'phone';
    int selectedStatus = isEdit ? (senderData['is_active'] ?? 1) : 1;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28)),
              title: Text(
                isEdit ? '✏️ تعديل مرسل' : '➕ إضافة مرسل',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // نوع المرسل
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: InputDecoration(
                        labelText: 'نوع الجهة',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'phone', child: Text('📞 رقم هاتف')),
                        DropdownMenuItem(value: 'name', child: Text('👤 اسم')),
                        DropdownMenuItem(
                            value: 'code', child: Text('🔑 كود جهة')),
                      ],
                      onChanged: (val) {
                        if (val != null)
                          setModalState(() => selectedType = val);
                      },
                    ),
                    const SizedBox(height: 12),

                    // قيمة المرسل
                    TextField(
                      controller: valueController,
                      decoration: InputDecoration(
                        hintText: 'القيمة (رقم أو اسم أو كود)',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // الاسم الظاهر
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        hintText: 'الاسم الظاهر (اختياري)',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // حالة التفعيل
                    DropdownButtonFormField<int>(
                      value: selectedStatus,
                      decoration: InputDecoration(
                        labelText: 'الحالة',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('🟢 مفعل')),
                        DropdownMenuItem(value: 0, child: Text('🔴 معطل')),
                      ],
                      onChanged: (val) {
                        if (val != null)
                          setModalState(() => selectedStatus = val);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                      foregroundColor: Colors.grey.shade700),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF27AE60),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                  onPressed: () async {
                    final value = valueController.text.trim();
                    final name = nameController.text.trim();

                    if (value.isEmpty) {
                      _showSnackBar('الرجاء إدخال القيمة', isError: true);
                      return;
                    }

                    final db = await _dbHelper.database;
                    if (isEdit) {
                      await db.update(
                        DatabaseHelper.tableAllowedSenders,
                        {
                          'sender': value,
                          'name': name.isEmpty ? value : name,
                          'sender_type': selectedType,
                          'is_active': selectedStatus,
                        },
                        where: 'id = ?',
                        whereArgs: [senderData['id']],
                      );
                      _showSnackBar('✅ تم تعديل بيانات المرسل');
                    } else {
                      await db.insert(
                        DatabaseHelper.tableAllowedSenders,
                        {
                          'sender': value,
                          'name': name.isEmpty ? value : name,
                          'sender_type': selectedType,
                          'is_active': selectedStatus,
                          'created_at': DateTime.now().millisecondsSinceEpoch,
                        },
                      );
                      _showSnackBar('✅ تم إضافة المرسل بنجاح');
                    }

                    Navigator.pop(ctx);
                    _loadSenders();
                  },
                  child: const Text('حفظ'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ==========================================
  // 3. حذف مرسل
  // ==========================================
  void _showDeleteDialog(Map<String, dynamic> sender) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('⚠️ تأكيد الحذف',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text(
              'هل تريد حذف "${sender['name'] ?? sender['sender']}" نهائياً؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE74C3C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: () async {
                final db = await _dbHelper.database;
                await db.delete(
                  DatabaseHelper.tableAllowedSenders,
                  where: 'id = ?',
                  whereArgs: [sender['id']],
                );
                Navigator.pop(ctx);
                _showSnackBar('✅ تم حذف المرسل بنجاح');
                _loadSenders();
              },
              child: const Text('نعم، احذف'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.center),
        backgroundColor:
            isError ? Colors.red.shade700 : const Color(0xFF27AE60),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ==========================================
  // 4. بناء واجهة المستخدم
  // ==========================================
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F4F8),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E2A36),
          title: const Text('المحافظ والبنوك',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          centerTitle: true,
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: const Color(0xFF27AE60),
                child: IconButton(
                  icon: const Icon(Icons.add, color: Colors.white),
                  onPressed: () => _showSenderDialog(),
                ),
              ),
            )
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(12.0),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Column(
                      children: [
                        // مربع البحث
                        TextField(
                          controller: _searchController,
                          onChanged: _filterSenders,
                          decoration: InputDecoration(
                            hintText: '🔍 بحث بالاسم أو الرقم...',
                            fillColor: Colors.white,
                            filled: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(50),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // الجدول (تم تعديله بحذف overflowAlignment)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              // ترويسة الجدول
                              Container(
                                color: const Color(0xFF2C3E50),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 10, horizontal: 16),
                                child: const Row(
                                  children: [
                                    Expanded(
                                        flex: 3,
                                        child: Text('الاسم / الجهة',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13))),
                                    Expanded(
                                        flex: 2,
                                        child: Text('الحالة',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13))),
                                    Expanded(
                                        flex: 2,
                                        child: Text('الإجراءات',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13))),
                                  ],
                                ),
                              ),

                              // قائمة العناصر
                              _filteredSenders.isEmpty
                                  ? const Padding(
                                      padding: EdgeInsets.all(24.0),
                                      child: Text('📭 لا توجد بيانات',
                                          style: TextStyle(color: Colors.grey)),
                                    )
                                  : ListView.separated(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      itemCount: _filteredSenders.length,
                                      separatorBuilder: (ctx, i) =>
                                          const Divider(
                                              height: 1,
                                              color: Color(0xFFE9ECEF)),
                                      itemBuilder: (ctx, index) {
                                        final sender = _filteredSenders[index];
                                        final bool isActive =
                                            (sender['is_active'] ?? 1) == 1;

                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 8, horizontal: 12),
                                          child: Row(
                                            children: [
                                              // الاسم والقيمة
                                              Expanded(
                                                flex: 3,
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      sender['name'] ??
                                                          sender['sender'] ??
                                                          '',
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 13),
                                                    ),
                                                    if (sender['name'] !=
                                                            null &&
                                                        sender['name'] !=
                                                            sender['sender'])
                                                      Text(
                                                        sender['sender'] ?? '',
                                                        style: const TextStyle(
                                                            fontSize: 11,
                                                            color: Colors.grey),
                                                      ),
                                                  ],
                                                ),
                                              ),

                                              // الحالة
                                              Expanded(
                                                flex: 2,
                                                child: Center(
                                                  child: Container(
                                                    padding: const EdgeInsets
                                                            .symmetric(
                                                        horizontal: 8,
                                                        vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: isActive
                                                          ? Colors.green.shade50
                                                          : Colors.red.shade50,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              20),
                                                    ),
                                                    child: Text(
                                                      isActive
                                                          ? '🟢 مفعل'
                                                          : '🔴 معطل',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: isActive
                                                            ? Colors
                                                                .green.shade800
                                                            : Colors
                                                                .red.shade800,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),

                                              // الأزرار
                                              Expanded(
                                                flex: 2,
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    IconButton(
                                                      constraints:
                                                          const BoxConstraints(),
                                                      padding:
                                                          const EdgeInsets.all(
                                                              6),
                                                      icon: const Icon(
                                                          Icons.edit,
                                                          size: 18,
                                                          color: Color(
                                                              0xFF3498DB)),
                                                      onPressed: () =>
                                                          _showSenderDialog(
                                                              senderData:
                                                                  sender),
                                                    ),
                                                    IconButton(
                                                      constraints:
                                                          const BoxConstraints(),
                                                      padding:
                                                          const EdgeInsets.all(
                                                              6),
                                                      icon: const Icon(
                                                          Icons.delete,
                                                          size: 18,
                                                          color: Color(
                                                              0xFFE74C3C)),
                                                      onPressed: () =>
                                                          _showDeleteDialog(
                                                              sender),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // إجمالي العدد
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: Text(
                            '📊 إجمالي الجهات المخولة: ${_filteredSenders.length}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
