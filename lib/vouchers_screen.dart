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
    // إظهار نافذة اختيار التنسيق العصرية من الأسفل
    final bool? isPairMode = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => const ImportFormatBottomSheet(),
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
class ImportFormatBottomSheet extends StatefulWidget {
  const ImportFormatBottomSheet({Key? key}) : super(key: key);

  @override
  State<ImportFormatBottomSheet> createState() => _ImportFormatBottomSheetState();
}

class _ImportFormatBottomSheetState extends State<ImportFormatBottomSheet> {
  bool _selectedIsPair = false; 

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'تنسيق استيراد الكروت',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'اختر كيفية قراءة البيانات وتنسيقها من داخل الملف:',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            _buildOptionCard(
              title: 'رمز/قسيمة فردية',
              subtitle: 'كل خلية أو سطر يحتوي على كرت منفصل (رمز فقط)',
              icon: Icons.qr_code_rounded,
              isSelected: !_selectedIsPair,
              onTap: () => setState(() => _selectedIsPair = false),
              activeColor: const Color(0xFF0EA5E9),
              isDark: isDark,
            ),
            const SizedBox(height: 10),
            _buildOptionCard(
              title: 'اسم مستخدم وكلمة مرور',
              subtitle: 'دمج كل خليتين أو سطرين متتاليين كقسيمة واحدة (User,Pass)',
              icon: Icons.badge_outlined,
              isSelected: _selectedIsPair,
              onTap: () => setState(() => _selectedIsPair = true),
              activeColor: const Color(0xFF10B981),
              isDark: isDark,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => Navigator.pop(context, null),
                    child: const Text('إلغاء', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.file_open_rounded, size: 18),
                    label: const Text('متابعة واختيار الملف', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedIsPair ? const Color(0xFF10B981) : const Color(0xFF0EA5E9),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => Navigator.pop(context, _selectedIsPair),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required Color activeColor,
    required bool isDark,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isSelected
            ? activeColor.withOpacity(isDark ? 0.15 : 0.08)
            : (isDark ? Colors.black26 : const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? activeColor : (isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isSelected ? activeColor : Colors.grey.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: isSelected ? Colors.white : Colors.grey, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? activeColor : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 11, color: Colors.grey, height: 1.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Radio<bool>(
                value: true,
                groupValue: isSelected,
                activeColor: activeColor,
                onChanged: (_) => onTap(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
