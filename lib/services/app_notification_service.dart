import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotificationService {
  static final FirebaseFirestore db =
      FirebaseFirestore.instance;

  static Future<void> createNotification({
    required String title,
    required String message,
    required String division, // Actually sectionId, keeping name for compatibility
    required String type,
  }) async {
    await db
        .collection('sections')
        .doc(division)
        .collection('notifications')
        .add({
      'title': title,
      'message': message,
      'type': type,
      'createdAt':
          FieldValue.serverTimestamp(),
    });
  }
}