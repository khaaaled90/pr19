import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({Key? key}) : super(key: key);

  void _showSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        duration: const Duration(milliseconds: 2000),
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    _showSnackBar(context, '✅ تم نسخ $label: $text');
  }

  Future<void> _makePhoneCall(BuildContext context, String phoneNumber) async {
    final Uri url = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      }
    } catch (_) {
      _showSnackBar(context, '❌ تعذر إجراء الاتصال تلقائياً', isError: true);
    }
  }

  Future<void> _openWhatsApp(BuildContext context, String phoneNumber) async {
    final Uri url = Uri.parse("https://wa.me/967$phoneNumber");
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      _showSnackBar(context, '❌ تعذر فتح تطبيق واتساب', isError: true);
    }
  }

  Future<void> _launchUrl(BuildContext context, String urlString) async {
    final Uri uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showSnackBar(context, '❌ تعذر فتح الرابط', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: const Text(
          'مركز الدعم والمساعدة',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(context, theme, isDark),
            const SizedBox(height: 24),
            
            _buildSectionHeader(theme, 'أرقام الدعم المباشر', Icons.headset_mic_rounded),
            const SizedBox(height: 12),
            
            _buildContactCard(
              context,
              theme: theme,
              title: 'الدعم الفني (الرئيسي)',
              phone: '734542531',
            ),
            const SizedBox(height: 12),
            
            _buildContactCard(
              context,
              theme: theme,
              title: 'الدعم الفني (المساعد)',
              phone: '777003000',
            ),

            const SizedBox(height: 24),

            _buildSectionHeader(theme, 'مجتمعاتنا وقنوات التواصل', Icons.hub_rounded),
            const SizedBox(height: 12),

            _buildSocialTile(
              context,
              theme: theme,
              title: 'قناة الواتساب الرسمية',
              subtitle: 'انضم لمتابعة جديد التحديثات والإصدارات',
              icon: Icons.groups_rounded,
              iconColor: const Color(0xFF25D366),
              onTap: () => _launchUrl(context, 'https://whatsapp.com/channel/YOUR_CHANNEL_ID'),
            ),
            const SizedBox(height: 10),

            _buildSocialTile(
              context,
              theme: theme,
              title: 'قناة التلجرام',
              subtitle: 'تغطية فورية وشروحات استخدام التطبيق',
              icon: Icons.telegram,
              iconColor: const Color(0xFF0088CC),
              onTap: () => _launchUrl(context, 'https://t.me/YOUR_TELEGRAM_CHANNEL'),
            ),
            const SizedBox(height: 10),

            _buildSocialTile(
              context,
              theme: theme,
              title: 'صفحة الفيسبوك',
              subtitle: 'تواصل مجتمعي ومشاركات يومية',
              icon: Icons.facebook,
              iconColor: const Color(0xFF1877F2),
              onTap: () => _launchUrl(context, 'https://facebook.com/YOUR_PAGE_URL'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, ThemeData theme, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [theme.cardColor, theme.cardColor.withOpacity(0.8)]
              : [theme.primaryColor.withOpacity(0.08), theme.primaryColor.withOpacity(0.03)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.primaryColor.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.support_agent_rounded, color: theme.primaryColor, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'فريق الدعم الفني جاهز!',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.titleMedium?.color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'يسعدنا تقديم المساعدة فوراً عبر وسائل الاتصال والقنوات المبينة أدناه',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.textTheme.bodySmall?.color,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.primaryColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: theme.textTheme.titleMedium?.color,
          ),
        ),
      ],
    );
  }

  Widget _buildContactCard(
    BuildContext context, {
    required ThemeData theme,
    required String title,
    required String phone,
  }) {
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: theme.primaryColor.withOpacity(0.1),
                child: Icon(Icons.phone_android_rounded, color: theme.primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                    Text(
                      phone,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _copyToClipboard(context, phone, title),
                icon: const Icon(Icons.copy_rounded, size: 18),
                tooltip: 'نسخ الرقم',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () => _openWhatsApp(context, phone),
                  icon: const Icon(Icons.chat_rounded, color: Colors.white, size: 16),
                  label: const Text('واتساب', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () => _makePhoneCall(context, phone),
                  icon: const Icon(Icons.phone, color: Colors.white, size: 16),
                  label: const Text('اتصال', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSocialTile(
    BuildContext context, {
    required ThemeData theme,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.12),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 11.5, color: theme.textTheme.bodySmall?.color),
        ),
        trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: theme.textTheme.bodySmall?.color),
      ),
    );
  }
}
/*import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({Key? key}) : super(key: key);

  void _showSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF27AE60),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        duration: const Duration(milliseconds: 2000),
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    _showSnackBar(context, '✅ تم نسخ $label: $text');
  }

  Future<void> _makePhoneCall(BuildContext context, String phoneNumber) async {
    final Uri url = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      }
    } catch (_) {
      _showSnackBar(context, '❌ تعذر إجراء الاتصال تلقائياً', isError: true);
    }
  }

  Future<void> _openWhatsApp(BuildContext context, String phoneNumber) async {
    final Uri url = Uri.parse("https://wa.me/967$phoneNumber");
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      _showSnackBar(context, '❌ تعذر فتح تطبيق واتساب', isError: true);
    }
  }

  Future<void> _launchUrl(BuildContext context, String urlString) async {
    final Uri uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showSnackBar(context, '❌ تعذر فتح الرابط', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '📞 معلومات الاتصال والدعم',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ترويسة ترحيبية بسيطة
            _buildHeaderCard(context, theme, isDark),

            const SizedBox(height: 20),

            // 1️⃣ قسم أرقام الدعم المباشر
            _buildSectionHeader(theme, 'أرقام الدعم الفني', Icons.headset_mic_rounded),
            const SizedBox(height: 10),
            
            _buildContactCard(
              context,
              theme: theme,
              title: 'الدعم الفني (الرئيسي)',
              phone: '734542531',
            ),
            
            const SizedBox(height: 12),
            
            _buildContactCard(
              context,
              theme: theme,
              title: 'الدعم الفني (المساعد)',
              phone: '777003000',
            ),

            const SizedBox(height: 24),

            // 2️⃣ قسم قنوات التواصل والمتابعة
            _buildSectionHeader(theme, 'قنوات التواصل الاجتماعية', Icons.share_rounded),
            const SizedBox(height: 10),

            _buildSocialTile(
              context,
              theme: theme,
              title: 'قناة الواتساب الرسمية',
              subtitle: 'تابع أحدث التحديثات والأخبار',
              icon: Icons.groups_rounded,
              iconColor: const Color(0xFF25D366),
              onTap: () => _launchUrl(context, 'https://whatsapp.com/channel/YOUR_CHANNEL_ID'),
            ),

            const SizedBox(height: 8),

            _buildSocialTile(
              context,
              theme: theme,
              title: 'قناة التلجرام',
              subtitle: 'انضم لمجتمعنا على تلجرام',
              icon: Icons.telegram,
              iconColor: const Color(0xFF0088CC),
              onTap: () => _launchUrl(context, 'https://t.me/YOUR_TELEGRAM_CHANNEL'),
            ),

            const SizedBox(height: 8),

            _buildSocialTile(
              context,
              theme: theme,
              title: 'صفحة الفيسبوك',
              subtitle: 'تواصل معنا على فيسبوك',
              icon: Icons.facebook,
              iconColor: const Color(0xFF1877F2),
              onTap: () => _launchUrl(context, 'https://facebook.com/YOUR_PAGE_URL'),
            ),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ترويسة رئيسية جذابة
  Widget _buildHeaderCard(BuildContext context, ThemeData theme, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: isDark ? theme.cardColor : theme.primaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.primaryColor.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: theme.primaryColor.withOpacity(0.15),
            child: Icon(Icons.support_agent_rounded, color: theme.primaryColor, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'نحن هنا لمساعدتك!',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.titleMedium?.color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'يمكنك التواصل معنا عبر الأرقام التالية أو متابعة قنواتنا الرسمية',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // عنوان كل قسم
  Widget _buildSectionHeader(ThemeData theme, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.primaryColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: theme.textTheme.titleMedium?.color,
          ),
        ),
      ],
    );
  }

  // بطاقة اتصال فردية بتصميم مريح
  Widget _buildContactCard(
    BuildContext context, {
    required ThemeData theme,
    required String title,
    required String phone,
  }) {
    return Card(
      elevation: theme.brightness == Brightness.dark ? 1 : 1.5,
      color: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            InkWell(
              onTap: () => _copyToClipboard(context, phone, title),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 6.0),
                child: Row(
                  children: [
                    Icon(Icons.phone_android_rounded, color: theme.primaryColor, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          Text(
                            '$phone  (اضغط للنسخ)',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.textTheme.bodySmall?.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.copy_rounded, size: 16, color: theme.textTheme.bodySmall?.color),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () => _openWhatsApp(context, phone),
                    icon: const Icon(Icons.chat_rounded, color: Colors.white, size: 18),
                    label: const Text('واتساب', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3498DB),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () => _makePhoneCall(context, phone),
                    icon: const Icon(Icons.phone, color: Colors.white, size: 18),
                    label: const Text('اتصال', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // قائمة القنوات الاجتماعية
  Widget _buildSocialTile(
    BuildContext context, {
    required ThemeData theme,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: theme.brightness == Brightness.dark ? 1 : 1,
      color: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.12),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 11.5, color: theme.textTheme.bodySmall?.color),
        ),
        trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: theme.textTheme.bodySmall?.color),
      ),
    );
  }
}*/