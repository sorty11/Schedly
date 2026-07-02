import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'topic_subscription_service.dart';

class NotificationService {
  static final FirebaseMessaging messaging = FirebaseMessaging.instance;
  static const String webVapidKey =
      "BKHIetL_dUjNsl40lp2OmV5EU1ebUm9GFhGcHDwH8hFJIVrOuNTx9vwuZQn1fadTFXw9WFUG7wB3_iNdK_Hrt_g";

  static Future<void> initialize() async {
    try {
      // On web, ensure we have an anonymous Firebase Auth user so we can
      // persist the FCM token under a stable UID.
      if (kIsWeb) {
        await _ensureAnonymousSignIn();
      }

      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('NotificationService: Permission denied by user.');
        return;
      }

      String? token;
      if (kIsWeb) {
        token = await messaging.getToken(vapidKey: webVapidKey);
      } else {
        token = await messaging.getToken();
      }

      debugPrint('NotificationService: FCM token obtained: ${token != null ? "YES" : "NO"}');

      if (token != null) {
        await _saveTokenToFirestore(token);
      }

      // iOS: show notifications as banners even when app is in foreground
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Listen for foreground messages (all platforms)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('NotificationService: Foreground message received: ${message.notification?.title}');
        // The iOS AppDelegate + setForegroundNotificationPresentationOptions
        // will automatically display the banner. No manual display needed.
      });

      // Listen for token refresh
      messaging.onTokenRefresh.listen((newToken) async {
        debugPrint('NotificationService: FCM token refreshed');
        await _saveTokenToFirestore(newToken);
      });

      // Topic subscriptions (Android/iOS only — web uses direct token dispatch)
      final prefs = await SharedPreferences.getInstance();
      final division = prefs.getString('selected_division');
      final role = prefs.getString('user_role') ?? 'student';
      final batch = prefs.getString('selected_batch');
      if (division != null) {
        await TopicSubscriptionService.updateSubscriptions(division, role, batch: batch);
      }
    } catch (e) {
      debugPrint('NotificationService: Init skipped: $e');
    }
  }

  /// Ensures there is a Firebase Auth user (anonymous) on web so we can
  /// store the FCM token under a stable document ID.
  static Future<void> _ensureAnonymousSignIn() async {
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        debugPrint('NotificationService: No auth user on web — signing in anonymously');
        await FirebaseAuth.instance.signInAnonymously();
      }
    } catch (e) {
      debugPrint('NotificationService: Anonymous sign-in failed: $e');
    }
  }

  static Future<void> _saveTokenToFirestore(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final division = prefs.getString('selected_division') ?? 'unknown';
      final role = prefs.getString('user_role') ?? 'student';

      // Prefer authenticated UID; fall back to division-keyed path
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('NotificationService: No auth user, skipping token save');
        return;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('fcm_tokens')
          .doc(token)
          .set({
        'token': token,
        'platform': kIsWeb
            ? 'web'
            : (defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android'),
        'division': division,
        'role': role,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('NotificationService: Token saved to Firestore (uid: ${user.uid}, div: $division)');
    } catch (e) {
      debugPrint('NotificationService: Failed to save FCM token: $e');
    }
  }

  static Future<void> updateDivisionSubscription(String newDivision) async {
    try {
      // Update token's division field in Firestore
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final role = (await SharedPreferences.getInstance()).getString('user_role') ?? 'student';
        String? token;
        if (kIsWeb) {
          token = await messaging.getToken(vapidKey: webVapidKey);
        } else {
          token = await messaging.getToken();
        }
        if (token != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('fcm_tokens')
              .doc(token)
              .set({
            'token': token,
            'platform': kIsWeb
                ? 'web'
                : (defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android'),
            'division': newDivision,
            'role': role,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }

      // Android/iOS topic subscriptions
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString('user_role') ?? 'student';
      final batch = prefs.getString('selected_batch');
      await TopicSubscriptionService.updateSubscriptions(newDivision, role, batch: batch);
    } catch (e) {
      debugPrint('NotificationService: updateDivisionSubscription failed: $e');
    }
  }

  static Future<void> clearTokenOnLogout() async {
    await TopicSubscriptionService.clearAllSubscriptions();
    try {
      final user = FirebaseAuth.instance.currentUser;
      String? token;
      if (kIsWeb) {
        token = await messaging.getToken(vapidKey: webVapidKey);
      } else {
        token = await messaging.getToken();
      }
      if (token != null && user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('fcm_tokens')
            .doc(token)
            .delete();
      }
      // Delete the FCM token itself so this device stops receiving
      await messaging.deleteToken();
    } catch (e) {
      debugPrint('NotificationService: Failed to clear token on logout: $e');
    }
  }
}