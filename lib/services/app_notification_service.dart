import 'package:flutter/foundation.dart';
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
    String? batch,
    String? subject,
  }) async {
    // 1. Resolve UID for push outbox
    String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (AppSettings.currentRole == UserRole.faculty &&
        AppSettings.facultyId != null) {
      uid = AppSettings.facultyId!;
    }

    // 2. Queue Push Notification Outbox independently
    final Map<String, dynamic> outboxPayload = {
      'notificationId': '${type}_${DateTime.now().millisecondsSinceEpoch}',
      'type': type,
      'title': title,
      'body': message,
      'division': division,
      if (batch != null && batch != 'Whole Class' && batch.isNotEmpty)
        'batch': batch,
      if (subject != null && subject.isNotEmpty) 'subject': subject,
      'priority': priority.toLowerCase() == 'high' ? 'high' : 'normal',
      'processed': false,
      'attempts': 0,
      'nextRetryAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'uid': uid,
    };

    try {
      final outboxDoc = await db
          .collection('notification_outbox')
          .add(outboxPayload);
      debugPrint(
        '[NOTIFICATION_OUTBOX] Successfully queued push notification: docId=${outboxDoc.id}, division=$division, type=$type, priority=$priority',
      );
    } catch (e, st) {
      debugPrint(
        '[NOTIFICATION_OUTBOX_ERROR] Failed to write notification_outbox: $e\n$st',
      );
      rethrow;
    }

    // 3. Attempt In-App Notification and Announcements in an isolated batch
    try {
      final inAppBatch = db.batch();

      final notifRef = db
          .collection('sections')
          .doc(division)
          .collection('notifications')
          .doc();
      inAppBatch.set(notifRef, {
        'title': title,
        'message': message,
        'type': type,
        if (batch != null && batch != 'Whole Class' && batch.isNotEmpty)
          'batch': batch,
        if (subject != null && subject.isNotEmpty) 'subject': subject,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (type == 'announcement') {
        final annRef = db
            .collection('sections')
            .doc(division)
            .collection('announcements')
            .doc();
        inAppBatch.set(annRef, {
          'title': title,
          'message': message,
          'priority': priority,
          if (batch != null && batch != 'Whole Class' && batch.isNotEmpty)
            'batch': batch,
          if (subject != null && subject.isNotEmpty) 'subject': subject,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await inAppBatch.commit();
      debugPrint(
        '[IN_APP_NOTIFICATION] Successfully saved in-app records for division=$division',
      );
    } catch (e, st) {
      // In-app failure must NEVER prevent push notification delivery
      debugPrint(
        '[IN_APP_NOTIFICATION_ERROR] In-app notification or announcement write failed: $e\n$st',
      );
    }
  }
}
