import 'package:flutter/material.dart';
import 'DatabaseHelper.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  int _selectedDays = 7;
  bool _isLoading = true;

  List<Map<String, dynamic>> _kwInfoList = [];
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
    if (!mounted) return;
    setState(() => _isLoading = true);

    final db = await _dbHelper.database;
    final allKeywords = await _dbHelper.getAllKeywords();
    
    int? cutoffTimestamp;
    if (_selectedDays > 0) {
      final now = DateTime.now();
      final cutoffDate = now.subtract(Duration(days: _selectedDays - 1));
      final startOfCutoffDay = DateTime(cutoffDate.year, cutoffDate.month, cutoffDate.day);
      cutoffTimestamp = startOfCutoffDay.millisecondsSinceEpoch;
    }

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
      final String dayKey = "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

      dataByDay.putIfAbsent(dayKey, () => {});
      dataByDay[dayKey]![kw] = (dataByDay[dayKey]![kw] ?? 0) + 1;
    }

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

    final List<Map<String, String>> daysList = [];
    final now = DateTime.now();

    if (_selectedDays > 0) {
      for (int i = 0; i < _selectedDays; i++) {
        final d = now.subtract(Duration(days: i));
        final label = "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}";
        final key = "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
        daysList.add({'label': label, 'key': key});
      }
    } else {
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
    final cardBg = theme.cardColor;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          centerTitle: true,
          title: const Text(
            'تقارير المبيعات',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: _loadSalesData,
            )
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadSalesData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              _buildTabButton('7 أيام', 7, cardBg, textColor, isDark),
                              const SizedBox(width: 8),
                              _buildTabButton('30 يوم', 30, cardBg, textColor, isDark),
                              const SizedBox(width: 8),
                              _buildTabButton('الكل', 0, cardBg, textColor, isDark),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04)),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'جدول المبيعات اليومية',
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
                                    ),
                                    Icon(Icons.bar_chart_rounded, color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0F172A)),
                                  ],
                                ),
                                const Divider(height: 20),
                                _kwInfoList.isEmpty
                                    ? const Padding(
                                        padding: EdgeInsets.all(24.0),
                                        child: Text('لا توجد مبيعات مسجلة خلال هذه الفترة', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                      )
                                    : SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: DataTable(
                                          headingRowHeight: 40,
                                          dataRowMinHeight: 36,
                                          dataRowMaxHeight: 36,
                                          columnSpacing: 16,
                                          horizontalMargin: 12,
                                          headingRowColor: MaterialStateProperty.all(isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
                                          border: TableBorder.all(
                                            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                                            width: 1,
                                          ),
                                          columns: _buildTableColumns(textColor),
                                          rows: _buildTableRows(isDark, textColor),
                                        ),
                                      ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isDark 
                                    ? [const Color(0xFF065F46), const Color(0xFF047857)]
                                    : [const Color(0xFF10B981), const Color(0xFF059669)],
                              ),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(
                                  children: [
                                    const Text('إجمالي الكروت', style: TextStyle(fontSize: 11, color: Colors.white70)),
                                    const SizedBox(height: 2),
                                    Text('$_grandTotalCards كرت', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                                  ],
                                ),
                                Container(height: 24, width: 1, color: Colors.white24),
                                Column(
                                  children: [
                                    const Text('إجمالي الإيرادات', style: TextStyle(fontSize: 11, color: Colors.white70)),
                                    const SizedBox(height: 2),
                                    Text('${_grandTotalAmount.toStringAsFixed(0)} ر.ي', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                                  ],
                                ),
                              ],
                            ),
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

  Widget _buildTabButton(String title, int daysValue, Color cardBg, Color textColor, bool isDark) {
    final bool isActive = _selectedDays == daysValue;
    final activeColor = isDark ? const Color(0xFF38BDF8) : const Color(0xFF0F172A);

    return Expanded(
      child: InkWell(
        onTap: () {
          if (_selectedDays != daysValue) {
            setState(() => _selectedDays = daysValue);
            _loadSalesData();
          }
        },
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? activeColor : cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isActive ? Colors.transparent : (isDark ? Colors.white10 : Colors.black.withOpacity(0.05))),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isActive ? Colors.white : textColor,
            ),
          ),
        ),
      ),
    );
  }

  List<DataColumn> _buildTableColumns(Color textColor) {
    List<DataColumn> columns = [
      DataColumn(
        label: Text('التاريخ', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    ];

    for (var item in _kwInfoList) {
      columns.add(DataColumn(
        label: Text('${item['keyword']}', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12)),
      ));
      columns.add(DataColumn(
        label: Text('المبلغ', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12)),
      ));
    }

    columns.add(DataColumn(
      label: Text('الإجمالي', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12)),
    ));

    return columns;
  }

  List<DataRow> _buildTableRows(bool isDark, Color textColor) {
    List<DataRow> rows = [];

    for (var row in _dailyRows) {
      List<DataCell> cells = [
        DataCell(Text(row['label'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: textColor))),
      ];

      for (var item in _kwInfoList) {
        String kw = item['keyword'];
        final int count = row['counts'][kw] ?? 0;
        final double amount = row['amounts'][kw] ?? 0.0;

        cells.add(DataCell(Center(child: Text('$count', style: TextStyle(fontSize: 11, color: textColor)))));
        cells.add(DataCell(Center(
          child: Text(amount > 0 ? '${amount.toStringAsFixed(0)}' : '0',
              style: TextStyle(color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7), fontSize: 11, fontWeight: FontWeight.w600)),
        )));
      }

      cells.add(DataCell(Center(
        child: Text('${(row['totalAmount'] as double).toStringAsFixed(0)}',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981), fontSize: 11)),
      )));

      rows.add(DataRow(cells: cells));
    }

    List<DataCell> totalCardsCells = [
      DataCell(Text('الكروت', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: textColor))),
    ];
    for (var item in _kwInfoList) {
      String kw = item['keyword'];
      totalCardsCells.add(DataCell(Center(
          child: Text('${_kwTotals[kw] ?? 0}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: textColor)))));
      totalCardsCells.add(const DataCell(Center(child: Text('-', style: TextStyle(color: Colors.grey)))));
    }
    totalCardsCells.add(DataCell(Center(
        child: Text('$_grandTotalCards', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: textColor)))));

    rows.add(DataRow(
      color: MaterialStateProperty.all(isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF8FAFC)),
      cells: totalCardsCells,
    ));

    List<DataCell> totalAmountCells = [
      DataCell(Text('الإيراد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: textColor))),
    ];
    for (var item in _kwInfoList) {
      String kw = item['keyword'];
      double price = item['price'];
      final double kwAmount = (_kwTotals[kw] ?? 0) * price;

      totalAmountCells.add(const DataCell(Center(child: Text('-', style: TextStyle(color: Colors.grey)))));
      totalAmountCells.add(DataCell(Center(
          child: Text('${kwAmount.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: textColor)))));
    }
    totalAmountCells.add(DataCell(Center(
        child: Text('${_grandTotalAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF10B981))))));

    rows.add(DataRow(
      color: MaterialStateProperty.all(isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFF1F5F9)),
      cells: totalAmountCells,
    ));

    return rows;
  }
}