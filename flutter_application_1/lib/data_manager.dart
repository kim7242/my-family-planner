import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:klc/klc.dart';

class SearchResultItem {
  final String type; // 'task', 'recurring', 'supply', 'note', 'anniversary', 'shopping'
  final String title;
  final String subtitle;
  final String? dateStr;
  final bool? done;

  const SearchResultItem({
    required this.type,
    required this.title,
    required this.subtitle,
    this.dateStr,
    this.done,
  });
}

class DataManager {
  static const String dbUrl = "https://familyplanners-a98b5-default-rtdb.firebaseio.com";

  static Map<String, List<Map<String, dynamic>>> tasks = {};
  static Map<String, Map<String, List<Map<String, dynamic>>>> supplies = {};
  static Map<String, String> notes = {};
  static Map<String, List<String>> templates = {};
  static List<Map<String, dynamic>> anniversaries = [];

  static List<Map<String, dynamic>> recurringTasks = [];
  static Map<String, Map<String, bool>> recurringDone = {};
  static List<Map<String, dynamic>> shoppingList = [];

  static bool isPushEnabled = false;
  static String pushTime = "08:00";
  static String vapidKey = "";
  static String lastPushSentDate = "";
  static Map<String, Map<String, dynamic>> pushTokens = {};

  static DateTime? lastSyncedAt;
  static bool isSyncing = false;

  static Future<void> loadAllData() async {
    if (isSyncing) return;
    isSyncing = true;
    try {
      await Future.wait([
        _fetchTasks(),
        _fetchSupplies(),
        _fetchNotes(),
        _fetchTemplates(),
        _fetchPushSettings(),
        _fetchPushTokens(),
        _fetchAnniversaries(),
        _fetchRecurringTasks(),
        _fetchRecurringDone(),
        _fetchShoppingList(),
      ]);
      lastSyncedAt = DateTime.now();
    } catch (e) {
      debugPrint("Load Error: $e");
    } finally {
      isSyncing = false;
    }
  }

  static Future<void> _fetchTasks() async {
    final res = await http.get(Uri.parse('$dbUrl/tasks.json'));
    if (res.statusCode != 200) return;
    if (res.body == 'null' || res.body.isEmpty) {
      tasks = {};
      return;
    }
    final decoded = json.decode(res.body);
    final parsed = <String, List<Map<String, dynamic>>>{};
    if (decoded is Map) {
      decoded.forEach((dateKey, rawList) {
        final list = <Map<String, dynamic>>[];
        if (rawList is List) {
          for (final item in rawList) {
            if (item == null) continue;
            if (item is String) {
              list.add({'text': item, 'done': false});
            } else if (item is Map) {
              list.add({
                'text': (item['text'] ?? '').toString(),
                'done': item['done'] == true,
              });
            }
          }
        }
        if (list.isNotEmpty) parsed[dateKey.toString()] = list;
      });
    }
    tasks = parsed;
  }

  static Future<void> _fetchSupplies() async {
    final res = await http.get(Uri.parse('$dbUrl/supplies.json'));
    if (res.statusCode != 200) return;
    if (res.body == 'null' || res.body.isEmpty) {
      supplies = {};
      return;
    }
    final decoded = json.decode(res.body);
    final parsed = <String, Map<String, List<Map<String, dynamic>>>>{};
    if (decoded is Map) {
      decoded.forEach((dateKey, rawCats) {
        if (rawCats is! Map) return;
        final catMap = <String, List<Map<String, dynamic>>>{};
        rawCats.forEach((catName, rawItems) {
          final items = <Map<String, dynamic>>[];
          if (rawItems is List) {
            for (final item in rawItems) {
              if (item == null) continue;
              if (item is String) {
                items.add({'text': item, 'done': false});
              } else if (item is Map) {
                items.add({
                  'text': (item['text'] ?? '').toString(),
                  'done': item['done'] == true,
                });
              }
            }
          }
          if (items.isNotEmpty) catMap[catName.toString()] = items;
        });
        if (catMap.isNotEmpty) parsed[dateKey.toString()] = catMap;
      });
    }
    supplies = parsed;
  }

