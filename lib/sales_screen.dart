import 'package:flutter/material.dart';
import 'DatabaseHelper.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  int _selectedDays = 7; // 7, 30, 0 (0 تعني الكل)
  bool _isLoading = true;

  List<Map<String, dynamic>> _kwInfoList = []; // يحتوي على (id, keyword, price)
  List<Map<String, dynamic>> _dailyRows = [];
  Map<String, int> _kwTotals = {};
  int _grandTotalCards = 0;
  double _grandTotalAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _loadSalesData();
  }

  Future<void> _loadSalesData() async {
    setState(() => _isLoading = true);

    final db = await _dbHelper.database;

    // 1. جلب الكلمات المفتاحية مع أسعارها من قاعدة البيانات
    final allKeywords = await _dbHelper.getAllKeywords();
    
    // 2. تحديد أقصى تاريخ بناءً على الفلترة الزمانية
    int? cutoffTimestamp;
    if (_selectedDays > 0) {
      final now = DateTime.now();
      final cutoffDate = now.subtract(Duration(days: _selectedDays - 1));
      final startOfCutoffDay =
          DateTime(cutoffDate.year, cutoffDate.month, cutoffDate.day);
      cutoffTimestamp = startOfCutoffDay.millisecondsSinceEpoch;
    }

    // 3. استعلام أرشيف الردود
    List<Map<String, dynamic>> archive;
    if (cutoffTimestamp != null) {
      archive = await db.query(
        DatabaseHelper.tableReplyLog,
        where: 'timestamp >= ? AND (is_deleted IS NULL OR is_deleted = 0) AND status IN (\'sent\', \'sent_reward\', \'sent_manual\')',
        whereArgs: [cutoffTimestamp],
        orderBy: 'timestamp DESC',
      );
    } else {
      archive = await db.query(
        DatabaseHelper.tableReplyLog,
        where: '(is_deleted IS NULL OR is_deleted = 0) AND status IN (\'sent\', \'sent_reward\', \'sent_manual\')',
        orderBy: 'timestamp DESC',
      );
    }

    // 4. تجميع البيانات وحساب المبيعات بالسعر الحقيقي
    final Set<String> foundKwNames = {};
    final Map<String, Map<String, int>> dataByDay = {};
    final Map<String, double> priceMap = {};

    for (var k in allKeywords) {
      String name = k['keyword'].toString().trim();
      double p = (k['price'] as num?)?.toDouble() ?? 0.0;
      priceMap[name] = p;
    }

    for (var row in archive) {
      final String kw = (row['matched_keyword'] ?? '').toString().trim();
      if (kw.isEmpty) continue;

      foundKwNames.add(kw);

      if (!priceMap.containsKey(kw) || (row['price'] != null && (row['price'] as num) > 0)) {
        priceMap[kw] = (row['price'] as num?)?.toDouble() ?? priceMap[kw] ?? 0.0;
      }

      final int ts = row['timestamp'] ?? 0;
      final DateTime d = DateTime.fromMillisecondsSinceEpoch(ts);
      final String dayKey =
          "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

      dataByDay.putIfAbsent(dayKey, () => {});
      dataByDay[dayKey]![kw] = (dataByDay[dayKey]![kw] ?? 0) + 1;
    }

    // ترتيب أسماء الباقات
    final List<String> sortedKwNames = foundKwNames.toList()
      ..sort((a, b) {
        int numA = int.tryParse(RegExp(r'\d+').stringMatch(a) ?? '') ?? 0;
        int numB = int.tryParse(RegExp(r'\d+').stringMatch(b) ?? '') ?? 0;
        return numA.compareTo(numB);
      });

    final List<Map<String, dynamic>> kwInfoList = sortedKwNames.map((name) {
      return {
        'keyword': name,
        'price': priceMap[name] ?? 0.0,
      };
    }).toList();

    // 5. توليد الأيام للعرض (تم الغاء الـ 90 يوم وتصحيح الهيكل)
    final List<Map<String, String>> daysList = [];
    final now = DateTime.now();

    if (_selectedDays > 0) {
      // نطاق محدد (7 أيام، 30 يوم...)
      for (int i = 0; i < _selectedDays; i++) {
        final d = now.subtract(Duration(days: i));
        final label = "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}";
        final key = "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
        daysList.add({'label': label, 'key': key});
      }
    } else {
      // اختيار "الكل" (0): توليد جميع الأيام من أقدم حركة حقيقية
      if (dataByDay.isNotEmpty) {
        final sortedKeys = dataByDay.keys.toList()..sort((a, b) => b.compareTo(a));
        
        final oldestKeyParts = sortedKeys.last.split('-');
        final startDate = DateTime(
          int.parse(oldestKeyParts[0]),
          int.parse(oldestKeyParts[1]),
          int.parse(oldestKeyParts[2]),
        );

        final DateTime endDate = DateTime(now.year, now.month, now.day);
        final int totalDays = endDate.difference(startDate).inDays + 1;

        for (int i = 0; i < totalDays; i++) {
          final d = endDate.subtract(Duration(days: i));
          final label = "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}";
          final key = "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
          daysList.add({'label': label, 'key': key});
        }
      } else {
        final label = "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}";
        final key = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
        daysList.add({'label': label, 'key': key});
      }
    }

    // 6. حساب المجاميع اليومية والكلية
    int cardsSum = 0;
    double amountSum = 0.0;
    final Map<String, int> kwTotalsMap = {for (var kw in sortedKwNames) kw: 0};
    final List<Map<String, dynamic>> calculatedRows = [];

    for (var day in daysList) {
      final String dayKey = day['key']!;
      final String dayLabel = day['label']!;
      double dayTotalAmount = 0.0;

      final Map<String, int> rowCounts = {};
      final Map<String, double> rowAmounts = {};

      for (var item in kwInfoList) {
        String kw = item['keyword'];
        double price = item['price'];

        final int count = (dataByDay[dayKey] != null && dataByDay[dayKey]![kw] != null)
            ? dataByDay[dayKey]![kw]!
            : 0;
        
        final double amount = count * price;

        rowCounts[kw] = count;
        rowAmounts[kw] = amount;

        dayTotalAmount += amount;
        kwTotalsMap[kw] = (kwTotalsMap[kw] ?? 0) + count;
        cardsSum += count;
      }

      calculatedRows.add({
        'label': dayLabel,
        'counts': rowCounts,
        'amounts': rowAmounts,
        'totalAmount': dayTotalAmount,
      });
    }

    for (var item in kwInfoList) {
      String kw = item['keyword'];
      double price = item['price'];
      amountSum += (kwTotalsMap[kw] ?? 0) * price;
    }

    if (!mounted) return;
    setState(() {
      _kwInfoList = kwInfoList;
      _dailyRows = calculatedRows;
      _kwTotals = kwTotalsMap;
      _grandTotalCards = cardsSum;
      _grandTotalAmount = amountSum;
      _isLoading = false;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: isDark ? theme.appBarTheme.backgroundColor : const Color(0xFF1E2A36),
          title: const Text('📊 تقارير المبيعات',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          centerTitle: true,
          elevation: 0,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF27AE60)))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(12.0),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // أزرار الفلاتر (7 أيام / 30 يوم / الكل)
                        Row(
                          children: [
                            _buildTabButton('📅 7 أيام', 7, isDark),
                            const SizedBox(width: 6),
                            _buildTabButton('📆 30 يوم', 30, isDark),
                            const SizedBox(width: 6),
                            _buildTabButton('📋 الكل', 0, isDark),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // جدول المبيعات
                        Card(
                          elevation: 2,
                          color: theme.cardColor,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.table_chart_rounded, color: Color(0xFF27AE60)),
                                    const SizedBox(width: 8),
                                    Text(
                                      'تفاصيل المبيعات اليومية',
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white : const Color(0xFF1E2A36)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _kwInfoList.isEmpty
                                    ? const Padding(
                                        padding: EdgeInsets.all(24.0),
                                        child: Text('📭 لا توجد مبيعات مسجلة',
                                            style: TextStyle(color: Colors.grey)),
                                      )
                                    : SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: DataTable(
                                          headingRowHeight: 42,
                                          dataRowMinHeight: 38,
                                          dataRowMaxHeight: 38,
                                          columnSpacing: 14,
                                          horizontalMargin: 10,
                                          headingRowColor: MaterialStateProperty.all(
                                            isDark ? Colors.grey.shade800 : const Color(0xFF1E2A36),
                                          ),
                                          border: TableBorder.all(
                                              color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                                              width: 0.8),
                                          columns: _buildTableColumns(),
                                          rows: _buildTableRows(isDark),
                                        ),
                                      ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ملخص المبيعات الكلي
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1B3E2B) : const Color(0xFFE0F2E9),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? const Color(0xFF27AE60) : const Color(0xFF52D68A),
                            ),
                          ),
                          child: Text(
                            '💰 إجمالي الكروت: $_grandTotalCards  |  💵 إجمالي المبلغ: ${_grandTotalAmount.toStringAsFixed(1)} ر.ي',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: isDark ? const Color(0xFF52D68A) : const Color(0xFF1F6E43),
                                fontWeight: FontWeight.bold,
                                fontSize: 14),
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

  Widget _buildTabButton(String title, int daysValue, bool isDark) {
    final bool isActive = _selectedDays == daysValue;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_selectedDays != daysValue) {
            setState(() => _selectedDays = daysValue);
            _loadSalesData();
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF27AE60)
                : (isDark ? Colors.grey.shade800 : Colors.white),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive ? const Color(0xFF27AE60) : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
            ),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isActive
                  ? Colors.white
                  : (isDark ? Colors.grey.shade300 : Colors.black87),
            ),
          ),
        ),
      ),
    );
  }

  List<DataColumn> _buildTableColumns() {
    List<DataColumn> columns = [
      const DataColumn(
        label: Text('التاريخ',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    ];

    for (var item in _kwInfoList) {
      columns.add(DataColumn(
        label: Text('باقة ${item['keyword']}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
      ));
      columns.add(const DataColumn(
        label: Text('المبلغ',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
      ));
    }

    columns.add(const DataColumn(
      label: Text('💰 الإجمالي',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
    ));

    return columns;
  }

  List<DataRow> _buildTableRows(bool isDark) {
    List<DataRow> rows = [];
    final textColor = isDark ? Colors.white : Colors.black87;

    for (var row in _dailyRows) {
      List<DataCell> cells = [
        DataCell(Text(row['label'],
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: textColor))),
      ];

      for (var item in _kwInfoList) {
        String kw = item['keyword'];
        final int count = row['counts'][kw] ?? 0;
        final double amount = row['amounts'][kw] ?? 0.0;

        cells.add(DataCell(Center(
            child: Text('$count', style: TextStyle(fontSize: 11, color: textColor)))));
        cells.add(DataCell(Center(
          child: Text(amount > 0 ? '${amount.toStringAsFixed(0)} ر.ي' : '0',
              style: TextStyle(
                  color: isDark ? Colors.blue.shade300 : const Color(0xFF1A5276),
                  fontSize: 11,
                  fontWeight: FontWeight.w500)),
        )));
      }

      cells.add(DataCell(Center(
        child: Text('${(row['totalAmount'] as double).toStringAsFixed(0)} ر.ي',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.amber.shade300 : const Color(0xFFB8860B),
                fontSize: 11)),
      )));

      rows.add(DataRow(cells: cells));
    }

    // صف إجمالي عدد الكروت
    List<DataCell> totalCardsCells = [
      DataCell(Text('📦 إجمالي',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: textColor))),
    ];
    for (var item in _kwInfoList) {
      String kw = item['keyword'];
      totalCardsCells.add(DataCell(Center(
          child: Text('${_kwTotals[kw] ?? 0}',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: textColor)))));
      totalCardsCells.add(const DataCell(
          Center(child: Text('—', style: TextStyle(color: Colors.grey)))));
    }
    totalCardsCells.add(DataCell(Center(
        child: Text('$_grandTotalCards كرت',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: textColor)))));

    rows.add(DataRow(
      color: MaterialStateProperty.all(isDark ? const Color(0xFF1B3E2B).withOpacity(0.5) : const Color(0xFFE8F5E9)),
      cells: totalCardsCells,
    ));

    // صف إجمالي المبلغ
    List<DataCell> totalAmountCells = [
      DataCell(Text('💵 المبلغ',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: textColor))),
    ];
    for (var item in _kwInfoList) {
      String kw = item['keyword'];
      double price = item['price'];
      final double kwAmount = (_kwTotals[kw] ?? 0) * price;

      totalAmountCells.add(const DataCell(
          Center(child: Text('—', style: TextStyle(color: Colors.grey)))));
      totalAmountCells.add(DataCell(Center(
          child: Text('${kwAmount.toStringAsFixed(0)} ر.ي',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: textColor)))));
    }
    totalAmountCells.add(DataCell(Center(
        child: Text('${_grandTotalAmount.toStringAsFixed(0)} ر.ي',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: textColor)))));

    rows.add(DataRow(
      color: MaterialStateProperty.all(isDark ? Colors.amber.shade900.withOpacity(0.3) : const Color(0xFFFFF3CD)),
      cells: totalAmountCells,
    ));

    return rows;
  }
}
//************************************* */
/*import 'package:flutter/material.dart';
import 'DatabaseHelper.dart'; // استدعاء ملف قاعدة البيانات الخاص بك

class SalesScreen extends StatefulWidget {
  const SalesScreen({Key? key}) : super(key: key);

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  int _selectedDays = 7; // 7, 30, 0 (0 تعني الكل)
  bool _isLoading = true;

  List<String> _kwList = [];
  List<Map<String, dynamic>> _dailyRows = [];
  Map<String, int> _kwTotals = {};
  int _grandTotalCards = 0;
  int _grandTotalAmount = 0;

  @override
  void initState() {
    super.initState();
    _loadSalesData();
  }

  // ==========================================
  // 1. جلب وحساب بيانات المبيعات من قاعدة البيانات
  // ==========================================
  Future<void> _loadSalesData() async {
    setState(() => _isLoading = true);

    final db = await _dbHelper.database;

    // تحديد أقصى تاريخ للمسح بناءً على التجميع
    int? cutoffTimestamp;
    if (_selectedDays > 0) {
      final now = DateTime.now();
      final cutoffDate = now.subtract(Duration(days: _selectedDays - 1));
      final startOfCutoffDay =
          DateTime(cutoffDate.year, cutoffDate.month, cutoffDate.day);
      cutoffTimestamp = startOfCutoffDay.millisecondsSinceEpoch;
    }

    // استعلام أرشيف الردود
    List<Map<String, dynamic>> archive;
    if (cutoffTimestamp != null) {
      archive = await db.query(
        DatabaseHelper.tableReplyLog,
        where: 'timestamp >= ? AND (is_deleted IS NULL OR is_deleted = 0)',
        whereArgs: [cutoffTimestamp],
        orderBy: 'timestamp DESC',
      );
    } else {
      archive = await db.query(
        DatabaseHelper.tableReplyLog,
        where: 'is_deleted IS NULL OR is_deleted = 0',
        orderBy: 'timestamp DESC',
      );
    }

    // تجميع الكلمات المفتاحية الفريدة وتجهيز المبيعات
    final Set<String> allKeywords = {};
    final Map<String, Map<String, int>> dataByDay = {};

    for (var row in archive) {
      final String kw = (row['matched_keyword'] ?? '').toString().trim();
      if (kw.isEmpty) continue;

      allKeywords.add(kw);

      final int ts = row['timestamp'] ?? 0;
      final DateTime d = DateTime.fromMillisecondsSinceEpoch(ts);
      final String dayKey =
          "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

      dataByDay.putIfAbsent(dayKey, () => {});
      dataByDay[dayKey]![kw] = (dataByDay[dayKey]![kw] ?? 0) + 1;
    }

    // ترتيب الكلمات المفتاحية
    final List<String> sortedKeywords = allKeywords.toList()
      ..sort((a, b) {
        int numA = int.tryParse(RegExp(r'\d+').stringMatch(a) ?? '') ?? 0;
        int numB = int.tryParse(RegExp(r'\d+').stringMatch(b) ?? '') ?? 0;
        return numA.compareTo(numB);
      });

    // توليد الأيام المطلوبة للعرض
    final List<Map<String, String>> daysList = [];
    final int totalDaysToGenerate = _selectedDays > 0
        ? _selectedDays
        : (dataByDay.keys.length > 0 ? dataByDay.keys.length : 7);

    final now = DateTime.now();
    for (int i = 0; i < totalDaysToGenerate; i++) {
      final d = now.subtract(Duration(days: i));
      final label =
          "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}";
      final key =
          "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
      daysList.add({'label': label, 'key': key});
    }

    // حساب المجاميع
    int cardsSum = 0;
    int amountSum = 0;
    final Map<String, int> kwTotalsMap = {for (var kw in sortedKeywords) kw: 0};

    final List<Map<String, dynamic>> calculatedRows = [];

    for (var day in daysList) {
      final String dayKey = day['key']!;
      final String dayLabel = day['label']!;
      int dayTotalAmount = 0;

      final Map<String, int> rowCounts = {};
      final Map<String, int> rowAmounts = {};

      for (var kw in sortedKeywords) {
        final int count =
            (dataByDay[dayKey] != null && dataByDay[dayKey]![kw] != null)
                ? dataByDay[dayKey]![kw]!
                : 0;
        final int price =
            int.tryParse(RegExp(r'\d+').stringMatch(kw) ?? '0') ?? 0;
        final int amount = count * price;

        rowCounts[kw] = count;
        rowAmounts[kw] = amount;

        dayTotalAmount += amount;
        kwTotalsMap[kw] = (kwTotalsMap[kw] ?? 0) + count;
        cardsSum += count;
      }

      calculatedRows.add({
        'label': dayLabel,
        'counts': rowCounts,
        'amounts': rowAmounts,
        'totalAmount': dayTotalAmount,
      });
    }

    for (var kw in sortedKeywords) {
      final int price =
          int.tryParse(RegExp(r'\d+').stringMatch(kw) ?? '0') ?? 0;
      amountSum += (kwTotalsMap[kw] ?? 0) * price;
    }

    setState(() {
      _kwList = sortedKeywords;
      _dailyRows = calculatedRows;
      _kwTotals = kwTotalsMap;
      _grandTotalCards = cardsSum;
      _grandTotalAmount = amountSum;
      _isLoading = false;
    });
  }

  // ==========================================
  // 2. بناء الواجهة
  // ==========================================
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F4F8),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E2A36),
          title: const Text('📊 مبيعات الكروت',
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
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // الشعار العلوي
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF111111),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.style,
                                color: Colors.white, size: 36),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // التبويبات (7 أيام / 30 يوم / الكل)
                        Row(
                          children: [
                            _buildTabButton('📅 7 أيام', 7),
                            const SizedBox(width: 6),
                            _buildTabButton('📆 30 يوم', 30),
                            const SizedBox(width: 6),
                            _buildTabButton('📋 الكل', 0),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // قسم الجدول
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                '📊 تقرير المبيعات',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2C3E50)),
                              ),
                              const SizedBox(height: 10),
                              _kwList.isEmpty
                                  ? const Padding(
                                      padding: EdgeInsets.all(24.0),
                                      child: Text('📭 لا توجد مبيعات مسجلة',
                                          style: TextStyle(color: Colors.grey)),
                                    )
                                  : SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: DataTable(
                                        headingRowHeight: 40,
                                        dataRowMinHeight: 36,
                                        dataRowMaxHeight: 36,
                                        columnSpacing: 12,
                                        horizontalMargin: 8,
                                        headingRowColor:
                                            MaterialStateProperty.all(
                                                const Color(0xFF2C3E50)),
                                        border: TableBorder.all(
                                            color: Colors.grey.shade300,
                                            width: 0.8),
                                        columns: _buildTableColumns(),
                                        rows: _buildTableRows(),
                                      ),
                                    ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // شريط ملخص الإجمالي
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2C3E50),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '💰 إجمالي الكروت: $_grandTotalCards  |  💵 إجمالي المبلغ: $_grandTotalAmount ر.ي',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13),
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

  // ==========================================
  // 3. مكونات الجدول والتبويبات
  // ==========================================

  Widget _buildTabButton(String title, int daysValue) {
    final bool isActive = _selectedDays == daysValue;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_selectedDays != daysValue) {
            setState(() => _selectedDays = daysValue);
            _loadSalesData();
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF2C3E50) : Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            title,
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

  List<DataColumn> _buildTableColumns() {
    List<DataColumn> columns = [
      const DataColumn(
        label: Text('التاريخ',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11)),
      ),
    ];

    for (var kw in _kwList) {
      columns.add(DataColumn(
        label: Text('باقة $kw',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11)),
      ));
      columns.add(const DataColumn(
        label: Text('مبلغ',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11)),
      ));
    }

    columns.add(const DataColumn(
      label: Text('💰 الإجمالي',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
    ));

    return columns;
  }

  List<DataRow> _buildTableRows() {
    List<DataRow> rows = [];

    // 1. الأيام اليومية
    for (var row in _dailyRows) {
      List<DataCell> cells = [
        DataCell(Text(row['label'],
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
      ];

      for (var kw in _kwList) {
        final int count = row['counts'][kw] ?? 0;
        final int amount = row['amounts'][kw] ?? 0;

        cells.add(DataCell(Center(
            child: Text('$count', style: const TextStyle(fontSize: 11)))));
        cells.add(DataCell(Center(
          child: Text(amount > 0 ? '$amount ر.ي' : '0',
              style: const TextStyle(color: Color(0xFF1A5276), fontSize: 11)),
        )));
      }

      cells.add(DataCell(Center(
        child: Text('${row['totalAmount']} ر.ي',
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFFB8860B),
                fontSize: 11)),
      )));

      rows.add(DataRow(cells: cells));
    }

    // 2. صف إجمالي عدد الكروت
    List<DataCell> totalCardsCells = [
      const DataCell(Text('📦 إجمالي',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
    ];
    for (var kw in _kwList) {
      totalCardsCells.add(DataCell(Center(
          child: Text('${_kwTotals[kw] ?? 0}',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 11)))));
      totalCardsCells.add(const DataCell(
          Center(child: Text('—', style: TextStyle(color: Colors.grey)))));
    }
    totalCardsCells.add(DataCell(Center(
        child: Text('$_grandTotalCards كرت',
            style:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)))));

    rows.add(DataRow(
      color: MaterialStateProperty.all(const Color(0xFFE8F5E9)),
      cells: totalCardsCells,
    ));

    // 3. صف إجمالي المبلغ
    List<DataCell> totalAmountCells = [
      const DataCell(Text('💵 المبلغ',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
    ];
    for (var kw in _kwList) {
      final int price =
          int.tryParse(RegExp(r'\d+').stringMatch(kw) ?? '0') ?? 0;
      final int kwAmount = (_kwTotals[kw] ?? 0) * price;

      totalAmountCells.add(const DataCell(
          Center(child: Text('—', style: TextStyle(color: Colors.grey)))));
      totalAmountCells.add(DataCell(Center(
          child: Text('$kwAmount ر.ي',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 11)))));
    }
    totalAmountCells.add(DataCell(Center(
        child: Text('$_grandTotalAmount ر.ي',
            style:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)))));

    rows.add(DataRow(
      color: MaterialStateProperty.all(const Color(0xFFFFF3CD)),
      cells: totalAmountCells,
    ));

    return rows;
  }
}
*/