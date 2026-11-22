import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'data_manager.dart';

class AnniversaryHelper {
  static void showModal(
    BuildContext context,
    VoidCallback onSave, {
    int? editIndex,
    String? initialDate,
  }) {
    final annivNameCtrl = TextEditingController();
    String chosenDate = initialDate ?? DateFormat('MM-dd').format(DateTime.now());
    int isLunarVal = 0;

    if (editIndex != null && editIndex < DataManager.anniversaries.length) {
      final anniv = DataManager.anniversaries[editIndex];
      annivNameCtrl.text = (anniv['name'] ?? '').toString();
      chosenDate = (anniv['date'] ?? chosenDate).toString();
      isLunarVal = anniv['isLunar'] == true ? 1 : 0;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      editIndex == null ? '🎂 새 기념일 등록' : '✏️ 기념일 수정',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.brown),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: annivNameCtrl,
                      decoration: InputDecoration(
                        labelText: '기념일 이름',
                        hintText: '예: 아이 생일, 결혼기념일',
                        filled: true,
                        fillColor: const Color(0xFFFFF9F2),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('달력 기준', style: TextStyle(fontWeight: FontWeight.bold)),
                        CupertinoSlidingSegmentedControl<int>(
                          groupValue: isLunarVal,
                          children: const {
                            0: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('양력')),
                            1: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('음력')),
                          },
                          onValueChanged: (val) {
                            if (val != null) setModalState(() => isLunarVal = val);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      tileColor: const Color(0xFFFFF9F2),
                      title: Text('날짜 선택: $chosenDate', style: const TextStyle(fontWeight: FontWeight.bold)),
                      trailing: const Icon(Icons.calendar_month, color: Colors.orangeAccent),
                      onTap: () async {
                        DateTime initialDt = DateTime.now();
                        try {
                          initialDt = DateFormat('yyyy-MM-dd').parse('2024-$chosenDate');
                        } catch (_) {}
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: initialDt,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                          helpText: '기념일 날짜를 선택하세요',
                        );
                        if (picked != null) {
                          setModalState(() => chosenDate = DateFormat('MM-dd').format(picked));
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        if (editIndex != null) ...[
                          Expanded(
                            flex: 1,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red[100],
                                foregroundColor: Colors.red,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                elevation: 0,
                              ),
                              onPressed: () {
                                DataManager.anniversaries.removeAt(editIndex);
                                DataManager.saveAnniversaries();
                                onSave();
                                Navigator.pop(context);
                              },
                              child: const Text('삭제', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.pinkAccent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 0,
                            ),
                            onPressed: () {
                              if (annivNameCtrl.text.trim().isNotEmpty) {
                                final item = {
                                  'name': annivNameCtrl.text.trim(),
                                  'date': chosenDate,
                                  'isLunar': isLunarVal == 1,
                                };
                                if (editIndex != null) {
                                  DataManager.anniversaries[editIndex] = item;
                                } else {
                                  DataManager.anniversaries.add(item);
                                }
                                DataManager.saveAnniversaries();
                                onSave();
                                Navigator.pop(context);
                              }
                            },
                            child: const Text('저장하기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class PlannerModals {
  static const Map<int, String> _weekdayNames = {
    1: '월',
    2: '화',
    3: '수',
    4: '목',
    5: '금',
    6: '토',
    7: '일',
  };

  /// 할 일 추가 모달 (단발성 할 일 또는 반복 일정 바로 등록 가능)
  static void showAddTaskModal(
    BuildContext context,
    String dateStr,
    VoidCallback onUpdate,
  ) {
    final taskCtrl = TextEditingController();
    final targetDate = DateTime.tryParse(dateStr) ?? DateTime.now();
    String repeatType = 'none'; // none, daily, weekly, monthly
    final selectedWeekdays = <int>{targetDate.weekday};
    int dayOfMonth = targetDate.day;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Text('✨', style: TextStyle(fontSize: 20)),
                            SizedBox(width: 8),
                            Text('새로운 할 일 등록', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.brown)),
                          ],
                        ),
                        Text(dateStr, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: taskCtrl,
                      autofocus: true,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                        filled: true,
                        fillColor: const Color(0xFFFFF9F2),
                        hintText: '무엇을 해야 할까요?',
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('🔁 반복', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.brown, fontSize: 13)),
                        CupertinoSlidingSegmentedControl<String>(
                          groupValue: repeatType,
                          children: const {
                            'none': Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('안함', style: TextStyle(fontSize: 12))),
                            'daily': Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('매일', style: TextStyle(fontSize: 12))),
                            'weekly': Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('매주', style: TextStyle(fontSize: 12))),
                            'monthly': Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('매월', style: TextStyle(fontSize: 12))),
                          },
                          onValueChanged: (val) {
                            if (val != null) setModalState(() => repeatType = val);
                          },
                        ),
                      ],
                    ),
                    if (repeatType == 'weekly') ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        children: _weekdayNames.entries.map((entry) {
                          final isSelected = selectedWeekdays.contains(entry.key);
                          return ChoiceChip(
                            label: Text(entry.value, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.brown)),
                            selected: isSelected,
                            selectedColor: Colors.orangeAccent,
                            backgroundColor: const Color(0xFFFFF9F2),
                            showCheckmark: false,
                            onSelected: (checked) {
                              setModalState(() {
                                if (checked) {
                                  selectedWeekdays.add(entry.key);
                                } else if (selectedWeekdays.length > 1) {
                                  selectedWeekdays.remove(entry.key);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                    if (repeatType == 'monthly') ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text('매월 ', style: TextStyle(color: Colors.brown, fontWeight: FontWeight.bold)),
                          DropdownButton<int>(
                            value: dayOfMonth,
                            items: List.generate(31, (i) => i + 1)
                                .map((d) => DropdownMenuItem(value: d, child: Text('$d일')))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) setModalState(() => dayOfMonth = val);
                            },
                          ),
                          const Text(' 마다 반복', style: TextStyle(color: Colors.brown)),
                        ],
                      ),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orangeAccent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                        ),
                        onPressed: () {
                          final text = taskCtrl.text.trim();
                          if (text.isEmpty) return;
                          if (repeatType == 'none') {
                            DataManager.tasks.putIfAbsent(dateStr, () => []);
                            DataManager.tasks[dateStr]!.add({'text': text, 'done': false});
                            DataManager.saveTasksForDate(dateStr);
                          } else {
                            final days = selectedWeekdays.toList()..sort();
                            DataManager.recurringTasks.add({
                              'id': 'rec_${DateTime.now().millisecondsSinceEpoch}',
                              'text': text,
                              'type': repeatType,
                              'weekdays': days,
                              'dayOfMonth': dayOfMonth,
                            });
                            DataManager.saveRecurringTasks();
                          }
                          onUpdate();
                          Navigator.pop(context);
                        },
                        child: Text(
                          repeatType == 'none' ? '추가하기' : '반복 일정으로 추가하기',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// 반복 일정 전용 등록/수정/삭제 모달
  static void showRecurringModal(
    BuildContext context,
    VoidCallback onUpdate, {
    int? editIndex,
  }) {
    final textCtrl = TextEditingController();
    String repeatType = 'weekly';
    final selectedWeekdays = <int>{DateTime.now().weekday};
    int dayOfMonth = DateTime.now().day;

    if (editIndex != null && editIndex < DataManager.recurringTasks.length) {
      final rec = DataManager.recurringTasks[editIndex];
      textCtrl.text = (rec['text'] ?? '').toString();
      repeatType = (rec['type'] ?? 'weekly').toString();
      selectedWeekdays
        ..clear()
        ..addAll(((rec['weekdays'] as List?) ?? []).cast<int>());
      if (selectedWeekdays.isEmpty) selectedWeekdays.add(DateTime.now().weekday);
      dayOfMonth = rec['dayOfMonth'] is int ? rec['dayOfMonth'] as int : 1;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      editIndex == null ? '🔁 새 반복 일정 등록' : '✏️ 반복 일정 수정',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.brown),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: textCtrl,
                      decoration: InputDecoration(
                        labelText: '반복할 할 일',
                        hintText: '예: 분리수거, 태권도 학원, 공과금 납부',
                        filled: true,
                        fillColor: const Color(0xFFFFF9F2),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('반복 주기', style: TextStyle(fontWeight: FontWeight.bold)),
                        CupertinoSlidingSegmentedControl<String>(
                          groupValue: repeatType,
                          children: const {
                            'daily': Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('매일')),
                            'weekly': Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('매주')),
                            'monthly': Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('매월')),
                          },
                          onValueChanged: (val) {
                            if (val != null) setModalState(() => repeatType = val);
                          },
                        ),
                      ],
                    ),
                    if (repeatType == 'weekly') ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        children: _weekdayNames.entries.map((entry) {
                          final isSelected = selectedWeekdays.contains(entry.key);
                          return ChoiceChip(
                            label: Text(entry.value, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.brown)),
                            selected: isSelected,
                            selectedColor: Colors.orangeAccent,
                            backgroundColor: const Color(0xFFFFF9F2),
                            showCheckmark: false,
                            onSelected: (checked) {
                              setModalState(() {
                                if (checked) {
                                  selectedWeekdays.add(entry.key);
                                } else if (selectedWeekdays.length > 1) {
                                  selectedWeekdays.remove(entry.key);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                    if (repeatType == 'monthly') ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text('매월 ', style: TextStyle(color: Colors.brown, fontWeight: FontWeight.bold)),
                          DropdownButton<int>(
                            value: dayOfMonth,
                            items: List.generate(31, (i) => i + 1)
                                .map((d) => DropdownMenuItem(value: d, child: Text('$d일')))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) setModalState(() => dayOfMonth = val);
                            },
                          ),
                          const Text(' 마다 반복', style: TextStyle(color: Colors.brown)),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        if (editIndex != null) ...[
                          Expanded(
                            flex: 1,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red[100],
                                foregroundColor: Colors.red,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                elevation: 0,
                              ),
                              onPressed: () {
                                DataManager.recurringTasks.removeAt(editIndex);
                                DataManager.saveRecurringTasks();
                                onUpdate();
                                Navigator.pop(context);
                              },
                              child: const Text('삭제', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orangeAccent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 0,
                            ),
                            onPressed: () {
                              final text = textCtrl.text.trim();
                              if (text.isEmpty) return;
                              final days = selectedWeekdays.toList()..sort();
                              final existingId = editIndex != null
                                  ? DataManager.recurringTasks[editIndex]['id']
                                  : 'rec_${DateTime.now().millisecondsSinceEpoch}';
                              final item = {
                                'id': existingId,
                                'text': text,
                                'type': repeatType,
                                'weekdays': days,
                                'dayOfMonth': dayOfMonth,
                              };
                              if (editIndex != null) {
                                DataManager.recurringTasks[editIndex] = item;
                              } else {
                                DataManager.recurringTasks.add(item);
                              }
                              DataManager.saveRecurringTasks();
                              onUpdate();
                              Navigator.pop(context);
                            },
                            child: const Text('저장하기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// 준비물 추가 모달 (템플릿 불러오기 버그 수정 + 단발성 직접 입력 탭)
  static void showAddSupplyModal(
    BuildContext context,
    String dateStr,
    VoidCallback onUpdate,
  ) {
    int mode = DataManager.templates.isNotEmpty ? 0 : 1; // 0: 템플릿, 1: 직접 입력
    String? selectedTemplate = DataManager.templates.isNotEmpty ? DataManager.templates.keys.first : null;
    Map<String, bool> checkedItems = {};

    void loadCheckedForTemplate(String? tmpl) {
      checkedItems = {};
      if (tmpl == null) return;
      for (final item in DataManager.templates[tmpl] ?? []) {
        checkedItems[item] = true;
      }
    }

    loadCheckedForTemplate(selectedTemplate);

    final customCatCtrl = TextEditingController(text: '기타 준비물');
    final customItemCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
                ),
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.72),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Text('🎒', style: TextStyle(fontSize: 20)),
                            SizedBox(width: 8),
                            Text('준비물 추가', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.brown)),
                          ],
                        ),
                        Text(dateStr, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: CupertinoSlidingSegmentedControl<int>(
                        groupValue: mode,
                        children: const {
                          0: Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('템플릿 불러오기', style: TextStyle(fontSize: 13))),
                          1: Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('직접 입력', style: TextStyle(fontSize: 13))),
                        },
                        onValueChanged: (val) {
                          if (val != null) setModalState(() => mode = val);
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (mode == 0) ...[
                      if (selectedTemplate == null)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: Text('설정에서 먼저 템플릿을 만들거나 [직접 입력]을 사용해 주세요!', style: TextStyle(color: Colors.brown))),
                        )
                      else ...[
                        DropdownButtonFormField<String>(
                          initialValue: selectedTemplate,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFFFF9F2),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                          ),
                          items: DataManager.templates.keys
                              .map((key) => DropdownMenuItem<String>(
                                    value: key,
                                    child: Text(key, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            setModalState(() {
                              selectedTemplate = val;
                              loadCheckedForTemplate(val);
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () {
                                setModalState(() {
                                  final allChecked = checkedItems.values.every((v) => v);
                                  for (final k in checkedItems.keys) {
                                    checkedItems[k] = !allChecked;
                                  }
                                });
                              },
                              child: Text(
                                checkedItems.values.every((v) => v) ? '전체 해제' : '전체 선택',
                                style: const TextStyle(color: Colors.deepOrangeAccent, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        Flexible(
                          child: ListView(
                            shrinkWrap: true,
                            children: checkedItems.keys.map((itemName) {
                              return CheckboxListTile(
                                dense: true,
                                activeColor: Colors.deepOrangeAccent,
                                title: Text(itemName, style: const TextStyle(fontSize: 14)),
                                value: checkedItems[itemName] ?? false,
                                onChanged: (val) {
                                  setModalState(() => checkedItems[itemName] = val ?? false);
                                },
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepOrangeAccent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 0,
                            ),
                            onPressed: () {
                              final tmpl = selectedTemplate!;
                              final chosen = checkedItems.entries.where((e) => e.value).map((e) => e.key).toList();
                              if (chosen.isEmpty) return;
                              DataManager.supplies.putIfAbsent(dateStr, () => {});
                              DataManager.supplies[dateStr]!.putIfAbsent(tmpl, () => []);
                              final existingTexts = DataManager.supplies[dateStr]![tmpl]!.map((e) => e['text']).toSet();
                              for (final name in chosen) {
                                if (!existingTexts.contains(name)) {
                                  DataManager.supplies[dateStr]![tmpl]!.add({'text': name, 'done': false});
                                }
                              }
                              DataManager.saveSuppliesForDate(dateStr);
                              onUpdate();
                              Navigator.pop(context);
                            },
                            child: const Text('적용하기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ] else ...[
                      Wrap(
                        spacing: 6,
                        children: ['기타 준비물', '외출', '병원', '어린이집/학교'].map((preset) {
                          return ActionChip(
                            label: Text(preset, style: const TextStyle(fontSize: 11, color: Colors.brown)),
                            backgroundColor: const Color(0xFFFFF9F2),
                            onPressed: () => setModalState(() => customCatCtrl.text = preset),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: customCatCtrl,
                        decoration: InputDecoration(
                          labelText: '카테고리 이름',
                          filled: true,
                          fillColor: const Color(0xFFFFF9F2),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: customItemCtrl,
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: '준비물 항목 (쉼표로 여러 개 입력 가능)',
                          hintText: '예: 우산, 처방전, 여벌 양말',
                          filled: true,
                          fillColor: const Color(0xFFFFF9F2),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepOrangeAccent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                          ),
                          onPressed: () {
                            final cat = customCatCtrl.text.trim().isEmpty ? '기타 준비물' : customCatCtrl.text.trim();
                            final rawItems = customItemCtrl.text
                                .split(RegExp(r'[,\n]+'))
                                .map((e) => e.trim())
                                .where((e) => e.isNotEmpty)
                                .toList();
                            if (rawItems.isEmpty) return;
                            DataManager.supplies.putIfAbsent(dateStr, () => {});
                            DataManager.supplies[dateStr]!.putIfAbsent(cat, () => []);
                            final existingTexts = DataManager.supplies[dateStr]![cat]!.map((e) => e['text']).toSet();
                            for (final item in rawItems) {
                              if (!existingTexts.contains(item)) {
                                DataManager.supplies[dateStr]![cat]!.add({'text': item, 'done': false});
                              }
                            }
                            DataManager.saveSuppliesForDate(dateStr);
                            onUpdate();
                            Navigator.pop(context);
                          },
                          child: const Text('추가하기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// 할 일 옵션 (수정 / 날짜 이동 / 삭제)
  static void showTaskOptions(
    BuildContext context,
    String dateStr,
    int index,
    VoidCallback onUpdate,
  ) {
    final tasks = DataManager.tasks[dateStr];
    if (tasks == null || index >= tasks.length) return;

    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext ctx) => CupertinoActionSheet(
        title: const Text('할 일 관리', style: TextStyle(fontFamily: 'GmarketSans')),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _showEditTextDialog(
                context: context,
                title: '✏️ 할 일 수정',
                initialText: tasks[index]['text'].toString(),
                buttonColor: Colors.orangeAccent,
                onSave: (newText) {
                  tasks[index]['text'] = newText;
                  DataManager.saveTasksForDate(dateStr);
                  onUpdate();
                },
              );
            },
            child: const Text('✏️ 내용 수정하기', style: TextStyle(color: Colors.blue, fontFamily: 'GmarketSans')),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _moveTaskDate(context, dateStr, index, onUpdate);
            },
            child: const Text('🗓️ 날짜 이동하기', style: TextStyle(color: Colors.blue, fontFamily: 'GmarketSans')),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              tasks.removeAt(index);
              DataManager.saveTasksForDate(dateStr);
              onUpdate();
              Navigator.pop(ctx);
            },
            child: const Text('🗑️ 삭제하기', style: TextStyle(fontFamily: 'GmarketSans')),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('취소', style: TextStyle(fontFamily: 'GmarketSans')),
        ),
      ),
    );
  }

  /// 준비물 옵션 (수정 / 날짜 이동 / 삭제)
  static void showSupplyOptions(
    BuildContext context,
    String dateStr,
    String category,
    int index,
    VoidCallback onUpdate,
  ) {
    final items = DataManager.supplies[dateStr]?[category];
    if (items == null || index >= items.length) return;

    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext ctx) => CupertinoActionSheet(
        title: const Text('준비물 관리', style: TextStyle(fontFamily: 'GmarketSans')),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _showEditTextDialog(
                context: context,
                title: '✏️ 준비물 수정',
                initialText: items[index]['text'].toString(),
                buttonColor: Colors.deepOrangeAccent,
                onSave: (newText) {
                  items[index]['text'] = newText;
                  DataManager.saveSuppliesForDate(dateStr);
                  onUpdate();
                },
              );
            },
            child: const Text('✏️ 내용 수정하기', style: TextStyle(color: Colors.blue, fontFamily: 'GmarketSans')),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _moveSupplyDate(context, dateStr, category, index, onUpdate);
            },
            child: const Text('🗓️ 날짜 이동하기', style: TextStyle(color: Colors.blue, fontFamily: 'GmarketSans')),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              items.removeAt(index);
              if (items.isEmpty) {
                DataManager.supplies[dateStr]?.remove(category);
              }
              DataManager.saveSuppliesForDate(dateStr);
              onUpdate();
              Navigator.pop(ctx);
            },
            child: const Text('🗑️ 삭제하기', style: TextStyle(fontFamily: 'GmarketSans')),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('취소', style: TextStyle(fontFamily: 'GmarketSans')),
        ),
      ),
    );
  }

  /// 반복 일정 옵션 (수정 / 삭제)
  static void showRecurringOptions(
    BuildContext context,
    String recId,
    VoidCallback onUpdate,
  ) {
    final idx = DataManager.recurringTasks.indexWhere((e) => e['id'] == recId);
    if (idx < 0) return;

    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext ctx) => CupertinoActionSheet(
        title: const Text('반복 일정 관리', style: TextStyle(fontFamily: 'GmarketSans')),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              showRecurringModal(context, onUpdate, editIndex: idx);
            },
            child: const Text('✏️ 반복 일정 수정', style: TextStyle(color: Colors.blue, fontFamily: 'GmarketSans')),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              DataManager.recurringTasks.removeAt(idx);
              DataManager.saveRecurringTasks();
              onUpdate();
              Navigator.pop(ctx);
            },
            child: const Text('🗑️ 반복 일정 삭제', style: TextStyle(fontFamily: 'GmarketSans')),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('취소', style: TextStyle(fontFamily: 'GmarketSans')),
        ),
      ),
    );
  }

  static Future<void> _moveTaskDate(
    BuildContext context,
    String oldDateStr,
    int index,
    VoidCallback onUpdate,
  ) async {
    final initialDt = DateTime.tryParse(oldDateStr) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDt,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: '이동할 날짜를 선택하세요',
    );
    if (picked == null) return;
    final newDateStr = DateFormat('yyyy-MM-dd').format(picked);
    if (newDateStr == oldDateStr) return;

    final tasks = DataManager.tasks[oldDateStr];
    if (tasks == null || index >= tasks.length) return;
    final taskToMove = tasks.removeAt(index);
    DataManager.tasks.putIfAbsent(newDateStr, () => []);
    DataManager.tasks[newDateStr]!.add(taskToMove);

    await Future.wait([
      DataManager.saveTasksForDate(oldDateStr),
      DataManager.saveTasksForDate(newDateStr),
    ]);
    onUpdate();
  }

  static Future<void> _moveSupplyDate(
    BuildContext context,
    String oldDateStr,
    String category,
    int index,
    VoidCallback onUpdate,
  ) async {
    final initialDt = DateTime.tryParse(oldDateStr) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDt,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: '이동할 날짜를 선택하세요',
    );
    if (picked == null) return;
    final newDateStr = DateFormat('yyyy-MM-dd').format(picked);
    if (newDateStr == oldDateStr) return;

    final items = DataManager.supplies[oldDateStr]?[category];
    if (items == null || index >= items.length) return;
    final itemToMove = items.removeAt(index);
    if (items.isEmpty) {
      DataManager.supplies[oldDateStr]?.remove(category);
    }
    DataManager.supplies.putIfAbsent(newDateStr, () => {});
    DataManager.supplies[newDateStr]!.putIfAbsent(category, () => []);
    DataManager.supplies[newDateStr]![category]!.add(itemToMove);

    await Future.wait([
      DataManager.saveSuppliesForDate(oldDateStr),
      DataManager.saveSuppliesForDate(newDateStr),
    ]);
    onUpdate();
  }

  static void _showEditTextDialog({
    required BuildContext context,
    required String title,
    required String initialText,
    required Color buttonColor,
    required ValueChanged<String> onSave,
  }) {
    final editCtrl = TextEditingController(text: initialText);
    showDialog(
      context: context,
      builder: (context) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: AnimatedPadding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, left: 20, right: 20),
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            child: Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.brown)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: editCtrl,
                      autofocus: true,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                        filled: true,
                        fillColor: const Color(0xFFFFF9F2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: buttonColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                        ),
                        onPressed: () {
                          final trimmed = editCtrl.text.trim();
                          if (trimmed.isNotEmpty) {
                            onSave(trimmed);
                            Navigator.pop(context);
                          }
                        },
                        child: const Text('수정 완료', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
