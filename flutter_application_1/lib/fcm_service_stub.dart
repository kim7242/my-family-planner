class FcmService {
  static Map<String, dynamic> getStatus() => {
        'supported': false,
        'permission': 'unsupported',
        'isIOS': false,
        'isStandalone': false,
        'deviceLabel': '미지원 환경',
        'token': '',
        'tokenKey': '',
      };

  static Future<Map<String, dynamic>> requestAndRegister(String vapidKey) async =>
      {'ok': false, 'error': '웹 브라우저 환경에서만 지원됩니다.'};

  static String clearLocalToken() => '';

  static Future<Map<String, dynamic>> sendTestNotification(String title, String body) async =>
      {'ok': false, 'error': '웹 브라우저 환경에서만 지원됩니다.'};
}
