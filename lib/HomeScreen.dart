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
  int _vouchersRefreshKey = 0;
  int _salesRefreshKey = 0;
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
          _vouchersRefreshKey++;
          break;
        case 2:
          _salesRefreshKey++;
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
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeScreen(key: ValueKey('home_$_homeRefreshKey')),
          VouchersScreen(key: ValueKey('vouchers_$_vouchersRefreshKey')),
          SalesScreen(key: ValueKey('sales_$_salesRefreshKey')),
          SettingsScreen(key: ValueKey('settings_$_settingsRefreshKey')),
          SupportScreen(key: ValueKey('contact_$_contactRefreshKey')),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: Colors.transparent, // شفاف لإبراز الأزرار المستقلة
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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

    final primaryColor = theme.primaryColor;
    final cardBg = theme.cardColor;

    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabTapped(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            // 1. ألوان مصمتة وواضحة بدون الشفافية المنخفضة
            color: isActive
                ? (isDark ? primaryColor : primaryColor)
                : cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              // 2. إطار واضح
              color: isActive
                  ? Colors.transparent
                  : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.4 : 0.08),
                blurRadius: 8,
                offset: const Offset(0, 3),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                // 3. ألوان أيقونات مصمتة (Solid Colors)
                color: isActive
                    ? Colors.white
                    : (isDark ? Colors.white70 : Colors.black87),
                size: isActive ? 22 : 20,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  // 4. ألوان نصوص مصمتة وواضحة
                  color: isActive
                      ? Colors.white
                      : (isDark ? Colors.white70 : Colors.black87),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  /*Widget _buildNavItem(IconData icon, String label, int index) {
    final bool isActive = _currentIndex == index;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryColor = theme.primaryColor;
    final cardBg = theme.cardColor;

    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabTapped(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? (isDark ? primaryColor.withOpacity(0.25) : primaryColor)
                : cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isActive
                  ? primaryColor.withOpacity(0.5)
                  : (isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
              width: 1.2,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    )
                  ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isActive
                    ? (isDark ? const Color(0xFF38BDF8) : Colors.white)
                    : (isDark ? Colors.white54 : Colors.black54),
                size: isActive ? 22 : 20,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  color: isActive
                      ? (isDark ? const Color(0xFF38BDF8) : Colors.white)
                      : (isDark ? Colors.white54 : Colors.black54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }*/
}

