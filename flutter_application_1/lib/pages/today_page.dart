import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data_manager.dart';
import '../modals.dart';
import 'monthly_page.dart';
import 'search_page.dart';
import 'settings_page.dart';
import 'shopping_page.dart';

class TodayPage extends StatefulWidget {
  const TodayPage({super.key});

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> with WidgetsBindingObserver {
  DateTime _currentDate = DateTime.now();
  final TextEditingController _noteController = TextEditingController();
  Timer? _noteDebounce;
  String? _pendingNoteDate;
  String _noteSaveStatus = ''; // '', 'saving', 'saved'
  bool _isRefreshing = false;

  String get _currentDateStr => DateFormat('yyyy-MM-dd').format(_currentDate);
  String get _currentDisplay => DateFormat('MM월 dd일 (E)', 'ko_KR').format(_currentDate);
  bool get _isToday {
    final now = DateTime.now();
    return now.year == _currentDate.year && now.month == _currentDate.month && now.day == _currentDate.day;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateNoteText();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flushPendingNote();
    _noteController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncFromServer(silent: true);
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _flushPendingNote();
    }
  }

  void _flushPendingNote() {
    if (_noteDebounce?.isActive ?? false) {
      _noteDebounce!.cancel();
      if (_pendingNoteDate != null) {
        DataManager.saveNoteForDate(_pendingNoteDate!);
        _pendingNoteDate = null;
      }
    }
  }

  void _onNoteChanged(String val) {
    final targetDate = _currentDateStr;
    DataManager.notes[targetDate] = val;
    _pendingNoteDate = targetDate;
    setState(() => _noteSaveStatus = 'saving');
    _noteDebounce?.cancel();
    _noteDebounce = Timer(const Duration(milliseconds: 600), () async {
      await DataManager.saveNoteForDate(targetDate);
      _pendingNoteDate = null;
      if (mounted && _currentDateStr == targetDate) {
        setState(() => _noteSaveStatus = 'saved');
      }
    });
  }

  void _changeDate(DateTime newDate) {
    _flushPendingNote();
    setState(() {
      _currentDate = newDate;
      _noteSaveStatus = '';
      _updateNoteText();
    });
  }

