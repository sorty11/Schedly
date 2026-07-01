const fs = require('fs');

let listener = fs.readFileSync('lib/services/announcement_listener.dart', 'utf8');
listener = listener.replace(/LocalNotificationService\.showNotification\(\s*title: data\['title'\] \?\? 'Announcement',\s*body: data\['message'\] \?\? '',\s*\);/g, '// Notification banner now handled by FCM foreground listener');
listener = listener.replace(/LocalNotificationService\.showNotification\(\s*title: data\['title'\] \?\? 'Timetable Update',\s*body: data\['message'\] \?\? '',\s*\);/g, '// Notification banner now handled by FCM foreground listener');
fs.writeFileSync('lib/services/announcement_listener.dart', listener);

let notif = fs.readFileSync('lib/services/notification_service.dart', 'utf8');
const fgListener = `
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        // Only show manual banner if there is no notification payload (data-only).
        // Since we send a notification payload in the backend, Android might automatically
        // show a head-up display in foreground for some Android versions, but flutter_local_notifications
        // can be used if we want explicit control. Actually, FCM plugin blocks foreground notifications on Android by default
        // unless you set foreground presentation options. We will just use our LocalNotificationService.
        
        final title = message.notification?.title ?? message.data['title'] ?? 'New Notification';
        final body = message.notification?.body ?? message.data['body'] ?? '';
        
        // Import must be handled
        // LocalNotificationService.showNotification(title: title, body: body);
        // Wait, since we are in NotificationService, we need to import LocalNotificationService.
      });
`;
// Let's rewrite the patch for notification_service.dart
let notifCode = fs.readFileSync('lib/services/notification_service.dart', 'utf8');
if (!notifCode.includes('import \'local_notification_service.dart\';')) {
  notifCode = notifCode.replace(/import 'package:shared_preferences\/shared_preferences.dart';/, "import 'package:shared_preferences/shared_preferences.dart';\nimport 'local_notification_service.dart';");
}

if (!notifCode.includes('FirebaseMessaging.onMessage.listen')) {
  notifCode = notifCode.replace(/messaging\.onTokenRefresh\.listen\(_saveTokenToFirestore\);/, `messaging.onTokenRefresh.listen(_saveTokenToFirestore);
      
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final title = message.notification?.title ?? message.data['title'] ?? 'New Notification';
        final body = message.notification?.body ?? message.data['body'] ?? '';
        LocalNotificationService.showNotification(title: title, body: body);
      });`);
}
fs.writeFileSync('lib/services/notification_service.dart', notifCode);

console.log('Patched Stage 5 files');
