const fs = require('fs');

let content = fs.readFileSync('lib/main.dart', 'utf8');

const bgHandler = `
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Handling a background message: \${message.messageId}");
  
  // Since Android displays notification payloads automatically, we only need to handle data-only
  // messages if we want to show a custom local notification. If it's a notification payload, 
  // the OS handles it in the background!
  
  // Wait, our backend sends both data and notification payloads so Android OS will automatically 
  // display the banner in the background. We don't strictly need to call LocalNotificationService.show() here
  // unless we want to override the default behavior or if it's data-only.
}
`;

if (!content.includes('_firebaseMessagingBackgroundHandler')) {
  // Insert right after the imports
  content = content.replace(/import 'firebase_options\.dart';/, "import 'firebase_options.dart';\nimport 'package:firebase_messaging/firebase_messaging.dart';\n" + bgHandler);
  
  // Register it inside main
  content = content.replace(/await NotificationService\.initialize\(\);/, "await NotificationService.initialize();\n  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);");
  fs.writeFileSync('lib/main.dart', content);
  console.log('Patched main.dart');
} else {
  console.log('main.dart already patched');
}