  static Future<void> _fetchNotes() async {
    final res = await http.get(Uri.parse('$dbUrl/notes.json'));
    if (res.statusCode != 200) return;
    if (res.body == 'null' || res.body.isEmpty) {
      notes = {};
      return;
    }
    final decoded = json.decode(res.body);
    final parsed = <String, String>{};
    if (decoded is Map) {
      decoded.forEach((k, v) {
        if (v != null) parsed[k.toString()] = v.toString();
      });
    }
    notes = parsed;
  }

  static Future<void> _fetchTemplates() async {
    final res = await http.get(Uri.parse('$dbUrl/templates.json'));
    if (res.statusCode != 200) return;
    if (res.body != 'null' && res.body.isNotEmpty) {
      final decoded = json.decode(res.body);
      final parsed = <String, List<String>>{};
      if (decoded is Map) {
        decoded.forEach((k, v) {
          if (v is List) {
            parsed[k.toString()] = v.where((e) => e != null).map((e) => e.toString()).toList();
          }
        });
      }
      templates = parsed;
    } else {
      templates = {
        "기본 외출": ["기저귀", "물티슈", "간식"]
      };
      await saveTemplates();
    }
  }

  static Future<void> _fetchPushSettings() async {
    final res = await http.get(Uri.parse('$dbUrl/push_settings.json'));
    if (res.statusCode != 200) return;
    if (res.body != 'null' && res.body.isNotEmpty) {
      final decoded = json.decode(res.body);
      if (decoded is Map) {
        isPushEnabled = decoded['enabled'] == true;
        pushTime = (decoded['time'] ?? "08:00").toString();
        vapidKey = (decoded['vapidKey'] ?? "").toString();
        lastPushSentDate = (decoded['lastSentDate'] ?? "").toString();
      }
    }
  }

  static Future<void> _fetchPushTokens() async {
    final res = await http.get(Uri.parse('$dbUrl/push_tokens.json'));
    if (res.statusCode != 200) return;
    if (res.body == 'null' || res.body.isEmpty) {
      pushTokens = {};
      return;
    }
    final decoded = json.decode(res.body);
    final parsed = <String, Map<String, dynamic>>{};
    if (decoded is Map) {
      decoded.forEach((k, v) {
        if (v is Map) {
          parsed[k.toString()] = Map<String, dynamic>.from(v);
        }
      });
    }
    pushTokens = parsed;
  }

  static Future<void> _fetchAnniversaries() async {
    final res = await http.get(Uri.parse('$dbUrl/anniversaries.json'));
    if (res.statusCode != 200) return;
    if (res.body == 'null' || res.body.isEmpty) {
      anniversaries = [];
      return;
    }
    final decoded = json.decode(res.body);
    final list = <Map<String, dynamic>>[];
    if (decoded is List) {
      for (final item in decoded) {
        if (item is Map) {
          list.add({
            'name': (item['name'] ?? '').toString(),
            'date': (item['date'] ?? '01-01').toString(),
            'isLunar': item['isLunar'] == true,
          });
        }
      }
    }
    anniversaries = list;
  }

  static Future<void> _fetchRecurringTasks() async {
    final res = await http.get(Uri.parse('$dbUrl/recurring_tasks.json'));
    if (res.statusCode != 200) return;
    if (res.body == 'null' || res.body.isEmpty) {
      recurringTasks = [];
      return;
    }
    final decoded = json.decode(res.body);
    final list = <Map<String, dynamic>>[];
    if (decoded is List) {
      for (final item in decoded) {
        if (item is Map) {
          final rawDays = item['weekdays'];
          final weekdays = <int>[];
          if (rawDays is List) {
            for (final d in rawDays) {
              if (d is int) weekdays.add(d);
            }
          }
          list.add({
            'id': (item['id'] ?? 'rec_${DateTime.now().millisecondsSinceEpoch}').toString(),
            'text': (item['text'] ?? '').toString(),
            'type': (item['type'] ?? 'weekly').toString(),
            'weekdays': weekdays,
            'dayOfMonth': item['dayOfMonth'] is int ? item['dayOfMonth'] : 1,
          });
        }
      }
    }
    recurringTasks = list;
  }

