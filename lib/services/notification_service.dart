import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  static final FirebaseMessaging messaging =
      FirebaseMessaging.instance;

  static Future<void> initialize() async {
    await messaging.requestPermission();

    String? token =
        await messaging.getToken();

    print(
      'FCM TOKEN: $token',
    );
  }
}