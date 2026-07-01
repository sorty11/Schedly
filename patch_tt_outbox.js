const fs = require('fs');
let code = fs.readFileSync('lib/services/timetable_event_service.dart', 'utf8');

const replacement = `    // Trigger Render Backend Push Notification via Outbox
    final outboxRef = FirebaseFirestore.instance.collection('notification_outbox').doc();
    await outboxRef.set({
      'notificationId': 'tt_\${DateTime.now().millisecondsSinceEpoch}',
      'type': type,
      'title': title,
      'body': message,
      'division': division,
      'priority': (type == 'cancel' || type == 'edit' || type == 'time_change' || type == 'room_change') ? 'high' : 'normal',
      'processed': false,
      'attempts': 0,
      'nextRetryAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'uid': FirebaseAuth.instance.currentUser?.uid ?? '',
    });
    NotificationApiClient.wakeUpWorker();`;

code = code.replace(/    \/\/ Trigger Render Backend Push Notification for timetable updates[\s\S]*?\}\);/m, replacement);

if (!code.includes("import 'package:cloud_firestore/cloud_firestore.dart';")) {
  code = "import 'package:cloud_firestore/cloud_firestore.dart';\n" + code;
}
if (!code.includes("import 'package:firebase_auth/firebase_auth.dart';")) {
  code = "import 'package:firebase_auth/firebase_auth.dart';\n" + code;
}

fs.writeFileSync('lib/services/timetable_event_service.dart', code);
console.log('Patched timetable_event_service.dart');
