import 'package:flutter/material.dart';
import 'backup_service.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({Key? key}) : super(key: key);

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  List<BackupItem> _backupFiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBackupFiles();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        backgroundColor:
            isError ? const Color(0xFFE74C3C) : const Color(0xFF27AE60),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
      ),
    );
  }

  Future<void> _loadBackupFiles() async {
    setState(() => _isLoading = true);
    final files = await BackupService.getBackupFilesList();
    if (!mounted) return;
    setState(() {
      _backupFiles = files;
      _isLoading = false;
    });
  }

  Future<void> _confirmAction({
    required String title,
    required String content,
    required VoidCallback onConfirm,
  }) async {
    final theme = Theme.of(context);
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: theme.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            content: Text(content, style: const TextStyle(fontSize: 13)),
            actions: <Widget>[
              TextButton(
                child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
                onPressed: () => Navigator.of(context).pop(),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE67E22),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('تأكيد الاستعادة',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.of(context).pop();
                  onConfirm();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // إنشاء نسخة
  Future<void> _handleCreateBackup() async {
    _showSnackBar('⏳ جاري حفظ النسخة الاحتياطية...');
    bool success = await BackupService.createBackup();
    if (success) {
      _showSnackBar('✅ تم حفظ النسخة الاحتياطية بنجاح');
      _loadBackupFiles();
    } else {
      _showSnackBar('❌ فشل إنشاء النسخة الاحتياطية', isError: true);
    }
  }

  // استعادة آخر نسخة
  void _handleRestoreLatest() {
    _confirmAction(
      title: 'تأكيد الاستعادة',
      content: '⚠️ استعادة آخر نسخة ستمسح جميع البيانات الحالية. هل أنت متأكد؟',
      onConfirm: () async {
        bool success = await BackupService.restoreLatest();
        if (success) {
          _showSnackBar('✅ تم استعادة البيانات بنجاح');
        } else {
          _showSnackBar('❌ لا توجد نسخ متاحة للإعادة أو حدث خطأ', isError: true);
        }
      },
    );
  }

  // اختيار ملف للاستعادة
  void _handleRestoreFromFile() {
    _confirmAction(
      title: 'استعادة من ملف',
      content: '⚠️ استعادة النسخة ستمسح البيانات الحالية. هل أنت متأكد؟',
      onConfirm: () async {
        bool success = await BackupService.restoreFromPicker();
        if (success) {
          _showSnackBar('✅ تم استعادة البيانات من الملف بنجاح');
        } else {
          _showSnackBar('❌ لم يتم اختيار ملف أو حدث خطأ في العملية', isError: true);
        }
      },
    );
  }

  // استعادة ملف محدد من القائمة
  void _handleRestoreSpecificFile(BackupItem file) {
    _confirmAction(
      title: 'استعادة ${file.name}',
      content: '⚠️ استعادة هذا الملف ستمسح البيانات الحالية. هل أنت متأكد؟',
      onConfirm: () async {
        bool success = await BackupService.restoreFromPath(file.path);
        if (success) {
          _showSnackBar('✅ تم استعادة البيانات بنجاح');
        } else {
          _showSnackBar('❌ حدث خطأ أثناء استعادة الملف', isError: true);
        }
      },
    );
  }

  // حذف ملف نسخة
  Future<void> _handleDeleteBackup(BackupItem file) async {
    final theme = Theme.of(context);
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: theme.cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('حذف النسخة', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          content: Text('هل أنت متأكد من حذف ${file.name}؟', style: const TextStyle(fontSize: 13)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE74C3C),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );

    if (confirm == true) {
      bool deleted = await BackupService.deleteBackup(file.path);
      if (deleted) {
        _showSnackBar('✅ تم الحذف بنجاح');
        _loadBackupFiles();
      } else {
        _showSnackBar('❌ فشل الحذف', isError: true);
      }
    }
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
          title: const Text('💾 النسخ الاحتياطي',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          centerTitle: true,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(12.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // شعار وقسم ترويسي علوي
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.blueGrey.shade900 : const Color(0xFFEBF5FB),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.shield_outlined,
                          color: Color(0xFF3498DB), size: 42),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // شريط التنبيه/التحذير
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF3E2723) : const Color(0xFFFFF3CD),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.orange.shade800 : const Color(0xFFFFEEBA),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: isDark ? Colors.orange.shade300 : const Color(0xFF856404), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'تنبيه: استعادة أي نسخة ستمسح وتستبدل جميع البيانات الحالية.',
                            style: TextStyle(
                              color: isDark ? Colors.orange.shade200 : const Color(0xFF856404),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // قسم إنشاء النسخ
                  _buildSectionCard(
                    theme: theme,
                    title: '💾 إنشاء نسخة احتياطية جديدة',
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add_to_drive_rounded, size: 18),
                        label: const Text('حفظ نسخة في Downloads/SMSQaid',
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF27AE60),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                        ),
                        onPressed: _handleCreateBackup,
                      ),
                    ),
                  ),

                  // قسم خيارات الاستعادة
                  _buildSectionCard(
                    theme: theme,
                    title: '📂 استعادة البيانات',
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.history_rounded, size: 16),
                            label: const Text('استعادة آخر نسخة',
                                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE67E22),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 0,
                            ),
                            onPressed: _handleRestoreLatest,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.folder_open_rounded, size: 16),
                            label: const Text('اختر ملفاً',
                                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3498DB),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 0,
                            ),
                            onPressed: _handleRestoreFromFile,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // قسم قائمة النسخ المتاحة
                  _buildSectionCard(
                    theme: theme,
                    title: '📁 النسخ الاحتياطية المحفوظة',
                    child: _isLoading
                        ? const Center(
                            child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: CircularProgressIndicator(color: Color(0xFF27AE60))))
                        : _backupFiles.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(20.0),
                                child: Text('📭 لا توجد نسخ احتياطية محفوظة حالياً',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey, fontSize: 12)),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _backupFiles.length,
                                separatorBuilder: (ctx, idx) => Divider(
                                    height: 12, color: isDark ? Colors.grey.shade800 : const Color(0xFFEEEEEE)),
                                itemBuilder: (ctx, idx) {
                                  final file = _backupFiles[idx];
                                  return Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: isDark ? Colors.grey.shade800 : const Color(0xFFF2F4F8),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(Icons.insert_drive_file_outlined,
                                            color: Color(0xFF3498DB), size: 20),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(file.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                    color: isDark ? Colors.white : Colors.black87)),
                                            const SizedBox(height: 2),
                                            Text('${file.sizeKB} KB  •  ${file.date}',
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.restore_rounded, color: Color(0xFF3498DB), size: 20),
                                            tooltip: 'استعادة',
                                            onPressed: () => _handleRestoreSpecificFile(file),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE74C3C), size: 20),
                                            tooltip: 'حذف',
                                            onPressed: () => _handleDeleteBackup(file),
                                          ),
                                        ],
                                      )
                                    ],
                                  );
                                },
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

  Widget _buildSectionCard({required ThemeData theme, required String title, required Widget child}) {
    final isDark = theme.brightness == Brightness.dark;
    return Card(
      elevation: 1,
      color: theme.cardColor,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E2A36))),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