//**************************** */
/*class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({Key? key}) : super(key: key);

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  // 1. عدادات موحدة لجميع الشاشات لإجبارها على التحديث عند النقر
  int _homeRefreshKey = 0;
  int _vouchersRefreshKey = 0;
  int _salesRefreshKey = 0;
  int _settingsRefreshKey = 0;
  int _contactRefreshKey = 0;

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;

      // 2. تحديث العداد الخاص بالتبويب المحدد فور التنقل
      switch (index) {
        case 0:
          _homeRefreshKey++;
          break;
        case 1:
          _vouchersRefreshKey++;
          break;
        case 2:
          _salesRefreshKey++;
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
    final cardBg = theme.cardColor;

    return Scaffold(
      // 🟢 تجعل محتوى الشاشة يتمتد لخلف الـ BottomNavigationBar
      extendBody: true, 

      body: IndexedStack(
        index: _currentIndex,
        children: [
          // 3. ربط جميع الشاشات بـ ValueKey لتعيد التحديث تلقائياً
          HomeScreen(key: ValueKey('home_$_homeRefreshKey')),
          VouchersScreen(key: ValueKey('vouchers_$_vouchersRefreshKey')),
          SalesScreen(key: ValueKey('sales_$_salesRefreshKey')),
          SettingsScreen(key: ValueKey('settings_$_settingsRefreshKey')),
          ContactTabScreen(key: ValueKey('contact_$_contactRefreshKey')),
        ],
      ),

      // 🟢 مغلف بـ SafeArea للتحكم بالهوامش في الشاشات العادية والحديثة
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: cardBg.withOpacity(isDark ? 0.92 : 0.98), // شفافة خفيفة لمظهر عائم عصري
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.4 : 0.12),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 6),
              )
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
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
      onTap: () => _onTabTapped(index),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
}*/
/*class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({Key? key}) : super(key: key);

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  // 1. عدادات موحدة لجميع الشاشات لإجبارها على التحديث عند النقر
  int _homeRefreshKey = 0;
  int _vouchersRefreshKey = 0;
  int _salesRefreshKey = 0;
  int _settingsRefreshKey = 0;
  int _contactRefreshKey = 0;

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;

      // 2. تحديث العداد الخاص بالتبويب المحدد فور التنقل
      switch (index) {
        case 0:
          _homeRefreshKey++;
          break;
        case 1:
          _vouchersRefreshKey++;
          break;
        case 2:
          _salesRefreshKey++;
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
    final cardBg = theme.cardColor;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // 3. ربط جميع الشاشات بـ ValueKey لتعيد التحديث تلقائياً
          HomeScreen(key: ValueKey('home_$_homeRefreshKey')),
          VouchersScreen(key: ValueKey('vouchers_$_vouchersRefreshKey')),
          SalesScreen(key: ValueKey('sales_$_salesRefreshKey')),
          SettingsScreen(key: ValueKey('settings_$_settingsRefreshKey')),
          ContactTabScreen(key: ValueKey('contact_$_contactRefreshKey')),
        ],
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
      onTap: () => _onTabTapped(index),
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
}*/
/*class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({Key? key}) : super(key: key);

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  // عدادات لإجبار الشاشات على التحديث عند النقر على التبويب
  int _vouchersRefreshKey = 0;
  int _salesRefreshKey = 0;

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;

      // عند الانتقال لتبويب الكروت (1)، نغير المفتاح لإعادة تشغيل initState داخل الشاشة وتحديث البيانات
      if (index == 1) {
        _vouchersRefreshKey++;
      }
      // عند الانتقال لتبويب التقارير/المبيعات (2)، نغير المفتاح لنفس الغرض
      else if (index == 2) {
        _salesRefreshKey++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = theme.cardColor;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const HomeScreen(),
          // استخدام ValueKey يربط المفتاح بالعداد، مما يحفز التحديث التلقائي فور التنقل
          VouchersScreen(key: ValueKey('vouchers_$_vouchersRefreshKey')),
          SalesScreen(key: ValueKey('sales_$_salesRefreshKey')),
          const SettingsScreen(),
          const ContactTabScreen(),
        ],
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
      // استدعاء دالة التنقل والتحديث عند الضغط
      onTap: () => _onTabTapped(index),
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
}*/
/*class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({Key? key}) : super(key: key);

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    //const VouchersTabScreen(),
    //const ReportsTabScreen(),
    //const SettingsTabScreen(),
    const VouchersScreen(),
    const SalesScreen(),
    const SettingsScreen(),
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
}*/

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
    /*setState(() {
      statReplies = 0;
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
    });*/
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
                                  /*child: Switch(
                                    value: _serviceEnabled,
                                    activeColor: const Color(0xFF10B981),
                                    onChanged: (val) async {
                                      setState(() => _serviceEnabled = val);
                                      await DatabaseHelper.instance.updateSetting(
                                          'service_enabled', val ? 'true' : 'false');
                                    },
                                  ),*/
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
                                  /*child: Switch(
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
                                  ),*/
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
                        /*_buildMenuItem('تغذية الكروت', Icons.add_card_rounded,
                            const Color(0xFFF59E0B), cardBg, textColor, () async {
                          await Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const VouchersScreen()));
                          _loadStats();
                        }),*/
                        _buildMenuItem('الأرشيف', Icons.mark_email_read_rounded,
                            const Color(0xFF06B6D4), cardBg, textColor, () async {
                          await Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const ArchiveScreen()));
                          _loadStats();
                        }),
                        /*_buildMenuItem('المبيعات', Icons.insights_rounded,
                            const Color(0xFF6366F1), cardBg, textColor, () async {
                          await Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const ExceptedCustomersScreen()));
                          _loadStats();
                        }), 
                        */
                        _buildMenuItem('العمليات', Icons.pending_actions_rounded,
                            const Color(0xFFEC4899), cardBg, textColor, () async {
                          await Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const PendingLogsScreen()));
                          _loadStats();
                        }),
                        _buildMenuItem('الاستثنائات', Icons.person_off_rounded,
                            const Color(0xFF6366F1), cardBg, textColor, () async {
                          await Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const ExceptedCustomersScreen()));
                          _loadStats();
                        }),
                        //_buildMenuItem('إرسال يدوي', Icons.send_rounded,
                            //const Color(0xFFEF4444), cardBg, textColor, _openManualSendDialog),
                        _buildMenuItem('المحافظ', Icons.account_balance_rounded,
                            const Color(0xFF10B981), cardBg, textColor, () async {
                          await Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const AllowedSendersScreen()));
                          _loadStats();
                        }),
                        _buildMenuItem('تعديل العملاء', Icons.manage_accounts_rounded,
                            const Color(0xFF64748B), cardBg, textColor, () async {
                          await Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const CustomersManagementScreen()));
                          _loadStats();
                        }),
                        _buildMenuItem('النسخ الاحتياطي', Icons.cloud_sync_rounded,
                            const Color(0xFF3B82F6), cardBg, textColor, () async {
                          await Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const BackupScreen()));
                          _loadStats();
                        }),
                      ],
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
        // 🎯 إضافة الزر العائم المطفي/المعطل
        /*floatingActionButton: FloatingActionButton.extended(
          onPressed: _openManualSendDialog, // تمرير مباشر بدون () وبدون أقواس دالة
          backgroundColor: Theme.of(context).primaryColor,
          elevation: 4,
          icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
          label: const Text(
            'إرسال يدوي',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        )
    );
  }*/

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

      //if (usedVoucher != null) {
        /*String cardCode = usedVoucher['number_code'];
        await dbHelper.saveOrUpdateCustomer(phone);
        String footerMsg = await dbHelper.getSetting('footer_message', '');
        String defaultReply = await DatabaseHelper.instance
          .getSetting('default_reply', 'شكراً لتواصلك. رقمك الخاص هو: ');
        String fullMsg = cardCode + (footerMsg.isNotEmpty ? '\n$footerMsg' : '');
        
        String fullMessage = "$defaultReply $fullMsg";

        bool sentStatus = await _sendSmsNativeDirect(phone, fullMessage);*/
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
  
  /*Future<void> _sendCard() async {
    
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
  }*/

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

/*class ContactTabScreen extends StatelessWidget {
  const ContactTabScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الدعم والتواصل')),
      body: const Center(child: Text('شاشة التواصل والدعم الفني')),
    );
  }
}*/