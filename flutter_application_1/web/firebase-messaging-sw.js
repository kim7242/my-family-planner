importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

self.addEventListener('install', () => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim());
});

firebase.initializeApp({
  apiKey: "AIzaSyCnpXB9mwIIrIvNHXOhbyOucbGORCTsV6U",
  authDomain: "familyplanners-a98b5.firebaseapp.com",
  databaseURL: "https://familyplanners-a98b5-default-rtdb.firebaseio.com",
  projectId: "familyplanners-a98b5",
  storageBucket: "familyplanners-a98b5.firebasestorage.app",
  messagingSenderId: "577482599274",
  appId: "1:577482599274:web:940cd377bcee9c66f91313",
  measurementId: "G-PWBHM2E0PM"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const title = (payload.notification && payload.notification.title) || (payload.data && payload.data.title) || '가족 플래너 알림';
  const body = (payload.notification && payload.notification.body) || (payload.data && payload.data.body) || '오늘의 일정을 확인해 보세요!';

  self.registration.showNotification(title, {
    body: body,
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: { url: '/' }
  });
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const targetUrl = (event.notification.data && event.notification.data.url) || '/';
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windowClients) => {
      for (const client of windowClients) {
        if (client.url.includes(self.location.origin) && 'focus' in client) {
          return client.focus();
        }
      }
      if (clients.openWindow) {
        return clients.openWindow(targetUrl);
      }
    })
  );
});
