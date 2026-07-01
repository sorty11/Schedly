const fs = require('fs');

const code = `import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final FirebaseMessaging messaging = FirebaseMessaging.instance;

  static Future<void> initialize() async {
    try {
      await messaging.requestPermission(
        alert: true,
        announcement: true,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      final String? token = await messaging.getToken();
      if (token != null) {
        await _saveTokenToFirestore(token);
      }

      messaging.onTokenRefresh.listen(_saveTokenToFirestore);

      final prefs = await SharedPreferences.getInstance();
      final division = prefs.getString('selected_division');
      if (division != null && division.isNotEmpty) {
        await updateDivisionSubscription(division);
      }
    } catch (e) {
      // FCM is unavailable on this device/emulator (e.g. no Google Play Services).
      debugPrint('FCM init skipped: $e');
    }
  }

  static Future<void> _saveTokenToFirestore(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final prefs = await SharedPreferences.getInstance();
      final division = prefs.getString('selected_division') ?? 'unknown';
      final role = prefs.getString('user_role') ?? 'student';

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('fcm_tokens')
          .doc(token)
          .set({
        'token': token,
        'platform': kIsWeb ? 'web' : (defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android'),
        'division': division,
        'role': role,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Failed to save FCM token: $e');
    }
  }

  static String sanitizeTopic(String topic) {
    return topic.replaceAll(RegExp(r'[^a-zA-Z0-9-_.~%]'), '_');
  }

  static Future<void> updateDivisionSubscription(String newDivision) async {
    if (kIsWeb) return; // FCM topics are not supported on Flutter Web natively
    try {
      final prefs = await SharedPreferences.getInstance();
      final oldTopic = prefs.getString('current_fcm_topic');
      final newTopic = 'division_\${sanitizeTopic(newDivision)}';

      if (oldTopic != null && oldTopic != newTopic) {
        await messaging.unsubscribeFromTopic(oldTopic);
      }

      await messaging.subscribeToTopic(newTopic);
      await prefs.setString('current_fcm_topic', newTopic);

      // Also subscribe to role-based topic (e.g., cr_division_A)
      final role = prefs.getString('user_role') ?? 'student';
      if (role != 'student') {
        final newRoleTopic = '\${role}_\${sanitizeTopic(newDivision)}';
        final oldRoleTopic = prefs.getString('current_fcm_role_topic');
        if (oldRoleTopic != null && oldRoleTopic != newRoleTopic) {
          await messaging.unsubscribeFromTopic(oldRoleTopic);
        }
        await messaging.subscribeToTopic(newRoleTopic);
        await prefs.setString('current_fcm_role_topic', newRoleTopic);
      }
    } catch (e) {
      debugPrint('Failed to update FCM topic subscription: $e');
    }
  }

  static Future<void> clearTokenOnLogout() async {
    try {
      final String? token = await messaging.getToken();
      final user = FirebaseAuth.instance.currentUser;
      if (token != null && user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('fcm_tokens')
            .doc(token)
            .delete();
      }
    } catch (e) {
      debugPrint('Failed to delete token on logout: $e');
    }
  }
}
`;

fs.writeFileSync('lib/services/notification_service.dart', code);
console.log('Rewrote notification_service.dart');
