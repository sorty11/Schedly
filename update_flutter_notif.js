const fs = require('fs');

const code = `import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'topic_subscription_service.dart';

class AppNotificationService {
  static final FirebaseMessaging messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    try {
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // We only initialize topics now, no fcm_tokens are stored in Firestore
        final prefs = await SharedPreferences.getInstance();
        final division = prefs.getString('selected_division');
        final role = prefs.getString('user_role');
        
        if (division != null) {
          await TopicSubscriptionService.updateSubscriptions(division, role ?? 'student');
        }
      }
    } catch (e) {
      debugPrint('FCM init skipped: \$e');
    }
  }

  static Future<void> updateDivisionSubscription(String newDivision) async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('user_role') ?? 'student';
    await TopicSubscriptionService.updateSubscriptions(newDivision, role);
  }

  static Future<void> clearTokenOnLogout() async {
    // Unsubscribe from existing topics on logout
    try {
      final prefs = await SharedPreferences.getInstance();
      final oldTopic = prefs.getString('current_fcm_topic');
      final oldRoleTopic = prefs.getString('current_fcm_role_topic');
      
      if (oldTopic != null) {
        await TopicSubscriptionService.unsubscribeDivision(oldTopic);
        await prefs.remove('current_fcm_topic');
      }
      if (oldRoleTopic != null) {
        await TopicSubscriptionService.unsubscribeRole(oldRoleTopic);
        await prefs.remove('current_fcm_role_topic');
      }
    } catch (e) {
      debugPrint('Failed to unsubscribe on logout: \$e');
    }
  }
}
`;

fs.writeFileSync('lib/services/notification_service.dart', code);
console.log('Updated notification_service.dart');
