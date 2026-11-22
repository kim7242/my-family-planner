(function () {
  const firebaseConfig = {
    apiKey: "AIzaSyCnpXB9mwIIrIvNHXOhbyOucbGORCTsV6U",
    authDomain: "familyplanners-a98b5.firebaseapp.com",
    databaseURL: "https://familyplanners-a98b5-default-rtdb.firebaseio.com",
    projectId: "familyplanners-a98b5",
    storageBucket: "familyplanners-a98b5.firebasestorage.app",
    messagingSenderId: "577482599274",
    appId: "1:577482599274:web:940cd377bcee9c66f91313",
    measurementId: "G-PWBHM2E0PM"
  };

  let messagingInstance = null;
  let swRegistration = null;

  function withTimeout(promise, ms, label) {
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error(label + ' 시간 초과(' + Math.round(ms / 1000) + '초)')), ms);
      promise.then(
        (val) => { clearTimeout(timer); resolve(val); },
        (err) => { clearTimeout(timer); reject(err); }
      );
    });
  }

  function waitForWorkerActive(reg, timeoutMs) {
    return new Promise((resolve, reject) => {
      if (reg.active && reg.active.state === 'activated') {
        resolve(reg);
        return;
      }
      const worker = reg.installing || reg.waiting || reg.active;
      if (!worker) {
        resolve(reg);
        return;
      }
      if (worker.state === 'activated') {
        resolve(reg);
        return;
      }
      const timer = setTimeout(() => {
        resolve(reg);
      }, timeoutMs || 6000);
      worker.addEventListener('statechange', function onChange() {
        if (worker.state === 'activated') {
          clearTimeout(timer);
          worker.removeEventListener('statechange', onChange);
          resolve(reg);
        } else if (worker.state === 'redundant') {
          clearTimeout(timer);
          worker.removeEventListener('statechange', onChange);
          reject(new Error('서비스 워커가 활성화되지 못했습니다. 새로고침 후 다시 시도해 주세요.'));
        }
      });
    });
  }

  function ensureFirebase() {
    if (typeof firebase === 'undefined') return null;
    if (!firebase.apps || firebase.apps.length === 0) {
      firebase.initializeApp(firebaseConfig);
    }
    if (!messagingInstance && firebase.messaging && firebase.messaging.isSupported()) {
      messagingInstance = firebase.messaging();
      messagingInstance.onMessage((payload) => {
        const title = (payload.notification && payload.notification.title) || '가족 플래너 알림';
        const body = (payload.notification && payload.notification.body) || '';
        if (Notification.permission === 'granted') {
          if (swRegistration && swRegistration.showNotification) {
            swRegistration.showNotification(title, { body: body, icon: '/icons/Icon-192.png' });
          } else {
            new Notification(title, { body: body, icon: '/icons/Icon-192.png' });
          }
        }
      });
    }
    return messagingInstance;
  }

  async function ensureServiceWorker() {
    if (!('serviceWorker' in navigator)) return null;
    if (swRegistration && swRegistration.active) return swRegistration;

    const reg = await withTimeout(
      navigator.serviceWorker.register('/firebase-messaging-sw.js', { scope: '/' }),
      10000,
      '서비스 워커 등록'
    );
    await waitForWorkerActive(reg, 6000);
    swRegistration = reg;
    return swRegistration;
  }

  function detectDeviceInfo() {
    const ua = navigator.userAgent || '';
    const isIOS = /iPad|iPhone|iPod/.test(ua) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
    const isStandalone = window.matchMedia('(display-mode: standalone)').matches || window.navigator.standalone === true;
    let label = '웹 브라우저';
    if (isIOS) label = isStandalone ? '아이폰 PWA' : '아이폰 Safari';
    else if (/Android/i.test(ua)) label = isStandalone ? '안드로이드 PWA' : '안드로이드 브라우저';
    else if (/Windows/i.test(ua)) label = 'Windows PC';
    else if (/Mac/i.test(ua)) label = 'Mac PC';
    return { isIOS, isStandalone, label };
  }

  window.FamilyPlannerFCM = {
    getStatus: function () {
      const info = detectDeviceInfo();
      const supported = ('Notification' in window) && ('serviceWorker' in navigator) && ('PushManager' in window);
      const permission = ('Notification' in window) ? Notification.permission : 'unsupported';
      const savedToken = localStorage.getItem('fp_fcm_token') || '';
      const savedKey = localStorage.getItem('fp_fcm_key') || '';
      return JSON.stringify({
        supported: supported,
        permission: permission,
        isIOS: info.isIOS,
        isStandalone: info.isStandalone,
        deviceLabel: info.label,
        token: savedToken,
        tokenKey: savedKey
      });
    },

    requestAndRegister: async function (vapidKey) {
      try {
        const info = detectDeviceInfo();
        if (info.isIOS && !info.isStandalone) {
          return JSON.stringify({
            ok: false,
            error: '아이폰은 Safari 하단 [공유] → [홈 화면에 추가]로 설치한 앱에서 열어야 푸시 알림을 받을 수 있습니다.'
          });
        }
        if (!('Notification' in window) || !('serviceWorker' in navigator) || !('PushManager' in window)) {
          return JSON.stringify({ ok: false, error: '이 브라우저는 웹 푸시 알림을 지원하지 않습니다.' });
        }
        if (!vapidKey || vapidKey.trim().length < 20) {
          return JSON.stringify({ ok: false, error: 'VAPID_MISSING' });
        }

        const permission = await withTimeout(
          Notification.requestPermission(),
          15000,
          '알림 권한 요청'
        );
        if (permission !== 'granted') {
          return JSON.stringify({ ok: false, error: '알림 권한이 거부되었습니다. 기기/브라우저 설정에서 알림을 허용해 주세요.' });
        }

        const reg = await ensureServiceWorker();
        if (!reg) {
          return JSON.stringify({ ok: false, error: '서비스 워커를 등록할 수 없습니다.' });
        }

        const messaging = ensureFirebase();
        if (!messaging) {
          return JSON.stringify({ ok: false, error: 'Firebase Messaging 초기화에 실패했습니다.' });
        }

        const token = await withTimeout(
          messaging.getToken({
            vapidKey: vapidKey.trim(),
            serviceWorkerRegistration: reg
          }),
          15000,
          'FCM 토큰 발급'
        );

        if (!token) {
          return JSON.stringify({ ok: false, error: '푸시 토큰을 발급받지 못했습니다. VAPID 키를 확인해 주세요.' });
        }

        let tokenKey = localStorage.getItem('fp_fcm_key');
        if (!tokenKey) {
          tokenKey = 'dev_' + Date.now() + '_' + Math.random().toString(36).slice(2, 8);
          localStorage.setItem('fp_fcm_key', tokenKey);
        }
        localStorage.setItem('fp_fcm_token', token);

        return JSON.stringify({
          ok: true,
          token: token,
          tokenKey: tokenKey,
          deviceLabel: info.label
        });
      } catch (e) {
        return JSON.stringify({ ok: false, error: String(e && e.message ? e.message : e) });
      }
    },

    clearLocalToken: function () {
      const key = localStorage.getItem('fp_fcm_key') || '';
      localStorage.removeItem('fp_fcm_token');
      return key;
    },

    sendTestNotification: async function (title, body) {
      try {
        if (!('Notification' in window)) {
          return JSON.stringify({ ok: false, error: '이 브라우저는 알림을 지원하지 않습니다.' });
        }
        let permission = Notification.permission;
        if (permission === 'default') {
          permission = await Notification.requestPermission();
        }
        if (permission !== 'granted') {
          return JSON.stringify({ ok: false, error: '알림 권한을 먼저 허용해 주세요.' });
        }
        const reg = await ensureServiceWorker();
        if (reg && reg.showNotification) {
          await reg.showNotification(title || '가족 플래너 테스트 알림', {
            body: body || '알림이 정상적으로 도착했습니다! 🎉',
            icon: '/icons/Icon-192.png'
          });
        } else {
          new Notification(title || '가족 플래너 테스트 알림', {
            body: body || '알림이 정상적으로 도착했습니다! 🎉',
            icon: '/icons/Icon-192.png'
          });
        }
        return JSON.stringify({ ok: true });
      } catch (e) {
        return JSON.stringify({ ok: false, error: String(e && e.message ? e.message : e) });
      }
    }
  };
})();