  static Future<void> _fetchRecurringDone() async {
    final res = await http.get(Uri.parse('$dbUrl/recurring_done.json'));
    if (res.statusCode != 200) return;
    if (res.body == 'null' || res.body.isEmpty) {
      recurringDone = {};
      return;
    }
    final decoded = json.decode(res.body);
    final parsed = <String, Map<String, bool>>{};
    if (decoded is Map) {
      decoded.forEach((dateKey, rawMap) {
        if (rawMap is Map) {
          final dayMap = <String, bool>{};
          rawMap.forEach((recId, val) {
            if (val == true) dayMap[recId.toString()] = true;
          });
          if (dayMap.isNotEmpty) parsed[dateKey.toString()] = dayMap;
        }
      });
    }
    recurringDone = parsed;
  }

  static Future<void> _fetchShoppingList() async {
    final res = await http.get(Uri.parse('$dbUrl/shopping_list.json'));
    if (res.statusCode != 200) return;
    if (res.body == 'null' || res.body.isEmpty) {
      shoppingList = [];
      return;
    }
    final decoded = json.decode(res.body);
    final list = <Map<String, dynamic>>[];
    if (decoded is List) {
      for (final item in decoded) {
        if (item is Map) {
          list.add({
            'id': (item['id'] ?? 'shop_${DateTime.now().millisecondsSinceEpoch}').toString(),
            'text': (item['text'] ?? '').toString(),
            'done': item['done'] == true,
            'category': (item['category'] ?? '마트').toString(),
          });
        }
      }
    }
    shoppingList = list;
  }

  // ---------------------------------------------------------
  // 날짜별 부분 저장 (동시 편집 충돌 방지)
  // ---------------------------------------------------------
  static Future<void> saveTasksForDate(String dateStr) async {
    final list = tasks[dateStr];
    final uri = Uri.parse('$dbUrl/tasks/$dateStr.json');
    if (list == null || list.isEmpty) {
      tasks.remove(dateStr);
      await http.delete(uri);
    } else {
      await http.put(uri, body: json.encode(list));
    }
  }

  static Future<void> saveSuppliesForDate(String dateStr) async {
    final map = supplies[dateStr];
    final uri = Uri.parse('$dbUrl/supplies/$dateStr.json');
    if (map == null || map.isEmpty) {
      supplies.remove(dateStr);
      await http.delete(uri);
    } else {
      map.removeWhere((_, items) => items.isEmpty);
      if (map.isEmpty) {
        supplies.remove(dateStr);
        await http.delete(uri);
      } else {
        await http.put(uri, body: json.encode(map));
      }
    }
  }

  static Future<void> saveNoteForDate(String dateStr) async {
    final text = notes[dateStr] ?? '';
    final uri = Uri.parse('$dbUrl/notes/$dateStr.json');
    if (text.trim().isEmpty) {
      notes.remove(dateStr);
      await http.delete(uri);
    } else {
      await http.put(uri, body: json.encode(text));
    }
  }

  static Future<void> saveRecurringDoneForDate(String dateStr) async {
    final map = recurringDone[dateStr];
    final uri = Uri.parse('$dbUrl/recurring_done/$dateStr.json');
    if (map == null || map.isEmpty) {
      recurringDone.remove(dateStr);
      await http.delete(uri);
    } else {
      await http.put(uri, body: json.encode(map));
    }
  }

  static Future<void> saveTemplates() async =>
      await http.put(Uri.parse('$dbUrl/templates.json'), body: json.encode(templates));

  static Future<void> saveAnniversaries() async =>
      await http.put(Uri.parse('$dbUrl/anniversaries.json'), body: json.encode(anniversaries));

