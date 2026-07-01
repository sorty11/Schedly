const fs = require('fs');
let code = fs.readFileSync('lib/services/timetable_event_service.dart', 'utf8');

if (!code.includes("import 'notification_api_client.dart';")) {
  code = code.replace(
    "import 'package:schedly/services/local_notification_service.dart';",
    "import 'package:schedly/services/local_notification_service.dart';\nimport 'package:schedly/services/notification_api_client.dart';"
  );
}

if (!code.includes("NotificationApiClient.sendNotificationAsync")) {
  code = code.replace(
    "    // 3. Local Push Notification",
    `    // Trigger Render Backend Push Notification for timetable updates
    NotificationApiClient.sendNotificationAsync({
      'notificationId': 'tt_\${DateTime.now().millisecondsSinceEpoch}',
      'type': type,
      'title': title,
      'body': message,
      'division': division,
      'priority': (type == 'cancel' || type == 'edit' || type == 'time_change' || type == 'room_change') ? 'high' : 'normal',
    });

    // 3. Local Push Notification`
  );
}

fs.writeFileSync('lib/services/timetable_event_service.dart', code);
console.log('Patched timetable_event_service.dart');
