import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationCountService {
  static Stream<int> getUnreadCount(
    String division,
  ) {
    return FirebaseFirestore.instance
        .collection('notifications')
        .where(
          'division',
          isEqualTo: division,
        )
        .snapshots()
        .map(
      (snapshot) =>
          snapshot.docs.length,
    );
  }
}