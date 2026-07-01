import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'topic_subscription_service.dart';

class NotificationService {
  static final FirebaseMessaging messaging = FirebaseMessaging.instance;

  static Future<void> initialize() async {
    try {
      await messaging.requestPermission();

      final token = await messaging.getToken();
      if (token != null) {
        await _saveTokenToFirestore(token);
      }
      
      // Topic subscriptions
      final prefs = await SharedPreferences.getInstance();
      final division = prefs.getString('selected_division');
      final role = prefs.getString('user_role') ?? 'student';
      final batch = prefs.getString('selected_batch');
      if (division != null) {
        await TopicSubscriptionService.updateSubscriptions(division, role, batch: batch);
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

  static Future<void> updateDivisionSubscription(String newDivision) async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('user_role') ?? 'student';
    final batch = prefs.getString('selected_batch');
    await TopicSubscriptionService.updateSubscriptions(newDivision, role, batch: batch);
  }

  static Future<void> clearTokenOnLogout() async {
    await TopicSubscriptionService.clearAllSubscriptions();
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