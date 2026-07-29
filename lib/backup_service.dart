import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sqflite/sqflite.dart';
import 'package:file_picker/file_picker.dart';
import 'DatabaseHelper.dart';

class BackupItem {
  final String name;
  final String path;
  final String sizeKB;
  final String date;

  BackupItem({
    required this.name,
    required this.path,
    required this.sizeKB,
    required this.date,
  });
}

class BackupService {
  static const String _dbName = "smsqaiddb.db";

  static Future<Directory> _getBackupDirectory() async {
    Directory? externalDir;
    if (Platform.isAndroid) {
      externalDir = Directory('/storage/emulated/0/Download/SMSQaid');
    } else {
      final docs = await getApplicationDocumentsDirectory();
      externalDir = Directory(join(docs.path, 'SMSQaid'));
    }

    if (!await externalDir.exists()) {
      await externalDir.create(recursive: true);
    }
    return externalDir;
  }

  static Future<bool> _requestPermissions() async {
    if (Platform.isAndroid) {
      if (await Permission.storage.request().isGranted ||
          await Permission.manageExternalStorage.request().isGranted) {
        return true;
      }
    }
    return true;
  }

  /// 1. إنشاء نسخة احتياطية مع دمج ملفات WAL وضمان سلامة البيانات
  static Future<bool> createBackup() async {
    try {
      await _requestPermissions();

      final db = await DatabaseHelper.instance.database;
      
      // دمج جميع التغييرات المعلقة في ملف الـ DB الأساسي
      await db.rawQuery('PRAGMA checkpoint(FULL);');

      final dbPath = join(await getDatabasesPath(), _dbName);
      final dbFile = File(dbPath);

      if (!await dbFile.exists()) return false;

      final backupDir = await _getBackupDirectory();
      final String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final String newFileName = 'SMSQaid_Backup_$timestamp.db';
      final String targetPath = join(backupDir.path, newFileName);

      await dbFile.copy(targetPath);
      return true;
    } catch (e) {
      print("Error creating backup: $e");
      return false;
    }
  }

  /// 2. جلب قائمة النسخ
  static Future<List<BackupItem>> getBackupFilesList() async {
    try {
      final backupDir = await _getBackupDirectory();
      if (!await backupDir.exists()) return [];

      final List<FileSystemEntity> files = backupDir.listSync();
      final List<BackupItem> backups = [];

      for (var file in files) {
        if (file is File && file.path.endsWith('.db')) {
          final stat = await file.stat();
          final sizeInKB = (stat.size / 1024).toStringAsFixed(1);
          final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(stat.modified);
          final fileName = basename(file.path);

          backups.add(BackupItem(
            name: fileName,
            path: file.path,
            sizeKB: sizeInKB,
            date: dateStr,
          ));
        }
      }

      backups.sort((a, b) => b.name.compareTo(a.name));
      return backups;
    } catch (e) {
      print("Error getting backup files: $e");
      return [];
    }
  }

  /// 3. استعادة آمنة بقطع جميع الاتصالات وإزالة ملفات الـ WAL القديمة
  static Future<bool> restoreFromPath(String filePath) async {
    try {
      final backupFile = File(filePath);
      if (!await backupFile.exists()) return false;

      final databasesPath = await getDatabasesPath();
      final dbPath = join(databasesPath, _dbName);

      // 1. اغلاق قاعدة البيانات وإلغاء تهيئتها من Singleton
      await DatabaseHelper.instance.closeDatabase();

      // 2. إزالة ملفات WAL المؤقتة إن وجدت لتجنب التضارب
      final walFile = File('$dbPath-wal');
      final shmFile = File('$dbPath-shm');
      if (await walFile.exists()) await walFile.delete();
      if (await shmFile.exists()) await shmFile.delete();

      // 3. استبدال ملف قاعدة البيانات بالنسخة الاحتياطية
      await backupFile.copy(dbPath);

      // 4. إعادة فتح قاعدة البيانات للتأكد من سلامتها
      await DatabaseHelper.instance.database;

      return true;
    } catch (e) {
      print("Error restoring database: $e");
      return false;
    }
  }

  static Future<bool> restoreLatest() async {
    final list = await getBackupFilesList();
    if (list.isEmpty) return false;
    return await restoreFromPath(list.first.path);
  }

