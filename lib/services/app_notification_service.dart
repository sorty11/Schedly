import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotificationService {
  static final FirebaseFirestore db =
      FirebaseFirestore.instance;

  static Future<void> createNotification({
    required String title,
    required String message,
    required String division,
    required String type,
  }) async {
    await db
        .collection('notifications')
        .add({
      'title': title,
      'message': message,
      'division': division,
      'type': type,
      'createdAt':
          FieldValue.serverTimestamp(),
    });
  }
}