import 'package:cloud_firestore/cloud_firestore.dart';

import 'local_notification_service.dart';

class AnnouncementListener {
  /// Deprecated: Realtime notification banners are now handled directly by
  /// the FCM foreground listener in [NotificationService].
  /// Kept as a lightweight no-op for backward compatibility.
  static void start(String division) {
    // No-op: FCM foreground listener handles incoming notifications.
    // Redundant Firestore socket listeners removed to save bandwidth and startup latency.
  }
}
