import 'package:cloud_firestore/cloud_firestore.dart';

class AnnouncementService {
  static final FirebaseFirestore db =
      FirebaseFirestore.instance;

  static Future<void> createAnnouncement({
    required String title,
    required String message,
    required String priority,
    required String sectionId,
  }) async {
    await db
        .collection('sections')
        .doc(sectionId)
        .collection('announcements')
        .add({
      'title': title,
      'message': message,
      'priority': priority,
      'createdAt':
          FieldValue.serverTimestamp(),
    });
  }
}