/*import 'package:flutter/material.dart';
import 'backup_service.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({Key? key}) : super(key: key);

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  List<BackupItem> _backupFiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBackupFiles();
  }

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

  Future<void> _loadBackupFiles() async {
    setState(() => _isLoading = true);
    final files = await BackupService.getBackupFilesList();
    setState(() {
      _backupFiles = files;
      _isLoading = false;
    });
  }

  Future<void> _confirmAction({
    required String title,
    required String content,
    required VoidCallback onConfirm,
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text(title,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            content: Text(content, style: const TextStyle(fontSize: 12)),
            actions: <Widget>[
              TextButton(
                child:
                    const Text('إلغاء', style: TextStyle(color: Colors.grey)),
                onPressed: () => Navigator.of(context).pop(),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE67E22)),
                child: const Text('تأكيد الاستعادة',
                    style: TextStyle(color: Colors.white, fontSize: 12)),
                onPressed: () {
                  Navigator.of(context).pop();
                  onConfirm();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // إنشاء نسخة
  Future<void> _handleCreateBackup() async {
    _showSnackBar('⏳ جاري الحفظ...');
    bool success = await BackupService.createBackup();
    if (success) {
      _showSnackBar('✅ تم حفظ النسخة الاحتياطية بنجاح');
      _loadBackupFiles();
    } else {
      _showSnackBar('❌ فشل إنشاء النسخة الاحتياطية', isError: true);
    }
  }

  // استعادة آخر نسخة
  void _handleRestoreLatest() {
    _confirmAction(
      title: 'تأكيد الاستعادة',
      content: '⚠️ استعادة آخر نسخة ستمسح جميع البيانات الحالية. هل أنت متأكد؟',
      onConfirm: () async {
        bool success = await BackupService.restoreLatest();
        if (success) {
          _showSnackBar('✅ تم استعادة البيانات بنجاح');
        } else {
          _showSnackBar('❌ لا توجد نسخ متاحة للإعادة أو حدث خطأ',
              isError: true);
        }
      },
    );
  }

  // اختيار ملف للاستعادة
  void _handleRestoreFromFile() {
    _confirmAction(
      title: 'استعادة من ملف',
      content: '⚠️ استعادة النسخة ستمسح البيانات الحالية. هل أنت متأكد؟',
      onConfirm: () async {
        bool success = await BackupService.restoreFromPicker();
        if (success) {
          _showSnackBar('✅ تم استعادة البيانات من الملف بنجاح');
        } else {
          _showSnackBar('❌ لم يتم اختيار ملف أو حدث خطأ في العملية',
              isError: true);
        }
      },
    );
  }

  // استعادة ملف محدد من القائمة
  void _handleRestoreSpecificFile(BackupItem file) {
    _confirmAction(
      title: 'استعادة ${file.name}',
      content: '⚠️ استعادة هذا الملف ستمسح البيانات الحالية. هل أنت متأكد؟',
      onConfirm: () async {
        bool success = await BackupService.restoreFromPath(file.path);
        if (success) {
          _showSnackBar('✅ تم استعادة البيانات بنجاح');
        } else {
          _showSnackBar('❌ حدث خطأ أثناء استعادة الملف', isError: true);
        }
      },
    );
  }

  // حذف ملف نسخة
  Future<void> _handleDeleteBackup(BackupItem file) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف النسخة', style: TextStyle(fontSize: 14)),
          content: Text('هل أنت متأكد من حذف ${file.name}؟',
              style: const TextStyle(fontSize: 12)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف', style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );

    if (confirm == true) {
      bool deleted = await BackupService.deleteBackup(file.path);
      if (deleted) {
        _showSnackBar('✅ تم الحذف');
        _loadBackupFiles();
      } else {
        _showSnackBar('❌ فشل الحذف', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F4F8),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E2A36),
          title: const Text('💾 النسخ الاحتياطي',
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
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(10.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // الشعار العلوي
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111111),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.shield,
                          color: Colors.white, size: 36),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // شريط التحذير
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3CD),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '⚠️ استعادة النسخة ستمسح جميع البيانات الحالية',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Color(0xFF856404),
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  ),

                  // قسم إنشاء النسخ
                  _buildSectionCard(
                    title: '💾 إنشاء نسخة',
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF27AE60),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25)),
                        padding: const EdgeInsets.symmetric(
                            vertical: 12), // التصحيح هنا
                        elevation: 0,
                      ),
                      onPressed: _handleCreateBackup,
                      child: const Text('💾 حفظ نسخة في Downloads/SMSQaid',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),

                  // قسم استعادة النسخ
                  _buildSectionCard(
                    title: '📂 استعادة نسخة',
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE67E22),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25)),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12), // التصحيح هنا
                              elevation: 0,
                            ),
                            onPressed: _handleRestoreLatest,
                            child: const Text('📂 استعادة آخر نسخة',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3498DB),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25)),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12), // التصحيح هنا
                              elevation: 0,
                            ),
                            onPressed: _handleRestoreFromFile,
                            child: const Text('📁 اختر ملف',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // قسم قائمة النسخ المتاحة
                  _buildSectionCard(
                    title: '📁 النسخ المتاحة',
                    child: _isLoading
                        ? const Center(
                            child: Padding(
                                padding: EdgeInsets.all(12.0),
                                child: CircularProgressIndicator()))
                        : _backupFiles.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(15.0),
                                child: Text('📭 لا توجد نسخ احتياطية',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 12)),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _backupFiles.length,
                                separatorBuilder: (ctx, idx) => const Divider(
                                    height: 1, color: Color(0xFFEEEEEE)),
                                itemBuilder: (ctx, idx) {
                                  final file = _backupFiles[idx];
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8.0),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text('📄 ${file.name}',
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 11)),
                                              const SizedBox(height: 2),
                                              Text(
                                                  '${file.sizeKB} KB - ${file.date}',
                                                  style: const TextStyle(
                                                      fontSize: 9,
                                                      color: Colors.grey)),
                                            ],
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            InkWell(
                                              onTap: () =>
                                                  _handleRestoreSpecificFile(
                                                      file),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 6),
                                                decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xFF3498DB),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10)),
                                                child: const Text('🔄',
                                                    style: TextStyle(
                                                        fontSize: 10,
                                                        color: Colors.white)),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            InkWell(
                                              onTap: () =>
                                                  _handleDeleteBackup(file),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 6),
                                                decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xFFE74C3C),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10)),
                                                child: const Text('🗑',
                                                    style: TextStyle(
                                                        fontSize: 10,
                                                        color: Colors.white)),
                                              ),
                                            ),
                                          ],
                                        )
                                      ],
                                    ),
                                  );
                                },
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

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50))),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}*/
