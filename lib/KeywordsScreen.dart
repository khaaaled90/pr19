import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'DatabaseHelper.dart'; // تأكد أن ملف DatabaseHelper في نفس المجلد

class KeywordsScreen extends StatefulWidget {
  const KeywordsScreen({super.key});

  @override
  State<KeywordsScreen> createState() => _KeywordsScreenState();
}

class _KeywordsScreenState extends State<KeywordsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  List<Map<String, dynamic>> _keywords = [];
  Map<int, Map<String, int>> _vouchersCountMap = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// تحميل الباقات وإحصائيات القسائم
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final allKeywords = await _dbHelper.getAllKeywords();
      final allNumbers = await _dbHelper.getAllNumbers();

      final filteredKeywords = allKeywords
          .where((k) => k['is_offer'] == 0 || k['is_offer'] == null)
          .toList();

      Map<int, Map<String, int>> counts = {};
      for (var k in filteredKeywords) {
        int kId = k['id'];
        int avail = allNumbers
            .where((n) => n['keyword_id'] == kId && n['status'] == 'available')
            .length;
        int used = allNumbers
            .where((n) => n['keyword_id'] == kId && n['status'] == 'used')
            .length;
        counts[kId] = {'available': avail, 'used': used};
      }

      if (!mounted) return;
      setState(() {
        _keywords = filteredKeywords;
        _vouchersCountMap = counts;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackBar('❌ حدث خطأ أثناء تحميل البيانات: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor:
            isError ? const Color(0xFFE74C3C) : const Color(0xFF27AE60),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        duration: const Duration(milliseconds: 2500),
      ),
    );
  }

  void _showKeywordDialog({Map<String, dynamic>? keywordToEdit}) {
    final isEditing = keywordToEdit != null;

    final TextEditingController keywordController = TextEditingController(
      text: isEditing ? keywordToEdit['keyword'].toString() : '',
    );
    final TextEditingController descController = TextEditingController(
      text: isEditing ? (keywordToEdit['description'] ?? '') : '',
    );
    final TextEditingController targetCountController = TextEditingController(
      text: isEditing ? (keywordToEdit['target_count'] ?? 0).toString() : '0',
    );
    final TextEditingController rewardQtyController = TextEditingController(
      text: isEditing ? (keywordToEdit['reward_qty'] ?? 1).toString() : '1',
    );

    int isActive = isEditing ? (keywordToEdit['is_active'] ?? 1) : 1;
    bool hasReward = isEditing && (keywordToEdit['target_count'] ?? 0) > 0;
    int? selectedRewardKeywordId =
        isEditing ? keywordToEdit['reward_keyword_id'] : null;

    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  Icon(
                    isEditing ? Icons.edit_note_rounded : Icons.add_box_rounded,
                    color: const Color(0xFF27AE60),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isEditing ? 'تعديل باقة' : 'إضافة باقة جديدة',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: keywordController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'رمز/اسم الباقة (مثال: 100)',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16)),
                        prefixIcon: const Icon(Icons.style_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'وصف الباقة (اختياري)',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16)),
                        prefixIcon: const Icon(Icons.description_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: isActive,
                      decoration: InputDecoration(
                        labelText: 'حالة الباقة',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16)),
                        prefixIcon: const Icon(Icons.toggle_on_rounded),
                      ),
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('🟢 مفعلة')),
                        DropdownMenuItem(value: 0, child: Text('🔴 معطلة')),
                      ],
                      onChanged: (val) =>
                          setDialogState(() => isActive = val ?? 1),
                    ),
                    const Divider(height: 24, thickness: 1),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('تفعيل نظام المكافآت',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle:
                          const Text('منح قسيمة مجانية عند الشراء التكراري'),
                      value: hasReward,
                      activeColor: const Color(0xFF27AE60),
                      onChanged: (val) {
                        setDialogState(() {
                          hasReward = val;
                          if (!val) {
                            targetCountController.text = '0';
                            selectedRewardKeywordId = null;
                          }
                        });
                      },
                    ),
                    if (hasReward) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: targetCountController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: InputDecoration(
                          labelText: 'العدد المستهدف (كم مرة يشتري؟)',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16)),
                          prefixIcon:
                              const Icon(Icons.shopping_cart_checkout_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int?>(
                        value: selectedRewardKeywordId,
                        decoration: InputDecoration(
                          labelText: 'باقة القسيمة المجانية (الهدية)',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16)),
                          prefixIcon: const Icon(Icons.card_giftcard_rounded),
                        ),
                        items: _keywords.map((k) {
                          return DropdownMenuItem<int?>(
                            value: k['id'] as int,
                            child: Text('باقة ${k['keyword']}'),
                          );
                        }).toList(),
                        onChanged: (val) =>
                            setDialogState(() => selectedRewardKeywordId = val),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: rewardQtyController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: InputDecoration(
                          labelText: 'عدد قسائم الهدية',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16)),
                          prefixIcon: const Icon(Icons.numbers_rounded),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      isSaving ? null : () => Navigator.pop(dialogContext),
                  child:
                      const Text('إلغاء', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF27AE60),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          final keywordText = keywordController.text.trim();
                          if (keywordText.isEmpty) {
                            _showSnackBar('❌ الرجاء إدخال اسم/رمز الباقة',
                                isError: true);
                            return;
                          }

                          int targetCount =
                              int.tryParse(targetCountController.text) ?? 0;
                          int rewardQty =
                              int.tryParse(rewardQtyController.text) ?? 1;

                          setDialogState(() => isSaving = true);

                          if (isEditing) {
                            int id = keywordToEdit['id'];
                            await _dbHelper.updateKeyword(
                              id: id,
                              keyword: keywordText,
                              description: descController.text.trim(),
                              isActive: isActive,
                              targetCount: hasReward ? targetCount : 0,
                              rewardKeywordId:
                                  hasReward ? selectedRewardKeywordId : null,
                              rewardQty: hasReward ? rewardQty : 1,
                            );
                          } else {
                            await _dbHelper.addKeyword(
                              keyword: keywordText,
                              description: descController.text.trim(),
                              targetCount: hasReward ? targetCount : 0,
                              rewardKeywordId:
                                  hasReward ? selectedRewardKeywordId : null,
                              rewardQty: hasReward ? rewardQty : 1,
                            );
                          }

                          if (!mounted) return;
                          Navigator.pop(dialogContext);
                          _loadData();
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('حفظ',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteKeyword(int id, String keywordName) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('تأكيد الحذف'),
        content: Text(
            'هل أنت تأكد من حذف باقة "$keywordName"؟ سيتم حذف جميع القسائم التابعة لها.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE74C3C)),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _dbHelper.deleteKeyword(id);
      if (!mounted) return; // إصلاح Async Gap[cite: 1]
      _showSnackBar('✅ تم حذف الباقة بنجاح');
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E2A36),
        elevation: 0,
        centerTitle: true,
        title: const Text('🔑 باقات الكروت',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19)),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'إجمالي الباقات: ${_keywords.length}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF1E2A36)),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF27AE60),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                  onPressed: () => _showKeywordDialog(),
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('إضافة باقة',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF27AE60)))
                : _keywords.isEmpty
                    ? const Center(
                        child: Text('📭 لا توجد باقات حالياً',
                            style: TextStyle(color: Colors.grey, fontSize: 16)),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _keywords.length,
                        itemBuilder: (context, index) {
                          final k = _keywords[index];
                          int kId = k['id'];
                          int avail = _vouchersCountMap[kId]?['available'] ?? 0;
                          int used = _vouchersCountMap[kId]?['used'] ?? 0;
                          bool isActive = (k['is_active'] ?? 1) == 1;

                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor:
                                            const Color(0xFF1E2A36),
                                        child: Text(
                                          k['keyword'].toString(),
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text('باقة ${k['keyword']}',
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16)),
                                            if (k['description'] != null)
                                              Text(k['description'],
                                                  style: const TextStyle(
                                                      color: Colors.grey,
                                                      fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isActive
                                              ? const Color(0xFFE0F2E9)
                                              : const Color(0xFFFFE6E5),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          isActive ? '🟢 مفعل' : '🔴 معطل',
                                          style: TextStyle(
                                            color: isActive
                                                ? const Color(0xFF1F6E43)
                                                : const Color(0xFFB13E3E),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 20),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('متاح: $avail | مستخدم: $used',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit,
                                                color: Colors.blue),
                                            onPressed: () => _showKeywordDialog(
                                                keywordToEdit: k),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete,
                                                color: Colors.red),
                                            onPressed: () => _deleteKeyword(
                                                kId, k['keyword'].toString()),
                                          ),
                                        ],
                                      )
                                    ],
                                  )
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
