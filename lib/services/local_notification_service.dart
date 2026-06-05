import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin
      notifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const android =
        AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const settings =
        InitializationSettings(
      android: android,
    );

    await notifications.initialize(
      settings,
    );
  }

  static Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    const androidDetails =
        AndroidNotificationDetails(
      'announcements',
      'Announcements',
      importance: Importance.max,
      priority: Priority.high,
    );

    const details =
        NotificationDetails(
      android: androidDetails,
    );

    await notifications.show(
      DateTime.now()
          .millisecondsSinceEpoch,
      title,
      body,
      details,
    );
  }
}