  static Future<void> saveRecurringTasks() async =>
      await http.put(Uri.parse('$dbUrl/recurring_tasks.json'), body: json.encode(recurringTasks));

  static Future<void> saveShoppingList() async =>
      await http.put(Uri.parse('$dbUrl/shopping_list.json'), body: json.encode(shoppingList));

  static Future<void> savePushSettings() async {
    final payload = <String, dynamic>{
      'enabled': isPushEnabled,
      'time': pushTime,
      'vapidKey': vapidKey.trim(),
    };
    if (lastPushSentDate.isNotEmpty) {
      payload['lastSentDate'] = lastPushSentDate;
    }
    await http.put(Uri.parse('$dbUrl/push_settings.json'), body: json.encode(payload));
  }

  static Future<void> savePushToken(String tokenKey, Map<String, dynamic> data) async {
    pushTokens[tokenKey] = data;
    await http.put(Uri.parse('$dbUrl/push_tokens/$tokenKey.json'), body: json.encode(data));
  }

  static Future<void> deletePushToken(String tokenKey) async {
    if (tokenKey.isEmpty) return;
    pushTokens.remove(tokenKey);
    await http.delete(Uri.parse('$dbUrl/push_tokens/$tokenKey.json'));
  }

  // ---------------------------------------------------------
  // 반복 일정 헬퍼
  // ---------------------------------------------------------
  static List<Map<String, dynamic>> getRecurringTasksForDate(DateTime date) {
    final lastDayOfMonth = DateTime(date.year, date.month + 1, 0).day;
    final results = <Map<String, dynamic>>[];
    for (final rec in recurringTasks) {
      final type = rec['type'] ?? 'weekly';
      if (type == 'daily') {
        results.add(rec);
      } else if (type == 'weekly') {
        final weekdays = (rec['weekdays'] as List?)?.cast<int>() ?? [];
        if (weekdays.contains(date.weekday)) {
          results.add(rec);
        }
      } else if (type == 'monthly') {
        final targetDay = (rec['dayOfMonth'] is int) ? rec['dayOfMonth'] as int : 1;
        final effectiveDay = targetDay > lastDayOfMonth ? lastDayOfMonth : targetDay;
        if (date.day == effectiveDay) {
          results.add(rec);
        }
      }
    }
    return results;
  }

  static bool isRecurringDone(String dateStr, String recId) {
    return recurringDone[dateStr]?[recId] == true;
  }

  static Future<void> setRecurringDone(String dateStr, String recId, bool done) async {
    recurringDone.putIfAbsent(dateStr, () => {});
    if (done) {
      recurringDone[dateStr]![recId] = true;
    } else {
      recurringDone[dateStr]!.remove(recId);
    }
    await saveRecurringDoneForDate(dateStr);
  }

  static String describeRecurringRule(Map<String, dynamic> rec) {
    final type = rec['type'] ?? 'weekly';
    if (type == 'daily') return '매일';
    if (type == 'monthly') return '매월 ${rec['dayOfMonth'] ?? 1}일';
    const dayLabels = {1: '월', 2: '화', 3: '수', 4: '목', 5: '금', 6: '토', 7: '일'};
    final weekdays = List<int>.from((rec['weekdays'] as List?) ?? [])..sort();
    if (weekdays.isEmpty) return '매주';
    if (weekdays.length == 7) return '매일';
    return '매주 ${weekdays.map((d) => dayLabels[d] ?? '').join('·')}';
  }

