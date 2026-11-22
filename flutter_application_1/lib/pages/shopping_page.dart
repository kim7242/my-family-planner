import 'package:flutter/material.dart';
import '../data_manager.dart';

class ShoppingListPage extends StatefulWidget {
  const ShoppingListPage({super.key});

  @override
  State<ShoppingListPage> createState() => _ShoppingListPageState();
}

class _ShoppingListPageState extends State<ShoppingListPage> {
  final TextEditingController _inputCtrl = TextEditingController();
  String _selectedCategory = '마트';
  String _filterCategory = '전체';

  static const List<String> _categories = ['마트', '생활/약국', '온라인', '상시 메모'];

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  void _addItem() {
    final raw = _inputCtrl.text.trim();
    if (raw.isEmpty) return;
    final parts = raw.split(RegExp(r'[,\n]+')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    setState(() {
      for (final text in parts) {
        DataManager.shoppingList.insert(0, {
          'id': 'shop_${DateTime.now().microsecondsSinceEpoch}',
          'text': text,
          'done': false,
          'category': _selectedCategory,
        });
      }
      _inputCtrl.clear();
    });
    DataManager.saveShoppingList();
  }

  void _clearCompleted() {
    setState(() {
      DataManager.shoppingList.removeWhere((item) => item['done'] == true);
    });
    DataManager.saveShoppingList();
  }

  void _editItem(int index) {
    final ctrl = TextEditingController(text: DataManager.shoppingList[index]['text'].toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('✏️ 항목 수정', style: TextStyle(color: Colors.brown, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFFFF9F2),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, foregroundColor: Colors.white, elevation: 0),
            onPressed: () {
              final text = ctrl.text.trim();
              if (text.isNotEmpty) {
                setState(() => DataManager.shoppingList[index]['text'] = text);
                DataManager.saveShoppingList();
              }
              Navigator.pop(ctx);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = DataManager.shoppingList.asMap().entries.where((e) {
      if (_filterCategory == '전체') return true;
      return (e.value['category'] ?? '마트') == _filterCategory;
    }).toList();

    final todoEntries = entries.where((e) => e.value['done'] != true).toList();
    final doneEntries = entries.where((e) => e.value['done'] == true).toList();
    final totalDone = DataManager.shoppingList.where((e) => e['done'] == true).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('🛒 장보기 · 상시 메모'),
        actions: [
          if (totalDone > 0)
            TextButton(
              onPressed: _clearCompleted,
              child: const Text('완료 비우기', style: TextStyle(color: Colors.deepOrangeAccent, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories.map((cat) {
                      final isSelected = _selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(cat, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.brown)),
                          selected: isSelected,
                          selectedColor: Colors.orangeAccent,
                          backgroundColor: const Color(0xFFFFF9F2),
                          showCheckmark: false,
                          onSelected: (_) => setState(() => _selectedCategory = cat),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inputCtrl,
                        onSubmitted: (_) => _addItem(),
                        decoration: InputDecoration(
                          hintText: '살 것·상시 메모 입력 (쉼표로 여러 개)',
                          hintStyle: TextStyle(fontSize: 13, color: Colors.grey[500]),
                          filled: true,
                          fillColor: const Color(0xFFFFF9F2),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orangeAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        elevation: 0,
                      ),
                      onPressed: _addItem,
                      child: const Text('추가', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['전체', ..._categories].map((cat) {
                  final active = _filterCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(cat, style: TextStyle(fontSize: 11, color: active ? Colors.white : Colors.brown)),
                      selected: active,
                      selectedColor: Colors.brown,
                      backgroundColor: Colors.white,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _filterCategory = cat),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: RefreshIndicator(
              color: Colors.orangeAccent,
              onRefresh: () async {
                await DataManager.loadAllData();
                if (mounted) setState(() {});
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                children: [
                  if (todoEntries.isEmpty && doneEntries.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 60),
                      child: Center(
                        child: Text('등록된 장보기·상시 메모가 없습니다.\n위 입력창에서 바로 추가해 보세요!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                      ),
                    ),
                  if (todoEntries.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 6, bottom: 6, top: 4),
                      child: Text('🛍️ 체크 전 (${todoEntries.length}개)', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.brown, fontSize: 13)),
                    ),
                    ...todoEntries.map((entry) => _buildItemTile(entry.key, entry.value)),
                  ],
                  if (doneEntries.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 6, bottom: 6, top: 14),
                      child: Text('✅ 완료됨 (${doneEntries.length}개)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[600], fontSize: 13)),
                    ),
                    ...doneEntries.map((entry) => _buildItemTile(entry.key, entry.value)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemTile(int index, Map<String, dynamic> item) {
    final isDone = item['done'] == true;
    final category = (item['category'] ?? '마트').toString();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        leading: Checkbox(
          activeColor: Colors.orangeAccent,
          value: isDone,
          onChanged: (val) {
            setState(() => DataManager.shoppingList[index]['done'] = val ?? false);
            DataManager.saveShoppingList();
          },
        ),
        title: Text(
          (item['text'] ?? '').toString(),
          style: TextStyle(
            fontSize: 14,
            decoration: isDone ? TextDecoration.lineThrough : null,
            color: isDone ? Colors.grey : Colors.black87,
          ),
        ),
        subtitle: Text(category, style: TextStyle(fontSize: 11, color: Colors.orange[700])),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 18, color: Colors.grey),
              onPressed: () => _editItem(index),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
              onPressed: () {
                setState(() => DataManager.shoppingList.removeAt(index));
                DataManager.saveShoppingList();
              },
            ),
          ],
        ),
      ),
    );
  }
}