  void _updateNoteText() {
    _noteController.text = DataManager.notes[_currentDateStr] ?? '';
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {
      if (_pendingNoteDate == null) {
        _updateNoteText();
      }
    });
  }

  Future<void> _syncFromServer({bool silent = false}) async {
    if (_isRefreshing) return;
    _flushPendingNote();
    setState(() => _isRefreshing = true);
    await DataManager.loadAllData();
    if (!mounted) return;
    setState(() {
      _isRefreshing = false;
      _updateNoteText();
    });
    if (!silent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('최신 가족 일정을 동기화했습니다.'),
          duration: Duration(milliseconds: 1200),
        ),
      );
    }
  }

  Future<void> _openSearch() async {
    _flushPendingNote();
    final selectedDateStr = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const SearchPage()),
    );
    if (selectedDateStr != null) {
      final parsed = DateTime.tryParse(selectedDateStr);
      if (parsed != null) {
        _changeDate(parsed);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 88,
        leading: Row(
          children: [
            IconButton(
              tooltip: '새로고침',
              icon: _isRefreshing
                  ? const CupertinoActivityIndicator(radius: 9)
                  : const Icon(Icons.refresh, color: Colors.brown, size: 22),
              onPressed: _isRefreshing ? null : () => _syncFromServer(silent: false),
            ),
            IconButton(
              tooltip: '통합 검색',
              icon: const Icon(Icons.search, color: Colors.brown, size: 22),
              onPressed: _openSearch,
            ),
          ],
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: const Icon(Icons.chevron_left, color: Colors.brown),
              onPressed: () => _changeDate(_currentDate.subtract(const Duration(days: 1))),
            ),
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _currentDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                  initialEntryMode: DatePickerEntryMode.calendarOnly,
                  helpText: '이동할 날짜를 선택하세요',
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.light(
                          primary: Colors.orangeAccent,
                          onPrimary: Colors.white,
                          surface: Color(0xFFFFF9F2),
                          onSurface: Colors.brown,
                        ),
                        dialogTheme: const DialogThemeData(backgroundColor: Color(0xFFFFF9F2)),
                        textButtonTheme: TextButtonThemeData(
                          style: TextButton.styleFrom(foregroundColor: Colors.deepOrangeAccent),
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (picked != null) _changeDate(picked);
              },
              child: Text(
                '🐤 $_currentDisplay',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.brown),
              ),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: const Icon(Icons.chevron_right, color: Colors.brown),
              onPressed: () => _changeDate(_currentDate.add(const Duration(days: 1))),
            ),
          ],
        ),
        actions: [
          if (!_isToday)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Center(
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _changeDate(DateTime.now()),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.orangeAccent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text('오늘', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        color: Colors.orangeAccent,
        onRefresh: () => _syncFromServer(silent: true),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orangeAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.calendar_month, size: 17),
                        label: const Text('월간', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        onPressed: () async {
                          _flushPendingNote();
                          await Navigator.push(context, MaterialPageRoute(builder: (_) => const MonthlyPage()));
                          _refresh();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.brown,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.shopping_cart_outlined, size: 17, color: Colors.deepOrangeAccent),
                        label: const Text('장보기', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        onPressed: () async {
                          _flushPendingNote();
                          await Navigator.push(context, MaterialPageRoute(builder: (_) => const ShoppingListPage()));
                          _refresh();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.brown,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.settings, size: 17),
                        label: const Text('설정', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        onPressed: () async {
                          _flushPendingNote();
                          await Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()));
                          _refresh();
                        },
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.43,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Row(
                    children: [
                      Expanded(child: _buildTodoList()),
                      const SizedBox(width: 8),
                      Expanded(child: _buildSupplyList()),
                    ],
                  ),
                ),
              ),
              SizedBox(
                height: 270,
                child: Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Text('📝', style: TextStyle(fontSize: 18)),
                              SizedBox(width: 8),
                              Text('메모장', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.brown)),
                            ],
                          ),
                          if (_noteSaveStatus == 'saving')
                            const Text('저장 중...', style: TextStyle(fontSize: 11, color: Colors.orangeAccent))
                          else if (_noteSaveStatus == 'saved')
                            const Text('저장됨 ✓', style: TextStyle(fontSize: 11, color: Colors.green)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: TextField(
                          controller: _noteController,
                          maxLines: null,
                          expands: true,
                          decoration: InputDecoration(
                            hintText: '자유롭게 메모를 남겨보세요...',
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            filled: true,
                            fillColor: const Color(0xFFFFF9F2),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                          ),
                          onChanged: _onNoteChanged,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodoList() {
    final tasks = DataManager.tasks[_currentDateStr] ?? [];
    final todaysAnnivs = DataManager.getAnniversariesForDate(_currentDateStr);
    final recurringList = DataManager.getRecurringTasksForDate(_currentDate);
    final totalCount = todaysAnnivs.length + recurringList.length + tasks.length;

    return Card(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFFFECB3),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 24),
                const Text('✅ 할 일', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.brown)),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => PlannerModals.showAddTaskModal(context, _currentDateStr, _refresh),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Icons.add_circle, color: Colors.orangeAccent, size: 22),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: totalCount == 0
                ? const Center(child: Text('할 일이 없어요', style: TextStyle(fontSize: 12, color: Colors.grey)))
                : ListView.builder(
                    itemCount: totalCount,
                    itemBuilder: (ctx, i) {
                      if (i < todaysAnnivs.length) {
                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                          leading: const Icon(Icons.cake, color: Colors.pinkAccent, size: 18),
                          title: Text(
                            todaysAnnivs[i],
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.pinkAccent),
                          ),
                        );
                      }

                      final recOffset = i - todaysAnnivs.length;
                      if (recOffset < recurringList.length) {
                        final rec = recurringList[recOffset];
                        final recId = rec['id'].toString();
                        final isDone = DataManager.isRecurringDone(_currentDateStr, recId);
                        return InkWell(
                          onLongPress: () => PlannerModals.showRecurringOptions(context, recId, _refresh),
                          child: ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                            leading: Checkbox(
                              activeColor: Colors.teal,
                              value: isDone,
                              onChanged: (val) {
                                setState(() {});
                                DataManager.setRecurringDone(_currentDateStr, recId, val ?? false).then((_) => _refresh());
                              },
                            ),
                            title: Row(
                              children: [
                                const Icon(Icons.repeat, size: 13, color: Colors.teal),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    rec['text'].toString(),
                                    style: TextStyle(
                                      fontSize: 13,
                                      decoration: isDone ? TextDecoration.lineThrough : null,
                                      color: isDone ? Colors.grey : Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final taskIdx = recOffset - recurringList.length;
                      final isDone = tasks[taskIdx]['done'] == true;
                      return InkWell(
                        onLongPress: () => PlannerModals.showTaskOptions(context, _currentDateStr, taskIdx, _refresh),
                        child: ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                          leading: Checkbox(
                            activeColor: Colors.orangeAccent,
                            value: isDone,
                            onChanged: (val) {
                              setState(() => tasks[taskIdx]['done'] = val ?? false);
                              DataManager.saveTasksForDate(_currentDateStr);
                            },
                          ),
                          title: Text(
                            tasks[taskIdx]['text'].toString(),
                            style: TextStyle(
                              fontSize: 13,
                              decoration: isDone ? TextDecoration.lineThrough : null,
                              color: isDone ? Colors.grey : Colors.black87,
                            ),
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

  Widget _buildSupplyList() {
    final supplies = DataManager.supplies[_currentDateStr] ?? {};
    final supplyWidgets = <Widget>[];

    supplies.forEach((catName, items) {
      supplyWidgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 10.0, left: 10.0, bottom: 2.0),
          child: Text(catName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrangeAccent, fontSize: 12)),
        ),
      );
      for (int i = 0; i < items.length; i++) {
        final isDone = items[i]['done'] == true;
        supplyWidgets.add(
          InkWell(
            onLongPress: () => PlannerModals.showSupplyOptions(context, _currentDateStr, catName, i, _refresh),
            child: ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: Checkbox(
                activeColor: Colors.deepOrangeAccent,
                value: isDone,
                onChanged: (val) {
                  setState(() => items[i]['done'] = val ?? false);
                  DataManager.saveSuppliesForDate(_currentDateStr);
                },
              ),
              title: Text(
                items[i]['text'].toString(),
                style: TextStyle(
                  fontSize: 13,
                  decoration: isDone ? TextDecoration.lineThrough : null,
                  color: isDone ? Colors.grey : Colors.black87,
                ),
              ),
            ),
          ),
        );
      }
    });

    return Card(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFFFDCC8),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 24),
                const Text('🎒 준비물', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.brown)),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => PlannerModals.showAddSupplyModal(context, _currentDateStr, _refresh),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Icons.add_circle, color: Colors.deepOrangeAccent, size: 22),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: supplyWidgets.isEmpty
                ? const Center(child: Text('준비물이 없어요', style: TextStyle(fontSize: 12, color: Colors.grey)))
                : ListView(children: supplyWidgets),
          ),
        ],
      ),
    );
  }
}
