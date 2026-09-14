import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationCountService {
  static Stream<int> getUnreadCount(String division) {
    return FirebaseFirestore.instance
        .collection('sections')
        .doc(division)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}
