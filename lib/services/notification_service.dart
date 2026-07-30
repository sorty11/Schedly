import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'topic_subscription_service.dart';
import 'local_notification_service.dart';
import '../app_settings.dart';
import 'diagnostic_logger.dart';

class NotificationService {
  static final FirebaseMessaging messaging = FirebaseMessaging.instance;
  static const String webVapidKey =
      "BKHIetL_dUjNsl40lp2OmV5EU1ebUm9GFhGcHDwH8hFJIVrOuNTx9vwuZQn1fadTFXw9WFUG7wB3_iNdK_Hrt_g";

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      // On web, ensure we have an anonymous Firebase Auth user so we can
      // persist the FCM token under a stable UID.
      if (kIsWeb) {
        await _ensureAnonymousSignIn();
      }

      NotificationSettings? settings;
      if (!kIsWeb) {
        settings = await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );
      } else {
        // On web, we check existing status. We DO NOT request on startup,
        // because browsers auto-deny if not in a user gesture.
        settings = await messaging.getNotificationSettings();
      }

      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        debugPrint('NotificationService: Permission not granted yet or denied.');
        return;
      }

      // iOS: show notifications as banners even when app is in foreground
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Listen for foreground messages (all platforms)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final title = message.notification?.title ?? message.data['title'] ?? 'Schedly';
        final body = message.notification?.body ?? message.data['body'] ?? '';
        final link = message.data['deepLink'] ?? '/';

        debugPrint('NotificationService: Foreground message received: $title (link: $link)');
        
        if (defaultTargetPlatform == TargetPlatform.android) {
          LocalNotificationService.showNotification(
            title: title,
            body: body,
            payload: link,
          );
        }
      });

      // Listen for token refresh
      messaging.onTokenRefresh.listen((newToken) async {
        debugPrint('NotificationService: FCM token refreshed');
        await _saveTokenToFirestore(newToken);
      });

      // After setting up listeners, trigger an initial token sync
      await reRegisterToken();

    } catch (e) {
      debugPrint('NotificationService: Init skipped: $e');
    }
  }

  static Future<void> reRegisterToken() async {
    try {
      if (kIsWeb) {
        await _ensureAnonymousSignIn();
      }
      
      String? token;
      try {
        debugPrint('[TOKEN_SYNC] getToken() called');
        if (kIsWeb) {
          token = await messaging.getToken(vapidKey: webVapidKey);
        } else {
          token = await messaging.getToken();
        }
      } catch (e) {
        debugPrint('NotificationService: Failed to get FCM token. This is normal if the browser (like Brave) blocks push services: $e');
      }

      if (token != null) {
        final tokenPrefix = token.length > 20 ? token.substring(0, 20) : token;
        debugPrint('[TOKEN_SYNC] token=\$tokenPrefix...');
        await _saveTokenToFirestore(token);
      } else {
        debugPrint('[TOKEN_SYNC] token=null');
      }



      // Topic subscriptions (Android/iOS only — web uses direct token dispatch)
      final prefs = await SharedPreferences.getInstance();
      final division = prefs.getString('selected_division');
      final role = prefs.getString('user_role') ?? 'student';
      final batch = prefs.getString('selected_batch');
      
      String? finalDivision = division;
      if (role == 'faculty') {
        final facultyId = AppSettings.facultyId;
        final user = FirebaseAuth.instance.currentUser;
        finalDivision = (facultyId != null && facultyId.isNotEmpty) ? facultyId : user?.uid ?? division;
      }
      
      if (finalDivision != null) {
        await TopicSubscriptionService.updateSubscriptions(finalDivision, role, batch: batch);
        debugPrint('[TOKEN_SYNC] Topic subscription SUCCESS');
      }
    } catch (e) {
      debugPrint('NotificationService: reRegisterToken failed: $e');
    }
  }

  static Future<void> promptWebPermission() async {
    if (!kIsWeb) return;
    try {
      await _ensureAnonymousSignIn();
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        final token = await messaging.getToken(vapidKey: webVapidKey);
        if (token != null) {
          await _saveTokenToFirestore(token);
        }
      }
    } catch (e) {
      debugPrint('NotificationService: promptWebPermission failed: $e');
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
      
      // [FCM_TRACE] Use strictly memory-validated role
      final role = AppSettings.currentRole.name;
      if (role.isEmpty || role == 'unknown') {
        debugPrint('NotificationService: Registration delayed - Role is unknown');
        return;
      }
      
      final division = AppSettings.sectionId ?? prefs.getString('selected_division') ?? '';
      final batch = prefs.getString('selected_batch') ?? '';

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('NotificationService: Registration delayed - No auth user');
        return;
      }
      
      String finalDivision;
      if (role == 'faculty') {
        final facultyId = AppSettings.facultyId;
        finalDivision = (facultyId != null && facultyId.isNotEmpty) ? facultyId : user.uid;
      } else {
        finalDivision = division;
      }

      DiagnosticLogger.logFCM('[FCM_TRACE] Preparing Token Registration -> Current Role: ${AppSettings.currentRole.name} | Routing Role: $role | Routing ID: $finalDivision');

      try {
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
          'division': finalDivision,
          'role': role,
          'batch': batch,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('[FS_ERROR]\ncollection: users/\${user.uid}/fcm_tokens\ndocument: \$token\noperation: WRITE\nexception: \$e');
        rethrow;
      }

      debugPrint('[TOKEN_SYNC] Firestore write SUCCESS');
    } catch (e) {
      debugPrint('NotificationService: Failed to save FCM token: $e');
    }
  }

  static Future<void> updateDivisionSubscription(String newDivision) async {
    try {
      // Update token's division field in Firestore
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final prefs = await SharedPreferences.getInstance();
        final role = prefs.getString('user_role');
        
        if (role == null || role.isEmpty) {
          debugPrint('NotificationService: updateDivision delayed - Role is unknown');
          return;
        }

        String? token;
        if (kIsWeb) {
          token = await messaging.getToken(vapidKey: webVapidKey);
        } else {
          token = await messaging.getToken();
        }
        
        if (token != null) {
          String finalDivision;
          if (role == 'faculty') {
            final facultyId = AppSettings.facultyId;
            finalDivision = (facultyId != null && facultyId.isNotEmpty) ? facultyId : user.uid;
          } else {
            finalDivision = newDivision;
          }

          debugPrint('NotificationService: Updating Division Subscription [Role: $role] [FinalDiv: $finalDivision]');

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
            'division': finalDivision,
            'role': role,
            'batch': prefs.getString('selected_batch') ?? '',
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }

      // Android/iOS topic subscriptions
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString('user_role');
      if (role == null || role.isEmpty) return;
      
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