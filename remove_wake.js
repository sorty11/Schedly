const fs = require('fs');

// 1. announcement_service.dart
let ann = fs.readFileSync('lib/services/announcement_service.dart', 'utf8');
ann = ann.replace("import 'notification_api_client.dart';\\n", "");
ann = ann.replace(/    \/\/ 3\. Ping backend to wake up worker\s+NotificationApiClient\.wakeUpWorker\(\);\s+/, "");
fs.writeFileSync('lib/services/announcement_service.dart', ann);

// 2. timetable_event_service.dart
let tt = fs.readFileSync('lib/services/timetable_event_service.dart', 'utf8');
tt = tt.replace("import 'notification_api_client.dart';\\n", "");
tt = tt.replace(/    NotificationApiClient\.wakeUpWorker\(\);\s*/, "");
fs.writeFileSync('lib/services/timetable_event_service.dart', tt);

// 3. main.dart (if it has the import)
let main = fs.readFileSync('lib/main.dart', 'utf8');
main = main.replace("import 'services/notification_api_client.dart';\\n", "");
main = main.replace(/    \/\/ Initialize background queue handler\s+await NotificationApiClient\.initOfflineQueue\(\);\s*/, "");
fs.writeFileSync('lib/main.dart', main);

console.log('Removed /wake from Flutter');