  // ---------------------------------------------------------
  // 기념일 양력/음력 매칭
  // ---------------------------------------------------------
  static List<String> getAnniversariesForDate(String dateStr) {
    final results = <String>[];
    if (dateStr.length != 10) return results;

    final solarMonthDay = dateStr.substring(5);
    String lunarMonthDay = '';
    try {
      final year = int.parse(dateStr.substring(0, 4));
      final month = int.parse(dateStr.substring(5, 7));
      final day = int.parse(dateStr.substring(8, 10));
      setSolarDate(year, month, day);
      final lunarIso = getLunarIsoFormat();
      if (lunarIso.length >= 10) {
        lunarMonthDay = lunarIso.substring(5);
      }
    } catch (e) {
      debugPrint('Lunar parse error: $e');
    }

    for (final anniv in anniversaries) {
      final isLunar = anniv['isLunar'] == true;
      final aDate = (anniv['date'] ?? '').toString();
      final name = (anniv['name'] ?? '').toString();
      if (!isLunar) {
        if (aDate == solarMonthDay) results.add(name);
      } else {
        if (lunarMonthDay.isNotEmpty && aDate == lunarMonthDay) {
          results.add('$name (음력)');
        }
      }
    }
    return results;
  }

  // ---------------------------------------------------------
  // 전체 통합 검색
  // ---------------------------------------------------------
  static List<SearchResultItem> searchAll(String rawQuery) {
    final q = rawQuery.trim().toLowerCase();
    if (q.isEmpty) return [];
    final results = <SearchResultItem>[];

    // 1. 반복 일정
    for (final rec in recurringTasks) {
      final text = (rec['text'] ?? '').toString();
      if (text.toLowerCase().contains(q)) {
        results.add(SearchResultItem(
          type: 'recurring',
          title: text,
          subtitle: '반복 일정 · ${describeRecurringRule(rec)}',
        ));
      }
    }

    // 2. 기념일
    for (final anniv in anniversaries) {
      final name = (anniv['name'] ?? '').toString();
      final date = (anniv['date'] ?? '').toString();
      if (name.toLowerCase().contains(q) || date.contains(q)) {
        results.add(SearchResultItem(
          type: 'anniversary',
          title: name,
          subtitle: '기념일 · ${anniv['isLunar'] == true ? "음력" : "양력"} $date',
        ));
      }
    }

    // 3. 장보기 리스트
    for (final item in shoppingList) {
      final text = (item['text'] ?? '').toString();
      final cat = (item['category'] ?? '마트').toString();
      if (text.toLowerCase().contains(q) || cat.toLowerCase().contains(q)) {
        results.add(SearchResultItem(
          type: 'shopping',
          title: text,
          subtitle: '상시 리스트 · $cat',
          done: item['done'] == true,
        ));
      }
    }

    // 4. 할 일 (최신 날짜순)
    final taskDates = tasks.keys.toList()..sort((a, b) => b.compareTo(a));
    for (final d in taskDates) {
      for (final task in tasks[d] ?? []) {
        final text = (task['text'] ?? '').toString();
        if (text.toLowerCase().contains(q)) {
          results.add(SearchResultItem(
            type: 'task',
            title: text,
            subtitle: '할 일 · $d',
            dateStr: d,
            done: task['done'] == true,
          ));
        }
      }
    }

    // 5. 준비물 (최신 날짜순)
    final supplyDates = supplies.keys.toList()..sort((a, b) => b.compareTo(a));
    for (final d in supplyDates) {
      supplies[d]?.forEach((catName, items) {
        for (final item in items) {
          final text = (item['text'] ?? '').toString();
          if (text.toLowerCase().contains(q) || catName.toLowerCase().contains(q)) {
            results.add(SearchResultItem(
              type: 'supply',
              title: text,
              subtitle: '준비물($catName) · $d',
              dateStr: d,
              done: item['done'] == true,
            ));
          }
        }
      });
    }

    // 6. 메모 (최신 날짜순)
    final noteDates = notes.keys.toList()..sort((a, b) => b.compareTo(a));
    for (final d in noteDates) {
      final content = notes[d] ?? '';
      if (content.toLowerCase().contains(q)) {
        final preview = content.replaceAll('\n', ' ').trim();
        results.add(SearchResultItem(
          type: 'note',
          title: preview.length > 60 ? '${preview.substring(0, 60)}...' : preview,
          subtitle: '메모장 · $d',
          dateStr: d,
        ));
      }
    }

    return results;
  }

  static String formatDate(DateTime dt) => DateFormat('yyyy-MM-dd').format(dt);
}
