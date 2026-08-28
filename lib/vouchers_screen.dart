import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart' as intl;
import 'package:excel/excel.dart' hide Border;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'DatabaseHelper.dart';

class VouchersScreen extends StatefulWidget {
  const VouchersScreen({Key? key}) : super(key: key);

  @override
  State<VouchersScreen> createState() => _VouchersScreenState();
}

class _VouchersScreenState extends State<VouchersScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  bool _isUserPassMode = false; // خيار مفعل/مغلق لاسم المستخدم وكلمة المرور

  List<Map<String, dynamic>> _keywords = [];
  List<Map<String, dynamic>> _allNumbers = [];
  List<Map<String, dynamic>> _archiveList = [];

  String _currentFilter = 'available'; 
  String _selectedKeywordId = 'all';
  String? _selectedUsedKeyword;

  final TextEditingController _numbersController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _numbersController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final keywordsData = await _dbHelper.getAllKeywords();
    final numbersData = await _dbHelper.getAllNumbers();

    final db = await _dbHelper.database;
    final archiveData = await db.query(
      DatabaseHelper.tableReplyLog,
      where: 'is_deleted = 0 OR is_deleted IS NULL',
      orderBy: 'timestamp DESC',
    );

    if (!mounted) return;
    setState(() {
      _keywords = keywordsData;
      _allNumbers = numbersData;
      _archiveList = archiveData;
      _isLoading = false;
    });

    _refreshEditorText();
  }

  void _refreshEditorText() {
    if (_selectedKeywordId == 'all') {
      _numbersController.text = '';
      return;
    }

    final kwId = int.tryParse(_selectedKeywordId);
    if (kwId == null) return;

    if (_currentFilter == 'available') {
      final availableCodes = _allNumbers
          .where((n) => n['keyword_id'] == kwId && n['status'] == 'available')
          .map((n) => n['number_code'].toString())
          .toList();
      _numbersController.text = availableCodes.join('\n');
    } else {
      final usedCodes = _allNumbers
          .where((n) => n['keyword_id'] == kwId && n['status'] == 'used')
          .map((n) => n['number_code'].toString())
          .toList();
      _numbersController.text = usedCodes.join('\n');
    }
  }

  Future<void> _pickAndReadFile() async {
    if (_selectedKeywordId == 'all') {
      _showSnackBar('❌ يرجى اختيار باقة أولاً قبل قراءة الملف', isError: true);
      return;
    }
    // إظهار مربع التنبيه لتحديد نوع التنسيق
    final bool? isPairMode = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('تحديد تنسيق الملف', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: const Text('اختر نوع التنسيق الموجود داخل الملف المراد استيراده:', style: TextStyle(fontSize: 13)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9)),
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('اسم مستخدم فقط', style: TextStyle(color: Colors.white, fontSize: 12)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('اسم مستخدم وكلمة مرور', style: TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ],
        ),
      ),
    );

    if (isPairMode == null) return;
    
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'csv', 'xlsx', 'xls', 'pdf'],
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final extension = filePath.split('.').last.toLowerCase();

        List<String> extractedCodes = [];

        if (extension == 'xlsx' || extension == 'xls') {
          extractedCodes = await _parseExcelFile(filePath, isPair: isPairMode);
        } else if (extension == 'pdf') {
          extractedCodes = await _parsePdfFile(filePath, isPair: isPairMode);
        } else {
          extractedCodes = await _parseTxtFile(filePath, isPair: isPairMode);
        }
        /*if (extension == 'xlsx' || extension == 'xls') {
          extractedCodes = await _parseExcelFile(filePath, isPair: _isUserPassMode);
        } else if (extension == 'pdf') {
          extractedCodes = await _parsePdfFile(filePath, isPair: _isUserPassMode);
        } else {
          extractedCodes = await _parseTxtFile(filePath, isPair: _isUserPassMode);
        }*/
        /*if (extension == 'xlsx' || extension == 'xls') {
          extractedCodes = await _parseExcelFile(filePath);
        } else if (extension == 'pdf') {
          extractedCodes = await _parsePdfFile(filePath);
        } else {
          File file = File(filePath);
          String content = await file.readAsString();
          extractedCodes = content
              .split(RegExp(r'\r?\n'))
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }*/

        if (extractedCodes.isEmpty) {
          _showSnackBar('⚠️ لم يتم العثور على أرقام أو أكواد كروت داخل الملف', isError: true);
          return;
        }

        setState(() {
          String currentText = _numbersController.text.trim();
          String newAdded = extractedCodes.join('\n');
          if (currentText.isNotEmpty) {
            _numbersController.text = '$currentText\n$newAdded';
          } else {
            _numbersController.text = newAdded;
          }
        });

        _showSnackBar('✅ تمت قراءة واستخراج (${extractedCodes.length}) كرت من الملف');
      }
    } catch (e) {
      _showSnackBar('❌ فشل في قراءة الملف: $e', isError: true);
    }
  }

  Future<List<String>> _parseExcelFile(String path, {required bool isPair}) async {
    final bytes = File(path).readAsBytesSync();
    final excel = Excel.decodeBytes(bytes);
    
    List<String> codes = [];

    for (var table in excel.tables.keys) {
      var sheet = excel.tables[table]!;
      if (sheet.rows.isEmpty) continue;

      if (isPair) {
        // ON: كل صفين من نفس العمود قسيمة واحدة
        int maxCols = sheet.maxColumns;
        for (int col = 0; col < maxCols; col++) {
          for (int row = 0; row < sheet.rows.length - 1; row += 2) {
            // 🛡️ التعديل هنا: التأكد من أن العمود موجود داخل حدود هذا الصف لتجنب RangeError
            var userCell = col < sheet.rows[row].length 
                ? sheet.rows[row][col]?.value?.toString().trim() 
                : null;
                
            var passCell = col < sheet.rows[row + 1].length 
                ? sheet.rows[row + 1][col]?.value?.toString().trim() 
                : null;
            /*var userCell = sheet.rows[row][col]?.value?.toString().trim();
            var passCell = sheet.rows[row + 1][col]?.value?.toString().trim();*/

            if (userCell != null && userCell.isNotEmpty &&
                passCell != null && passCell.isNotEmpty) {
              codes.add('$userCell,$passCell');
            }
          }
        }
      } else {
        // OFF: كل خلية من أي عمود قسيمة منفصلة
        for (var row in sheet.rows) {
          for (var cell in row) {
            if (cell != null && cell.value != null) {
              String val = cell.value.toString().trim();
              if (val.isNotEmpty && !val.contains(RegExp(r'[^\w\d-]'))) {
                codes.add(val);
              }
            }
          }
        }
      }
    }
    return codes;
  }
  /*Future<List<String>> _parseExcelFile(String path) async {
    final bytes = File(path).readAsBytesSync();
    final excel = Excel.decodeBytes(bytes);
    List<String> codes = [];

    for (var table in excel.tables.keys) {
      for (var row in excel.tables[table]!.rows) {
        for (var cell in row) {
          if (cell != null && cell.value != null) {
            String val = cell.value.toString().trim();
            if (val.isNotEmpty && !val.contains(RegExp(r'[^\w\d-]'))) {
              codes.add(val);
            }
          }
        }
      }
    }
    return codes;
  }*/

  Future<List<String>> _parsePdfFile(String path, {required bool isPair}) async {
    final PdfDocument document = PdfDocument(inputBytes: File(path).readAsBytesSync());
    String text = PdfTextExtractor(document).extractText();
    document.dispose();

    if (isPair) {
      // ON: معالجة بالأعمدة (صفين متتاليين من نفس العمود)
      List<String> rawLines = text
          .split(RegExp(r'\r?\n'))
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      List<List<String>> grid = [];
      for (var line in rawLines) {
        List<String> colsInLine = RegExp(r'[A-Za-z0-9]{2,30}')
            .allMatches(line)
            .map((m) => m.group(0)!)
            .toList();
        if (colsInLine.isNotEmpty) {
          grid.add(colsInLine);
        }
      }

      List<String> codes = [];
      if (grid.isEmpty) return codes;

      int maxCols = 0;
      for (var row in grid) {
        if (row.length > maxCols) maxCols = row.length;
      }

      for (int col = 0; col < maxCols; col++) {
        for (int row = 0; row < grid.length - 1; row += 2) {
          if (col < grid[row].length && col < grid[row + 1].length) {
            String user = grid[row][col];
            String pass = grid[row + 1][col];
            codes.add('$user,$pass');
          }
        }
      }
      return codes;
    } else {
      // OFF: استخراج كافة العناصر كأكواد فردية
      final matches = RegExp(r'[A-Za-z0-9]{4,30}').allMatches(text);
      return matches.map((m) => m.group(0)!.trim()).toList();
    }
  }

  Future<List<String>> _parseTxtFile(String path, {required bool isPair}) async {
    File file = File(path);
    List<String> lines = (await file.readAsString())
        .split(RegExp(r'\r?\n'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    List<String> codes = [];

    if (isPair) {
      // ON: كل سطرين متتاليين كرت واحد
      for (int i = 0; i < lines.length - 1; i += 2) {
        String user = lines[i];
        String pass = lines[i + 1];
        codes.add('$user,$pass');
      }
    } else {
      // OFF: كل سطر قسيمة مستقلة
      codes.addAll(lines);
    }

    return codes;
  }
  /*Future<List<String>> _parsePdfFile(String path) async {
    final PdfDocument document = PdfDocument(inputBytes: File(path).readAsBytesSync());
    String text = PdfTextExtractor(document).extractText();
    document.dispose();

    final matches = RegExp(r'[A-Za-z0-9]{4,30}').allMatches(text);
    return matches.map((m) => m.group(0)!..trim()).toList();
  }*/

  Future<void> _saveNumbers() async {
    if (_selectedKeywordId == 'all' || _currentFilter != 'available') {
      _showSnackBar('❌ اختر باقة متاحة للتعديل والحفظ', isError: true);
      return;
    }

    final kwId = int.tryParse(_selectedKeywordId);
    if (kwId == null) return;

    List<String> lines = _numbersController.text
        .split(RegExp(r'\r?\n'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final currentAvailable = _allNumbers
        .where((n) => n['keyword_id'] == kwId && n['status'] == 'available')
        .toList();

    final currentCodes = currentAvailable.map((n) => n['number_code'].toString()).toSet();
    final newCodes = lines.toSet();

    final toAdd = newCodes.difference(currentCodes);
    final toDelete = currentAvailable
        .where((n) => !newCodes.contains(n['number_code'].toString()))
        .toList();

    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      for (var item in toDelete) {
        await txn.delete(
          DatabaseHelper.tableNumbersPool,
          where: 'id = ?',
          whereArgs: [item['id']],
        );
      }
      for (var code in toAdd) {
        await txn.insert(
          DatabaseHelper.tableNumbersPool,
          {
            'keyword_id': kwId,
            'number_code': code,
            'status': 'available',
          },
        );
      }
    });

    _showSnackBar('✅ تم الحفظ: +${toAdd.length} أرقام مضافة، -${toDelete.length} أرقام محذوفة');
    await _loadData();
  }

  Future<void> _deleteUsedCard(int archiveId) async {
    final bool? confirm = await _showConfirmDialog('حذف الكرت', 'هل تريد حذف هذا الكرت من الأرشيف؟');
    if (confirm != true) return;

    final db = await _dbHelper.database;
    await db.update(
      DatabaseHelper.tableReplyLog,
      {'is_deleted': 1},
      where: 'id = ?',
      whereArgs: [archiveId],
    );

    _showSnackBar('✅ تم الحذف من الأرشيف');
    _loadData();
  }

  Future<void> _deleteAllUsed() async {
    final bool? confirm = await _showConfirmDialog('⚠️ حذف الكل', 'هل أنت تأكد من حذف جميع الكروت المستخدمة من الأرشيف؟');
    if (confirm != true) return;

    final db = await _dbHelper.database;
    await db.update(
      DatabaseHelper.tableReplyLog,
      {'is_deleted': 1},
      where: 'sent_number IS NOT NULL AND sent_number != ""',
    );

    _showSnackBar('✅ تم حذف الأرشيف بالكامل');
    _loadData();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        backgroundColor: isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<bool?> _showConfirmDialog(String title, String content) {
    final theme = Theme.of(context);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: theme.cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Text(content, style: const TextStyle(fontSize: 13)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تأكيد', style: TextStyle(color: Colors.white, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
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
            'تغذية وإدارة الكروت',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: _loadData,
            )
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildFilterRow(isDark, cardBg, textColor),
                          const SizedBox(height: 14),
                          if (_currentFilter == 'available')
                            _buildKeywordAndToolsRow(isDark, cardBg, textColor),
                          const SizedBox(height: 14),
                          if (_currentFilter == 'available')
                            _buildEditorSection(isDark, cardBg, textColor)
                          else
                            _buildUsedCardsSection(isDark, cardBg, textColor),
                          const SizedBox(height: 16),
                          _buildFooterStats(isDark, cardBg, textColor),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildFilterRow(bool isDark, Color cardBg, Color textColor) {
    final activeColor = isDark ? const Color(0xFF38BDF8) : const Color(0xFF0F172A);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () {
                setState(() => _currentFilter = 'available');
                _refreshEditorText();
              },
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _currentFilter == 'available' ? activeColor.withOpacity(0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inventory_2_rounded,
                      size: 18,
                      color: _currentFilter == 'available' ? activeColor : Colors.grey,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'الكروت المتاحة',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: _currentFilter == 'available' ? FontWeight.bold : FontWeight.w500,
                        color: _currentFilter == 'available' ? activeColor : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () {
                setState(() => _currentFilter = 'used');
                _refreshEditorText();
              },
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _currentFilter == 'used' ? activeColor.withOpacity(0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.history_rounded,
                      size: 18,
                      color: _currentFilter == 'used' ? activeColor : Colors.grey,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'الكروت المستخدمة',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: _currentFilter == 'used' ? FontWeight.bold : FontWeight.w500,
                        color: _currentFilter == 'used' ? activeColor : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeywordAndToolsRow(bool isDark, Color cardBg, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            value: _selectedKeywordId,
            dropdownColor: cardBg,
            decoration: InputDecoration(
              labelText: 'الباقة المستهدفة',
              prefixIcon: const Icon(Icons.vpn_key_rounded, size: 20),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
            items: [
              const DropdownMenuItem(value: 'all', child: Text('اختر باقة للبدء...')),
              ..._keywords.map((k) {
                return DropdownMenuItem(
                  value: k['id'].toString(),
                  child: Text('${k['keyword']}'),
                );
              }).toList(),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() => _selectedKeywordId = val);
                _refreshEditorText();
              }
            },
          ),
          if (_selectedKeywordId != 'all') ...[
            /*const SizedBox(height: 8),
            // --- مفتاح التبديل ON / OFF ---
            SwitchListTile(
              title: const Text(
                'تنسيق (اسم مستخدم وكلمة مرور)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                _isUserPassMode
                    ? 'مفعل: سيتم قراءة كل خليتين/سطرين كقسيمة واحدة'
                    : 'مغلق: سيتم قراءة كل خلية/سطر كقسيمة منفصلة',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              value: _isUserPassMode,
              activeColor: const Color(0xFF10B981),
              contentPadding: EdgeInsets.zero,
              onChanged: (val) {
                setState(() {
                  _isUserPassMode = val;
                });
              },
            ),*/
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.note_add_rounded, size: 18),
                label: const Text('استيراد أكواد من ملف (Excel / PDF / TXT)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _pickAndReadFile,
              ),
            ),
          ]
        ],
      ),
    );
  }
  
  Widget _buildEditorSection(bool isDark, Color cardBg, Color textColor) {
    bool isAllSelected = _selectedKeywordId == 'all';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isAllSelected ? 'رجاء تحديد الباقة أولاً' : 'الأكواد والكروت (رمز في كل سطر)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _numbersController,
            enabled: !isAllSelected,
            maxLines: 9,
            textDirection: TextDirection.ltr,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              hintText: isAllSelected ? 'حدد باقة لتتمكن من إضافة وحفظ الكروت' : '1000123456\n1000123457\n1000123458',
              hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
              filled: true,
              fillColor: isDark ? Colors.black26 : const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 14),
          if (!isAllSelected)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check_circle_rounded, size: 20),
                label: const Text('حفظ التغييرات والقسائم', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _saveNumbers,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUsedCardsSection(bool isDark, Color cardBg, Color textColor) {
    Map<String, List<Map<String, dynamic>>> groupedUsed = {};
    for (var item in _archiveList) {
      String kw = item['matched_keyword']?.toString() ?? 'غير معروف';
      if (kw.isEmpty) kw = 'غير معروف';
      groupedUsed.putIfAbsent(kw, () => []).add(item);
    }

    if (groupedUsed.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Center(
          child: Text('لا توجد كروت مستخدمة مسبقاً', style: TextStyle(color: Colors.grey, fontSize: 13)),
        ),
      );
    }

    if (_selectedUsedKeyword == null || !groupedUsed.containsKey(_selectedUsedKeyword)) {
      _selectedUsedKeyword = groupedUsed.keys.first;
    }

    List<Map<String, dynamic>> currentUsedList = groupedUsed[_selectedUsedKeyword] ?? [];

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: groupedUsed.keys.map((kw) {
              bool isActive = _selectedUsedKeyword == kw;
              int count = groupedUsed[kw]?.length ?? 0;
              return Padding(
                padding: const EdgeInsets.only(left: 6.0),
                child: ChoiceChip(
                  label: Text('$kw ($count)'),
                  selected: isActive,
                  selectedColor: const Color(0xFF0EA5E9),
                  backgroundColor: cardBg,
                  labelStyle: TextStyle(
                    color: isActive ? Colors.white : textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedUsedKeyword = kw);
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: currentUsedList.length,
          itemBuilder: (ctx, idx) {
            final item = currentUsedList[idx];
            final dt = DateTime.fromMillisecondsSinceEpoch(item['timestamp'] ?? 0);
            final dateStr = intl.DateFormat('yyyy-MM-dd HH:mm').format(dt);
            final String senderName = (item['sender_name'] != null && item['sender_name'].toString().isNotEmpty)
                ? item['sender_name'].toString()
                : (item['sender'] ?? '-').toString();

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black26 : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item['sent_number'] ?? '-',
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('📅 $dateStr', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        const SizedBox(height: 2),
                        Text('👤 $senderName',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: textColor, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                    onPressed: () => _deleteUsedCard(item['id']),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.delete_sweep_rounded, size: 18),
            label: const Text('تفريغ الكروت المستخدمة', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
              side: const BorderSide(color: Color(0xFFEF4444)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: _deleteAllUsed,
          ),
        ),
      ],
    );
  }

  Widget _buildFooterStats(bool isDark, Color cardBg, Color textColor) {
    int totalCount = 0;
    int availCount = 0;
    int usedCount = 0;

    if (_selectedKeywordId != 'all') {
      final kwId = int.tryParse(_selectedKeywordId);
      final filtered = _allNumbers.where((n) => n['keyword_id'] == kwId).toList();
      availCount = filtered.where((n) => n['status'] == 'available').length;
      usedCount = filtered.where((n) => n['status'] == 'used').length;
      totalCount = availCount + usedCount;
    } else {
      totalCount = _allNumbers.length;
      availCount = _allNumbers.where((n) => n['status'] == 'available').length;
      usedCount = _allNumbers.where((n) => n['status'] == 'used').length;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatBox('الإجمالي', '$totalCount', const Color(0xFF0EA5E9), textColor),
          _buildStatBox('المتاحة', '$availCount', const Color(0xFF10B981), textColor),
          _buildStatBox('المستخدمة', '$usedCount', const Color(0xFFF59E0B), textColor),
        ],
      ),
    );
  }

  Widget _buildStatBox(String label, String value, Color color, Color textColor) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: textColor.withOpacity(0.6))),
      ],
    );
  }
}

