import 'package:flutter/material.dart';
import 'package:intl/intl.dart'
    hide TextDirection; // إخفاء TextDirection لمنع التعارض
import 'DatabaseHelper.dart';

class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key}); // استخدام Super parameter لخاصية key

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  List<Map<String, dynamic>> _allData = [];
  List<Map<String, dynamic>> _filteredData = [];
  List<Map<String, dynamic>> _keywordsList = [];

  bool _isLoading = true;
  String _currentFilter = 'today'; // 'today', 'week', 'month', 'all'
  String _selectedKeyword = 'all';
  String _searchQuery = '';

  final TextEditingController _searchController = TextEditingController();

  // نظام الصفحات (Pagination)
  static const int _perPage = 50;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // جلب البيانات من قاعدة البيانات
  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final db = await _dbHelper.database;

    // جلب أرشيف الردود من جدول reply_log
    final archiveData = await db.query(
      DatabaseHelper.tableReplyLog,
      where: 'is_deleted = 0',
      orderBy: 'timestamp DESC',
    );

    // جلب الكلمات المفتاحية للفلاتر
    final keywords = await _dbHelper.getAllKeywords();

    setState(() {
      _allData = archiveData;
      _keywordsList = keywords;
      _isLoading = false;
    });

    _applyFilters();
  }

  // فلترة البيانات بناءً على التبويب، الكلمة المفتاحية، ونص البحث
  void _applyFilters() {
    List<Map<String, dynamic>> temp = List.from(_allData);

    // 1. فلترة حسب التاريخ
    final now = DateTime.now();
    final todayStart =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;

    if (_currentFilter == 'today') {
      temp = temp.where((r) => (r['timestamp'] ?? 0) >= todayStart).toList();
    } else if (_currentFilter == 'week') {
      final weekStart = DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 6))
          .millisecondsSinceEpoch;
      temp = temp.where((r) => (r['timestamp'] ?? 0) >= weekStart).toList();
    } else if (_currentFilter == 'month') {
      final monthStart =
          DateTime(now.year, now.month, 1).millisecondsSinceEpoch;
      temp = temp.where((r) => (r['timestamp'] ?? 0) >= monthStart).toList();
    }

    // 2. فلترة حسب الكلمة المفتاحية
    if (_selectedKeyword != 'all') {
      temp =
          temp.where((r) => r['matched_keyword'] == _selectedKeyword).toList();
    }

    // 3. فلترة حسب نص البحث (الرقم، المرسل، أو الاسم)
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      temp = temp.where((r) {
        final sentNumber = (r['sent_number'] ?? '').toString().toLowerCase();
        final senderName = (r['sender_name'] ?? '').toString().toLowerCase();
        final sender = (r['sender'] ?? '').toString().toLowerCase();
        return sentNumber.contains(query) ||
            senderName.contains(query) ||
            sender.contains(query);
      }).toList();
    }

    setState(() {
      _filteredData = temp;
      _currentPage = 1; // العودة للصفحة الأولى عند التغيير
    });
  }

  // إظهار تنبيه Toast سريع
  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        backgroundColor:
            isError ? Colors.red.shade700 : const Color(0xFF27AE60),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      ),
    );
  }

  // حذف سجل محدد
  Future<void> _deleteRecord(int id) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl, // استخدام الاتجاه القياسي لـ Flutter
        child: AlertDialog(
          title: const Text('حذف السجل',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          content: const Text('هل أنت متأكد من حذف هذا السجل من الأرشيف؟',
              style: TextStyle(fontSize: 12)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE74C3C)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف',
                  style: TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      final db = await _dbHelper.database;
      // تحديث حالة الحذف المنطقي is_deleted = 1
      await db.update(
        DatabaseHelper.tableReplyLog,
        {'is_deleted': 1},
        where: 'id = ?',
        whereArgs: [id],
      );

      _showSnackBar('✅ تم الحذف بنجاح');
      _loadData();
    }
  }

  // حساب الإحصائيات (Summary)
  Map<String, int> _calculateSummary() {
    final Map<String, int> counts = {};
    final dataToSummarize = _currentFilter == 'all' ? _allData : _filteredData;

    for (var row in dataToSummarize) {
      final kw = (row['matched_keyword'] != null &&
              row['matched_keyword'].toString().isNotEmpty)
          ? row['matched_keyword'].toString()
          : 'غير معروف';
      counts[kw] = (counts[kw] ?? 0) + 1;
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    // حساب بيانات الصفحة الحالية
    final totalPages = (_filteredData.length / _perPage).ceil();
    final startIndex = (_currentPage - 1) * _perPage;
    final endIndex = (startIndex + _perPage < _filteredData.length)
        ? startIndex + _perPage
        : _filteredData.length;
    final pageData = _filteredData.isEmpty
        ? []
        : _filteredData.sublist(startIndex, endIndex);

    final summaryCounts = _calculateSummary();

    return Directionality(
      textDirection: TextDirection.rtl, // استخدام الاتجاه القياسي لـ Flutter
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F4F8),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E2A36),
          title: const Text('📊 أرشيف الكروت',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          centerTitle: true,
          elevation: 0,
          leading: IconButton(
            icon:
                const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
            onPressed: () => Navigator.of(context).pop(),
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(8.0),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. أزرار الفلترة الزمانية (Tabs)
                        Row(
                          children: [
                            _buildTabButton('📊 اليوم', 'today'),
                            const SizedBox(width: 4),
                            _buildTabButton('📅 الأسبوع', 'week'),
                            const SizedBox(width: 4),
                            _buildTabButton('📆 الشهر', 'month'),
                            const SizedBox(width: 4),
                            _buildTabButton('📋 الكل', 'all'),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // 2. كروت الملخص (Summary Row)
                        SizedBox(
                          height: 55,
                          child: summaryCounts.isEmpty
                              ? _buildSummaryCard('📭 لا توجد', '')
                              : ListView(
                                  scrollDirection: Axis.horizontal,
                                  children: summaryCounts.entries.map((e) {
                                    return _buildSummaryCard(
                                        '💰 ${e.key}', '${e.value}');
                                  }).toList(),
                                ),
                        ),
                        const SizedBox(height: 8),

                        // 3. شريط البحث والفلترة حسب الكلمة
                        Row(
                          children: [
                            // القائمة المنسدلة للكلمات المفتاحية
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedKeyword,
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.black87),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _selectedKeyword = val);
                                      _applyFilters();
                                    }
                                  },
                                  items: [
                                    const DropdownMenuItem(
                                        value: 'all', child: Text('الكل')),
                                    ..._keywordsList.map((k) {
                                      // إزالة toList() غير الضرورية داخل Spread
                                      return DropdownMenuItem<String>(
                                        value: k['keyword'].toString(),
                                        child: Text(k['keyword'].toString()),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            // حقل النص للبحث
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                style: const TextStyle(fontSize: 12),
                                decoration: InputDecoration(
                                  hintText: '🔍 بحث...',
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  fillColor: Colors.white,
                                  filled: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    borderSide:
                                        BorderSide(color: Colors.grey.shade300),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    borderSide:
                                        BorderSide(color: Colors.grey.shade300),
                                  ),
                                ),
                                onChanged: (val) {
                                  _searchQuery = val.trim();
                                  _applyFilters();
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // 4. قائمة الكروت الأرشيفية
                        pageData.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(30.0),
                                child: Center(
                                  child: Text('📭 لا توجد سجلات',
                                      style: TextStyle(
                                          color: Colors.grey, fontSize: 13)),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: pageData.length,
                                itemBuilder: (ctx, idx) {
                                  final item = pageData[idx];
                                  return _buildArchiveCard(item);
                                },
                              ),

                        const SizedBox(height: 10),

                        // 5. الترقيم (Pagination Controls)
                        if (totalPages > 1)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chevron_left),
                                onPressed: _currentPage > 1
                                    ? () => setState(() => _currentPage--)
                                    : null,
                              ),
                              Text('صفحة $_currentPage من $totalPages',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                              IconButton(
                                icon: const Icon(Icons.chevron_right),
                                onPressed: _currentPage < totalPages
                                    ? () => setState(() => _currentPage++)
                                    : null,
                              ),
                            ],
                          ),

                        // 6. شريط الإجمالي
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6.0),
                            child: Text(
                              '📊 الإجمالي: ${_filteredData.length} كرت',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold),
                            ),
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

  // تبويب الاختيار (Today, Week, Month, All)
  Widget _buildTabButton(String label, String value) {
    final bool isActive = _currentFilter == value;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() => _currentFilter = value);
          _applyFilters();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF2C3E50) : Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isActive ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  // عنصر الملخص العلوي
  Widget _buildSummaryCard(String title, String count) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          if (count.isNotEmpty)
            Text(count,
                style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF2C3E50),
                    fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // كرت عرض كود القسيمة والأرشيف
  Widget _buildArchiveCard(Map<String, dynamic> r) {
    final int? timestamp = r['timestamp'];
    String dateStr = '-';
    if (timestamp != null) {
      final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
      dateStr = DateFormat('yyyy-MM-dd HH:mm').format(dt);
    }

    final String source = r['source'] ?? 'Noti';
    final bool isSms = source.toUpperCase() == 'SMS';

    final String senderName =
        (r['sender_name'] != null && r['sender_name'].toString().isNotEmpty)
            ? r['sender_name'].toString()
            : (r['sender'] ?? '-').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // كود الكرت المبعوث
          Container(
            constraints: const BoxConstraints(minWidth: 95),
            child: Text(
              r['sent_number'] ?? '-',
              textDirection: TextDirection
                  .ltr, // استخدام TextDirection الخاص بشركة Flutter
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // التفاصيل والبيانات
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('📅 $dateStr',
                    style: const TextStyle(fontSize: 9, color: Colors.grey)),
                Text('👤 $senderName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 10,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 4,
                  children: [
                    // Badge المصدر (SMS / Noti)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: isSms
                            ? const Color(0xFFE3F2FD)
                            : const Color(0xFFFCE4EC),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isSms ? '📨 SMS' : '🔔 إشعار',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: isSms
                              ? const Color(0xFF1976D2)
                              : const Color(0xFFC62828),
                        ),
                      ),
                    ),
                    // Badge الكلمة المفتاحية
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '💰 ${r['matched_keyword'] ?? '-'}',
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // زر الحذف
          InkWell(
            onTap: () => _deleteRecord(r['id']),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFFE74C3C),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Center(
                child: Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
