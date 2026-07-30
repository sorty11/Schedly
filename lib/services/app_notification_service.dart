import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../app_settings.dart';
import '../user_roles.dart';

class AppNotificationService {
  static final FirebaseFirestore db = FirebaseFirestore.instance;

  static Future<void> dispatch({
    required String title,
    required String message,
    required String division,
    required String type, // 'announcement', 'reschedule', 'cancellation'
    String priority = 'Normal',
  }) async {
    final batch = db.batch();

    // 1. In-app notification (for Updates tab)
    final notifRef = db.collection('sections').doc(division).collection('notifications').doc();
    batch.set(notifRef, {
      'title': title,
      'message': message,
      'type': type,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2. Announcements board
    if (type == 'announcement') {
      final annRef = db.collection('sections').doc(division).collection('announcements').doc();
      batch.set(annRef, {
        'title': title,
        'message': message,
        'priority': priority,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    // 3. Push Notification Outbox
    String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (AppSettings.currentRole == UserRole.faculty && AppSettings.facultyId != null) {
      uid = AppSettings.facultyId!;
    }

    final outboxRef = db.collection('notification_outbox').doc();
    batch.set(outboxRef, {
      'notificationId': '${type}_${DateTime.now().millisecondsSinceEpoch}',
      'type': type,
      'title': title,
      'body': message,
      'division': division,
      'priority': priority.toLowerCase() == 'high' ? 'high' : 'normal',
      'processed': false,
      'attempts': 0,
      'nextRetryAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'uid': uid,
    });

    await batch.commit();
  }
}