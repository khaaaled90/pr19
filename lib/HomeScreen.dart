import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:sqflite/sqflite.dart';
import 'DatabaseHelper.dart';
import 'KeywordsScreen.dart'; // استدعاء شاشة إدارة الباقات
import 'PendingLogsScreen.dart';
import 'SettingsScreen.dart'; // استدعاء شاشة الإعدادات العامة
import 'vouchers_screen.dart'; // استدعاء شاشة الإعدادات العامة
import 'allowed_senders_screen.dart';
import 'sales_screen.dart';
import 'backup_screen.dart';
import 'archive_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool isLoading = true;
  int statReplies = 0;
  int totalAvailable = 0;
  int totalUsed = 0;

  // هيكلية بيانات توزيع الفئات للمخططات
  List<_CategoryStatData> availableCategoriesData = [];
  List<_CategoryStatData> usedCategoriesData = [];

  // قائمة ألوان أنيقة ومتناسقة للفئات المختلفة
  final List<Color> categoryColors = [
    const Color(0xFF2EC4B6), // تركواز
    const Color(0xFFFF9F1C), // برتقالي
    const Color(0xFFE71D36), // أحمر
    const Color(0xFF3A86FF), // أزرق
    const Color(0xFF8338EC), // بنفسجي
    const Color(0xFF00F5D4), // أخضر نعناعي
  ];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => isLoading = true);

    try {
      final db = DatabaseHelper.instance;
      final keywords =
          await db.getAllKeywords().timeout(const Duration(seconds: 2));
      final numbers =
          await db.getAllNumbers().timeout(const Duration(seconds: 2));

      final dbInstance = await db.database;
      final repliesCount = Sqflite.firstIntValue(
              await dbInstance.rawQuery('SELECT COUNT(*) FROM reply_log')) ??
          0;

      _processChartData(keywords, numbers);

      setState(() {
        statReplies = repliesCount;
        isLoading = false;
      });
    } catch (e) {
      _loadDummyData();
    }
  }

  void _loadDummyData() {
    setState(() {
      statReplies = 42;
      availableCategoriesData = [
        _CategoryStatData('باقة 100', 50, categoryColors[0]),
        _CategoryStatData('باقة 200', 30, categoryColors[1]),
        _CategoryStatData('باقة 500', 15, categoryColors[2]),
        _CategoryStatData('باقة 1000', 10, categoryColors[3]),
      ];

      usedCategoriesData = [
        _CategoryStatData('باقة 100', 120, categoryColors[0]),
        _CategoryStatData('باقة 200', 85, categoryColors[1]),
        _CategoryStatData('باقة 500', 40, categoryColors[2]),
        _CategoryStatData('باقة 1000', 20, categoryColors[3]),
      ];

      totalAvailable =
          availableCategoriesData.fold(0, (sum, item) => sum + item.count);
      totalUsed = usedCategoriesData.fold(0, (sum, item) => sum + item.count);
      isLoading = false;
    });
  }

  void _processChartData(
      List<Map<String, dynamic>> keywords, List<Map<String, dynamic>> numbers) {
    List<_CategoryStatData> availTemp = [];
    List<_CategoryStatData> usedTemp = [];

    int colorIndex = 0;
    int availSum = 0;
    int usedSum = 0;

    for (var kw in keywords) {
      int kwId = kw['id'];
      String kwName = kw['keyword'] ?? 'فئة $kwId';
      Color color = categoryColors[colorIndex % categoryColors.length];

      int availCount = numbers
          .where((n) => n['keyword_id'] == kwId && n['status'] == 'available')
          .length;
      int usedCount = numbers
          .where((n) => n['keyword_id'] == kwId && n['status'] == 'used')
          .length;

      if (availCount > 0)
        availTemp.add(_CategoryStatData(kwName, availCount, color));
      if (usedCount > 0)
        usedTemp.add(_CategoryStatData(kwName, usedCount, color));

      availSum += availCount;
      usedSum += usedCount;
      colorIndex++;
    }

    setState(() {
      availableCategoriesData = availTemp;
      usedCategoriesData = usedTemp;
      totalAvailable = availSum;
      totalUsed = usedSum;
    });
  }

  void _openManualSendDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ManualSendBottomSheet(
        onSentSuccess: () => _loadStats(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.wifi_tethering,
                  color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            const Text(
              'كرت شبكة - لوحة التحكم',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _loadStats,
            tooltip: 'تحديث البيانات',
          ),
          IconButton(
            icon: const Icon(Icons.power_settings_new, color: Colors.redAccent),
            onPressed: () => SystemNavigator.pop(),
            tooltip: 'خروج',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // ===== 1. المخططات الدائرية للإحصائيات =====
                    _buildPieChartSection('القسائم المتاحة حسب الفئة', '📥',
                        availableCategoriesData, totalAvailable, Colors.teal),
                    const SizedBox(height: 16),
                    _buildPieChartSection('القسائم المستخدمة حسب الفئة', '📤',
                        usedCategoriesData, totalUsed, Colors.deepOrange),
                    const SizedBox(height: 20),

                    // ===== 2. شبكة الخيارات والخدمات (Menu Grid) =====
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.25,
                      children: [
                        // تم ربط الانتقال بشاشة إدارة الباقات KeywordsScreen
                        _buildMenuItem('إدارة الباقات', '🔑', () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const KeywordsScreen()),
                          );
                          _loadStats(); // إعادة تحميل الإحصائيات عند العودة
                        }),
                        _buildMenuItem('تغذية الكروت', '📦', () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const VouchersScreen()),
                          );
                          _loadStats(); // إعادة تحميل الإحصائيات عند العودة
                        }),
                        _buildMenuItem('أرشيف الرسائل', '📋', () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const ArchiveScreen()),
                          );
                          _loadStats();
                        }),
                        _buildMenuItem('تقرير المبيعات', '📊', () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const SalesScreen()),
                          );
                          _loadStats();
                        }),
                        _buildMenuItem('العمليات المعلقة', '🎁', () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    const PendingLogsScreen()),
                          );
                          _loadStats();
                        }),

                        // تم ربط الانتقال بشاشة الإعدادات العامة SettingsScreen
                        _buildMenuItem('الإعدادات العامة', '⚙️', () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const SettingsScreen()),
                          );
                          _loadStats();
                        }),
                        _buildMenuItem('حسابات البنوك', '👤', () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    const AllowedSendersScreen()),
                          );
                          _loadStats();
                        }),

                        // زر الإرسال اليدوي
                        _buildMenuItem(
                          'إرسال يدوي',
                          '📤',
                          _openManualSendDialog,
                          bgColor: const Color(0xFFFFF3E0),
                          borderColor: Colors.orange,
                        ),

                        _buildMenuItem('نسخ احتياطي', '💾', () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const BackupScreen()),
                          );
                          _loadStats();
                        }),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ===== 3. شريط الحالة =====
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 4)
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle,
                              color: Colors.green, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'النظام جاهز  |  إجمالي الكروت: ${totalAvailable + totalUsed}  |  الردود: $statReplies',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF334155)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ===== 4. التذييل =====
                    const Text(
                      '© 2026 كرت شبكة - جميع الحقوق محفوظة',
                      style: TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPieChartSection(String title, String icon,
      List<_CategoryStatData> data, int total, Color themeColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(icon, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: themeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(
                  'المجموع: $total',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: themeColor),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          data.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Center(
                      child: Text('لا توجد بيانات متوفرة حالياً',
                          style: TextStyle(color: Colors.grey))),
                )
              : Row(
                  children: [
                    SizedBox(
                      height: 110,
                      width: 110,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 24,
                          sections: data.map((item) {
                            final double percentage =
                                total > 0 ? (item.count / total) * 100 : 0;
                            return PieChartSectionData(
                              color: item.color,
                              value: item.count.toDouble(),
                              title: '${percentage.toStringAsFixed(0)}%',
                              radius: 28,
                              titleStyle: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: data.map((item) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3.0),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                      color: item.color,
                                      shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    item.categoryName,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '${item.count}',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade800),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(String title, String icon, VoidCallback onTap,
      {Color bgColor = Colors.white, Color? borderColor}) {
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(14),
      elevation: 2,
      shadowColor: Colors.black12,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: borderColor != null
                ? Border.all(color: borderColor, width: 1.5)
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(icon, style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 6),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF334155)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryStatData {
  final String categoryName;
  final int count;
  final Color color;

  _CategoryStatData(this.categoryName, this.count, this.color);
}

// =========================================================
// نافذة الإرسال اليدوي BottomSheet
// =========================================================
class ManualSendBottomSheet extends StatefulWidget {
  final VoidCallback onSentSuccess;
  const ManualSendBottomSheet({Key? key, required this.onSentSuccess})
      : super(key: key);

  @override
  State<ManualSendBottomSheet> createState() => _ManualSendBottomSheetState();
}

class _ManualSendBottomSheetState extends State<ManualSendBottomSheet> {
  List<Map<String, dynamic>> keywords = [];
  int? selectedKeywordId;
  Map<String, dynamic>? availableVoucher;
  final TextEditingController _phoneController = TextEditingController();
  bool isLoadingKeywords = true;
  bool isSending = false;
  bool noCardsAvailable = false;

  @override
  void initState() {
    super.initState();
    _loadKeywords();
  }

  Future<void> _loadKeywords() async {
    try {
      final list = await DatabaseHelper.instance.getAllKeywords();
      setState(() {
        keywords = list.where((k) => k['is_active'] == 1).toList();
        isLoadingKeywords = false;
      });
    } catch (e) {
      setState(() => isLoadingKeywords = false);
    }
  }

  Future<void> _onKeywordSelected(int? id) async {
    if (id == null) return;
    setState(() {
      selectedKeywordId = id;
      availableVoucher = null;
      noCardsAvailable = false;
    });

    try {
      final db = await DatabaseHelper.instance.database;
      List<Map<String, dynamic>> results = await db.query(
        DatabaseHelper.tableNumbersPool,
        where: 'keyword_id = ? AND status = ?',
        whereArgs: [id, 'available'],
        limit: 1,
      );

      setState(() {
        if (results.isNotEmpty) {
          availableVoucher = results.first;
        } else {
          noCardsAvailable = true;
        }
      });
    } catch (e) {
      setState(() => noCardsAvailable = true);
    }
  }

  Future<void> _sendCard() async {
    String phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _showMessage('⚠️ الرجاء إدخال رقم الجوال', isError: true);
      return;
    }

    if (availableVoucher == null || selectedKeywordId == null) {
      _showMessage('⚠️ لا يوجد كرت متاح للإرسال', isError: true);
      return;
    }

    setState(() => isSending = true);

    try {
      final dbHelper = DatabaseHelper.instance;
      var usedVoucher =
          await dbHelper.getAndUseVoucher(selectedKeywordId!, phone);

      if (usedVoucher != null) {
        String cardCode = usedVoucher['number_code'];
        await dbHelper.saveOrUpdateCustomer(phone);
        String footerMsg = await dbHelper.getSetting('footer_message', '');
        String fullMessage =
            cardCode + (footerMsg.isNotEmpty ? '\n$footerMsg' : '');

        var matchedKw =
            keywords.firstWhere((k) => k['id'] == selectedKeywordId);
        String kwName = matchedKw['keyword'] ?? 'يدوي';

        await dbHelper.addToArchive(
          sender: 'إرسال يدوي',
          senderName: phone,
          receivedMessage: fullMessage,
          matchedKeyword: kwName,
          sentNumber: cardCode,
          status: 'sent',
        );

        _showMessage('✅ تم إرسال الكرت إلى $phone بنجاح');
        widget.onSentSuccess();
        Navigator.pop(context);
      } else {
        _showMessage('❌ فشل تعيين الكرت', isError: true);
      }
    } catch (e) {
      _showMessage('⚠️ خطأ في معالجة العملية', isError: true);
    }

    setState(() => isSending = false);
  }

  void _showMessage(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, textAlign: TextAlign.center),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFF4F6F9),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('📤 إرسال يدوي',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🔑 اختر الباقة:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  isLoadingKeywords
                      ? const Center(child: CircularProgressIndicator())
                      : DropdownButtonFormField<int>(
                          value: selectedKeywordId,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30)),
                          ),
                          hint: const Text('-- اختر الباقة --'),
                          items: keywords.map((k) {
                            return DropdownMenuItem<int>(
                              value: k['id'] as int,
                              child: Text(
                                  '${k['keyword']} ${k['description'] != null ? "- " + k['description'] : ""}'),
                            );
                          }).toList(),
                          onChanged: _onKeywordSelected,
                        ),
                ],
              ),
            ),
            if (availableVoucher != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('💳 الكرت المتاح:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        availableVoucher!['number_code'] ?? '---',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('📞 رقم الجوال:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textDirection: TextDirection.ltr,
                      decoration: InputDecoration(
                        hintText: 'أدخل رقم الجوال',
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: isSending ? null : _sendCard,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                      ),
                      child: isSending
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('📤 إرسال الكرت',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ],
            if (noCardsAvailable) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12)),
                child: const Text('⚠️ لا توجد كروت متاحة لهذه الباقة',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
/*import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart'; // استدعاء مكتبة الرسم البياني
import 'package:sqflite/sqflite.dart';
import 'DatabaseHelper.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool isLoading = true;
  int statReplies = 0;
  int totalAvailable = 0;
  int totalUsed = 0;

  // هيكلية بيانات توزيع الفئات للمخططات
  List<_CategoryStatData> availableCategoriesData = [];
  List<_CategoryStatData> usedCategoriesData = [];

  // قائمة ألوان أنيقة ومتناسقة للفئات المختلفة
  final List<Color> categoryColors = [
    const Color(0xFF2EC4B6), // تركواز
    const Color(0xFFFF9F1C), // برتقالي
    const Color(0xFFE71D36), // أحمر
    const Color(0xFF3A86FF), // أزرق
    const Color(0xFF8338EC), // بنفسجي
    const Color(0xFF00F5D4), // أخضر نعناعي
  ];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => isLoading = true);

    try {
      final db = DatabaseHelper.instance;
      final keywords =
          await db.getAllKeywords().timeout(const Duration(seconds: 2));
      final numbers =
          await db.getAllNumbers().timeout(const Duration(seconds: 2));

      final dbInstance = await db.database;
      final repliesCount = Sqflite.firstIntValue(
              await dbInstance.rawQuery('SELECT COUNT(*) FROM reply_log')) ??
          0;

      _processChartData(keywords, numbers);

      setState(() {
        statReplies = repliesCount;
        isLoading = false;
      });
    } catch (e) {
      // بيانات تجريبية خفيفة وعصرية في حال التجربة أونلاين/مُحاكي المتصفح
      _loadDummyData();
    }
  }

  void _loadDummyData() {
    setState(() {
      statReplies = 42;
      availableCategoriesData = [
        _CategoryStatData('باقة 100', 50, categoryColors[0]),
        _CategoryStatData('باقة 200', 30, categoryColors[1]),
        _CategoryStatData('باقة 500', 15, categoryColors[2]),
        _CategoryStatData('باقة 1000', 10, categoryColors[3]),
      ];

      usedCategoriesData = [
        _CategoryStatData('باقة 100', 120, categoryColors[0]),
        _CategoryStatData('باقة 200', 85, categoryColors[1]),
        _CategoryStatData('باقة 500', 40, categoryColors[2]),
        _CategoryStatData('باقة 1000', 20, categoryColors[3]),
      ];

      totalAvailable =
          availableCategoriesData.fold(0, (sum, item) => sum + item.count);
      totalUsed = usedCategoriesData.fold(0, (sum, item) => sum + item.count);
      isLoading = false;
    });
  }

  void _processChartData(
      List<Map<String, dynamic>> keywords, List<Map<String, dynamic>> numbers) {
    List<_CategoryStatData> availTemp = [];
    List<_CategoryStatData> usedTemp = [];

    int colorIndex = 0;
    int availSum = 0;
    int usedSum = 0;

    for (var kw in keywords) {
      int kwId = kw['id'];
      String kwName = kw['keyword'] ?? 'فئة $kwId';
      Color color = categoryColors[colorIndex % categoryColors.length];

      int availCount = numbers
          .where((n) => n['keyword_id'] == kwId && n['status'] == 'available')
          .length;
      int usedCount = numbers
          .where((n) => n['keyword_id'] == kwId && n['status'] == 'used')
          .length;

      if (availCount > 0)
        availTemp.add(_CategoryStatData(kwName, availCount, color));
      if (usedCount > 0)
        usedTemp.add(_CategoryStatData(kwName, usedCount, color));

      availSum += availCount;
      usedSum += usedCount;
      colorIndex++;
    }

    setState(() {
      availableCategoriesData = availTemp;
      usedCategoriesData = usedTemp;
      totalAvailable = availSum;
      totalUsed = usedSum;
    });
  }

  void _openManualSendDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ManualSendBottomSheet(
        onSentSuccess: () => _loadStats(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.wifi_tethering,
                  color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            const Text(
              'كرت شبكة - لوحة التحكم',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _loadStats,
            tooltip: 'تحديث البيانات',
          ),
          IconButton(
            icon: const Icon(Icons.power_settings_new, color: Colors.redAccent),
            onPressed: () => SystemNavigator.pop(),
            tooltip: 'خروج',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // ===== 1. المخططات الدائرية للإحصائيات =====
                    _buildPieChartSection('القسائم المتاحة حسب الفئة', '📥',
                        availableCategoriesData, totalAvailable, Colors.teal),
                    const SizedBox(height: 16),
                    _buildPieChartSection('القسائم المستخدمة حسب الفئة', '📤',
                        usedCategoriesData, totalUsed, Colors.deepOrange),
                    const SizedBox(height: 20),

                    // ===== 2. شبكة الخيارات والخدمات (Menu Grid) =====
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.25,
                      children: [
                        _buildMenuItem('إدارة الباقات', '🔑', () {}),
                        _buildMenuItem('تغذية الكروت', '📦', () {}),
                        _buildMenuItem('عروض الباقات', '🎁', () {}),
                        _buildMenuItem('أرشيف الرسائل', '📋', () {}),
                        _buildMenuItem('تقرير المبيعات', '📊', () {}),
                        _buildMenuItem('الإعدادات العامة', '⚙️', () {}),
                        _buildMenuItem('حسابات البنوك', '👤', () {}),

                        // زر الإرسال اليدوي المميز
                        _buildMenuItem(
                          'إرسال يدوي',
                          '📤',
                          _openManualSendDialog,
                          bgColor: const Color(0xFFFFF3E0),
                          borderColor: Colors.orange,
                        ),

                        _buildMenuItem('نسخ احتياطي', '💾', () {}),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ===== 3. شريط الحالة الأنيق =====
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 4)
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle,
                              color: Colors.green, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'النظام جاهز  |  إجمالي الكروت: ${totalAvailable + totalUsed}  |  الردود: $statReplies',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF334155)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ===== 4. التذييل (Footer) =====
                    const Text(
                      '© 2026 كرت شبكة - جميع الحقوق محفوظة',
                      style: TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // ===== ويدجت بناء بطاقة المخطط الدائري =====
  // ===== ويدجت بناء بطاقة المخطط الدائري (معدلة ومقاومة للـ Overflow) =====
  Widget _buildPieChartSection(String title, String icon,
      List<_CategoryStatData> data, int total, Color themeColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row الرئيسي مع استخدام Expanded لمنع Overflow
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(icon, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: themeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(
                  'المجموع: $total',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: themeColor),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          data.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Center(
                      child: Text('لا توجد بيانات متوفرة حالياً',
                          style: TextStyle(color: Colors.grey))),
                )
              : Row(
                  children: [
                    // الرسم البياني الدائري
                    SizedBox(
                      height: 110,
                      width: 110,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 24,
                          sections: data.map((item) {
                            final double percentage =
                                total > 0 ? (item.count / total) * 100 : 0;
                            return PieChartSectionData(
                              color: item.color,
                              value: item.count.toDouble(),
                              title: '${percentage.toStringAsFixed(0)}%',
                              radius: 28,
                              titleStyle: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // الدليل والرموز التوضيحية للفئات
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: data.map((item) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3.0),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                      color: item.color,
                                      shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    item.categoryName,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '${item.count}',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade800),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  // ويدجت زر القائمة
  Widget _buildMenuItem(String title, String icon, VoidCallback onTap,
      {Color bgColor = Colors.white, Color? borderColor}) {
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(14),
      elevation: 2,
      shadowColor: Colors.black12,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: borderColor != null
                ? Border.all(color: borderColor, width: 1.5)
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(icon, style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 6),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF334155)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// كلاس مساعد لتخزين بيانات المخططات
class _CategoryStatData {
  final String categoryName;
  final int count;
  final Color color;

  _CategoryStatData(this.categoryName, this.count, this.color);
}

// =========================================================
// نافذة الإرسال اليدوي BottomSheet
// =========================================================
class ManualSendBottomSheet extends StatefulWidget {
  final VoidCallback onSentSuccess;
  const ManualSendBottomSheet({Key? key, required this.onSentSuccess})
      : super(key: key);

  @override
  State<ManualSendBottomSheet> createState() => _ManualSendBottomSheetState();
}

class _ManualSendBottomSheetState extends State<ManualSendBottomSheet> {
  List<Map<String, dynamic>> keywords = [];
  int? selectedKeywordId;
  Map<String, dynamic>? availableVoucher;
  final TextEditingController _phoneController = TextEditingController();
  bool isLoadingKeywords = true;
  bool isSending = false;
  bool noCardsAvailable = false;

  @override
  void initState() {
    super.initState();
    _loadKeywords();
  }

  Future<void> _loadKeywords() async {
    try {
      final list = await DatabaseHelper.instance.getAllKeywords();
      setState(() {
        keywords = list.where((k) => k['is_active'] == 1).toList();
        isLoadingKeywords = false;
      });
    } catch (e) {
      setState(() => isLoadingKeywords = false);
    }
  }

  Future<void> _onKeywordSelected(int? id) async {
    if (id == null) return;
    setState(() {
      selectedKeywordId = id;
      availableVoucher = null;
      noCardsAvailable = false;
    });

    try {
      final db = await DatabaseHelper.instance.database;
      List<Map<String, dynamic>> results = await db.query(
        DatabaseHelper.tableNumbersPool,
        where: 'keyword_id = ? AND status = ?',
        whereArgs: [id, 'available'],
        limit: 1,
      );

      setState(() {
        if (results.isNotEmpty) {
          availableVoucher = results.first;
        } else {
          noCardsAvailable = true;
        }
      });
    } catch (e) {
      setState(() => noCardsAvailable = true);
    }
  }

  Future<void> _sendCard() async {
    String phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _showMessage('⚠️ الرجاء إدخال رقم الجوال', isError: true);
      return;
    }

    if (availableVoucher == null || selectedKeywordId == null) {
      _showMessage('⚠️ لا يوجد كرت متاح للإرسال', isError: true);
      return;
    }

    setState(() => isSending = true);

    try {
      final dbHelper = DatabaseHelper.instance;
      var usedVoucher =
          await dbHelper.getAndUseVoucher(selectedKeywordId!, phone);

      if (usedVoucher != null) {
        String cardCode = usedVoucher['number_code'];
        await dbHelper.saveOrUpdateCustomer(phone);
        String footerMsg = await dbHelper.getSetting('footer_message', '');
        String fullMessage =
            cardCode + (footerMsg.isNotEmpty ? '\n$footerMsg' : '');

        var matchedKw =
            keywords.firstWhere((k) => k['id'] == selectedKeywordId);
        String kwName = matchedKw['keyword'] ?? 'يدوي';

        await dbHelper.addToArchive(
          sender: 'إرسال يدوي',
          senderName: phone,
          receivedMessage: fullMessage,
          matchedKeyword: kwName,
          sentNumber: cardCode,
          status: 'sent',
        );

        _showMessage('✅ تم إرسال الكرت إلى $phone بنجاح');
        widget.onSentSuccess();
        Navigator.pop(context);
      } else {
        _showMessage('❌ فشل تعيين الكرت', isError: true);
      }
    } catch (e) {
      _showMessage('⚠️ خطأ في معالجة العملية', isError: true);
    }

    setState(() => isSending = false);
  }

  void _showMessage(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, textAlign: TextAlign.center),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFF4F6F9),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('📤 إرسال يدوي',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🔑 اختر الباقة:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  isLoadingKeywords
                      ? const Center(child: CircularProgressIndicator())
                      : DropdownButtonFormField<int>(
                          value: selectedKeywordId,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30)),
                          ),
                          hint: const Text('-- اختر الباقة --'),
                          items: keywords.map((k) {
                            return DropdownMenuItem<int>(
                              value: k['id'] as int,
                              child: Text(
                                  '${k['keyword']} ${k['description'] != null ? "- " + k['description'] : ""}'),
                            );
                          }).toList(),
                          onChanged: _onKeywordSelected,
                        ),
                ],
              ),
            ),
            if (availableVoucher != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('💳 الكرت المتاح:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        availableVoucher!['number_code'] ?? '---',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('📞 رقم الجوال:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textDirection: TextDirection.ltr,
                      decoration: InputDecoration(
                        hintText: 'أدخل رقم الجوال',
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: isSending ? null : _sendCard,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                      ),
                      child: isSending
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('📤 إرسال الكرت',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ],
            if (noCardsAvailable) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12)),
                child: const Text('⚠️ لا توجد كروت متاحة لهذه الباقة',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}*/
