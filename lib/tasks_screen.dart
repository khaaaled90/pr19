import 'package:flutter/material.dart';

// استيراد الشاشات المرتبطة بالمهام
import 'PendingLogsScreen.dart';
import 'ExceptedCustomersScreen.dart';
import 'CustomersManagementScreen.dart';
import 'archive_screen.dart';

class TasksScreen extends StatelessWidget {
  const TasksScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'المهام والعمليات',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'إدارة العمليات والعملاء',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            const Text(
              'متابعة الطلبات المعلقة، والاستثناءات وإدارة بيانات العملاء',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            _build3DTaskCard(
              context: context,
              title: 'سجل العمليات المعلقة',
              subtitle: 'متابعة وإعادة إرسال الرسائل والعمليات المعلقة',
              icon: Icons.history_toggle_off_rounded,
              badgeText: 'العمليات',
              gradientColors: const [Color(0xFFEC4899), Color(0xFFBE185D)],
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PendingLogsScreen()),
                );
              },
            ),
            const SizedBox(height: 14),
            _build3DTaskCard(
              context: context,
              title: 'العملاء المستثنون',
              subtitle: 'حظر أو استثناء أرقام محددة من الرد الآلي',
              icon: Icons.block_rounded,
              badgeText: 'الاستثناءات',
              gradientColors: const [Color(0xFFEF4444), Color(0xFFB91C1C)],
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ExceptedCustomersScreen()),
                );
              },
            ),
            const SizedBox(height: 14),
            _build3DTaskCard(
              context: context,
              title: 'تعديل وإدارة العملاء',
              subtitle: 'عرض، تعديل، وحذف بيانات وسجلات العملاء',
              icon: Icons.people_alt_rounded,
              badgeText: 'العملاء',
              gradientColors: const [Color(0xFF6366F1), Color(0xFF4338CA)],
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CustomersManagementScreen()),
                );
              },
            ),
            const SizedBox(height: 14),
            _build3DTaskCard(
              context: context,
              title: 'سجل الأرشيف والمبيعات',
              subtitle: 'استعراض التقارير القديمة والعمليات المكتملة',
              icon: Icons.archive_rounded,
              badgeText: 'الأرشيف',
              gradientColors: const [Color(0xFF14B8A6), Color(0xFF0F766E)],
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ArchiveScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _build3DTaskCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required String badgeText,
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
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: gradientColors.first.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: gradientColors.first,
                            ),
                          ),
                        ),
                      ],
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