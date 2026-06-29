import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  static final FirebaseMessaging messaging =
      FirebaseMessaging.instance;

  static Future<void> initialize() async {
    try {
      await messaging.requestPermission();

      final token = await messaging.getToken();
      debugPrint('FCM TOKEN: $token');
    } catch (e) {
      // FCM is unavailable on this device/emulator (e.g. no Google Play Services).
      // This is non-fatal — the in-app notification feed still works without FCM.
      debugPrint('FCM init skipped: $e');
    }
  }
}