import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart' as intl;
import 'DatabaseHelper.dart'; // تأكد من استدعاء ملف قاعدة البيانات الخاص بك

class VouchersScreen extends StatefulWidget {
  const VouchersScreen({Key? key}) : super(key: key);

  @override
  State<VouchersScreen> createState() => _VouchersScreenState();
}

class _VouchersScreenState extends State<VouchersScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // البيانات والمجموعات
  List<Map<String, dynamic>> _keywords = [];
  List<Map<String, dynamic>> _allNumbers = [];
  List<Map<String, dynamic>> _archiveList = [];

  // حالات الواجهة
  String _currentFilter = 'available'; // 'available' أو 'used'
  String _selectedKeywordId = 'all';
  String? _selectedUsedKeyword;

  final TextEditingController _numbersController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _numbersController.dispose();
    super.dispose();
  }

  // ==========================================
  // 1. تحميل البيانات وتفريغها
  // ==========================================
  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final keywordsData = await _dbHelper.getAllKeywords();
    final numbersData = await _dbHelper.getAllNumbers();

    // جلب الأرشيف للحصول على الكروت المستخدمة
    final db = await _dbHelper.database;
    final archiveData = await db.query(
      DatabaseHelper.tableReplyLog,
      where: 'is_deleted = 0 AND sent_number IS NOT NULL AND sent_number != ""',
      orderBy: 'timestamp DESC',
    );

    setState(() {
      _keywords = keywordsData;
      _allNumbers = numbersData;
      _archiveList = archiveData;
      _isLoading = false;
    });

    _refreshEditorText();
  }

  void _refreshEditorText() {
    if (_selectedKeywordId == 'all') {
      _numbersController.text = '';
      return;
    }

    final kwId = int.tryParse(_selectedKeywordId);
    if (kwId == null) return;

    if (_currentFilter == 'available') {
      final availableCodes = _allNumbers
          .where((n) => n['keyword_id'] == kwId && n['status'] == 'available')
          .map((n) => n['number_code'].toString())
          .toList();
      _numbersController.text = availableCodes.join('\n');
    } else {
      final usedCodes = _allNumbers
          .where((n) => n['keyword_id'] == kwId && n['status'] == 'used')
          .map((n) => n['number_code'].toString())
          .toList();
      _numbersController.text = usedCodes.join('\n');
    }
  }

  // ==========================================
  // 2. إدارة وقراءة الملفات (TXT / CSV)
  // ==========================================
  Future<void> _pickAndReadFile() async {
    if (_selectedKeywordId == 'all') {
      _showSnackBar('❌ يرجى اختيار باقة أولاً قبل قراءة الملف', isError: true);
      return;
    }

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'csv'],
      );

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        String content = await file.readAsString();

        setState(() {
          String currentText = _numbersController.text.trim();
          if (currentText.isNotEmpty) {
            _numbersController.text = '$currentText\n${content.trim()}';
          } else {
            _numbersController.text = content.trim();
          }
        });

        _showSnackBar('✅ تمت إضافة الكروت من الملف بنجاح');
      }
    } catch (e) {
      _showSnackBar('❌ فشل في قراءة الملف: $e', isError: true);
    }
  }

  // ==========================================
  // 3. حفظ الأرقام والمزامنة مع قاعدة البيانات
  // ==========================================
  Future<void> _saveNumbers() async {
    if (_selectedKeywordId == 'all' || _currentFilter != 'available') {
      _showSnackBar('❌ اختر باقة متاحة للتعديل والحفظ', isError: true);
      return;
    }

    final kwId = int.tryParse(_selectedKeywordId);
    if (kwId == null) return;

    // استخراج الكروت من النص
    List<String> lines = _numbersController.text
        .split(RegExp(r'\r?\n'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    // جلب المتاح حالياً لهذا المعرف
    final currentAvailable = _allNumbers
        .where((n) => n['keyword_id'] == kwId && n['status'] == 'available')
        .toList();

    final currentCodes =
        currentAvailable.map((n) => n['number_code'].toString()).toSet();
    final newCodes = lines.toSet();

    // تحديد المضاف والمحذوف
    final toAdd = newCodes.difference(currentCodes);
    final toDelete = currentAvailable
        .where((n) => !newCodes.contains(n['number_code'].toString()))
        .toList();

    // تنفيذ العمليات بداخل Transaction لقواعد البيانات
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      for (var item in toDelete) {
        await txn.delete(
          DatabaseHelper.tableNumbersPool,
          where: 'id = ?',
          whereArgs: [item['id']],
        );
      }
      for (var code in toAdd) {
        await txn.insert(
          DatabaseHelper.tableNumbersPool,
          {
            'keyword_id': kwId,
            'number_code': code,
            'status': 'available',
          },
        );
      }
    });

    _showSnackBar(
        '✅ تم الحفظ: +${toAdd.length} أرقام، -${toDelete.length} أرقام');
    await _loadData();
  }

  // ==========================================
  // 4. عمليات الأرشيف والكروت المستخدمة
  // ==========================================
  Future<void> _deleteUsedCard(int archiveId) async {
    final bool? confirm = await _showConfirmDialog(
        'حذف الكرت', 'هل تريد حذف هذا الكرت من الأرشيف؟');
    if (confirm != true) return;

    final db = await _dbHelper.database;
    await db.update(
      DatabaseHelper.tableReplyLog,
      {'is_deleted': 1},
      where: 'id = ?',
      whereArgs: [archiveId],
    );

    _showSnackBar('✅ تم الحذف من الأرشيف');
    _loadData();
  }

  Future<void> _deleteAllUsed() async {
    final bool? confirm = await _showConfirmDialog(
        '⚠️ حذف الكل', 'هل أنت تأكد من حذف جميع الكروت المستخدمة من الأرشيف؟');
    if (confirm != true) return;

    final db = await _dbHelper.database;
    await db.update(
      DatabaseHelper.tableReplyLog,
      {'is_deleted': 1},
      where: 'sent_number IS NOT NULL AND sent_number != ""',
    );

    _showSnackBar('✅ تم حذف الأرشيف بالكامل');
    _loadData();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Segoe UI')),
        backgroundColor:
            isError ? Colors.red.shade700 : const Color(0xFF27AE60),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<bool?> _showConfirmDialog(String title, String content) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, textDirection: TextDirection.rtl),
        content: Text(content, textDirection: TextDirection.rtl),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 5. بناء واجهة المستخدم (UI Build)
  // ==========================================
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F4F8),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E2A36),
          title: const Text('📦 إدارة تغذية الكروت',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          centerTitle: true,
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(12.0),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // شريط التصفية الأعلى (متاح / مستخدم)
                        _buildFilterRow(),
                        const SizedBox(height: 12),

                        // اختيارات الباقة واستيراد الملف (تختفي في قسم المستخدم)
                        if (_currentFilter == 'available')
                          _buildKeywordAndFileRow(),

                        const SizedBox(height: 12),

                        // المحتوى الرئيسي
                        if (_currentFilter == 'available')
                          _buildEditorSection()
                        else
                          _buildUsedCardsSection(),

                        const SizedBox(height: 12),

                        // إحصائيات أسفل الصفحة
                        _buildFooterStats(),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  // شريط التصفية الرئيسي
  Widget _buildFilterRow() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(50),
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.move_to_inbox, size: 18),
              label: const Text('📥 متاح'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _currentFilter == 'available'
                    ? const Color(0xFF2C3E50)
                    : const Color(0xFFF1F3F5),
                foregroundColor: _currentFilter == 'available'
                    ? Colors.white
                    : Colors.black87,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () {
                setState(() => _currentFilter = 'available');
                _refreshEditorText();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.outbox, size: 18),
              label: const Text('📤 مستخدم'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _currentFilter == 'used'
                    ? const Color(0xFF2C3E50)
                    : const Color(0xFFF1F3F5),
                foregroundColor:
                    _currentFilter == 'used' ? Colors.white : Colors.black87,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () {
                setState(() => _currentFilter = 'used');
                _refreshEditorText();
              },
            ),
          ),
        ],
      ),
    );
  }

  // صف القائمة المنسدلة وزر اختيار الملف
  Widget _buildKeywordAndFileRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(60),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedKeywordId,
                isExpanded: true,
                items: [
                  const DropdownMenuItem(
                      value: 'all', child: Text('كل الباقات')),
                  ..._keywords.map((k) {
                    return DropdownMenuItem(
                      value: k['id'].toString(),
                      child: Text('🔑 ${k['keyword']}'),
                    );
                  }).toList(),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedKeywordId = val);
                    _refreshEditorText();
                  }
                },
              ),
            ),
          ),
          if (_selectedKeywordId != 'all') ...[
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.folder_open, size: 16),
                label: const Text('📂 قراءة من ملف',
                    style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3498DB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(40)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onPressed: _pickAndReadFile,
              ),
            ),
          ]
        ],
      ),
    );
  }

  // محرر الكروت المتاحة
  Widget _buildEditorSection() {
    bool isAllSelected = _selectedKeywordId == 'all';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isAllSelected
                ? '📌 اختر باقة أولاً'
                : '✏️ الكروت المتاحة (قابلة للتعديل)',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _numbersController,
            enabled: !isAllSelected,
            maxLines: 10,
            textDirection: TextDirection.ltr, // اتجاه الأكواد LTR
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: InputDecoration(
              hintText: isAllSelected
                  ? 'اختر باقة لعرض وتعديل الكروت...'
                  : 'أدخل كل كرت في سطر مستقل...',
              fillColor: isAllSelected
                  ? const Color(0xFFF5F5F5)
                  : const Color(0xFFFEFEF5),
              filled: true,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Colors.grey)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isAllSelected
                ? ''
                : '✅ يمكنك إضافة أو حذف الكروت يدوياً ثم الضغط على حفظ.',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          if (!isAllSelected)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('💾 حفظ التغييرات',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF27AE60),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(60)),
                ),
                onPressed: _saveNumbers,
              ),
            ),
        ],
      ),
    );
  }

  // قسم الكروت المستخدمة والأرشيف
  Widget _buildUsedCardsSection() {
    // تجميع الكروت الأرشيفية بحسب الكلمة المفتاحية
    Map<String, List<Map<String, dynamic>>> groupedUsed = {};
    for (var item in _archiveList) {
      String kw = item['matched_keyword']?.toString() ?? 'غير معروف';
      if (kw.isEmpty) kw = 'غير معروف';
      groupedUsed.putIfAbsent(kw, () => []).add(item);
    }

    if (groupedUsed.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(28)),
        child:
            const Center(child: Text('لا توجد كروت مستخدمة في الأرشيف حالياً')),
      );
    }

    // تحديد التاب النشط
    if (_selectedUsedKeyword == null ||
        !groupedUsed.containsKey(_selectedUsedKeyword)) {
      _selectedUsedKeyword = groupedUsed.keys.first;
    }

    List<Map<String, dynamic>> currentUsedList =
        groupedUsed[_selectedUsedKeyword] ?? [];

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: const Color(0xFF2C3E50),
              borderRadius: BorderRadius.circular(14)),
          child: const Text('📤 سجل الكروت المرسلة',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 8),

        // تابات الكلمات المفتاحية
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: groupedUsed.keys.map((kw) {
              bool isActive = _selectedUsedKeyword == kw;
              int count = groupedUsed[kw]?.length ?? 0;
              return Padding(
                padding: const EdgeInsets.only(left: 6.0),
                child: ChoiceChip(
                  label: Text('$kw ($count)'),
                  selected: isActive,
                  selectedColor: const Color(0xFF1976D2),
                  labelStyle: TextStyle(
                      color: isActive ? Colors.white : const Color(0xFF1976D2),
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedUsedKeyword = kw);
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),

        // قائمة العناصر المستخدمة
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: currentUsedList.length,
          itemBuilder: (ctx, idx) {
            final item = currentUsedList[idx];
            final dt =
                DateTime.fromMillisecondsSinceEpoch(item['timestamp'] ?? 0);
            final dateStr = intl.DateFormat('yyyy-MM-dd HH:mm').format(dt);

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              child: ListTile(
                title: Text(item['sent_number'] ?? '',
                    style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
                subtitle: Text(
                    '📅 $dateStr | 👤 ${item['sender_name'] ?? item['sender'] ?? '-'}',
                    style: const TextStyle(fontSize: 11)),
                trailing: IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () => _deleteUsedCard(item['id']),
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.delete_forever, size: 16),
                label: const Text('حذف الكل من الأرشيف',
                    style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE74C3C),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: _deleteAllUsed,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // كرت الإحصائيات في أسفل الواجهة
  Widget _buildFooterStats() {
    int totalCount = 0;
    int availCount = 0;
    int usedCount = 0;

    if (_selectedKeywordId != 'all') {
      final kwId = int.tryParse(_selectedKeywordId);
      final filtered =
          _allNumbers.where((n) => n['keyword_id'] == kwId).toList();
      availCount = filtered.where((n) => n['status'] == 'available').length;
      usedCount = filtered.where((n) => n['status'] == 'used').length;
      totalCount = availCount + usedCount;
    } else {
      totalCount = _allNumbers.length;
      availCount = _allNumbers.where((n) => n['status'] == 'available').length;
      usedCount = _allNumbers.where((n) => n['status'] == 'used').length;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(28)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatBox('الإجمالي', totalCount.toString(), Colors.blueGrey),
          _buildStatBox(
              '📥 متاح', availCount.toString(), const Color(0xFF1F6E43)),
          _buildStatBox(
              '📤 مستخدم', usedCount.toString(), Colors.orange.shade800),
        ],
      ),
    );
  }

  Widget _buildStatBox(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
