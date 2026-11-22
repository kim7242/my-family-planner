import 'dart:convert';
import 'dart:js_interop';

@JS('FamilyPlannerFCM.getStatus')
external JSString _fcmGetStatus();

@JS('FamilyPlannerFCM.requestAndRegister')
external JSPromise<JSString> _fcmRequestAndRegister(JSString vapidKey);

@JS('FamilyPlannerFCM.clearLocalToken')
external JSString _fcmClearLocalToken();

@JS('FamilyPlannerFCM.sendTestNotification')
external JSPromise<JSString> _fcmSendTestNotification(JSString title, JSString body);

class FcmService {
  static Map<String, dynamic> getStatus() {
    try {
      final raw = _fcmGetStatus().toDart;
      return Map<String, dynamic>.from(json.decode(raw));
    } catch (_) {
      return {
        'supported': false,
        'permission': 'unsupported',
        'isIOS': false,
        'isStandalone': false,
        'deviceLabel': '웹 브라우저',
        'token': '',
        'tokenKey': '',
      };
    }
  }

  static Future<Map<String, dynamic>> requestAndRegister(String vapidKey) async {
    try {
      final raw = (await _fcmRequestAndRegister(vapidKey.toJS).toDart).toDart;
      return Map<String, dynamic>.from(json.decode(raw));
    } catch (e) {
      return {'ok': false, 'error': e.toString()};
    }
  }

  static String clearLocalToken() {
    try {
      return _fcmClearLocalToken().toDart;
    } catch (_) {
      return '';
    }
  }

  static Future<Map<String, dynamic>> sendTestNotification(String title, String body) async {
    try {
      final raw = (await _fcmSendTestNotification(title.toJS, body.toJS).toDart).toDart;
      return Map<String, dynamic>.from(json.decode(raw));
    } catch (e) {
      return {'ok': false, 'error': e.toString()};
    }
  }
}
