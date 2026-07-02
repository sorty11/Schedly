importScripts("https://www.gstatic.com/firebasejs/10.8.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.8.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyCArNp9zrzErkeuwMgG-_wPxlKcWZsyn1g",
  appId: "1:981132399209:web:792ac46f48a77e896e88f8",
  messagingSenderId: "981132399209",
  projectId: "schedly-e625d",
  authDomain: "schedly-e625d.firebaseapp.com",
  storageBucket: "schedly-e625d.firebasestorage.app",
  measurementId: "G-HZQ5GZE5T2"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  
  // Backend might send it in notification or data payload
  const notificationTitle = payload.notification?.title || payload.data?.title || 'New Notification';
  const notificationOptions = {
    body: payload.notification?.body || payload.data?.body || '',
    icon: '/icons/Icon-192.png'
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
