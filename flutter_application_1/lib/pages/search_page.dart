import 'package:flutter/material.dart';
import '../data_manager.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _queryCtrl = TextEditingController();
  List<SearchResultItem> _results = [];

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    setState(() {
      _results = DataManager.searchAll(val);
    });
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'task':
        return Icons.check_circle_outline;
      case 'recurring':
        return Icons.repeat;
      case 'supply':
        return Icons.backpack_outlined;
      case 'note':
        return Icons.notes;
      case 'anniversary':
        return Icons.cake_outlined;
      case 'shopping':
        return Icons.shopping_cart_outlined;
      default:
        return Icons.search;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'task':
        return Colors.orangeAccent;
      case 'recurring':
        return Colors.teal;
      case 'supply':
        return Colors.deepOrangeAccent;
      case 'note':
        return Colors.brown;
      case 'anniversary':
        return Colors.pinkAccent;
      case 'shopping':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _queryCtrl,
          autofocus: true,
          onChanged: _onSearchChanged,
          decoration: const InputDecoration(
            hintText: '할 일, 준비물, 메모, 기념일, 장보기 검색...',
            border: InputBorder.none,
            hintStyle: TextStyle(fontSize: 14, color: Colors.black54),
          ),
          style: const TextStyle(fontSize: 15, color: Colors.brown),
        ),
        actions: [
          if (_queryCtrl.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _queryCtrl.clear();
                _onSearchChanged('');
              },
            ),
        ],
      ),
      body: _queryCtrl.text.trim().isEmpty
          ? const Center(
              child: Text(
                '🔍 찾고 싶은 키워드를 입력해 주세요.\n날짜가 있는 항목을 누르면 해당 날짜로 바로 이동합니다.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            )
          : _results.isEmpty
              ? const Center(
                  child: Text('일치하는 항목이 없습니다.', style: TextStyle(color: Colors.grey)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final item = _results[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _colorForType(item.type).withValues(alpha: 0.14),
                          child: Icon(_iconForType(item.type), color: _colorForType(item.type), size: 20),
                        ),
                        title: Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            decoration: item.done == true ? TextDecoration.lineThrough : null,
                            color: item.done == true ? Colors.grey : Colors.black87,
                          ),
                        ),
                        subtitle: Text(item.subtitle, style: const TextStyle(fontSize: 12)),
                        trailing: item.dateStr != null
                            ? const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey)
                            : null,
                        onTap: () {
                          if (item.dateStr != null) {
                            Navigator.pop(context, item.dateStr);
                          }
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
