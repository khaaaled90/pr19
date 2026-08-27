import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:sqflite/sqflite.dart';

import 'DatabaseHelper.dart';
import 'KeywordsScreen.dart';
import 'PendingLogsScreen.dart';
import 'SettingsScreen.dart';
import 'vouchers_screen.dart';
import 'services_screen.dart';
import 'tasks_screen.dart';
import 'allowed_senders_screen.dart';
import 'sales_screen.dart';
import 'support_screen.dart';
import 'backup_screen.dart';
import 'archive_screen.dart';
import 'CustomersManagementScreen.dart';
import 'ExceptedCustomersScreen.dart';
import 'service/native_service_controller.dart';
import 'helpers/secure_storage_helper.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'notifications_screen.dart'; // تأكد من مطابقة اسم الملف


const MethodChannel _smsChannel = MethodChannel('com.example.app/sms');
const MethodChannel _nativeControlChannel = MethodChannel('com.example.pr19/native_control');


class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({Key? key}) : super(key: key);

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  int _homeRefreshKey = 0;
  //int _vouchersRefreshKey = 0;
  int _servicesRefreshKey = 0;
  int _tasksRefreshKey = 0;
  //int _salesRefreshKey = 0;
  int _settingsRefreshKey = 0;
  int _contactRefreshKey = 0;

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
      switch (index) {
        case 0:
          _homeRefreshKey++;
          break;
        case 1:
          _servicesRefreshKey++;
          //_vouchersRefreshKey++;
          break;
        case 2:
          _tasksRefreshKey++;
          break;
        case 3:
          _settingsRefreshKey++;
          break;
        case 4:
          _contactRefreshKey++;
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;

    return Scaffold(
      //extendBody: true,
      extendBody: false, // 👈 تغيير القيمة من true إلى false
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeScreen(key: ValueKey('home_$_homeRefreshKey')),
          ServicesScreen(key: ValueKey('services_$_servicesRefreshKey')), // شاشة الخدمات الجديدة
          TasksScreen(key: ValueKey('tasks_$_tasksRefreshKey')),       // شاشة المهام الجديدة
          //VouchersScreen(key: ValueKey('vouchers_$_vouchersRefreshKey')),
          //SalesScreen(key: ValueKey('sales_$_salesRefreshKey')),
          SettingsScreen(key: ValueKey('settings_$_settingsRefreshKey')),
          SupportScreen(key: ValueKey('contact_$_contactRefreshKey')),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.5 : 0.08),
              blurRadius: 15,
              offset: const Offset(0, -4),
            ),
          ],
          border: Border(
            top: BorderSide(
              color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200,
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _build3DNavItem(Icons.dashboard_rounded, 'الرئيسية', 0),
                _build3DNavItem(Icons.grid_view_rounded, 'الخدمات', 1),
                _build3DNavItem(Icons.assignment_rounded, 'المهام', 2),
                //_build3DNavItem(Icons.donut_small_rounded, 'التقارير', 3),
                _build3DNavItem(Icons.tune_rounded, 'الإعدادات', 3),
                _build3DNavItem(Icons.headset_mic_rounded, 'الدعم', 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
  Widget _build3DNavItem(IconData icon, String label, int index) {
    final bool isActive = _currentIndex == index;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: GestureDetector(
          onTap: () => _onTabTapped(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: isActive
                  ? LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        primaryColor,
                        HSLColor.fromColor(primaryColor).withLightness(0.35).toColor(),
                      ],
                    )
                  : LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: isDark
                          ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                          : [Colors.white, Colors.grey.shade100],
                    ),
              border: Border.all(
                color: isActive
                    ? Colors.white.withOpacity(0.3)
                    : (isDark ? Colors.white10 : Colors.grey.shade300),
                width: 1.2,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.2),
                        offset: const Offset(0, -2),
                        blurRadius: 2,
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        offset: const Offset(0, 4),
                        blurRadius: 6,
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                        offset: const Offset(0, 3),
                        blurRadius: 4,
                      ),
                    ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: isActive
                      ? Colors.white
                      : (isDark ? Colors.white60 : Colors.black54),
                  size: isActive ? 22 : 20,
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                    color: isActive
                        ? Colors.white
                        : (isDark ? Colors.white60 : Colors.black54),
                  ),
                ),
              ],
            ),
          ),
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

  // 🟢 أضف هذه المتغيرات مع بقية متغيرات الحالة في الأعلى
  bool isTrial = true;
  String deviceId = '';
  int remainingDays = 0;
  int remainingVouchers = 0;
  String licenseType = 'تجريبي';
  
  int statReplies = 0;
  int totalAvailable = 0;
  int totalUsed = 0;
  int todaySalesCount = 0; // 👈 قم بإنشاء هذا المتغير هنا

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
    _startCardPayForegroundService();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStats());
  }

  Future<void> _startCardPayForegroundService() async {
    try {
      await _nativeControlChannel.invokeMethod('startForegroundService');
      debugPrint("تم تشغيل خدمة CardPay في الخلفية بنجاح");
    } catch (e) {
      debugPrint("خطأ في تشغيل الخدمة: $e");
    }
  }

  Future<void> _loadStats() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final db = DatabaseHelper.instance;
      final dbInstance = await db.database;

      // 🟢 قراءة الإعدادات أولاً عبر استدعاء الدالة المستقلة
      await _loadSettings();
      
      // 🟢 أضف هذا السطر هنا ليتم تحديث بيانات الترخيص عند كل تنشيط
      await _loadLicenseInfo();

      final keywords = await db.getAllKeywords();
      final numbers = await db.getAllNumbers();

      // 1. حساب إجمالي الردود
      final repliesCount = Sqflite.firstIntValue(
          await dbInstance.rawQuery('SELECT COUNT(*) FROM reply_log WHERE is_deleted = 0')) ?? 0;
      // 2. حساب إجمالي مبيعات اليوم مباشرة من SQL (مثل تقرير المبيعات)
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59, 999).millisecondsSinceEpoch;

      final List<Map<String, dynamic>> salesResult = await dbInstance.rawQuery('''
        SELECT COALESCE(SUM(price), 0.0) as total_sales
        FROM reply_log
        WHERE is_deleted = 0
          AND status IN ('sent', 'sent_reward', 'sent_manual')
          AND (timestamp BETWEEN ? AND ?)
      ''', [startOfDay, endOfDay]);

      // قراءة القيمة كـ double ثم تحويلها إلى num/int
      final double totalSalesDouble = (salesResult.first['total_sales'] as num?)?.toDouble() ?? 0.0;

      _processChartData(keywords, numbers, totalSalesDouble.toInt());

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

  Future<void> _loadSettings() async {
    try {
      final db = DatabaseHelper.instance;

      // تمرير مفتاح الإعداد والقيمة الافتراضية (مثلاً 'true' أو 'false')
      final serviceVal = await db.getSetting('service_enabled', 'false');
      final notifVal = await db.getSetting('enable_notification', 'true');

      if (mounted) {
        setState(() {
          // تحويل النص إلى bool مباشرة
          _serviceEnabled = (serviceVal == 'true');
          _notificationEnabled = (notifVal == 'true');
        });
      }
    } catch (e) {
      debugPrint("خطأ أثناء قراءة الإعدادات: $e");
    }
  }

  Future<void> _loadLicenseInfo() async { // 👈 تم حذف المعامل db
    try {
      // القراءة المباشرة من SecureStorageHelper باستخدام الدالة الجديدة
      final info = await SecureStorageHelper.getLicenseDetailsForUI();

      if (mounted) {
        setState(() {
          deviceId = info['deviceId'];
          isTrial = info['isTrial'];
          
          // تسمية نوع الترخيص بالعربية
          final String rawType = info['planType'];
          licenseType = isTrial 
              ? 'تجريبي' 
              : (rawType == 'lifetime' ? 'دائم' : 'مدفوع');
              
          remainingDays = info['remainingDays'];
          
          // القسائم/الرسائل المتبقية للترخيص (أو إظهار -1 إن كان غيراً محدود)
          remainingVouchers = info['remainingVouchers'];
        });
      }
    } catch (e) {
      debugPrint("خطأ أثناء قراءة بيانات الترخيص من SecureStorage: $e");
    }
  }

  void _loadDummyData() {
    if (!mounted) return;
    setState(() {
      statReplies = 0;
      availableCategoriesData = [];
      usedCategoriesData = [];
      totalAvailable = 0;
      totalUsed = 0;
      isLoading = false; // 👈 مهم جداً لإيقاف مؤشر التحميل
    });
  }

  void _processChartData(
    List<Map<String, dynamic>> keywords, 
    List<Map<String, dynamic>> numbers,
    int todaySales, // 🎯 تم إضافة مبيعات اليوم هنا
  ) {
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
        todaySalesCount = todaySales; // 🎯 تحديث قيمة مبيعات اليوم
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
          // أيقونة الإشعارات
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            tooltip: 'سجل الإشعارات',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationsScreen(),
                ),
              );
              _loadStats(); // تحديث إحصائيات الصفحة الرئيسية بعد العودة
            },
          ),
          // أيقونة الخروج
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
                    // 🟢 1. كارت تفاصيل الترخيص في البداية
                    _buildLicenseCard(cardBg, textColor, isDark),
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
                                      // 1. تحديث شكل الزر في الواجهة
                                      setState(() => _serviceEnabled = val);

                                      // 2. تحديث قاعدة البيانات والكاش الناتيف
                                      await DatabaseHelper.instance.updateSetting(
                                        'service_enabled', val ? 'true' : 'false',
                                      );

                                      // 3. التحكم الفعلي بالخدمة في الخلفية (Native Service)
                                      if (val) {
                                        await _startCardPayForegroundService();
                                      } else {
                                        try {
                                          await _nativeControlChannel.invokeMethod('stopForegroundService');
                                        } catch (e) {
                                          debugPrint("خطأ في إيقاف خدمة الرد الآلي: $e");
                                        }
                                      }
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
                                      // 1. تحديث الواجهة
                                      setState(() => _notificationEnabled = val);

                                      // 2. التحديث في قاعدة البيانات
                                      await DatabaseHelper.instance.updateSetting(
                                        'enable_notification', val ? 'true' : 'false',
                                      );

                                      // 3. طلب الصلاحيات الخاصة بالاستماع للإشعارات
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
                            //'$todaySalesCount',
                            '$todaySalesCount ر.ي', // 🎯 سيعرض الآن: 1200 ر.ي
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
                    //_buildPieChartSection('القسائم المتاحة', availableCategoriesData,
                      //  totalAvailable, cardBg, textColor),
                    //const SizedBox(height: 16),
                    //_buildPieChartSection('القسائم المستخدمة', usedCategoriesData,
                      //  totalUsed, cardBg, textColor),
                    /*_buildUnifiedStatsSection(
                      'إحصائيات القسائم الفئوية',
                      availableCategoriesData,
                      usedCategoriesData,
                      totalAvailable,
                      totalUsed,
                      cardBg,
                      textColor,
                    )*/
                    // 🌟 كارت الإحصائيات الموحد والعصري
                    _buildUnifiedStatsSection(
                      'إحصائيات القسائم الشاملة',
                      availableCategoriesData,
                      usedCategoriesData,
                      totalAvailable,
                      totalUsed,
                      cardBg,
                      textColor,
                    ),  
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
        // 🎯 إضافة الزر العائم فوق شريط التنقل بشكل متناسق ومستقل
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 75), // رفعه أعلى المنيو بار العائم
          child: FloatingActionButton.extended(
            onPressed: _openManualSendDialog,
            backgroundColor: Theme.of(context).primaryColor,
            elevation: 6,
            icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            label: const Text(
              'إرسال يدوي',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
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

  Widget _buildLicenseCard(Color cardBg, Color textColor, bool isDark) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isTrial 
              ? Colors.amber.shade700.withOpacity(0.4) 
              : Colors.blue.shade700.withOpacity(0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isTrial ? Icons.timer_outlined : Icons.verified_user_rounded,
                    color: isTrial ? Colors.amber.shade800 : Colors.blueAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'معرف الجهاز: $deviceId',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isTrial 
                      ? Colors.amber.withOpacity(0.15) 
                      : Colors.green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isTrial ? 'نسخة تجريبية' : 'ترخيص: $licenseType',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isTrial ? Colors.amber.shade900 : Colors.green.shade700,
                  ),
                ),
              ),
            ],
          ),
          if (isTrial) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      'الأيام المتبقية: ',
                      style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.7)),
                    ),
                    Text(
                      '$remainingDays يوم',
                      style: const TextStyle(
                        fontSize: 12, 
                        fontWeight: FontWeight.bold, 
                        color: Colors.redAccent
                      ),
                    ),
                  ],
                ),
                Container(height: 14, width: 1, color: Colors.grey.withOpacity(0.3)),
                Row(
                  children: [
                    const Icon(Icons.confirmation_number_outlined, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      'القسائم المتبقية: ',
                      style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.7)),
                    ),
                    Text(
                      '$remainingVouchers كرت',
                      style: const TextStyle(
                        fontSize: 12, 
                        fontWeight: FontWeight.bold, 
                        color: Color(0xFF10B981)
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
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
// ─── 1. الدالة الرئيسية الموحدة للإحصائيات ───
  Widget _buildUnifiedStatsSection(
    String title,
    List<_CategoryStatData> availData,
    List<_CategoryStatData> usedData,
    int totalAvail,
    int totalUsed,
    Color cardBg,
    Color textColor,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // دمج كافة أسماء الفئات الفريدة
    final Set<String> allCategoryNames = {
      ...availData.map((e) => e.categoryName),
      ...usedData.map((e) => e.categoryName),
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.35 : 0.05),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── 1. Header Section (رأس البطاقة الرئيسي) ───
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 5,
                    height: 20,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF0EA5E9)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  _buildModernHeaderBadge('متاح', '$totalAvail', const Color(0xFF0EA5E9), isDark),
                  const SizedBox(width: 6),
                  _buildModernHeaderBadge('مباع', '$totalUsed', const Color(0xFFF59E0B), isDark),
                ],
              ),
            ],
          ),
          const SizedBox(height: 22),

          // ─── 2. Category List (قائمة الفئات بتصميم Card Tiles) ───
          if (allCategoryNames.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Center(
                child: Text(
                  'لا توجد كروت مسجلة حالياً',
                  style: TextStyle(color: textColor.withOpacity(0.4), fontSize: 13),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: allCategoryNames.length,
              separatorBuilder: (context, index) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final catName = allCategoryNames.elementAt(index);

                final availItem = availData.firstWhere(
                  (e) => e.categoryName == catName,
                  orElse: () => _CategoryStatData(catName, 0, Colors.grey),
                );
                final usedItem = usedData.firstWhere(
                  (e) => e.categoryName == catName,
                  orElse: () => _CategoryStatData(catName, 0, Colors.grey),
                );

                final int catTotal = availItem.count + usedItem.count;
                final double availPercent = catTotal > 0 ? (availItem.count / catTotal) : 0;
                final double usedPercent = catTotal > 0 ? (usedItem.count / catTotal) : 0;

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // عنوان الفئة + الإجمالي
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.style_rounded,
                                size: 16,
                                color: Theme.of(context).primaryColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                catName,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: textColor.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'الإجمالي: $catTotal',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: textColor.withOpacity(0.7),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // تفاصيل الأرقام المتاحة والمباعة
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildStatChip(
                            'متاح: ${availItem.count}',
                            '${(availPercent * 100).toStringAsFixed(1)}%',
                            const Color(0xFF0EA5E9),
                          ),
                          _buildStatChip(
                            'مباع: ${usedItem.count}',
                            '${(usedPercent * 100).toStringAsFixed(1)}%',
                            const Color(0xFFF59E0B),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // ─── 3. Glowing Split Progress Bar (شريط التوهج المقسم) ───
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          height: 9,
                          width: double.infinity,
                          color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade200,
                          child: Row(
                            children: [
                              if (availItem.count > 0)
                                Expanded(
                                  flex: availItem.count,
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [Color(0xFF38BDF8), Color(0xFF0284C7)],
                                      ),
                                    ),
                                  ),
                                ),
                              if (availItem.count > 0 && usedItem.count > 0)
                                const SizedBox(width: 2), // فاصل صغير وأنيق بين الشريطين
                              if (usedItem.count > 0)
                                Expanded(
                                  flex: usedItem.count,
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [Color(0xFFFBBF24), Color(0xFFD97706)],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    ); // إغلاق الـ Container الخاص بالدالة الرئيسية
  } // إغلاق الدالة _buildUnifiedStatsSection

  // ─── 2. ودجت المساعد للشارات العلوية (Header Badges) ───
  Widget _buildModernHeaderBadge(String label, String count, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$label: $count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ─── 3. ودجت المساعد لأرقام الفئة (Stat Chips) ───
  Widget _buildStatChip(String title, String percent, Color color) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '($percent)',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: color.withOpacity(0.7),
          ),
        ),
      ],
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

  // 2️⃣ دالة اختيار جهة الاتصال (تُوضع هنا داخل الكلاس)
  Future<void> _pickContact() async {
    var status = await Permission.contacts.request();
    if (status.isGranted) {
      try {
        Contact? contact = await FlutterContacts.openExternalPick();
        if (contact != null) {
          Contact? fullContact = await FlutterContacts.getContact(contact.id);
          if (fullContact != null && fullContact.phones.isNotEmpty) {
            String rawPhone = fullContact.phones.first.number;

            // تنظيف الرقم من المسافات والرموز الزائدة
            String cleanPhone = rawPhone.replaceAll(RegExp(r'[^\d+]'), '');

            setState(() {
              _phoneController.text = cleanPhone;
            });
          }
        }
      } catch (e) {
        debugPrint("خطأ أثناء اختيار جهة الاتصال: $e");
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("يرجى منح إذن الوصول لجهات الاتصال لتفعيل الميزة"),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
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

  // 🟢 دالة قراءة بيانات الترخيص والقسائم المتبقية
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

    var matchedKw = keywords.firstWhere(
      (k) => k['id'] == selectedKeywordId,
      orElse: () => <String, dynamic>{},
    );
    String kwName = matchedKw['keyword'] ?? 'يدوي';
    
    // استخراج سعر الباقة/الكلمة المفتاحية
    double cardPrice = (matchedKw['price'] as num?)?.toDouble() ?? 0.0;

    await triggerManagerAlertNative(selectedKeywordId!, kwName);
    setState(() => isSending = true);

    try {
      final dbHelper = DatabaseHelper.instance;
      var usedVoucher = await dbHelper.getAndUseVoucher(selectedKeywordId!, phone);

      if (usedVoucher != null) {
        String cardCode = usedVoucher['number_code'] ?? '';
        // 🟢 1. تنظيف النص واستخراج الأرقام فقط
        String cleanDigits = phone.replaceAll(RegExp(r'\D'), '');

        // 🟢 2. تحويل الرقم إلى الصيغة الدولية إذا كان يتكون من 9 أرقام أو أكثر
        if (cleanDigits.length >= 9) {
          phone = "+967${cleanDigits.substring(cleanDigits.length - 9)}";
        }
        await dbHelper.saveOrUpdateCustomer(phone);

        // 🛡️ تقسيم الكرت إذا كان يحتوي على (فاصلة أو شرطة أو سلاش)
        List<String> parts = cardCode.split(RegExp(r'[,\-/]'));
        
        String formattedCardCode;
        if (parts.length >= 2) {
          formattedCardCode = "\nاسم المستخدم: ${parts[0].trim()}\nكلمة المرور: ${parts[1].trim()}";
        } else {
          formattedCardCode = "\nرمز الكرت: ${cardCode.trim()}";
        } 
        String footerMsg = await dbHelper.getSetting('footer_message', '');
        String defaultReply = await DatabaseHelper.instance
          .getSetting('default_reply', 'شكراً لتواصلك. رقمك الخاص هو: ');
        
        // ✏️ استخدام الكرت المنسق داخل الرسالة
        String fullMsg = formattedCardCode + (footerMsg.isNotEmpty ? '\n$footerMsg' : '');
        String fullMessage = "$defaultReply $fullMsg";
        bool sentStatus = await _sendSmsNativeDirect(phone, fullMessage);
        
        // حفظ العملية محلياً مع السعر وتغيير الحالة إلى sent_manual
        bool isArchived = await dbHelper.addToArchive(
          sender: 'إرسال يدوي',
          senderName: phone,
          receivedMessage: fullMessage,
          matchedKeyword: kwName,
          sentNumber: cardCode,
          price: cardPrice,
          status: sentStatus ? 'sent_manual' : 'failed',
        );

        if (sentStatus) {
          // رفع السجل إلى الفايربيس (قم بفك التعليق وتعديل اسم الدالة إذا لزم الأمر)
          // await FirebaseService.uploadReplyLog(logId);
          try {
            await _nativeControlChannel.invokeMethod("showVoucherNotification", {
              "categoryName": kwName, // اسم الكلمة المفتاحية أو فئة الكرت
              "phone": phone,                 // رقم هاتف المستلم
            });
          } catch (e) {
            debugPrint("خطأ أثناء استدعاء إشعار القسيمة: $e");
          }          
          _showMessage('✅ تم إرسال الكرت إلى $phone بنجاح');
          widget.onSentSuccess();
          if (mounted) Navigator.pop(context);
        } else {
          _showMessage('⚠️ تم استهلاك الكرت ولكن فشل إرسال الـ SMS', isError: true);
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
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16)),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.contacts_rounded, color: Colors.blue),
                    tooltip: 'اختيار من جهات الاتصال',
                    onPressed: _pickContact,
                  ),
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
