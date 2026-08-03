import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:sqflite/sqflite.dart';

import 'DatabaseHelper.dart';
import 'KeywordsScreen.dart';
import 'PendingLogsScreen.dart';
import 'SettingsScreen.dart';
import 'vouchers_screen.dart';
import 'allowed_senders_screen.dart';
import 'sales_screen.dart';
import 'backup_screen.dart';
import 'archive_screen.dart';
import 'service/native_service_controller.dart';


const MethodChannel _smsChannel = MethodChannel('com.example.app/sms');
const MethodChannel _nativeControlChannel = MethodChannel('com.example.pr19/native_control');

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({Key? key}) : super(key: key);

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const VouchersTabScreen(),
    const ReportsTabScreen(),
    const SettingsTabScreen(),
    const ContactTabScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = theme.cardColor;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.dashboard_rounded, 'الرئيسية', 0),
              _buildNavItem(Icons.confirmation_number_rounded, 'الكروت', 1),
              _buildNavItem(Icons.donut_small_rounded, 'التقارير', 2),
              _buildNavItem(Icons.tune_rounded, 'الإعدادات', 3),
              _buildNavItem(Icons.headset_mic_rounded, 'الدعم', 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final bool isActive = _currentIndex == index;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final activeColor = isDark ? const Color(0xFF38BDF8) : const Color(0xFF0F172A);
    final inactiveColor = isDark ? Colors.white38 : Colors.black38;

    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: isActive
            ? BoxDecoration(
                color: activeColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isActive ? activeColor : inactiveColor, size: 22),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? activeColor : inactiveColor,
              ),
            )
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  bool isLoading = true;
  bool _serviceEnabled = true;
  bool _notificationEnabled = true;
  
  int statReplies = 0;
  int totalAvailable = 0;
  int totalUsed = 0;

  List<_CategoryStatData> availableCategoriesData = [];
  List<_CategoryStatData> usedCategoriesData = [];

  final List<Color> categoryColors = [
    const Color(0xFF0EA5E9),
    const Color(0xFFF59E0B),
    const Color(0xFF10B981),
    const Color(0xFF8B5CF6),
    const Color(0xFFEC4899),
    const Color(0xFF6366F1),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStats());
  }

  Future<void> _loadStats() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final db = DatabaseHelper.instance;
      final dbInstance = await db.database;

      final keywords = await db.getAllKeywords();
      final numbers = await db.getAllNumbers();

      final repliesCount = Sqflite.firstIntValue(
              await dbInstance.rawQuery('SELECT COUNT(*) FROM reply_log')) ??
          0;

      _processChartData(keywords, numbers);

      if (mounted) {
        setState(() {
          statReplies = repliesCount;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("خطأ أثناء جلب البيانات: $e");
      if (mounted) _loadDummyData();
    }
  }

  void _loadDummyData() {
    setState(() {
      statReplies = 42;
      availableCategoriesData = [
        _CategoryStatData('باقة 100', 50, categoryColors[0]),
        _CategoryStatData('باقة 200', 30, categoryColors[1]),
        _CategoryStatData('باقة 500', 15, categoryColors[2]),
      ];
      usedCategoriesData = [
        _CategoryStatData('باقة 100', 120, categoryColors[0]),
        _CategoryStatData('باقة 200', 85, categoryColors[1]),
      ];

      totalAvailable = availableCategoriesData.fold(0, (s, i) => s + i.count);
      totalUsed = usedCategoriesData.fold(0, (s, i) => s + i.count);
      isLoading = false;
    });
  }

  void _processChartData(List<Map<String, dynamic>> keywords, List<Map<String, dynamic>> numbers) {
    List<_CategoryStatData> availTemp = [];
    List<_CategoryStatData> usedTemp = [];

    int colorIndex = 0;
    int availSum = 0;
    int usedSum = 0;

    for (var kw in keywords) {
      int kwId = kw['id'];
      String kwName = kw['keyword'] ?? 'فئة $kwId';
      Color color = categoryColors[colorIndex % categoryColors.length];

      int availCount = numbers.where((n) => n['keyword_id'] == kwId && n['status'] == 'available').length;
      int usedCount = numbers.where((n) => n['keyword_id'] == kwId && n['status'] == 'used').length;

      if (availCount > 0) availTemp.add(_CategoryStatData(kwName, availCount, color));
      if (usedCount > 0) usedTemp.add(_CategoryStatData(kwName, usedCount, color));

      availSum += availCount;
      usedSum += usedCount;
      colorIndex++;
    }

    if (mounted) {
      setState(() {
        availableCategoriesData = availTemp;
        usedCategoriesData = usedTemp;
        totalAvailable = availSum;
        totalUsed = usedSum;
      });
    }
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgMain = theme.scaffoldBackgroundColor;
    final cardBg = theme.cardColor;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextColor = isDark ? Colors.white60 : Colors.black54;

    return Scaffold(
      backgroundColor: bgMain,
      appBar: AppBar(
        centerTitle: true,
        title: Column(
          children: const [
            Text(
              'CardPay',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            SizedBox(height: 2),
            Text(
              'Auto CardPay - البيع الآلي للكروت',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          onPressed: _loadStats,
          tooltip: 'تحديث البيانات',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.power_settings_new, color: Colors.white),
            onPressed: () => SystemNavigator.pop(),
            tooltip: 'خروج',
          ),
        ],
      ),
      /*appBar: AppBar(
        centerTitle: false,
        title: const Text(
          'نظام البيع الآلي',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadStats,
            tooltip: 'تحديث البيانات',
          ),
          IconButton(
            icon: const Icon(Icons.power_settings_new_rounded),
            onPressed: () => SystemNavigator.pop(),
            tooltip: 'خروج',
          ),
        ],
      ),*/
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 🌟 بطاقة حالة النظام العصرية (طراز محفظة رقمية)
                    Row(
                      children: [
                        // تفعيل / إيقاف الرد الآلي
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '🤖 الرد الآلي',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: textColor,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Transform.scale(
                                  scale: 0.8,
                                  child: Switch(
                                    value: _serviceEnabled,
                                    activeColor: const Color(0xFF10B981),
                                    onChanged: (val) async {
                                      setState(() => _serviceEnabled = val);
                                      await DatabaseHelper.instance.updateSetting(
                                          'service_enabled', val ? 'true' : 'false');
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // تفعيل / إيقاف قراءة الإشعارات
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '🔔 الإشعارات',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: textColor,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Transform.scale(
                                  scale: 0.8,
                                  child: Switch(
                                    value: _notificationEnabled,
                                    activeColor: const Color(0xFF10B981),
                                    onChanged: (val) async {
                                      setState(() => _notificationEnabled = val);
                                      await DatabaseHelper.instance.updateSetting(
                                          'enable_notification', val ? 'true' : 'false');
                                      if (val) {
                                        await NativeServiceController
                                            .requestNotificationListenerPermission();
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    /*Row(
                      children: [
                        Expanded(
                          child: _buildToggleControl(
                            title: '🤖 الرد الآلي',
                            value: _serviceEnabled,
                            isDark: isDark,
                            cardBg: cardBg,
                            textColor: textColor,
                            onChanged: (val) async {
                              setState(() => _serviceEnabled = val);
                              await DatabaseHelper.instance.updateSetting(
                                  'service_enabled', val ? 'true' : 'false');
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildToggleControl(
                            title: '🔔 الإشعارات',
                            value: _notificationEnabled,
                            isDark: isDark,
                            cardBg: cardBg,
                            textColor: textColor,
                            onChanged: (val) async {
                              setState(() => _notificationEnabled = val);
                              await DatabaseHelper.instance.updateSetting(
                                  'enable_notification', val ? 'true' : 'false');
                              if (val) {
                                await NativeServiceController
                                    .requestNotificationListenerPermission();
                              }
                            },
                          ),
                        ),
                      ],
                    ),*/
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _serviceEnabled
                              ? (isDark
                                  ? [
                                      const Color(0xFF991B1B),
                                      const Color(0xFF0F766E),
                                    ]
                                  : [
                                      const Color(0xFFDC2626),
                                      const Color(0xFF0D9488),
                                    ])
                              : (isDark
                                  ? [
                                      const Color(0xFF374151),
                                      const Color(0xFF111827),
                                    ]
                                  : [
                                      const Color(0xFF9CA3AF),
                                      const Color(0xFF6B7280),
                                    ]),
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.bolt_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),

                          const SizedBox(width: 16),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _serviceEnabled
                                            ? 'خادم الرسائل نشط'
                                            : 'خادم الرسائل متوقف',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: _serviceEnabled
                                            ? const Color(0xFF4ADE80)
                                            : Colors.redAccent,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 8),

                                const Text(
                                  'يستقبل التحويلات ويصرف الكروت تلقائياً',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),

                                const SizedBox(height: 8),

                                Text(
                                  'الردود: $statReplies | إجمالي الكروت: ${totalAvailable + totalUsed}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    /*Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. رأس الكارت: حالة الخادم والإحصائيات
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.bolt_rounded,
                                    color: Color(0xFF10B981), size: 24),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          _serviceEnabled ? 'خادم الرسائل نشط' : 'خادم الرسائل متوقف',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: textColor,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: _serviceEnabled
                                                ? const Color(0xFF10B981)
                                                : Colors.redAccent,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'الردود: $statReplies | إجمالي الكروت: ${totalAvailable + totalUsed}',
                                      style: TextStyle(fontSize: 12, color: subTextColor),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Divider(height: 1),
                          ),

                          // 2. التحكم السريع بالخدمات (الرد الآلي والإشعارات)
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(
                              '🤖 الرد الآلي',
                              style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
                            ),
                            subtitle: Text(
                              'تفعيل المعالجة التلقائية للرسائل الواردة',
                              style: TextStyle(fontSize: 11, color: subTextColor),
                            ),
                            value: _serviceEnabled,
                            activeColor: const Color(0xFF10B981),
                            onChanged: (val) async {
                              setState(() => _serviceEnabled = val);
                              await DatabaseHelper.instance.updateSetting('service_enabled', val ? 'true' : 'false');
                            },
                          ),

                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(
                              '🔔 قراءة الإشعارات',
                              style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
                            ),
                            subtitle: Text(
                              'استلام الإشعارات من البنوك والمحافظ',
                              style: TextStyle(fontSize: 11, color: subTextColor),
                            ),
                            value: _notificationEnabled,
                            activeColor: const Color(0xFF10B981),
                            onChanged: (val) async {
                              setState(() => _notificationEnabled = val);
                              await DatabaseHelper.instance.updateSetting('enable_notification', val ? 'true' : 'false');
                              if (val) {
                                await NativeServiceController.requestNotificationListenerPermission();
                              }
                            },
                          ),
                        ],
                      ),
                    ),*/
                    /*Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.bolt_rounded,
                                color: Color(0xFF10B981), size: 28),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text('خادم الرسائل نشط',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: textColor)),
                                    const SizedBox(width: 6),
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF10B981),
                                        shape: BoxShape.circle,
                                      ),
                                    )
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'الردود: $statReplies | إجمالي الكروت: ${totalAvailable + totalUsed}',
                                  style: TextStyle(fontSize: 12, color: subTextColor),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),*/
                    const SizedBox(height: 16),

                    // 📊 الإحصائيات السريعة
                    Row(
                      children: [
                        Expanded(
                          child: _buildQuickStatCard(
                            'متاحة',
                            '$totalAvailable',
                            Icons.inventory_2_outlined,
                            const Color(0xFF0EA5E9),
                            cardBg,
                            textColor,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildQuickStatCard(
                            'مباعة',
                            '$totalUsed',
                            Icons.shopping_bag_outlined,
                            const Color(0xFFF59E0B),
                            cardBg,
                            textColor,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildQuickStatCard(
                            'مبيعات اليوم',
                            '0',
                            Icons.payments_outlined,
                            const Color(0xFF10B981),
                            cardBg,
                            textColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // 📈 الرسوم البيانية
                    _buildPieChartSection('القسائم المتاحة', availableCategoriesData,
                        totalAvailable, cardBg, textColor),
                    const SizedBox(height: 16),
                    _buildPieChartSection('القسائم المستخدمة', usedCategoriesData,
                        totalUsed, cardBg, textColor),
                    const SizedBox(height: 24),

                    Text(
                      'الخيارات والخدمات',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor),
                    ),
                    const SizedBox(height: 14),

                    // 🔲 شبكة خيارات الخدمة (Grid UI)
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.35,
                      children: [
                        _buildMenuItem('الباقات', Icons.vpn_key_rounded,
                            const Color(0xFF8B5CF6), cardBg, textColor, () async {
                          await Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const KeywordsScreen()));
                          _loadStats();
                        }),
                        _buildMenuItem('تغذية الكروت', Icons.add_card_rounded,
                            const Color(0xFFF59E0B), cardBg, textColor, () async {
                          await Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const VouchersScreen()));
                          _loadStats();
                        }),
                        _buildMenuItem('الأرشيف', Icons.mark_email_read_rounded,
                            const Color(0xFF06B6D4), cardBg, textColor, () async {
                          await Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const ArchiveScreen()));
                          _loadStats();
                        }),
                        _buildMenuItem('المبيعات', Icons.insights_rounded,
                            const Color(0xFF6366F1), cardBg, textColor, () async {
                          await Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const SalesScreen()));
                          _loadStats();
                        }),
                        _buildMenuItem('العمليات', Icons.pending_actions_rounded,
                            const Color(0xFFEC4899), cardBg, textColor, () async {
                          await Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const PendingLogsScreen()));
                          _loadStats();
                        }),
                        _buildMenuItem('إرسال يدوي', Icons.send_rounded,
                            const Color(0xFFEF4444), cardBg, textColor, _openManualSendDialog),
                        _buildMenuItem('الحسابات', Icons.account_balance_rounded,
                            const Color(0xFF10B981), cardBg, textColor, () async {
                          await Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const AllowedSendersScreen()));
                          _loadStats();
                        }),
                        _buildMenuItem('النسخ', Icons.cloud_sync_rounded,
                            const Color(0xFF3B82F6), cardBg, textColor, () async {
                          await Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const BackupScreen()));
                          _loadStats();
                        }),
                        _buildMenuItem('الإعدادات', Icons.settings_rounded,
                            const Color(0xFF64748B), cardBg, textColor, () async {
                          await Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const SettingsScreen()));
                          _loadStats();
                        }),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildToggleControl({
    required String title,
    required bool value,
    required bool isDark,
    required Color cardBg,
    required Color textColor,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: textColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: value,
              activeColor: const Color(0xFF10B981),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatCard(String title, String value, IconData icon, Color color, Color bg, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(fontSize: 11, color: textColor.withOpacity(0.6)),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChartSection(String title, List<_CategoryStatData> data,
      int total, Color cardBg, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
              Text('المجموع: $total', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor.withOpacity(0.6))),
            ],
          ),
          const Divider(height: 20),
          data.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: Text('لا توجد بيانات متاحة', style: TextStyle(color: Colors.grey, fontSize: 12))),
                )
              : Row(
                  children: [
                    SizedBox(
                      height: 90,
                      width: 90,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 20,
                          sections: data.map((item) {
                            return PieChartSectionData(
                              color: item.color,
                              value: item.count.toDouble(),
                              title: '',
                              radius: 20,
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        children: data.map((item) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                            child: Row(
                              children: [
                                Container(width: 8, height: 8, decoration: BoxDecoration(color: item.color, shape: BoxShape.circle)),
                                const SizedBox(width: 6),
                                Expanded(child: Text(item.categoryName, style: TextStyle(fontSize: 11, color: textColor))),
                                Text('${item.count}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor)),
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

  Widget _buildMenuItem(String title, IconData icon, Color color, Color cardBg, Color textColor, VoidCallback onTap) {
    return Material(
      color: cardBg,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black.withOpacity(0.04)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadKeywords() async {
    try {
      final list = await DatabaseHelper.instance.getAllKeywords();
      if (mounted) {
        setState(() {
          keywords = list.where((k) => k['is_active'] == 1).toList();
          isLoadingKeywords = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoadingKeywords = false);
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

      if (mounted) {
        setState(() {
          if (results.isNotEmpty) {
            availableVoucher = results.first;
          } else {
            noCardsAvailable = true;
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => noCardsAvailable = true);
    }
  }

  Future<bool> _sendSmsNativeDirect(String phone, String message) async {
    try {
      final bool? result = await _smsChannel.invokeMethod('sendSms', {
        'phone': phone,
        'message': message,
      });
      return result ?? true;
    } catch (e) {
      return false;
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

    // فور نجاح السحب أو عند الفشل لعدم توفر كروت:
    var matchedKw = keywords.firstWhere(
      (k) => k['id'] == selectedKeywordId,
      orElse: () => <String, dynamic>{},
    );
    String kwName = matchedKw['keyword'] ?? 'يدوي';
    await triggerManagerAlertNative(selectedKeywordId!, kwName);
    
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

        bool sentStatus = await _sendSmsNativeDirect(phone, fullMessage);

        await dbHelper.addToArchive(
          sender: 'إرسال يدوي',
          senderName: phone,
          receivedMessage: fullMessage,
          matchedKeyword: kwName,
          sentNumber: cardCode,
          status: sentStatus ? 'sent' : 'failed',
        );

        if (sentStatus) {
          _showMessage('✅ تم إرسال الكرت إلى $phone بنجاح');
          widget.onSentSuccess();
          if (mounted) Navigator.pop(context);
        } else {
          _showMessage('⚠️ تم استهلاك الكرت ولكن فشل إرسال الـ SMS',
              isError: true);
        }
      } else {
        _showMessage('❌ فشل تعيين الكرت', isError: true);
      }
    } catch (e) {
      _showMessage('⚠️ خطأ في معالجة العملية: $e', isError: true);
    }

    if (mounted) setState(() => isSending = false);
  }

  /// دالة تنبيه الـ Native لمتابعة مخزون الكروت
  Future<void> triggerManagerAlertNative(int keywordId, String keywordText) async {
    try {
      // 🎯 استخدام اسم الـ Method المطابق لـ Kotlin: 'checkAndSendManagerAlert'
      await _nativeControlChannel.invokeMethod('checkAndSendManagerAlert', {
        'keywordId': keywordId,
        'keywordText': keywordText,
      });
      debugPrint("✅ تم طلب فحص تنبيه المخزون بنجاح");
    } catch (e) {
      debugPrint("⚠️ تعذر استدعاء دالة تنبيه المخزون في Kotlin: $e");
    }
  }
  /*Future<void> triggerManagerAlertNative(int keywordId, String keywordText) async {
    try {
      await _nativeControlChannel.invokeMethod('native_control', {
        'keywordId': keywordId,
        'keywordText': keywordText,
      });
    } catch (e) {
      debugPrint("⚠️ تعذر استدعاء دالة تنبيه المخزون في Kotlin: $e");
    }
  }*/

  void _showMessage(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, textAlign: TextAlign.center),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgSheet = theme.cardColor;

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: bgSheet,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('إرسال كرت يدوي',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            isLoadingKeywords
                ? const Center(child: CircularProgressIndicator())
                : DropdownButtonFormField<int>(
                    value: selectedKeywordId,
                    decoration: InputDecoration(
                      labelText: 'اختر الباقة',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    items: keywords.map((k) {
                      return DropdownMenuItem<int>(
                        value: k['id'] as int,
                        child: Text('${k['keyword']}'),
                      );
                    }).toList(),
                    onChanged: _onKeywordSelected,
                  ),
            if (noCardsAvailable) ...[
              const SizedBox(height: 12),
              const Text(
                '⚠️ لا توجد كروت متاحة لهذه الباقة.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ],
            if (availableVoucher != null) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: 'رقم المستلم',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: isSending ? null : _sendCard,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  isSending ? 'جاري الإرسال...' : 'تأكيد وإرسال',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class VouchersTabScreen extends StatelessWidget {
  const VouchersTabScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة الكروت')),
      body: const Center(child: Text('شاشة إدارة وتغذية الكروت')),
    );
  }
}

class ReportsTabScreen extends StatelessWidget {
  const ReportsTabScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('التقارير والمبيعات')),
      body: const Center(child: Text('شاشة التقارير والمبيعات')),
    );
  }
}

class SettingsTabScreen extends StatelessWidget {
  const SettingsTabScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات العامة')),
      body: const Center(child: Text('شاشة الإعدادات')),
    );
  }
}

class ContactTabScreen extends StatelessWidget {
  const ContactTabScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الدعم والتواصل')),
      body: const Center(child: Text('شاشة التواصل والدعم الفني')),
    );
  }
}


/*class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({Key? key}) : super(key: key);

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const VouchersTabScreen(),
    const ReportsTabScreen(),
    const SettingsTabScreen(),
    const ContactTabScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardBg = theme.cardColor;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
            )
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.home, 'الرئيسية', 0),
            _buildNavItem(Icons.style, 'الكروت', 1),
            _buildNavItem(Icons.bar_chart, 'التقارير', 2),
            _buildNavItem(Icons.settings, 'الإعدادات', 3),
            _buildNavItem(Icons.support_agent, 'تواصل', 4),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final bool isActive = _currentIndex == index;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final activeColor = isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0D9488);
    final inactiveColor = isDark ? Colors.white54 : Colors.black45;

    return InkWell(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: isActive
                ? BoxDecoration(
                    color: activeColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  )
                : null,
            child: Icon(icon, color: isActive ? activeColor : inactiveColor, size: 22),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? activeColor : inactiveColor,
            ),
          )
        ],
      ),
    );
  }
}

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

  List<_CategoryStatData> availableCategoriesData = [];
  List<_CategoryStatData> usedCategoriesData = [];

  final List<Color> categoryColors = [
    const Color(0xFF2EC4B6),
    const Color(0xFFFF9F1C),
    const Color(0xFFE71D36),
    const Color(0xFF3A86FF),
    const Color(0xFF8338EC),
    const Color(0xFF00F5D4),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStats();
    });
  }

  Future<void> _loadStats() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final db = DatabaseHelper.instance;
      final dbInstance = await db.database;

      final keywords = await db.getAllKeywords();
      final numbers = await db.getAllNumbers();

      final repliesCount = Sqflite.firstIntValue(
              await dbInstance.rawQuery('SELECT COUNT(*) FROM reply_log')) ??
          0;

      _processChartData(keywords, numbers);

      if (mounted) {
        setState(() {
          statReplies = repliesCount;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("خطأ أثناء جلب البيانات: $e");
      if (mounted) {
        _loadDummyData();
      }
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

      if (availCount > 0) {
        availTemp.add(_CategoryStatData(kwName, availCount, color));
      }
      if (usedCount > 0) {
        usedTemp.add(_CategoryStatData(kwName, usedCount, color));
      }

      availSum += availCount;
      usedSum += usedCount;
      colorIndex++;
    }

    if (mounted) {
      setState(() {
        availableCategoriesData = availTemp;
        usedCategoriesData = usedTemp;
        totalAvailable = availSum;
        totalUsed = usedSum;
      });
    }
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgMain = theme.scaffoldBackgroundColor;
    final cardBg = theme.cardColor;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextColor = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      backgroundColor: bgMain,
      appBar: AppBar(
        centerTitle: true,
        title: Column(
          children: const [
            Text(
              'CardPay',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            SizedBox(height: 2),
            Text(
              'Auto CardPay - البيع الآلي للكروت',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          onPressed: _loadStats,
          tooltip: 'تحديث البيانات',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.power_settings_new, color: Colors.white),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [const Color(0xFF991B1B), const Color(0xFF0F766E)]
                              : [const Color(0xFFDC2626), const Color(0xFF0D9488)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'النظام يعمل',
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                              ),
                              Container(
                                width: 12,
                                height: 12,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF4ADE80),
                                  shape: BoxShape.circle,
                                ),
                              )
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'يستقبل التحويلات ويصرف الكروت تلقائياً',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'إجمالي الكروت: ${totalAvailable + totalUsed}  |  الردود: $statReplies',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: _buildQuickStatCard(
                            'مبيعات اليوم',
                            '0',
                            isDark ? const Color(0xFF0891B2) : const Color(0xFF0284C7),
                            Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildQuickStatCard(
                            'إجمالي اليوم',
                            '0',
                            isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            textColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildQuickStatCard(
                            'كروت متاحة',
                            '$totalAvailable',
                            isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2),
                            isDark ? Colors.white : const Color(0xFF991B1B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _buildPieChartSection('القسائم المتاحة حسب الفئة', '📥',
                        availableCategoriesData, totalAvailable, isDark ? Colors.tealAccent : Colors.teal, cardBg, textColor),
                    const SizedBox(height: 16),
                    _buildPieChartSection('القسائم المستخدمة حسب الفئة', '📤',
                        usedCategoriesData, totalUsed, isDark ? Colors.orangeAccent : Colors.deepOrange, cardBg, textColor),
                    const SizedBox(height: 20),

                    Text(
                      'أقسام النظام',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor),
                    ),
                    const SizedBox(height: 12),

                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.35,
                      children: [
                        _buildMenuItem('إدارة الباقات', 'المخزون والاستيراد', '🔑',
                            const Color(0xFF8B5CF6), cardBg, textColor, subTextColor, () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const KeywordsScreen()),
                          );
                          _loadStats();
                        }),
                        _buildMenuItem('تغذية الكروت', 'إضافة وتغذية الكروت', '📦',
                            const Color(0xFFF59E0B), cardBg, textColor, subTextColor, () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const VouchersScreen()),
                          );
                          _loadStats();
                        }),
                        _buildMenuItem('أرشيف الرسائل', 'تتبع وقراءة الرسائل', '📋',
                            const Color(0xFF06B6D4), cardBg, textColor, subTextColor, () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const ArchiveScreen()),
                          );
                          _loadStats();
                        }),
                        _buildMenuItem('تقرير المبيعات', 'المبيعات والعمليات', '📊',
                            const Color(0xFF6366F1), cardBg, textColor, subTextColor, () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const SalesScreen()),
                          );
                          _loadStats();
                        }),
                        _buildMenuItem('العمليات المعلقة', 'متابعة الديون والعمليات', '🎁',
                            const Color(0xFFEC4899), cardBg, textColor, subTextColor, () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    const PendingLogsScreen()),
                          );
                          _loadStats();
                        }),
                        _buildMenuItem('الإعدادات العامة', 'الترخيص والنسخ والصحة', '⚙️',
                            const Color(0xFF64748B), cardBg, textColor, subTextColor, () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const SettingsScreen()),
                          );
                          _loadStats();
                        }),
                        _buildMenuItem('حسابات البنوك', 'ربط معرف الحسابات', '👤',
                            const Color(0xFFF97316), cardBg, textColor, subTextColor, () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    const AllowedSendersScreen()),
                          );
                          _loadStats();
                        }),
                        _buildMenuItem(
                          'إرسال يدوي',
                          'سحب وإرسال كرت لعميل',
                          '📤',
                          const Color(0xFFEF4444),
                          cardBg,
                          textColor,
                          subTextColor,
                          _openManualSendDialog,
                        ),
                        _buildMenuItem('نسخ احتياطي', 'حفظ استعادة البيانات', '💾',
                            const Color(0xFF10B981), cardBg, textColor, subTextColor, () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const BackupScreen()),
                          );
                          _loadStats();
                        }),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Text(
                        '© 2026 كرت شبكة - جميع الحقوق محفوظة',
                        style: TextStyle(color: subTextColor, fontSize: 11),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildQuickStatCard(String title, String value, Color bg, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 11, color: textColor.withOpacity(0.8)),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChartSection(String title, String icon,
      List<_CategoryStatData> data, int total, Color themeColor, Color cardBg, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
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
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: textColor),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: themeColor.withOpacity(0.15),
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
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: textColor),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '${item.count}',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: textColor.withOpacity(0.7)),
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

  Widget _buildMenuItem(
      String title,
      String subtitle,
      String icon,
      Color iconBg,
      Color cardBg,
      Color textColor,
      Color subTextColor,
      VoidCallback onTap) {
    return Material(
      color: cardBg,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: Colors.black.withOpacity(0.04), width: 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: textColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 10, color: subTextColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(icon, style: const TextStyle(fontSize: 20)),
                ),
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

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadKeywords() async {
    try {
      final list = await DatabaseHelper.instance.getAllKeywords();
      if (mounted) {
        setState(() {
          keywords = list.where((k) => k['is_active'] == 1).toList();
          isLoadingKeywords = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoadingKeywords = false);
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

      if (mounted) {
        setState(() {
          if (results.isNotEmpty) {
            availableVoucher = results.first;
          } else {
            noCardsAvailable = true;
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => noCardsAvailable = true);
    }
  }

  Future<bool> _sendSmsNativeDirect(String phone, String message) async {
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
      debugPrint("خطأ غير متوقع: $e");
      return false;
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

        bool sentStatus = await _sendSmsNativeDirect(phone, fullMessage);

        await dbHelper.addToArchive(
          sender: 'إرسال يدوي',
          senderName: phone,
          receivedMessage: fullMessage,
          matchedKeyword: kwName,
          sentNumber: cardCode,
          status: sentStatus ? 'sent' : 'failed',
        );

        if (sentStatus) {
          _showMessage('✅ تم إرسال الكرت إلى $phone بنجاح');
          widget.onSentSuccess();
          if (mounted) Navigator.pop(context);
        } else {
          _showMessage('⚠️ تم استهلاك الكرت ولكن فشل إرسال الـ SMS',
              isError: true);
        }
      } else {
        _showMessage('❌ فشل تعيين الكرت', isError: true);
      }
    } catch (e) {
      _showMessage('⚠️ خطأ في معالجة العملية: $e', isError: true);
    }

    if (mounted) setState(() => isSending = false);
  }

  void _showMessage(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, textAlign: TextAlign.center),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgSheet = theme.cardColor;

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: bgSheet,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12)),
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
            if (noCardsAvailable) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: const Text(
                  '⚠️ لا توجد كروت متاحة لهذه الباقة حالياً.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ),
            ],
            if (availableVoucher != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
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
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade600),
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
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: isSending ? null : _sendCard,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        icon: isSending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.send, color: Colors.white),
                        label: Text(
                          isSending ? 'جاري الإرسال...' : 'إرسال الكرت الآن',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class VouchersTabScreen extends StatelessWidget {
  const VouchersTabScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الكروت'),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.style, size: 64, color: Color(0xFF0D9488)),
            SizedBox(height: 12),
            Text(
              'شاشة إدارة وتغذية الكروت',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 6),
            Text('يمكنك تصميم أو ربط كود الكروت هنا', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class ReportsTabScreen extends StatelessWidget {
  const ReportsTabScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('التقارير والمبيعات'),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 64, color: Color(0xFF6366F1)),
            SizedBox(height: 12),
            Text(
              'شاشة التقارير والمبيعات',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 6),
            Text('يمكنك استعراض الرسوم البيانية والعمليات هنا', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class SettingsTabScreen extends StatelessWidget {
  const SettingsTabScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات العامة'),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.settings, size: 64, color: Color(0xFF64748B)),
            SizedBox(height: 12),
            Text(
              'شاشة الإعدادات والضبط',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 6),
            Text('يمكنك ربط إعدادات التطبيق أو الترخيص هنا', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class ContactTabScreen extends StatelessWidget {
  const ContactTabScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الدعم والتواصل'),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.support_agent, size: 64, color: Color(0xFFF97316)),
            SizedBox(height: 12),
            Text(
              'شاشة التواصل والدعم الفني',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 6),
            Text('يمكنك إدراج أرقام التواصل أو الدعم هنا', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}*/
/*import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:fl_chart/fl_chart.dart';
import 'package:sqflite/sqflite.dart';

import 'DatabaseHelper.dart';
import 'KeywordsScreen.dart';
import 'PendingLogsScreen.dart';
import 'SettingsScreen.dart';
import 'vouchers_screen.dart';
import 'allowed_senders_screen.dart';
import 'sales_screen.dart';
import 'backup_screen.dart';
import 'archive_screen.dart';

// تعريف القناة للاتصال بكود Kotlin Native مباشرة
const MethodChannel _smsChannel = MethodChannel('com.example.app/sms');

// =========================================================
// الشاشة الرئيسية للتنقل التي تحوي الـ BottomNavigationBar
// =========================================================
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({Key? key}) : super(key: key);

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  // قائمة الواجهات الخمس للـ BottomNavBar
  final List<Widget> _screens = [
    const HomeScreen(),        // 0: الرئيسية
    const VouchersTabScreen(),  // 1: الكروت (وهمية)
    const ReportsTabScreen(),   // 2: التقارير (وهمية)
    const SettingsTabScreen(),  // 3: الإعدادات (وهمية)
    const ContactTabScreen(),   // 4: تواصل (وهمية)
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
            )
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.home, 'الرئيسية', 0, isDark),
            _buildNavItem(Icons.style, 'الكروت', 1, isDark),
            _buildNavItem(Icons.bar_chart, 'التقارير', 2, isDark),
            _buildNavItem(Icons.settings, 'الإعدادات', 3, isDark),
            _buildNavItem(Icons.support_agent, 'تواصل', 4, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, bool isDark) {
    final bool isActive = _currentIndex == index;
    final activeColor = const Color(0xFF0D9488);
    final inactiveColor = isDark ? Colors.white54 : Colors.black45;

    return InkWell(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: isActive
                ? BoxDecoration(
                    color: activeColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  )
                : null,
            child: Icon(icon, color: isActive ? activeColor : inactiveColor, size: 22),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? activeColor : inactiveColor,
            ),
          )
        ],
      ),
    );
  }
}

// =========================================================
// شاشة الصفحة الرئيسية (التبويب الأول)
// =========================================================
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

  List<_CategoryStatData> availableCategoriesData = [];
  List<_CategoryStatData> usedCategoriesData = [];

  final List<Color> categoryColors = [
    const Color(0xFF2EC4B6),
    const Color(0xFFFF9F1C),
    const Color(0xFFE71D36),
    const Color(0xFF3A86FF),
    const Color(0xFF8338EC),
    const Color(0xFF00F5D4),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStats();
    });
  }

  Future<void> _loadStats() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final db = DatabaseHelper.instance;
      final dbInstance = await db.database;

      final keywords = await db.getAllKeywords();
      final numbers = await db.getAllNumbers();

      final repliesCount = Sqflite.firstIntValue(
              await dbInstance.rawQuery('SELECT COUNT(*) FROM reply_log')) ??
          0;

      _processChartData(keywords, numbers);

      if (mounted) {
        setState(() {
          statReplies = repliesCount;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("خطأ أثناء جلب البيانات: $e");
      if (mounted) {
        _loadDummyData();
      }
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

      if (availCount > 0) {
        availTemp.add(_CategoryStatData(kwName, availCount, color));
      }
      if (usedCount > 0) {
        usedTemp.add(_CategoryStatData(kwName, usedCount, color));
      }

      availSum += availCount;
      usedSum += usedCount;
      colorIndex++;
    }

    if (mounted) {
      setState(() {
        availableCategoriesData = availTemp;
        usedCategoriesData = usedTemp;
        totalAvailable = availSum;
        totalUsed = usedSum;
      });
    }
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgMain = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextColor = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      backgroundColor: bgMain,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0284C7),
        elevation: 0,
        centerTitle: true,
        title: Column(
          children: const [
            Text(
              'MikroTik Yemen',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            SizedBox(height: 2),
            Text(
              'AUTOCARD - البيع الآلي للكروت',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          onPressed: _loadStats,
          tooltip: 'تحديث البيانات',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.power_settings_new, color: Colors.white),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // كرت حالة النظام المزين بالمتدرج
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFDC2626), Color(0xFF0D9488)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'النظام يعمل',
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                              ),
                              Container(
                                width: 12,
                                height: 12,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF4ADE80),
                                  shape: BoxShape.circle,
                                ),
                              )
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'يستقبل التحويلات ويصرف الكروت تلقائياً',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                            //style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'إجمالي الكروت: ${totalAvailable + totalUsed}  |  الردود: $statReplies',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // شبكة العدادات الخمس السريعة
                    Row(
                      children: [
                        Expanded(
                          child: _buildQuickStatCard(
                            'مبيعات اليوم',
                            '0',
                            isDark ? const Color(0xFF0891B2) : const Color(0xFF0284C7),
                            Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildQuickStatCard(
                            'إجمالي اليوم',
                            '0',
                            isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            textColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildQuickStatCard(
                            'كروت متاحة',
                            '$totalAvailable',
                            isDark ? const Color(0xFF991B1B) : const Color(0xFFFEE2E2),
                            isDark ? Colors.white : const Color(0xFF991B1B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // المخططات البيانية للفئات
                    _buildPieChartSection('القسائم المتاحة حسب الفئة', '📥',
                        availableCategoriesData, totalAvailable, Colors.teal, cardBg, textColor),
                    const SizedBox(height: 16),
                    _buildPieChartSection('القسائم المستخدمة حسب الفئة', '📤',
                        usedCategoriesData, totalUsed, Colors.deepOrange, cardBg, textColor),
                    const SizedBox(height: 20),

                    Text(
                      'أقسام النظام',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor),
                    ),
                    const SizedBox(height: 12),

                    // شبكة أزرار القائمة الرئيسية
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.35,
                      children: [
                        _buildMenuItem('إدارة الباقات', 'المخزون والاستيراد', '🔑',
                            const Color(0xFF8B5CF6), cardBg, textColor, subTextColor, () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const KeywordsScreen()),
                          );
                          _loadStats();
                        }),
                        _buildMenuItem('تغذية الكروت', 'إضافة وتغذية الكروت', '📦',
                            const Color(0xFFF59E0B), cardBg, textColor, subTextColor, () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const VouchersScreen()),
                          );
                          _loadStats();
                        }),
                        _buildMenuItem('أرشيف الرسائل', 'تتبع وقراءة الرسائل', '📋',
                            const Color(0xFF06B6D4), cardBg, textColor, subTextColor, () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const ArchiveScreen()),
                          );
                          _loadStats();
                        }),
                        _buildMenuItem('تقرير المبيعات', 'المبيعات والعمليات', '📊',
                            const Color(0xFF6366F1), cardBg, textColor, subTextColor, () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const SalesScreen()),
                          );
                          _loadStats();
                        }),
                        _buildMenuItem('العمليات المعلقة', 'متابعة الديون والعمليات', '🎁',
                            const Color(0xFFEC4899), cardBg, textColor, subTextColor, () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    const PendingLogsScreen()),
                          );
                          _loadStats();
                        }),
                        _buildMenuItem('الإعدادات العامة', 'الترخيص والنسخ والصحة', '⚙️',
                            const Color(0xFF64748B), cardBg, textColor, subTextColor, () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const SettingsScreen()),
                          );
                          _loadStats();
                        }),
                        _buildMenuItem('حسابات البنوك', 'ربط معرف الحسابات', '👤',
                            const Color(0xFFF97316), cardBg, textColor, subTextColor, () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    const AllowedSendersScreen()),
                          );
                          _loadStats();
                        }),
                        _buildMenuItem(
                          'إرسال يدوي',
                          'سحب وإرسال كرت لعميل',
                          '📤',
                          const Color(0xFFEF4444),
                          cardBg,
                          textColor,
                          subTextColor,
                          _openManualSendDialog,
                        ),
                        _buildMenuItem('نسخ احتياطي', 'حفظ استعادة البيانات', '💾',
                            const Color(0xFF10B981), cardBg, textColor, subTextColor, () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const BackupScreen()),
                          );
                          _loadStats();
                        }),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Text(
                        '© 2026 كرت شبكة - جميع الحقوق محفوظة',
                        style: TextStyle(color: subTextColor, fontSize: 11),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildQuickStatCard(String title, String value, Color bg, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 11, color: textColor.withOpacity(0.8)),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChartSection(String title, String icon,
      List<_CategoryStatData> data, int total, Color themeColor, Color cardBg, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
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
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: textColor),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: themeColor.withOpacity(0.15),
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
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: textColor),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '${item.count}',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: textColor.withOpacity(0.7)),
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

  Widget _buildMenuItem(
      String title,
      String subtitle,
      String icon,
      Color iconBg,
      Color cardBg,
      Color textColor,
      Color subTextColor,
      VoidCallback onTap) {
    return Material(
      color: cardBg,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: Colors.black.withOpacity(0.04), width: 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: textColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 10, color: subTextColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(icon, style: const TextStyle(fontSize: 20)),
                ),
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

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadKeywords() async {
    try {
      final list = await DatabaseHelper.instance.getAllKeywords();
      if (mounted) {
        setState(() {
          keywords = list.where((k) => k['is_active'] == 1).toList();
          isLoadingKeywords = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoadingKeywords = false);
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

      if (mounted) {
        setState(() {
          if (results.isNotEmpty) {
            availableVoucher = results.first;
          } else {
            noCardsAvailable = true;
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => noCardsAvailable = true);
    }
  }

  Future<bool> _sendSmsNativeDirect(String phone, String message) async {
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
      debugPrint("خطأ غير متوقع: $e");
      return false;
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

        bool sentStatus = await _sendSmsNativeDirect(phone, fullMessage);

        await dbHelper.addToArchive(
          sender: 'إرسال يدوي',
          senderName: phone,
          receivedMessage: fullMessage,
          matchedKeyword: kwName,
          sentNumber: cardCode,
          status: sentStatus ? 'sent' : 'failed',
        );

        if (sentStatus) {
          _showMessage('✅ تم إرسال الكرت إلى $phone بنجاح');
          widget.onSentSuccess();
          if (mounted) Navigator.pop(context);
        } else {
          _showMessage('⚠️ تم استهلاك الكرت ولكن فشل إرسال الـ SMS',
              isError: true);
        }
      } else {
        _showMessage('❌ فشل تعيين الكرت', isError: true);
      }
    } catch (e) {
      _showMessage('⚠️ خطأ في معالجة العملية: $e', isError: true);
    }

    if (mounted) setState(() => isSending = false);
  }

  void _showMessage(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, textAlign: TextAlign.center),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgSheet = isDark ? const Color(0xFF1E293B) : const Color(0xFFF4F6F9);

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: bgSheet,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                  color: isDark ? const Color(0xFF0F172A) : Colors.white, borderRadius: BorderRadius.circular(12)),
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
            if (noCardsAvailable) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: const Text(
                  '⚠️ لا توجد كروت متاحة لهذه الباقة حالياً.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ),
            ],
            if (availableVoucher != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : Colors.white,
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
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8F9FA),
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
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: isSending ? null : _sendCard,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        icon: isSending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.send, color: Colors.white),
                        label: Text(
                          isSending ? 'جاري الإرسال...' : 'إرسال الكرت الآن',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =========================================================
// الواجهات الوهمية (Dummy Screens) للتبويبات الأربعة
// يمكنك تعديل كل شاشة منها أو استبدالها بشاشتك الفعلية مستقبلاً
// =========================================================

class VouchersTabScreen extends StatelessWidget {
  const VouchersTabScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الكروت'),
        backgroundColor: const Color(0xFF0284C7),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.style, size: 64, color: Color(0xFF0D9488)),
            SizedBox(height: 12),
            Text(
              'شاشة إدارة وتغذية الكروت',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 6),
            Text('يمكنك تصميم أو ربط كود الكروت هنا', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class ReportsTabScreen extends StatelessWidget {
  const ReportsTabScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('التقارير والمبيعات'),
        backgroundColor: const Color(0xFF0284C7),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 64, color: Color(0xFF6366F1)),
            SizedBox(height: 12),
            Text(
              'شاشة التقارير والمبيعات',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 6),
            Text('يمكنك استعراض الرسوم البيانية والعمليات هنا', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class SettingsTabScreen extends StatelessWidget {
  const SettingsTabScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات العامة'),
        backgroundColor: const Color(0xFF0284C7),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.settings, size: 64, color: Color(0xFF64748B)),
            SizedBox(height: 12),
            Text(
              'شاشة الإعدادات والضبط',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 6),
            Text('يمكنك ربط إعدادات التطبيق أو الترخيص هنا', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class ContactTabScreen extends StatelessWidget {
  const ContactTabScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الدعم والتواصيل'),
        backgroundColor: const Color(0xFF0284C7),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.support_agent, size: 64, color: Color(0xFFF97316)),
            SizedBox(height: 12),
            Text(
              'شاشة التواصل والدعم الفني',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 6),
            Text('يمكنك إدراج أرقام التواصل أو الدعم هنا', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}*/


/*import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // يتضمن MethodChannel
import 'package:fl_chart/fl_chart.dart';
import 'package:sqflite/sqflite.dart';

import 'DatabaseHelper.dart';
import 'KeywordsScreen.dart';
import 'PendingLogsScreen.dart';
import 'SettingsScreen.dart';
import 'vouchers_screen.dart';
import 'allowed_senders_screen.dart';
import 'sales_screen.dart';
import 'backup_screen.dart';
import 'archive_screen.dart';

// تعريف القناة للاتصال بكود Kotlin Native مباشرة (تأكد من مطابقة الاسم مع كود Kotlin لديك)
const MethodChannel _smsChannel = MethodChannel('com.example.app/sms');

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

  List<_CategoryStatData> availableCategoriesData = [];
  List<_CategoryStatData> usedCategoriesData = [];

  final List<Color> categoryColors = [
    const Color(0xFF2EC4B6),
    const Color(0xFFFF9F1C),
    const Color(0xFFE71D36),
    const Color(0xFF3A86FF),
    const Color(0xFF8338EC),
    const Color(0xFF00F5D4),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStats();
    });
  }

  Future<void> _loadStats() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final db = DatabaseHelper.instance;
      final dbInstance = await db.database;

      final keywords = await db.getAllKeywords();
      final numbers = await db.getAllNumbers();

      final repliesCount = Sqflite.firstIntValue(
              await dbInstance.rawQuery('SELECT COUNT(*) FROM reply_log')) ??
          0;

      _processChartData(keywords, numbers);

      if (mounted) {
        setState(() {
          statReplies = repliesCount;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("خطأ أثناء جلب البيانات: $e");
      if (mounted) {
        _loadDummyData();
      }
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

      if (availCount > 0) {
        availTemp.add(_CategoryStatData(kwName, availCount, color));
      }
      if (usedCount > 0) {
        usedTemp.add(_CategoryStatData(kwName, usedCount, color));
      }

      availSum += availCount;
      usedSum += usedCount;
      colorIndex++;
    }

    if (mounted) {
      setState(() {
        availableCategoriesData = availTemp;
        usedCategoriesData = usedTemp;
        totalAvailable = availSum;
        totalUsed = usedSum;
      });
    }
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
                    _buildPieChartSection('القسائم المتاحة حسب الفئة', '📥',
                        availableCategoriesData, totalAvailable, Colors.teal),
                    const SizedBox(height: 16),
                    _buildPieChartSection('القسائم المستخدمة حسب الفئة', '📤',
                        usedCategoriesData, totalUsed, Colors.deepOrange),
                    const SizedBox(height: 20),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.25,
                      children: [
                        _buildMenuItem('إدارة الباقات', '🔑', () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const KeywordsScreen()),
                          );
                          _loadStats();
                        }),
                        _buildMenuItem('تغذية الكروت', '📦', () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const VouchersScreen()),
                          );
                          _loadStats();
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
// نافذة الإرسال اليدوي BottomSheet (تستخدم MethodChannel مباشرة)
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

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadKeywords() async {
    try {
      final list = await DatabaseHelper.instance.getAllKeywords();
      if (mounted) {
        setState(() {
          keywords = list.where((k) => k['is_active'] == 1).toList();
          isLoadingKeywords = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoadingKeywords = false);
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

      if (mounted) {
        setState(() {
          if (results.isNotEmpty) {
            availableVoucher = results.first;
          } else {
            noCardsAvailable = true;
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => noCardsAvailable = true);
    }
  }

  // دالة الإرسال النيتيف المباشرة بدون أي ملف خارجي
  Future<bool> _sendSmsNativeDirect(String phone, String message) async {
    try {
      final bool? result = await _smsChannel.invokeMethod('sendSms', {
        'phone': phone,
        'message': message,
      });
      return result ?? true; // تفترض النجاح أو ترجع القيمة من Kotlin
    } on PlatformException catch (e) {
      debugPrint("فشل إرسال SMS عبر القناة: ${e.message}");
      return false;
    } catch (e) {
      debugPrint("خطأ غير متوقع: $e");
      return false;
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

        // 1. الإرسال عبر الـ MethodChannel المباشر
        bool sentStatus = await _sendSmsNativeDirect(phone, fullMessage);

        // 2. التوثيق في الأرشيف
        await dbHelper.addToArchive(
          sender: 'إرسال يدوي',
          senderName: phone,
          receivedMessage: fullMessage,
          matchedKeyword: kwName,
          sentNumber: cardCode,
          status: sentStatus ? 'sent' : 'failed',
        );

        if (sentStatus) {
          _showMessage('✅ تم إرسال الكرت إلى $phone بنجاح');
          widget.onSentSuccess();
          if (mounted) Navigator.pop(context);
        } else {
          _showMessage('⚠️ تم استهلاك الكرت ولكن فشل إرسال الـ SMS',
              isError: true);
        }
      } else {
        _showMessage('❌ فشل تعيين الكرت', isError: true);
      }
    } catch (e) {
      _showMessage('⚠️ خطأ في معالجة العملية: $e', isError: true);
    }

    if (mounted) setState(() => isSending = false);
  }

  void _showMessage(String msg, {bool isError = false}) {
    if (!mounted) return;
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
            if (noCardsAvailable) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: const Text(
                  '⚠️ لا توجد كروت متاحة لهذه الباقة حالياً.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ),
            ],
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
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: isSending ? null : _sendCard,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        icon: isSending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.send, color: Colors.white),
                        label: Text(
                          isSending ? 'جاري الإرسال...' : 'إرسال الكرت الآن',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
*/