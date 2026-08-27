import 'package:flutter/material.dart';

// استيراد الشاشات المرتبطة بالخدمات
import 'KeywordsScreen.dart';
import 'allowed_senders_screen.dart';
import 'backup_screen.dart';
import 'vouchers_screen.dart';
import 'sales_screen.dart';
import 'SimSettingsScreen.dart'; // أو حسب المسار الخاص بالملف لديلك

class ServicesScreen extends StatelessWidget {
  const ServicesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'الخدمات والإدارة',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'الخدمات الأساسية',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            const Text(
              'إدارة الباقات والمحافظ والنسخ الاحتياطي',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            _build3DServiceCard(
              context: context,
              title: 'إدارة الباقات والفئات',
              subtitle: 'إضافة الكلمات المفتاحية والأسعار',
              icon: Icons.inventory_2_rounded,
              gradientColors: const [Color(0xFF0EA5E9), Color(0xFF0284C7)],
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const KeywordsScreen()),
                );
              },
            ),
            const SizedBox(height: 14),
            _build3DServiceCard(
              context: context,
              title: 'إدارة الكروت والمخزون',
              subtitle: 'استيراد وعرض الكروت المتاحة والمستخدمة',
              icon: Icons.confirmation_number_rounded,
              gradientColors: const [Color(0xFFF59E0B), Color(0xFFD97706)],
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const VouchersScreen()),
                );
              },
            ),
            const SizedBox(height: 14),
            _build3DServiceCard(
              context: context,
              title: 'تقارير المبيعات',
              subtitle: 'عرض المبيعات اليومية والاسبوعية والشهرية ',
              icon: Icons.bar_chart_rounded, // استبدال أيقونة الكروت بأيقونة الرسم البياني
                gradientColors: const [Color(0xFFEC4899), Color(0xFFBE185D)], // تدرج ورودي/بنفسجي مميز للمبيعات
                onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SalesScreen()),
                );
              },
            ),
            const SizedBox(height: 14),
            _build3DServiceCard(
              context: context,
              title: 'المحافظ والجهات المسموحة',
              subtitle: 'عرض الحافظ والبنوك المعتمدين',
              icon: Icons.account_balance_wallet_rounded,
              gradientColors: const [Color(0xFF10B981), Color(0xFF059669)],
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AllowedSendersScreen()),
                );
              },
            ),
            const SizedBox(height: 14),
            // 🟢 البطاقة المُضافة: شاشة اختيار شريحة الإرسال
            _build3DServiceCard(
              context: context,
              title: 'إعدادات شريحة الإرسال',
              subtitle: 'تحديد الشريحة المعتمدة لإرسال كروت الرد الآلي',
              icon: Icons.sim_card_rounded,
              gradientColors: const [Color(0xFF6366F1), Color(0xFF4F46E5)],
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SimSettingsScreen()),
                );
              },
            ),
            const SizedBox(height: 14),
            _build3DServiceCard(
              context: context,
              title: 'النسخ الاحتياطي والاستعادة',
              subtitle: 'حفظ واسترجاع بيانات التطبيق والقسائم بأمان',
              icon: Icons.cloud_sync_rounded,
              gradientColors: const [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const BackupScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _build3DServiceCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradientColors,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.grey.shade200,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: gradientColors.first.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradientColors,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: gradientColors.last.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 18,
                color: isDark ? Colors.white38 : Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}