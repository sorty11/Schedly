import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'local_notification_service.dart';

class AnnouncementListener {
  static String? lastId;

  static Future<void> start() async {
    final prefs =
        await SharedPreferences.getInstance();

    final division =
        prefs.getString(
      'selected_division',
    );

    if (division == null) return;

    FirebaseFirestore.instance
        .collection('announcements')
        .where(
          'division',
          isEqualTo: division,
        )
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isEmpty) {
        return;
      }

      snapshot.docChanges.forEach((
        change,
      ) {
        if (change.type !=
            DocumentChangeType.added) {
          return;
        }

        final doc = change.doc;

        if (lastId == null) {
          lastId = doc.id;
          return;
        }

        if (doc.id == lastId) {
          return;
        }

        lastId = doc.id;

        final data =
            doc.data();

        if (data == null) return;

        LocalNotificationService
            .showNotification(
          title:
              data['title'] ??
                  'Announcement',
          body:
              data['message'] ??
                  '',
        );
      });
    });
  }
}