const fs = require('fs');

let code = fs.readFileSync('lib/services/announcement_service.dart', 'utf8');

if (!code.includes("import 'notification_api_client.dart';")) {
  code = code.replace(
    "import 'package:cloud_firestore/cloud_firestore.dart';",
    "import 'package:cloud_firestore/cloud_firestore.dart';\nimport 'notification_api_client.dart';"
  );
}

if (!code.includes("NotificationApiClient.sendNotificationAsync")) {
  code = code.replace(
    "});\n  }",
    `});
    
    NotificationApiClient.sendNotificationAsync({
      'notificationId': 'ann_\${DateTime.now().millisecondsSinceEpoch}',
      'type': 'announcement',
      'title': title,
      'body': message,
      'division': sectionId,
      'priority': priority.toLowerCase() == 'high' ? 'high' : 'normal',
    });
  }`
  );
}

fs.writeFileSync('lib/services/announcement_service.dart', code);
console.log('Patched announcement_service.dart');