  static Future<bool> restoreFromPicker() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        return await restoreFromPath(result.files.single.path!);
      }
      return false;
    } catch (e) {
      print("Error picking backup file: $e");
      return false;
    }
  }

  static Future<bool> deleteBackup(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      print("Error deleting backup file: $e");
      return false;
    }
  }
}
/*import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sqflite/sqflite.dart';
import 'package:file_picker/file_picker.dart'; // تصحيح استيراد الحزمة
import 'DatabaseHelper.dart';

class BackupItem {
  final String name;
  final String path;
  final String sizeKB;
  final String date;

  BackupItem({
    required this.name,
    required this.path,
    required this.sizeKB,
    required this.date,
  });
}

class BackupService {
  static const String _dbName = "smsqaiddb.db";

  // الحصول على مجلد الحفظ في Downloads/SMSQaid
  static Future<Directory> _getBackupDirectory() async {
    Directory? externalDir;
    if (Platform.isAndroid) {
      externalDir = Directory('/storage/emulated/0/Download/SMSQaid');
    } else {
      final docs = await getApplicationDocumentsDirectory();
      externalDir = Directory(join(docs.path, 'SMSQaid'));
    }

    if (!await externalDir.exists()) {
      await externalDir.create(recursive: true); // تصحيح البرامتر
    }
    return externalDir;
  }

  // طلب صلاحيات التخزين
  static Future<bool> _requestPermissions() async {
    if (Platform.isAndroid) {
      if (await Permission.storage.request().isGranted ||
          await Permission.manageExternalStorage.request().isGranted) {
        return true;
      }
      return true;
    }
    return true;
  }

  /// 1. إنشاء نسخة احتياطية جديدة
  static Future<bool> createBackup() async {
    try {
      await _requestPermissions();

      final db = await DatabaseHelper.instance.database;
      await db.close();

      final dbPath = join(await getDatabasesPath(), _dbName);
      final dbFile = File(dbPath);

      if (!await dbFile.exists()) return false;

      final backupDir = await _getBackupDirectory();
      final String timestamp =
          DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final String newFileName = 'SMSQaid_Backup_$timestamp.db';
      final String targetPath = join(backupDir.path, newFileName);

      await dbFile.copy(targetPath);
      return true;
    } catch (e) {
      print("Error creating backup: $e");
      return false;
    }
  }

  /// 2. جلب قائمة النسخ الاحتياطية المتاحة
  static Future<List<BackupItem>> getBackupFilesList() async {
    try {
      final backupDir = await _getBackupDirectory();
      if (!await backupDir.exists()) return [];

      final List<FileSystemEntity> files = backupDir.listSync();
      final List<BackupItem> backups = [];

      for (var file in files) {
        if (file is File && file.path.endsWith('.db')) {
          final stat = await file.stat();
          final sizeInKB = (stat.size / 1024).toStringAsFixed(1);
          final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(stat.modified);
          final fileName = basename(file.path);

          backups.add(BackupItem(
            name: fileName,
            path: file.path,
            sizeKB: sizeInKB,
            date: dateStr,
          ));
        }
      }

      backups.sort((a, b) => b.name.compareTo(a.name));
      return backups;
    } catch (e) {
      print("Error getting backup files: $e");
      return [];
    }
  }

  /// 3. استعادة نسخة ملف محدد من المجلد
  static Future<bool> restoreFromPath(String filePath) async {
    try {
      final backupFile = File(filePath);
      if (!await backupFile.exists()) return false;

      final db = await DatabaseHelper.instance.database;
      await db.close();

      final dbPath = join(await getDatabasesPath(), _dbName);
      await backupFile.copy(dbPath);

      return true;
    } catch (e) {
      print("Error restoring database: $e");
      return false;
    }
  }

  /// 4. استعادة آخر نسخة احتياطية تلقائياً
  static Future<bool> restoreLatest() async {
    final list = await getBackupFilesList();
    if (list.isEmpty) return false;
    return await restoreFromPath(list.first.path);
  }

  /// 5. اختيار ملف يدوي من الجهاز
  static Future<bool> restoreFromPicker() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        return await restoreFromPath(result.files.single.path!);
      }
      return false;
    } catch (e) {
      print("Error picking backup file: $e");
      return false;
    }
  }

  /// 6. حذف ملف نسخة احتياطية
  static Future<bool> deleteBackup(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      print("Error deleting backup file: $e");
      return false;
    }
  }
}*/
