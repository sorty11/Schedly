importScripts("https://www.gstatic.com/firebasejs/10.8.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.8.0/firebase-messaging-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.8.0/firebase-firestore-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyCvHene63scD_yzJiR0HHWHBKTad-n-sSI",
  appId: "1:1044389536762:web:8b8c7ec25645328411ba43",
  messagingSenderId: "1044389536762",
  projectId: "schedly-production",
  authDomain: "schedly-production.firebaseapp.com",
  storageBucket: "schedly-production.firebasestorage.app",
  measurementId: "G-RKCNHWHVX9"
});

const messaging = firebase.messaging();
const db = firebase.firestore();

const DEBUG_MODE = true; // Set to false to disable telemetry

function logDiagnostic(stage, data) {
  if (!DEBUG_MODE) return;
  try {
    db.collection('diagnostic_logs').add({
      stage: stage,
      data: JSON.stringify(data),
      timestamp: firebase.firestore.FieldValue.serverTimestamp(),
      source: 'service-worker'
    });
  } catch (e) { console.error('Diag Error', e); }
}

// ── Background message handler (FCM SDK fires this) ────────────────────────
messaging.onBackgroundMessage((payload) => {
  console.log('[SW] onBackgroundMessage:', payload);
  logDiagnostic('SW_ON_BACKGROUND_MESSAGE', payload);
  const title = payload.notification?.title || payload.data?.title || 'Schedly';
  const body  = payload.notification?.body  || payload.data?.body  || '';
  const link  = payload.data?.deepLink || payload.fcmOptions?.link || '/';

  self.registration.showNotification(title, {
    body,
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    tag: payload.data?.notificationId || 'schedly-notification',
    renotify: true,
    data: { link },
    vibrate: [200, 100, 200],
    actions: [{ action: 'open', title: 'Open Schedly' }],
  });
});

// ── Raw push fallback (fires when FCM SDK doesn't intercept) ───────────────
// This handles cases where the FCM SDK onBackgroundMessage doesn't fire
// (e.g. some browsers, or when data-only messages arrive)
self.addEventListener('push', (event) => {
  logDiagnostic('SW_RAW_PUSH_EVENT_RECEIVED', { hasData: !!event.data });
  // If Firebase messaging already handled it, skip
  if (!event.data) return;

  let payload = {};
  try {
    payload = event.data.json();
  } catch (_) {
    // Some browsers send text
    payload = { notification: { title: 'Schedly', body: event.data.text() } };
  }
  
  logDiagnostic('SW_RAW_PUSH_PARSED', payload);

  // Firebase wraps the payload under notification or data
  const notification = payload.notification || {};
  const data = payload.data || {};

  const title = notification.title || data.title || 'Schedly';
  const body  = notification.body  || data.body  || '';
  const link  = data.deepLink || '/';

  // Don't double-show if Firebase SDK already caught it
  const showPromise = self.registration.showNotification(title, {
    body,
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    tag: data.notificationId || 'schedly-push',
    data: { link },
    vibrate: [200, 100, 200],
  }).then(() => logDiagnostic('SW_RAW_PUSH_SHOW_NOTIFICATION_SUCCESS', { title }))
    .catch(err => logDiagnostic('SW_RAW_PUSH_SHOW_NOTIFICATION_ERROR', { error: err.toString() }));

  event.waitUntil(showPromise);
});

// ── Notification click handler ─────────────────────────────────────────────
self.addEventListener('notificationclick', (event) => {
  logDiagnostic('SW_NOTIFICATION_CLICK', { action: event.action, tag: event.notification.tag });
  event.notification.close();

  const link = event.notification.data?.link || '/';
  const url = new URL(link, self.location.origin).href;

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windowClients) => {
      // Focus existing open tab if available
      for (const client of windowClients) {
        if (client.url === url && 'focus' in client) {
          return client.focus();
        }
      }
      // Otherwise open a new window
      if (clients.openWindow) {
        return clients.openWindow(url);
      }
    })
  );
});

// ── Service Worker lifecycle ────────────────────────────────────────────────
self.addEventListener('install', (event) => {
  logDiagnostic('SW_INSTALL', {});
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  logDiagnostic('SW_ACTIVATE', {});
  event.waitUntil(clients.claim());
});
