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

    if (mounted) {
      setState(() {
        _allSenders = data;
        _isLoading = false;
      });
      _filterSenders(_searchController.text);
    }
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

  // أرقام إحصائية سريعة
  int get _activeCount =>
      _filteredSenders.where((s) => (s['is_active'] ?? 1) == 1).length;
  int get _disabledCount => _filteredSenders.length - _activeCount;

  // ==========================================
  // 2. إضافة أو تعديل مرسل (Dialog)
  // ==========================================
  void _showSenderDialog({Map<String, dynamic>? senderData}) {
    final isEdit = senderData != null;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
                  borderRadius: BorderRadius.circular(24)),
              backgroundColor: theme.dialogBackgroundColor,
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isEdit ? Colors.orange : theme.primaryColor)
                          .withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isEdit ? Icons.edit_rounded : Icons.add_rounded,
                      color: isEdit ? Colors.orange : theme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isEdit ? 'تعديل جهة مرسلة' : 'إضافة جهة جديدة',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    // نوع المرسل
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: InputDecoration(
                        labelText: 'نوع الجهة',
                        prefixIcon: const Icon(Icons.category_rounded),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'phone', child: Text('📞 رقم هاتف')),
                        DropdownMenuItem(
                            value: 'name', child: Text('👤 اسم جهة/شركة')),
                        DropdownMenuItem(
                            value: 'code', child: Text('🔑 كود خاص')),
                      ],
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedType = val);
                      },
                    ),
                    const SizedBox(height: 14),

                    // قيمة المرسل
                    TextField(
                      controller: valueController,
                      decoration: InputDecoration(
                        labelText: 'القيمة (الرقم أو الكود)',
                        prefixIcon: const Icon(Icons.numbers_rounded),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // الاسم الظاهر
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'الاسم الظاهر (اختياري)',
                        prefixIcon: const Icon(Icons.badge_rounded),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // حالة التفعيل
                    DropdownButtonFormField<int>(
                      value: selectedStatus,
                      decoration: InputDecoration(
                        labelText: 'الحالة',
                        prefixIcon: const Icon(Icons.toggle_on_rounded),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 1,
                            child: Text('🟢 مفعل (يتم قبول الرسائل)')),
                        DropdownMenuItem(
                            value: 0, child: Text('🔴 معطل (تجاهل الرسائل)')),
                      ],
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedStatus = val);
                      },
                    ),
                  ],
                ),
              ),
              actionsPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('إلغاء',
                      style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[700])),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('حفظ البيانات'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final value = valueController.text.trim();
                    final name = nameController.text.trim();

                    if (value.isEmpty) {
                      _showSnackBar('الرجاء إدخال قيمة المرسل', isError: true);
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
                      _showSnackBar('تم تعديل بيانات المرسل بنجاح');
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
                      _showSnackBar('تم إضافة المرسل بنجاح');
                    }

                    Navigator.pop(ctx);
                    _loadSenders();
                  },
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
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text('تأكيد الحذف', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
              'هل أنت تأكد من حذف الجهة "${sender['name'] ?? sender['sender']}" نهائياً؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final db = await _dbHelper.database;
                await db.delete(
                  DatabaseHelper.tableAllowedSenders,
                  where: 'id = ?',
                  whereArgs: [sender['id']],
                );
                Navigator.pop(ctx);
                _showSnackBar('تم حذف الجهة بنجاح');
                _loadSenders();
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

  IconData _getTypeIcon(String? type) {
    switch (type) {
      case 'phone':
        return Icons.phone_android_rounded;
      case 'name':
        return Icons.account_balance_wallet_rounded;
      case 'code':
        return Icons.qr_code_rounded;
      default:
        return Icons.contact_mail_rounded;
    }
  }

  // ==========================================
  // 4. بناء واجهة المستخدم العصرية
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
          title: const Text('المحافظ والبنوك المعتمدة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          centerTitle: true,
          elevation: 0,
        ),
        /*floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showSenderDialog(),
          icon: const Icon(Icons.add_rounded),
          label: const Text('إضافة جهة',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ),*/
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
                        // 1. مربع البحث العصري
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
                            onChanged: _filterSenders,
                            decoration: InputDecoration(
                              hintText: 'بحث بالاسم، الرقم، أو الكود...',
                              prefixIcon: Icon(Icons.search_rounded,
                                  color: theme.primaryColor),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded),
                                      onPressed: () {
                                        _searchController.clear();
                                        _filterSenders('');
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

                        // 2. شريط إحصائي سريع (Summary Bar)
                        Row(
                          children: [
                            _buildStatBadge(
                              context,
                              label: 'الإجمالي',
                              count: _filteredSenders.length,
                              color: theme.primaryColor,
                            ),
                            const SizedBox(width: 8),
                            _buildStatBadge(
                              context,
                              label: 'مفعل',
                              count: _activeCount,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 8),
                            _buildStatBadge(
                              context,
                              label: 'معطل',
                              count: _disabledCount,
                              color: Colors.red,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // 3. قائمة البطاقات الحديثة
                        _filteredSenders.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(40.0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.subtitles_off_rounded,
                                        size: 64,
                                        color: isDark
                                            ? Colors.grey[700]
                                            : Colors.grey[400],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'لا توجد جهات أو محافظ مطابقة للبحث',
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.grey[400]
                                              : Colors.grey[600],
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
                                itemCount: _filteredSenders.length,
                                itemBuilder: (ctx, index) {
                                  final sender = _filteredSenders[index];
                                  final bool isActive =
                                      (sender['is_active'] ?? 1) == 1;
                                  final String type =
                                      sender['sender_type'] ?? 'phone';

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    decoration: BoxDecoration(
                                      color: theme.cardColor,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isDark
                                            ? Colors.white10
                                            : Colors.grey.shade200,
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
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 6),
                                      leading: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: (isActive
                                                  ? theme.primaryColor
                                                  : Colors.grey)
                                              .withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          _getTypeIcon(type),
                                          color: isActive
                                              ? theme.primaryColor
                                              : Colors.grey,
                                        ),
                                      ),
                                      title: Text(
                                        sender['name'] ??
                                            sender['sender'] ??
                                            '',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      subtitle: Padding(
                                        padding:
                                            const EdgeInsets.only(top: 4.0),
                                        child: Row(
                                          children: [
                                            Text(
                                              sender['sender'] ?? '',
                                              style: TextStyle(
                                                color: isDark
                                                    ? Colors.grey[400]
                                                    : Colors.grey[600],
                                                fontSize: 13,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isActive
                                                    ? Colors.green
                                                        .withOpacity(0.12)
                                                    : Colors.red
                                                        .withOpacity(0.12),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                isActive ? 'مفعل' : 'معطل',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: isActive
                                                      ? Colors.green
                                                      : Colors.red,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      /*trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                              Icons.edit_outlined,
                                              size: 20,
                                              color: Colors.blueAccent,
                                            ),
                                            onPressed: () => _showSenderDialog(
                                                senderData: sender),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.delete_outline_rounded,
                                              size: 20,
                                              color: Colors.redAccent,
                                            ),
                                            onPressed: () =>
                                                _showDeleteDialog(sender),
                                          ),
                                        ],
                                      ),*/
                                    ),
                                  );
                                },
                              ),
                        const SizedBox(height: 60), // مسافة من أجل الزر العائم
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  // ودجت صغيرة للملخص الإحصائي
  Widget _buildStatBadge(BuildContext context,
      {required String label, required int count, required Color color}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
