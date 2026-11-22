import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../data_manager.dart';
import '../modals.dart';

class MonthlyPage extends StatefulWidget {
  const MonthlyPage({super.key});

  @override
  State<MonthlyPage> createState() => _MonthlyPageState();
}

class _MonthlyPageState extends State<MonthlyPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  bool _showCompletedTasks = false;

  String get _selDateStr => DateFormat('yyyy-MM-dd').format(_selectedDay);
  String get _selDisplay => DateFormat('yyyy-MM-dd (E)', 'ko_KR').format(_selectedDay);

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final todaysAnnivs = DataManager.getAnniversariesForDate(_selDateStr);
    final tasks = DataManager.tasks[_selDateStr] ?? [];
    final recurringList = DataManager.getRecurringTasksForDate(_selectedDay);
    final supplies = DataManager.supplies[_selDateStr] ?? {};

    final incompleteTaskEntries = tasks.asMap().entries.where((e) => e.value['done'] != true).toList();
    final completedTaskEntries = tasks.asMap().entries.where((e) => e.value['done'] == true).toList();

    final incompleteRecurring = recurringList.where((r) => !DataManager.isRecurringDone(_selDateStr, r['id'].toString())).toList();
    final completedRecurring = recurringList.where((r) => DataManager.isRecurringDone(_selDateStr, r['id'].toString())).toList();

    final totalIncompleteTodo = incompleteTaskEntries.length + incompleteRecurring.length;
    final totalCompletedTodo = completedTaskEntries.length + completedRecurring.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('📅 월간 플래너'),
        actions: [
          IconButton(
            tooltip: '새로고침',
            icon: const Icon(Icons.refresh, color: Colors.brown),
            onPressed: () async {
              await DataManager.loadAllData();
              _refresh();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
            ),
            child: TableCalendar(
              locale: 'ko_KR',
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2035, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              onDayLongPressed: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
                PlannerModals.showAddTaskModal(context, DateFormat('yyyy-MM-dd').format(selectedDay), _refresh);
              },
              headerStyle: const HeaderStyle(
                titleCentered: true,
                formatButtonVisible: false,
                titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.brown),
                leftChevronIcon: Icon(Icons.chevron_left, color: Colors.orangeAccent),
                rightChevronIcon: Icon(Icons.chevron_right, color: Colors.orangeAccent),
              ),
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: Colors.transparent,
                  border: Border.all(color: Colors.orangeAccent, width: 2),
                  shape: BoxShape.circle,
                ),
                todayTextStyle: const TextStyle(color: Colors.brown, fontWeight: FontWeight.bold),
                selectedDecoration: const BoxDecoration(color: Colors.orangeAccent, shape: BoxShape.circle),
                markerDecoration: const BoxDecoration(color: Colors.deepOrangeAccent, shape: BoxShape.circle),
                outsideDaysVisible: false,
              ),
              calendarFormat: CalendarFormat.month,
              eventLoader: (day) {
                final dStr = DateFormat('yyyy-MM-dd').format(day);
                final events = <dynamic>[];
                final dayTasks = DataManager.tasks[dStr] ?? [];
                events.addAll(dayTasks.where((t) => t['done'] != true));
                final dayRecs = DataManager.getRecurringTasksForDate(day);
                events.addAll(dayRecs.where((r) => !DataManager.isRecurringDone(dStr, r['id'].toString())));
                events.addAll(DataManager.getAnniversariesForDate(dStr));
                return events;
              },
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          '✨ $_selDisplay',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.brown),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Row(
                        children: [
                          InkWell(
                            onTap: () => AnniversaryHelper.showModal(
                              context,
                              _refresh,
                              initialDate: DateFormat('MM-dd').format(_selectedDay),
                            ),
                            child: const Text('+ 기념일', style: TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                          const SizedBox(width: 12),
                          InkWell(
                            onTap: () => PlannerModals.showAddTaskModal(context, _selDateStr, _refresh),
                            child: const Text('+ 할일', style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                          const SizedBox(width: 12),
                          InkWell(
                            onTap: () => PlannerModals.showAddSupplyModal(context, _selDateStr, _refresh),
                            child: const Text('+ 준비물', style: TextStyle(color: Colors.deepOrangeAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFFFFF9F2), thickness: 2),
                  const SizedBox(height: 6),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.only(top: 4, bottom: 20),
                      children: [
                        if (todaysAnnivs.isNotEmpty)
                          ...todaysAnnivs.map(
                            (a) => Card(
                              elevation: 0,
                              color: const Color(0xFFFFF0F5),
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              child: Padding(
                                padding: const EdgeInsets.all(14.0),
                                child: Row(
                                  children: [
                                    const Icon(Icons.cake, color: Colors.pinkAccent, size: 20),
                                    const SizedBox(width: 12),
                                    Text(a, style: const TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        if (totalIncompleteTodo > 0) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 6, bottom: 8, left: 4),
                            child: Text('✅ 할 일 ($totalIncompleteTodo건)', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.brown)),
                          ),
                          ...incompleteRecurring.map((rec) => _buildRecurringCard(rec, false)),
                          ...incompleteTaskEntries.map((entry) => _buildTaskCard(entry.key, entry.value, false)),
                        ],
                        if (supplies.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.only(top: 14, bottom: 8, left: 4),
                            child: Text('🎒 준비물', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.brown)),
                          ),
                          ...supplies.entries.map((entry) {
                            final catName = entry.key;
                            final items = entry.value;
                            final remainCount = items.where((item) => item['done'] != true).length;
                            final isAllDone = items.isNotEmpty && remainCount == 0;
                            return Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 8),
                              color: const Color(0xFFFFF9F2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              child: Theme(
                                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                child: ExpansionTile(
                                  initiallyExpanded: remainCount > 0,
                                  tilePadding: const EdgeInsets.symmetric(horizontal: 14),
                                  iconColor: Colors.deepOrangeAccent,
                                  collapsedIconColor: Colors.deepOrangeAccent,
                                  title: Text(
                                    isAllDone ? '🔵 $catName (완료)' : '$catName ($remainCount개 남음)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isAllDone ? Colors.grey : Colors.deepOrangeAccent,
                                      fontSize: 14,
                                    ),
                                  ),
                                  children: items.asMap().entries.map((itemEntry) {
                                    final idx = itemEntry.key;
                                    final item = itemEntry.value;
                                    final isDone = item['done'] == true;
                                    return InkWell(
                                      onLongPress: () => PlannerModals.showSupplyOptions(context, _selDateStr, catName, idx, _refresh),
                                      child: CheckboxListTile(
                                        dense: true,
                                        controlAffinity: ListTileControlAffinity.leading,
                                        activeColor: Colors.deepOrangeAccent,
                                        value: isDone,
                                        onChanged: (val) {
                                          setState(() => item['done'] = val ?? false);
                                          DataManager.saveSuppliesForDate(_selDateStr);
                                        },
                                        title: Text(
                                          item['text'].toString(),
                                          style: TextStyle(
                                            fontSize: 14,
                                            decoration: isDone ? TextDecoration.lineThrough : null,
                                            color: isDone ? Colors.grey : Colors.black87,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            );
                          }),
                        ],
                        if (totalCompletedTodo > 0) ...[
                          const SizedBox(height: 8),
                          InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => setState(() => _showCompletedTasks = !_showCompletedTasks),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    _showCompletedTasks ? Icons.expand_less : Icons.expand_more,
                                    size: 18,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '완료된 할 일 ($totalCompletedTodo건)',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_showCompletedTasks) ...[
                            ...completedRecurring.map((rec) => _buildRecurringCard(rec, true)),
                            ...completedTaskEntries.map((entry) => _buildTaskCard(entry.key, entry.value, true)),
                          ],
                        ],
                        if (totalIncompleteTodo == 0 && totalCompletedTodo == 0 && supplies.isEmpty && todaysAnnivs.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 30),
                            child: Center(child: Text('등록된 일정이 없습니다.', style: TextStyle(color: Colors.grey))),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(int idx, Map<String, dynamic> task, bool isDone) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: const Color(0xFFFFF9F2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onLongPress: () => PlannerModals.showTaskOptions(context, _selDateStr, idx, _refresh),
        child: CheckboxListTile(
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: Colors.orangeAccent,
          value: isDone,
          onChanged: (val) {
            setState(() => task['done'] = val ?? false);
            DataManager.saveTasksForDate(_selDateStr);
          },
          title: Text(
            task['text'].toString(),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              decoration: isDone ? TextDecoration.lineThrough : null,
              color: isDone ? Colors.grey : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecurringCard(Map<String, dynamic> rec, bool isDone) {
    final recId = rec['id'].toString();
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: const Color(0xFFF0FAF8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onLongPress: () => PlannerModals.showRecurringOptions(context, recId, _refresh),
        child: CheckboxListTile(
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: Colors.teal,
          value: isDone,
          onChanged: (val) {
            DataManager.setRecurringDone(_selDateStr, recId, val ?? false).then((_) => _refresh());
          },
          title: Row(
            children: [
              const Icon(Icons.repeat, size: 15, color: Colors.teal),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  rec['text'].toString(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                    color: isDone ? Colors.grey : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Text(DataManager.describeRecurringRule(rec), style: const TextStyle(fontSize: 11, color: Colors.teal)),
        ),
      ),
    );
  }
}
