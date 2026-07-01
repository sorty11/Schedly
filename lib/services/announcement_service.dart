import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AnnouncementService {
  static final FirebaseFirestore db = FirebaseFirestore.instance;

  static Future<void> createAnnouncement({
    required String title,
    required String message,
    required String priority,
    required String sectionId,
  }) async {
    final batch = db.batch();
    
    // 1. Create announcement
    final annRef = db.collection('sections').doc(sectionId).collection('announcements').doc();
    batch.set(annRef, {
      'title': title,
      'message': message,
      'priority': priority,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2. Create outbox entry
    final outboxRef = db.collection('notification_outbox').doc();
    batch.set(outboxRef, {
      'notificationId': 'ann_${DateTime.now().millisecondsSinceEpoch}',
      'type': 'announcement',
      'title': title,
      'body': message,
      'division': sectionId,
      'priority': priority.toLowerCase() == 'high' ? 'high' : 'normal',
      'processed': false,
      'attempts': 0,
      'nextRetryAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'uid': FirebaseAuth.instance.currentUser?.uid ?? '',
    });

    await batch.commit();

}
}
