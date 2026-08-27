import 'package:flutter/material.dart';
import 'DatabaseHelper.dart'; // قم بتعديل مسار الملف حسب مشروعك

class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({Key? key}) : super(key: key);

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;

  void _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    final results = await DatabaseHelper.instance.searchGlobal(query);

    setState(() {
      _searchResults = results;
      _isLoading = false;
    });
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'voucher':
        return Icons.confirmation_number_outlined;
      case 'customer':
        return Icons.person_outline;
      case 'identifier':
        return Icons.fingerprint;
      case 'log':
        return Icons.history;
      default:
        return Icons.search;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'voucher':
        return Colors.orange;
      case 'customer':
        return Colors.blue;
      case 'identifier':
        return Colors.purple;
      case 'log':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'voucher':
        return 'قسيمة / كرت';
      case 'customer':
        return 'عميل';
      case 'identifier':
        return 'معرّف عميل';
      case 'log':
        return 'سجل عملية';
      default:
        return 'نتيجة';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('البحث الشامل في النظام'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // شريط البحث
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              onChanged: _performSearch,
              decoration: InputDecoration(
                hintText: 'ابحث عن رقم كرت، اسم، هاتف، محفظة، أو بصمة عملية...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _performSearch('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),

          // مؤشر التحميل أو عرض النتائج
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _searchResults.isEmpty
                    ? Center(
                        child: Text(
                          _searchController.text.isEmpty
                              ? 'أدخل كلمة البحث للبدء'
                              : 'لم يتم العثور على نتائج مطابقة',
                          style: const TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _searchResults.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = _searchResults[index];
                          final type = item['result_type'] as String;
                          final color = _getTypeColor(type);

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: color.withOpacity(0.15),
                              child: Icon(_getTypeIcon(type), color: color),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item['title'] ?? '',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    _getTypeLabel(type),
                                    style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  item['subtitle'] ?? '',
                                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                                ),
                                if (item['extra_info'] != null && item['extra_info'].toString().isNotEmpty)
                                  Text(
                                    item['extra_info'],
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                            onTap: () {
                              // يمكنك هنا توجيه المستخدم لشاشة التفاصيل بحسب نوع النتيجة (item['result_type'])
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}