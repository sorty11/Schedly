import 'package:cloud_firestore/cloud_firestore.dart';

import 'local_notification_service.dart';

class AnnouncementListener {
  static bool _isFirstAnnouncementSnapshot = true;
  static bool _isFirstNotificationSnapshot = true;

  /// Call this from HomePage.initState() where [division] is always known.
  static void start(String division) {
    // Listen to Announcements
    FirebaseFirestore.instance
        .collection('announcements')
        .where('division', isEqualTo: division)
        .snapshots()
        .listen((snapshot) {
      if (_isFirstAnnouncementSnapshot) {
        _isFirstAnnouncementSnapshot = false;
        return; // Ignore existing documents on startup
      }

      if (snapshot.docs.isEmpty) return;

      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data == null) continue;

          // Notification banner now handled by FCM foreground listener
        }
      }
    });

    // Listen to Timetable Notifications
    FirebaseFirestore.instance
        .collection('notifications')
        .where('division', isEqualTo: division)
        .snapshots()
        .listen((snapshot) {
      if (_isFirstNotificationSnapshot) {
        _isFirstNotificationSnapshot = false;
        return; // Ignore existing documents on startup
      }

      if (snapshot.docs.isEmpty) return;

      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data == null) continue;

          // Notification banner now handled by FCM foreground listener
        }
      }
    });
  }
}