//**************************** */
/*import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart' as intl;
import 'package:excel/excel.dart' hide Border;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'DatabaseHelper.dart';

class VouchersScreen extends StatefulWidget {
  const VouchersScreen({Key? key}) : super(key: key);

  @override
  State<VouchersScreen> createState() => _VouchersScreenState();
}

class _VouchersScreenState extends State<VouchersScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // البيانات والمجموعات
  List<Map<String, dynamic>> _keywords = [];
  List<Map<String, dynamic>> _allNumbers = [];
  List<Map<String, dynamic>> _archiveList = [];

  // حالات الواجهة
  String _currentFilter = 'available'; // 'available' أو 'used'
  String _selectedKeywordId = 'all';
  String? _selectedUsedKeyword;

  final TextEditingController _numbersController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _numbersController.dispose();
    super.dispose();
  }

  // ==========================================
  // 1. تحميل البيانات وتفريغها
  // ==========================================
  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final keywordsData = await _dbHelper.getAllKeywords();
    final numbersData = await _dbHelper.getAllNumbers();

    // جلب الأرشيف للحصول على الكروت المستخدمة
    final db = await _dbHelper.database;
    final archiveData = await db.query(
      DatabaseHelper.tableReplyLog,
      where: 'is_deleted = 0 OR is_deleted IS NULL',
      orderBy: 'timestamp DESC',
    );

    if (!mounted) return;
    setState(() {
      _keywords = keywordsData;
      _allNumbers = numbersData;
      _archiveList = archiveData;
      _isLoading = false;
    });

    _refreshEditorText();
  }

  void _refreshEditorText() {
    if (_selectedKeywordId == 'all') {
      _numbersController.text = '';
      return;
    }

    final kwId = int.tryParse(_selectedKeywordId);
    if (kwId == null) return;

    if (_currentFilter == 'available') {
      final availableCodes = _allNumbers
          .where((n) => n['keyword_id'] == kwId && n['status'] == 'available')
          .map((n) => n['number_code'].toString())
          .toList();
      _numbersController.text = availableCodes.join('\n');
    } else {
      final usedCodes = _allNumbers
          .where((n) => n['keyword_id'] == kwId && n['status'] == 'used')
          .map((n) => n['number_code'].toString())
          .toList();
      _numbersController.text = usedCodes.join('\n');
    }
  }

  // ==========================================
  // 2. إدارة وقراءة الملفات (Excel / PDF / TXT / CSV)
  // ==========================================
  Future<void> _pickAndReadFile() async {
    if (_selectedKeywordId == 'all') {
      _showSnackBar('❌ يرجى اختيار باقة أولاً قبل قراءة الملف', isError: true);
      return;
    }

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'csv', 'xlsx', 'xls', 'pdf'],
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final extension = filePath.split('.').last.toLowerCase();

        List<String> extractedCodes = [];

        if (extension == 'xlsx' || extension == 'xls') {
          extractedCodes = await _parseExcelFile(filePath);
        } else if (extension == 'pdf') {
          extractedCodes = await _parsePdfFile(filePath);
        } else {
          // TXT / CSV
          File file = File(filePath);
          String content = await file.readAsString();
          extractedCodes = content
              .split(RegExp(r'\r?\n'))
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }

        if (extractedCodes.isEmpty) {
          _showSnackBar('⚠️ لم يتم العثور على أرقام أو أكواد كروت داخل الملف',
              isError: true);
          return;
        }

        setState(() {
          String currentText = _numbersController.text.trim();
          String newAdded = extractedCodes.join('\n');
          if (currentText.isNotEmpty) {
            _numbersController.text = '$currentText\n$newAdded';
          } else {
            _numbersController.text = newAdded;
          }
        });

        _showSnackBar(
            '✅ تمت قراءة واستخراج (${extractedCodes.length}) كرت من الملف');
      }
    } catch (e) {
      _showSnackBar('❌ فشل في قراءة الملف: $e', isError: true);
    }
  }

  // استخراج الأكواد من ملفات إكسل
  Future<List<String>> _parseExcelFile(String path) async {
    final bytes = File(path).readAsBytesSync();
    final excel = Excel.decodeBytes(bytes);
    List<String> codes = [];

    for (var table in excel.tables.keys) {
      for (var row in excel.tables[table]!.rows) {
        for (var cell in row) {
          if (cell != null && cell.value != null) {
            String val = cell.value.toString().trim();
            if (val.isNotEmpty && !val.contains(RegExp(r'[^\w\d-]'))) {
              codes.add(val);
            }
          }
        }
      }
    }
    return codes;
  }

  // استخراج الأكواد من ملفات PDF
  Future<List<String>> _parsePdfFile(String path) async {
    final PdfDocument document =
        PdfDocument(inputBytes: File(path).readAsBytesSync());
    String text = PdfTextExtractor(document).extractText();
    document.dispose();

    // استخراج الكلمات أو المتسلسلات الرقمية
    final matches = RegExp(r'[A-Za-z0-9]{4,30}').allMatches(text);
    return matches.map((m) => m.group(0)!..trim()).toList();
  }

  
  // ==========================================
  // 4. حفظ الأرقام والمزامنة مع قاعدة البيانات
  // ==========================================
  Future<void> _saveNumbers() async {
    if (_selectedKeywordId == 'all' || _currentFilter != 'available') {
      _showSnackBar('❌ اختر باقة متاحة للتعديل والحفظ', isError: true);
      return;
    }

    final kwId = int.tryParse(_selectedKeywordId);
    if (kwId == null) return;

    // استخراج الكروت من النص وتصفية المكرر
    List<String> lines = _numbersController.text
        .split(RegExp(r'\r?\n'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    // جلب المتاح حالياً لهذا المعرف
    final currentAvailable = _allNumbers
        .where((n) => n['keyword_id'] == kwId && n['status'] == 'available')
        .toList();

    final currentCodes =
        currentAvailable.map((n) => n['number_code'].toString()).toSet();
    final newCodes = lines.toSet();

    // تحديد المضاف والمحذوف
    final toAdd = newCodes.difference(currentCodes);
    final toDelete = currentAvailable
        .where((n) => !newCodes.contains(n['number_code'].toString()))
        .toList();

    // تنفيذ العمليات بداخل Transaction لقواعد البيانات
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      for (var item in toDelete) {
        await txn.delete(
          DatabaseHelper.tableNumbersPool,
          where: 'id = ?',
          whereArgs: [item['id']],
        );
      }
      for (var code in toAdd) {
        await txn.insert(
          DatabaseHelper.tableNumbersPool,
          {
            'keyword_id': kwId,
            'number_code': code,
            'status': 'available',
          },
        );
      }
    });

    _showSnackBar(
        '✅ تم الحفظ: +${toAdd.length} أرقام مضافة، -${toDelete.length} أرقام محذوفة');
    await _loadData();
  }

  // ==========================================
  // 5. عمليات الأرشيف والكروت المستخدمة
  // ==========================================
  Future<void> _deleteUsedCard(int archiveId) async {
    final bool? confirm = await _showConfirmDialog(
        'حذف الكرت', 'هل تريد حذف هذا الكرت من الأرشيف؟');
    if (confirm != true) return;

    final db = await _dbHelper.database;
    await db.update(
      DatabaseHelper.tableReplyLog,
      {'is_deleted': 1},
      where: 'id = ?',
      whereArgs: [archiveId],
    );

    _showSnackBar('✅ تم الحذف من الأرشيف');
    _loadData();
  }

  Future<void> _deleteAllUsed() async {
    final bool? confirm = await _showConfirmDialog(
        '⚠️ حذف الكل', 'هل أنت تأكد من حذف جميع الكروت المستخدمة من الأرشيف؟');
    if (confirm != true) return;

    final db = await _dbHelper.database;
    await db.update(
      DatabaseHelper.tableReplyLog,
      {'is_deleted': 1},
      where: 'sent_number IS NOT NULL AND sent_number != ""',
    );

    _showSnackBar('✅ تم حذف الأرشيف بالكامل');
    _loadData();
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
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<bool?> _showConfirmDialog(String title, String content) {
    final theme = Theme.of(context);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: theme.cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Text(content, style: const TextStyle(fontSize: 13)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE74C3C)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تأكيد',
                  style: TextStyle(color: Colors.white, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 6. بناء واجهة المستخدم (UI Build)
  // ==========================================
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
          title: const Text('📦 إدارة تغذية الكروت',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          centerTitle: true,
          elevation: 0,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF27AE60)))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(12.0),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. شريط التصفية الأعلى (متاح / مستخدم)
                        _buildFilterRow(isDark, theme),
                        const SizedBox(height: 12),

                        // 2. اختيارات الباقة واستيراد الملف والتسلسل
                        if (_currentFilter == 'available')
                          _buildKeywordAndToolsRow(isDark, theme),

                        const SizedBox(height: 12),

                        // 3. المحتوى الرئيسي
                        if (_currentFilter == 'available')
                          _buildEditorSection(isDark, theme)
                        else
                          _buildUsedCardsSection(isDark, theme),

                        const SizedBox(height: 12),

                        // 4. إحصائيات أسفل الصفحة
                        _buildFooterStats(isDark, theme),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  // شريط التصفية الرئيسي (متاح / مستخدم)
  Widget _buildFilterRow(bool isDark, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.move_to_inbox_rounded, size: 18),
              label: const Text('📥 الكروت المتاحة', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _currentFilter == 'available'
                    ? const Color(0xFF27AE60)
                    : Colors.transparent,
                foregroundColor: _currentFilter == 'available'
                    ? Colors.white
                    : (isDark ? Colors.grey.shade300 : Colors.black87),
                elevation: 0,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onPressed: () {
                setState(() => _currentFilter = 'available');
                _refreshEditorText();
              },
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.outbox_rounded, size: 18),
              label: const Text('📤 الكروت المستخدمة', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _currentFilter == 'used'
                    ? const Color(0xFF27AE60)
                    : Colors.transparent,
                foregroundColor: _currentFilter == 'used'
                    ? Colors.white
                    : (isDark ? Colors.grey.shade300 : Colors.black87),
                elevation: 0,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onPressed: () {
                setState(() => _currentFilter = 'used');
                _refreshEditorText();
              },
            ),
          ),
        ],
      ),
    );
  }

  // صف القائمة المنسدلة وأزرار الأدوات (ملفات / تسلسل)
  Widget _buildKeywordAndToolsRow(bool isDark, ThemeData theme) {
    return Card(
      elevation: 1,
      color: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade800 : const Color(0xFFF2F4F8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        dropdownColor: theme.cardColor,
                        value: _selectedKeywordId,
                        isExpanded: true,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87),
                        items: [
                          const DropdownMenuItem(
                              value: 'all', child: Text('📌 اختر باقة لتغذيتها...')),
                          ..._keywords.map((k) {
                            return DropdownMenuItem(
                              value: k['id'].toString(),
                              child: Text('🔑 باقة ${k['keyword']}'),
                            );
                          }).toList(),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedKeywordId = val);
                            _refreshEditorText();
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_selectedKeywordId != 'all') ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.attach_file_rounded, size: 16),
                      label: const Text('استيراد من ملف', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF3498DB),
                        side: const BorderSide(color: Color(0xFF3498DB)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onPressed: _pickAndReadFile,
                    ),
                  ),
                  //const SizedBox(width: 8),
                  /*Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.format_list_numbered_rtl_rounded, size: 16),
                      label: const Text('توليد متسلسل', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF8E44AD),
                        side: const BorderSide(color: Color(0xFF8E44AD)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onPressed: _showRangeGeneratorDialog,
                    ),
                  ),*/
                ],
              ),
            ]
          ],
        ),
      ),
    );
  }

  // محرر الكروت المتاحة
  Widget _buildEditorSection(bool isDark, ThemeData theme) {
    bool isAllSelected = _selectedKeywordId == 'all';

    return Card(
      elevation: 1.5,
      color: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isAllSelected ? Icons.info_outline : Icons.edit_note_rounded,
                  color: const Color(0xFF27AE60),
                ),
                const SizedBox(width: 8),
                Text(
                  isAllSelected
                      ? 'حدد الباقة أولاً للبدء بإضافة الكروت'
                      : 'قائمة الكروت (كل كرت في سطر)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _numbersController,
              enabled: !isAllSelected,
              maxLines: 10,
              textDirection: TextDirection.ltr,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.greenAccent : const Color(0xFF1E2A36),
              ),
              decoration: InputDecoration(
                hintText: isAllSelected
                    ? 'اختر باقة من القائمة اعلاه...'
                    : 'أدخل الأكواد/الأرقام هنا...\nمثال:\n1001\n1002\n1003',
                hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                fillColor: isDark
                    ? (isAllSelected ? Colors.grey.shade900 : Colors.grey.shade800)
                    : (isAllSelected ? const Color(0xFFF5F5F5) : const Color(0xFFFAFAFA)),
                filled: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300)),
              ),
            ),
            const SizedBox(height: 12),
            if (!isAllSelected)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: const Text('💾 حفظ الكروت في قاعدة البيانات',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF27AE60),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _saveNumbers,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // قسم الكروت المستخدمة والأرشيف
  Widget _buildUsedCardsSection(bool isDark, ThemeData theme) {
    Map<String, List<Map<String, dynamic>>> groupedUsed = {};
    for (var item in _archiveList) {
      String kw = item['matched_keyword']?.toString() ?? 'غير معروف';
      if (kw.isEmpty) kw = 'غير معروف';
      groupedUsed.putIfAbsent(kw, () => []).add(item);
    }

    if (groupedUsed.isEmpty) {
      return Card(
        color: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.all(30),
          child: Center(
              child: Text('📭 لا توجد كروت مستخدمة في الأرشيف حالياً',
                  style: TextStyle(color: Colors.grey, fontSize: 13))),
        ),
      );
    }

    if (_selectedUsedKeyword == null ||
        !groupedUsed.containsKey(_selectedUsedKeyword)) {
      _selectedUsedKeyword = groupedUsed.keys.first;
    }

    List<Map<String, dynamic>> currentUsedList =
        groupedUsed[_selectedUsedKeyword] ?? [];

    return Column(
      children: [
        // تابات الباقات للكروت المستخدمة
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: groupedUsed.keys.map((kw) {
              bool isActive = _selectedUsedKeyword == kw;
              int count = groupedUsed[kw]?.length ?? 0;
              return Padding(
                padding: const EdgeInsets.only(left: 6.0),
                child: ChoiceChip(
                  label: Text('باقة $kw ($count)'),
                  selected: isActive,
                  selectedColor: const Color(0xFF27AE60),
                  backgroundColor: isDark ? Colors.grey.shade800 : Colors.white,
                  labelStyle: TextStyle(
                      color: isActive ? Colors.white : (isDark ? Colors.grey.shade300 : Colors.black87),
                      fontWeight: FontWeight.bold,
                      fontSize: 11),
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedUsedKeyword = kw);
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),

        // قائمة العناصر المستخدمة
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: currentUsedList.length,
          itemBuilder: (ctx, idx) {
            final item = currentUsedList[idx];
            final dt =
                DateTime.fromMillisecondsSinceEpoch(item['timestamp'] ?? 0);
            final dateStr = intl.DateFormat('yyyy-MM-dd HH:mm').format(dt);

            final String senderName =
                (item['sender_name'] != null && item['sender_name'].toString().isNotEmpty)
                    ? item['sender_name'].toString()
                    : (item['sender'] ?? '-').toString();

            return Card(
              elevation: 1,
              color: theme.cardColor,
              margin: const EdgeInsets.only(bottom: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey.shade800 : const Color(0xFFF2F4F8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item['sent_number'] ?? '-',
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.greenAccent : const Color(0xFF1E2A36),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('📅 $dateStr',
                              style: TextStyle(fontSize: 10, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                          const SizedBox(height: 2),
                          Text('👤 $senderName',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFFE74C3C), size: 18),
                      onPressed: () => _deleteUsedCard(item['id']),
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.delete_sweep_rounded, size: 18),
            label: const Text('حذف كافة الكروت المستخدمة من الأرشيف',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFE74C3C),
              side: const BorderSide(color: Color(0xFFE74C3C)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onPressed: _deleteAllUsed,
          ),
        ),
      ],
    );
  }

  // كرت الإحصائيات في أسفل الواجهة
  Widget _buildFooterStats(bool isDark, ThemeData theme) {
    int totalCount = 0;
    int availCount = 0;
    int usedCount = 0;

    if (_selectedKeywordId != 'all') {
      final kwId = int.tryParse(_selectedKeywordId);
      final filtered =
          _allNumbers.where((n) => n['keyword_id'] == kwId).toList();
      availCount = filtered.where((n) => n['status'] == 'available').length;
      usedCount = filtered.where((n) => n['status'] == 'used').length;
      totalCount = availCount + usedCount;
    } else {
      totalCount = _allNumbers.length;
      availCount = _allNumbers.where((n) => n['status'] == 'available').length;
      usedCount = _allNumbers.where((n) => n['status'] == 'used').length;
    }

    return Card(
      elevation: 1,
      color: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatBox('الإجمالي', totalCount.toString(), isDark ? Colors.blue.shade300 : const Color(0xFF1976D2), isDark),
            _buildStatBox('📥 المتاح', availCount.toString(), const Color(0xFF27AE60), isDark),
            _buildStatBox('📤 المستخدم', usedCount.toString(), isDark ? Colors.amber.shade300 : const Color(0xFFE67E22), isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBox(String label, String value, Color color, bool isDark) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
      ],
    );
  }
}*/
/*import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart' as intl;
import 'DatabaseHelper.dart'; // تأكد من استدعاء ملف قاعدة البيانات الخاص بك

class VouchersScreen extends StatefulWidget {
  const VouchersScreen({Key? key}) : super(key: key);

  @override
  State<VouchersScreen> createState() => _VouchersScreenState();
}

class _VouchersScreenState extends State<VouchersScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // البيانات والمجموعات
  List<Map<String, dynamic>> _keywords = [];
  List<Map<String, dynamic>> _allNumbers = [];
  List<Map<String, dynamic>> _archiveList = [];

  // حالات الواجهة
  String _currentFilter = 'available'; // 'available' أو 'used'
  String _selectedKeywordId = 'all';
  String? _selectedUsedKeyword;

  final TextEditingController _numbersController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _numbersController.dispose();
    super.dispose();
  }

  // ==========================================
  // 1. تحميل البيانات وتفريغها
  // ==========================================
  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final keywordsData = await _dbHelper.getAllKeywords();
    final numbersData = await _dbHelper.getAllNumbers();

    // جلب الأرشيف للحصول على الكروت المستخدمة
    final db = await _dbHelper.database;
    final archiveData = await db.query(
      DatabaseHelper.tableReplyLog,
      where: 'is_deleted = 0 AND sent_number IS NOT NULL AND sent_number != ""',
      orderBy: 'timestamp DESC',
    );

    setState(() {
      _keywords = keywordsData;
      _allNumbers = numbersData;
      _archiveList = archiveData;
      _isLoading = false;
    });

    _refreshEditorText();
  }

  void _refreshEditorText() {
    if (_selectedKeywordId == 'all') {
      _numbersController.text = '';
      return;
    }

    final kwId = int.tryParse(_selectedKeywordId);
    if (kwId == null) return;

    if (_currentFilter == 'available') {
      final availableCodes = _allNumbers
          .where((n) => n['keyword_id'] == kwId && n['status'] == 'available')
          .map((n) => n['number_code'].toString())
          .toList();
      _numbersController.text = availableCodes.join('\n');
    } else {
      final usedCodes = _allNumbers
          .where((n) => n['keyword_id'] == kwId && n['status'] == 'used')
          .map((n) => n['number_code'].toString())
          .toList();
      _numbersController.text = usedCodes.join('\n');
    }
  }

  // ==========================================
  // 2. إدارة وقراءة الملفات (TXT / CSV)
  // ==========================================
  Future<void> _pickAndReadFile() async {
    if (_selectedKeywordId == 'all') {
      _showSnackBar('❌ يرجى اختيار باقة أولاً قبل قراءة الملف', isError: true);
      return;
    }

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'csv'],
      );

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        String content = await file.readAsString();

        setState(() {
          String currentText = _numbersController.text.trim();
          if (currentText.isNotEmpty) {
            _numbersController.text = '$currentText\n${content.trim()}';
          } else {
            _numbersController.text = content.trim();
          }
        });

        _showSnackBar('✅ تمت إضافة الكروت من الملف بنجاح');
      }
    } catch (e) {
      _showSnackBar('❌ فشل في قراءة الملف: $e', isError: true);
    }
  }

  // ==========================================
  // 3. حفظ الأرقام والمزامنة مع قاعدة البيانات
  // ==========================================
  Future<void> _saveNumbers() async {
    if (_selectedKeywordId == 'all' || _currentFilter != 'available') {
      _showSnackBar('❌ اختر باقة متاحة للتعديل والحفظ', isError: true);
      return;
    }

    final kwId = int.tryParse(_selectedKeywordId);
    if (kwId == null) return;

    // استخراج الكروت من النص
    List<String> lines = _numbersController.text
        .split(RegExp(r'\r?\n'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    // جلب المتاح حالياً لهذا المعرف
    final currentAvailable = _allNumbers
        .where((n) => n['keyword_id'] == kwId && n['status'] == 'available')
        .toList();

    final currentCodes =
        currentAvailable.map((n) => n['number_code'].toString()).toSet();
    final newCodes = lines.toSet();

    // تحديد المضاف والمحذوف
    final toAdd = newCodes.difference(currentCodes);
    final toDelete = currentAvailable
        .where((n) => !newCodes.contains(n['number_code'].toString()))
        .toList();

    // تنفيذ العمليات بداخل Transaction لقواعد البيانات
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      for (var item in toDelete) {
        await txn.delete(
          DatabaseHelper.tableNumbersPool,
          where: 'id = ?',
          whereArgs: [item['id']],
        );
      }
      for (var code in toAdd) {
        await txn.insert(
          DatabaseHelper.tableNumbersPool,
          {
            'keyword_id': kwId,
            'number_code': code,
            'status': 'available',
          },
        );
      }
    });

    _showSnackBar(
        '✅ تم الحفظ: +${toAdd.length} أرقام، -${toDelete.length} أرقام');
    await _loadData();
  }

  // ==========================================
  // 4. عمليات الأرشيف والكروت المستخدمة
  // ==========================================
  Future<void> _deleteUsedCard(int archiveId) async {
    final bool? confirm = await _showConfirmDialog(
        'حذف الكرت', 'هل تريد حذف هذا الكرت من الأرشيف؟');
    if (confirm != true) return;

    final db = await _dbHelper.database;
    await db.update(
      DatabaseHelper.tableReplyLog,
      {'is_deleted': 1},
      where: 'id = ?',
      whereArgs: [archiveId],
    );

    _showSnackBar('✅ تم الحذف من الأرشيف');
    _loadData();
  }

  Future<void> _deleteAllUsed() async {
    final bool? confirm = await _showConfirmDialog(
        '⚠️ حذف الكل', 'هل أنت تأكد من حذف جميع الكروت المستخدمة من الأرشيف؟');
    if (confirm != true) return;

    final db = await _dbHelper.database;
    await db.update(
      DatabaseHelper.tableReplyLog,
      {'is_deleted': 1},
      where: 'sent_number IS NOT NULL AND sent_number != ""',
    );

    _showSnackBar('✅ تم حذف الأرشيف بالكامل');
    _loadData();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Segoe UI')),
        backgroundColor:
            isError ? Colors.red.shade700 : const Color(0xFF27AE60),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<bool?> _showConfirmDialog(String title, String content) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, textDirection: TextDirection.rtl),
        content: Text(content, textDirection: TextDirection.rtl),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 5. بناء واجهة المستخدم (UI Build)
  // ==========================================
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F4F8),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E2A36),
          title: const Text('📦 إدارة تغذية الكروت',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          centerTitle: true,
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(12.0),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // شريط التصفية الأعلى (متاح / مستخدم)
                        _buildFilterRow(),
                        const SizedBox(height: 12),

                        // اختيارات الباقة واستيراد الملف (تختفي في قسم المستخدم)
                        if (_currentFilter == 'available')
                          _buildKeywordAndFileRow(),

                        const SizedBox(height: 12),

                        // المحتوى الرئيسي
                        if (_currentFilter == 'available')
                          _buildEditorSection()
                        else
                          _buildUsedCardsSection(),

                        const SizedBox(height: 12),

                        // إحصائيات أسفل الصفحة
                        _buildFooterStats(),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  // شريط التصفية الرئيسي
  Widget _buildFilterRow() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(50),
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.move_to_inbox, size: 18),
              label: const Text('📥 متاح'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _currentFilter == 'available'
                    ? const Color(0xFF2C3E50)
                    : const Color(0xFFF1F3F5),
                foregroundColor: _currentFilter == 'available'
                    ? Colors.white
                    : Colors.black87,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () {
                setState(() => _currentFilter = 'available');
                _refreshEditorText();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.outbox, size: 18),
              label: const Text('📤 مستخدم'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _currentFilter == 'used'
                    ? const Color(0xFF2C3E50)
                    : const Color(0xFFF1F3F5),
                foregroundColor:
                    _currentFilter == 'used' ? Colors.white : Colors.black87,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () {
                setState(() => _currentFilter = 'used');
                _refreshEditorText();
              },
            ),
          ),
        ],
      ),
    );
  }

  // صف القائمة المنسدلة وزر اختيار الملف
  Widget _buildKeywordAndFileRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(60),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedKeywordId,
                isExpanded: true,
                items: [
                  const DropdownMenuItem(
                      value: 'all', child: Text('كل الباقات')),
                  ..._keywords.map((k) {
                    return DropdownMenuItem(
                      value: k['id'].toString(),
                      child: Text('🔑 ${k['keyword']}'),
                    );
                  }).toList(),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedKeywordId = val);
                    _refreshEditorText();
                  }
                },
              ),
            ),
          ),
          if (_selectedKeywordId != 'all') ...[
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.folder_open, size: 16),
                label: const Text('📂 قراءة من ملف',
                    style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3498DB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(40)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onPressed: _pickAndReadFile,
              ),
            ),
          ]
        ],
      ),
    );
  }

  // محرر الكروت المتاحة
  Widget _buildEditorSection() {
    bool isAllSelected = _selectedKeywordId == 'all';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isAllSelected
                ? '📌 اختر باقة أولاً'
                : '✏️ الكروت المتاحة (قابلة للتعديل)',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _numbersController,
            enabled: !isAllSelected,
            maxLines: 10,
            textDirection: TextDirection.ltr, // اتجاه الأكواد LTR
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: InputDecoration(
              hintText: isAllSelected
                  ? 'اختر باقة لعرض وتعديل الكروت...'
                  : 'أدخل كل كرت في سطر مستقل...',
              fillColor: isAllSelected
                  ? const Color(0xFFF5F5F5)
                  : const Color(0xFFFEFEF5),
              filled: true,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Colors.grey)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isAllSelected
                ? ''
                : '✅ يمكنك إضافة أو حذف الكروت يدوياً ثم الضغط على حفظ.',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          if (!isAllSelected)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('💾 حفظ التغييرات',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF27AE60),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(60)),
                ),
                onPressed: _saveNumbers,
              ),
            ),
        ],
      ),
    );
  }

  // قسم الكروت المستخدمة والأرشيف
  Widget _buildUsedCardsSection() {
    // تجميع الكروت الأرشيفية بحسب الكلمة المفتاحية
    Map<String, List<Map<String, dynamic>>> groupedUsed = {};
    for (var item in _archiveList) {
      String kw = item['matched_keyword']?.toString() ?? 'غير معروف';
      if (kw.isEmpty) kw = 'غير معروف';
      groupedUsed.putIfAbsent(kw, () => []).add(item);
    }

    if (groupedUsed.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(28)),
        child:
            const Center(child: Text('لا توجد كروت مستخدمة في الأرشيف حالياً')),
      );
    }

    // تحديد التاب النشط
    if (_selectedUsedKeyword == null ||
        !groupedUsed.containsKey(_selectedUsedKeyword)) {
      _selectedUsedKeyword = groupedUsed.keys.first;
    }

    List<Map<String, dynamic>> currentUsedList =
        groupedUsed[_selectedUsedKeyword] ?? [];

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: const Color(0xFF2C3E50),
              borderRadius: BorderRadius.circular(14)),
          child: const Text('📤 سجل الكروت المرسلة',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 8),

        // تابات الكلمات المفتاحية
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: groupedUsed.keys.map((kw) {
              bool isActive = _selectedUsedKeyword == kw;
              int count = groupedUsed[kw]?.length ?? 0;
              return Padding(
                padding: const EdgeInsets.only(left: 6.0),
                child: ChoiceChip(
                  label: Text('$kw ($count)'),
                  selected: isActive,
                  selectedColor: const Color(0xFF1976D2),
                  labelStyle: TextStyle(
                      color: isActive ? Colors.white : const Color(0xFF1976D2),
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedUsedKeyword = kw);
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),

        // قائمة العناصر المستخدمة
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: currentUsedList.length,
          itemBuilder: (ctx, idx) {
            final item = currentUsedList[idx];
            final dt =
                DateTime.fromMillisecondsSinceEpoch(item['timestamp'] ?? 0);
            final dateStr = intl.DateFormat('yyyy-MM-dd HH:mm').format(dt);

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              child: ListTile(
                title: Text(item['sent_number'] ?? '',
                    style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
                subtitle: Text(
                    '📅 $dateStr | 👤 ${item['sender_name'] ?? item['sender'] ?? '-'}',
                    style: const TextStyle(fontSize: 11)),
                trailing: IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () => _deleteUsedCard(item['id']),
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.delete_forever, size: 16),
                label: const Text('حذف الكل من الأرشيف',
                    style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE74C3C),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: _deleteAllUsed,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // كرت الإحصائيات في أسفل الواجهة
  Widget _buildFooterStats() {
    int totalCount = 0;
    int availCount = 0;
    int usedCount = 0;

    if (_selectedKeywordId != 'all') {
      final kwId = int.tryParse(_selectedKeywordId);
      final filtered =
          _allNumbers.where((n) => n['keyword_id'] == kwId).toList();
      availCount = filtered.where((n) => n['status'] == 'available').length;
      usedCount = filtered.where((n) => n['status'] == 'used').length;
      totalCount = availCount + usedCount;
    } else {
      totalCount = _allNumbers.length;
      availCount = _allNumbers.where((n) => n['status'] == 'available').length;
      usedCount = _allNumbers.where((n) => n['status'] == 'used').length;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(28)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatBox('الإجمالي', totalCount.toString(), Colors.blueGrey),
          _buildStatBox(
              '📥 متاح', availCount.toString(), const Color(0xFF1F6E43)),
          _buildStatBox(
              '📤 مستخدم', usedCount.toString(), Colors.orange.shade800),
        ],
      ),
    );
  }

  Widget _buildStatBox(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}*/
