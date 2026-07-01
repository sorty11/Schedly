const fs = require('fs');
let code = fs.readFileSync('lib/main.dart', 'utf8');

if (!code.includes("import 'services/notification_api_client.dart';")) {
  code = code.replace(
    "import 'services/notification_service.dart';",
    "import 'services/notification_service.dart';\nimport 'services/notification_api_client.dart';"
  );
}

if (!code.includes("NotificationApiClient.initOfflineQueue();")) {
  code = code.replace(
    "await NotificationService.initialize();",
    "await NotificationService.initialize();\n  await NotificationApiClient.initOfflineQueue();"
  );
}

fs.writeFileSync('lib/main.dart', code);
console.log('Patched main.dart');
