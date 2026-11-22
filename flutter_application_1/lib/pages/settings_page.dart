import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data_manager.dart';
import '../fcm_service.dart';
import '../modals.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _itemsController = TextEditingController();
  final TextEditingController _vapidController = TextEditingController();

  Map<String, dynamic> _fcmStatus = {};
  bool _isRegisteringPush = false;
  bool _showVapidInput = false;

  @override
  void initState() {
    super.initState();
    _vapidController.text = DataManager.vapidKey;
    _refreshFcmStatus();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _itemsController.dispose();
    _vapidController.dispose();
    super.dispose();
  }

  void _refreshFcmStatus() {
    _fcmStatus = FcmService.getStatus();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _addTemplate() {
    final name = _nameController.text.trim();
    final itemsText = _itemsController.text.trim();
    if (name.isNotEmpty && itemsText.isNotEmpty) {
      final itemsList = itemsText.split(RegExp(r'[\s,]+')).where((e) => e.isNotEmpty).toList();
      setState(() {
        DataManager.templates[name] = itemsList;
      });
      DataManager.saveTemplates();
      _nameController.clear();
      _itemsController.clear();
      FocusScope.of(context).unfocus();
    }
  }

  void _deleteTemplate(String name) {
    setState(() => DataManager.templates.remove(name));
    DataManager.saveTemplates();
  }

  void _editTemplate(String name, List<String> items) {
    setState(() {
      _nameController.text = name;
      _itemsController.text = items.join(' ');
    });
  }

  void _selectPushTime() {
    final parts = DataManager.pushTime.split(':');
    final currentHour = int.tryParse(parts.isNotEmpty ? parts[0] : '8') ?? 8;
    final currentMinute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext builder) {
        return SizedBox(
          height: 250,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CupertinoButton(
                    child: const Text('완료', style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      DataManager.savePushSettings();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  initialDateTime: DateTime(2023, 1, 1, currentHour, currentMinute),
                  use24hFormat: false,
                  onDateTimeChanged: (DateTime newDateTime) {
                    setState(() {
                      DataManager.pushTime = DateFormat('HH:mm').format(newDateTime);
                    });
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _registerThisDevice() async {
    final keyToUse = _vapidController.text.trim().isNotEmpty ? _vapidController.text.trim() : DataManager.vapidKey.trim();
    if (keyToUse.isEmpty) {
      setState(() => _showVapidInput = true);
      _showSnack('먼저 아래에 Firebase 웹 푸시 인증서(VAPID 키)를 입력해 주세요.');
      return;
    }

    setState(() => _isRegisteringPush = true);
    if (keyToUse != DataManager.vapidKey) {
      DataManager.vapidKey = keyToUse;
      await DataManager.savePushSettings();
    }

    final result = await FcmService.requestAndRegister(keyToUse);
    if (result['ok'] == true) {
      final tokenKey = result['tokenKey'].toString();
      await DataManager.savePushToken(tokenKey, {
        'token': result['token'].toString(),
        'device': (result['deviceLabel'] ?? '웹 기기').toString(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
      if (!DataManager.isPushEnabled) {
        DataManager.isPushEnabled = true;
        await DataManager.savePushSettings();
      }
      _refreshFcmStatus();
      _showSnack('이 기기가 아침 푸시 알림 기기로 등록되었습니다! 🔔');
    } else {
      final err = (result['error'] ?? '등록에 실패했습니다.').toString();
      if (err == 'VAPID_MISSING') {
        setState(() => _showVapidInput = true);
        _showSnack('VAPID 키를 먼저 입력해 주세요.');
      } else {
        _showSnack(err);
      }
    }
    if (mounted) setState(() => _isRegisteringPush = false);
  }

  Future<void> _unregisterThisDevice() async {
    final tokenKey = FcmService.clearLocalToken();
    if (tokenKey.isNotEmpty) {
      await DataManager.deletePushToken(tokenKey);
    }
    _refreshFcmStatus();
    if (mounted) setState(() {});
    _showSnack('이 기기의 푸시 알림 등록을 해제했습니다.');
  }

  Future<void> _sendLocalTestNotification() async {
    final res = await FcmService.sendTestNotification(
      '🐤 가족 플래너 테스트 알림',
      '설정하신 ${DataManager.pushTime}에 오늘의 할 일·준비물·기념일을 알려드려요!',
    );
    if (res['ok'] == true) {
      _showSnack('테스트 알림을 보냈습니다!');
    } else {
      _showSnack((res['error'] ?? '알림 전송에 실패했습니다.').toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final localToken = (_fcmStatus['token'] ?? '').toString();
    final localTokenKey = (_fcmStatus['tokenKey'] ?? '').toString();
    final isRegisteredLocally = localToken.isNotEmpty && DataManager.pushTokens.containsKey(localTokenKey);
    final isIOS = _fcmStatus['isIOS'] == true;
    final isStandalone = _fcmStatus['isStandalone'] == true;
    final deviceLabel = (_fcmStatus['deviceLabel'] ?? '웹 브라우저').toString();

    return Scaffold(
      appBar: AppBar(title: const Text('⚙️ 앱 설정')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // 1. 기념일 관리
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Text('🎂', style: TextStyle(fontSize: 18)),
                  SizedBox(width: 8),
                  Text('기념일 관리', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.brown)),
                ],
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => AnniversaryHelper.showModal(context, () => setState(() {})),
                child: const Text('+ 추가', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.pinkAccent)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            child: DataManager.anniversaries.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Center(child: Text('등록된 기념일이 없습니다.', style: TextStyle(color: Colors.grey))),
                  )
                : Column(
                    children: DataManager.anniversaries.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final anniv = entry.value;
                      return ListTile(
                        title: Text(anniv['name'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.brown)),
                        subtitle: Text('${anniv['isLunar'] == true ? "음력" : "양력"} ${anniv['date']}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit, color: Colors.orangeAccent),
                          onPressed: () => AnniversaryHelper.showModal(context, () => setState(() {}), editIndex: idx),
                        ),
                      );
                    }).toList(),
                  ),
          ),

          const SizedBox(height: 26),

          // 2. 반복 일정 관리
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Text('🔁', style: TextStyle(fontSize: 18)),
                  SizedBox(width: 8),
                  Text('반복 일정 관리', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.brown)),
                ],
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => PlannerModals.showRecurringModal(context, () => setState(() {})),
                child: const Text('+ 추가', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            child: DataManager.recurringTasks.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Center(child: Text('등록된 반복 일정이 없습니다.\n(예: 매주 수요일 분리수거, 매월 25일 공과금)', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12))),
                  )
                : Column(
                    children: DataManager.recurringTasks.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final rec = entry.value;
                      return ListTile(
                        leading: const Icon(Icons.repeat, color: Colors.teal),
                        title: Text(rec['text'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.brown)),
                        subtitle: Text(DataManager.describeRecurringRule(rec), style: const TextStyle(color: Colors.teal, fontSize: 12)),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit, color: Colors.orangeAccent),
                          onPressed: () => PlannerModals.showRecurringModal(context, () => setState(() {}), editIndex: idx),
                        ),
                      );
                    }).toList(),
                  ),
          ),

          const SizedBox(height: 26),

          // 3. 푸시 알림 설정 (FCM / PWA)
          const Row(
            children: [
              Text('🔔', style: TextStyle(fontSize: 18)),
              SizedBox(width: 8),
              Text('아침 푸시 알림 설정', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.brown)),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('오늘의 일정 알림 켜기'),
                  subtitle: const Text('할 일·반복 일정·준비물·기념일이 있는 날 알림을 받습니다.', style: TextStyle(fontSize: 12)),
                  trailing: CupertinoSwitch(
                    activeTrackColor: Colors.orangeAccent,
                    value: DataManager.isPushEnabled,
                    onChanged: (bool value) {
                      setState(() => DataManager.isPushEnabled = value);
                      DataManager.savePushSettings();
                    },
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFFFF9F2)),
                ListTile(
                  title: const Text('알림 수신 시간'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(DataManager.pushTime, style: const TextStyle(fontSize: 16, color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                    ],
                  ),
                  onTap: _selectPushTime,
                ),
                const Divider(height: 1, color: Color(0xFFFFF9F2)),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '등록된 가족 기기: ${DataManager.pushTokens.length}대',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.brown, fontSize: 13),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isRegisteredLocally ? Colors.green[50] : Colors.grey[100],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              isRegisteredLocally ? '이 기기 등록됨 ($deviceLabel)' : '이 기기 미등록',
                              style: TextStyle(fontSize: 11, color: isRegisteredLocally ? Colors.green[700] : Colors.grey[700]),
                            ),
                          ),
                        ],
                      ),
                      if (isIOS && !isStandalone) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            '📱 아이폰 안내: Safari 하단 [공유] → [홈 화면에 추가]로 설치한 뒤, 홈 화면 아이콘으로 열어야 푸시 알림을 받을 수 있어요.',
                            style: TextStyle(fontSize: 12, color: Colors.brown),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isRegisteredLocally ? Colors.grey[200] : Colors.orangeAccent,
                                foregroundColor: isRegisteredLocally ? Colors.brown : Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                elevation: 0,
                              ),
                              onPressed: _isRegisteringPush
                                  ? null
                                  : (isRegisteredLocally ? _unregisterThisDevice : _registerThisDevice),
                              icon: _isRegisteringPush
                                  ? const CupertinoActivityIndicator(radius: 8)
                                  : Icon(isRegisteredLocally ? Icons.notifications_off_outlined : Icons.notifications_active, size: 18),
                              label: Text(
                                isRegisteredLocally ? '이 기기 알림 해제' : '이 기기 알림 등록',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.deepOrangeAccent,
                              side: const BorderSide(color: Colors.deepOrangeAccent),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                            ),
                            onPressed: _sendLocalTestNotification,
                            child: const Text('테스트', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => setState(() => _showVapidInput = !_showVapidInput),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Icon(_showVapidInput ? Icons.expand_less : Icons.expand_more, size: 16, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                DataManager.vapidKey.isNotEmpty
                                    ? '웹 푸시 인증서(VAPID 키) 설정됨 ✓'
                                    : '웹 푸시 인증서(VAPID 키) 설정 필요',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: DataManager.vapidKey.isNotEmpty ? Colors.green[700] : Colors.deepOrangeAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_showVapidInput) ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: _vapidController,
                          decoration: InputDecoration(
                            labelText: 'Firebase 웹 푸시 인증서 키 (VAPID Key)',
                            hintText: 'Firebase 콘솔 > 클라우드 메시징 > 웹 푸시 인증서',
                            filled: true,
                            fillColor: const Color(0xFFFFF9F2),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.brown,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            onPressed: () async {
                              DataManager.vapidKey = _vapidController.text.trim();
                              await DataManager.savePushSettings();
                              if (mounted) {
                                setState(() => _showVapidInput = false);
                                _showSnack('VAPID 키가 저장되었습니다. 이제 [이 기기 알림 등록]을 눌러주세요!');
                              }
                            },
                            child: const Text('VAPID 키 저장'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 26),

          // 4. 준비물 템플릿 관리
          const Row(
            children: [
              Text('🎒', style: TextStyle(fontSize: 18)),
              SizedBox(width: 8),
              Text('준비물 템플릿 관리', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.brown)),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('➕ 새 템플릿 추가 및 수정', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: '템플릿 이름 (예: 수영장 가방)',
                      filled: true,
                      fillColor: const Color(0xFFFFF9F2),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _itemsController,
                    decoration: InputDecoration(
                      labelText: '항목 입력 (띄어쓰기 또는 쉼표로 구분)',
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
                      onPressed: _addTemplate,
                      child: const Text('저장하기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          ...DataManager.templates.entries.map((entry) {
            final key = entry.key;
            final items = entry.value;
            return Card(
              child: ListTile(
                title: Text(key, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.brown)),
                subtitle: Text(items.join(', ')),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.edit, color: Colors.orangeAccent), onPressed: () => _editTemplate(key, items)),
                    IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: () => _deleteTemplate(key)),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
