import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TopicSubscriptionService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static String sanitizeTopic(String topic) {
    return topic.replaceAll(RegExp(r'[^a-zA-Z0-9-_.~%]'), '_');
  }

  static Future<void> updateSubscriptions(String division, String role, {String? batch}) async {
    if (kIsWeb) return; // FCM topics are not supported natively on Flutter Web
    
    try {
      await _updateDivisionSubscription(division);
      await _updateRoleSubscription(division, role);
      if (batch != null) {
        await _updateBatchSubscription(division, batch);
      }
    } catch (e) {
      debugPrint('Failed to update subscriptions: $e');
    }
  }

  static Future<void> clearAllSubscriptions() async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final oldTopic = prefs.getString('current_fcm_topic');
      if (oldTopic != null) {
        await unsubscribeDivision(oldTopic);
        await prefs.remove('current_fcm_topic');
      }

      final oldRoleTopic = prefs.getString('current_fcm_role_topic');
      if (oldRoleTopic != null) {
        await unsubscribeRole(oldRoleTopic);
        await prefs.remove('current_fcm_role_topic');
      }

      final oldBatchTopic = prefs.getString('current_fcm_batch_topic');
      if (oldBatchTopic != null) {
        await unsubscribeBatch(oldBatchTopic);
        await prefs.remove('current_fcm_batch_topic');
      }
    } catch (e) {
      debugPrint('Failed to clear subscriptions: $e');
    }
  }

  static Future<void> _updateDivisionSubscription(String newDivision) async {
    final prefs = await SharedPreferences.getInstance();
    final oldTopic = prefs.getString('current_fcm_topic');
    final newTopic = 'division_${sanitizeTopic(newDivision)}';

    if (oldTopic != null && oldTopic != newTopic) {
      await unsubscribeDivision(oldTopic);
    }

    if (oldTopic != newTopic) {
      await subscribeToDivision(newTopic);
      await prefs.setString('current_fcm_topic', newTopic);
    }
  }

  static Future<void> _updateRoleSubscription(String division, String role) async {
    final prefs = await SharedPreferences.getInstance();
    final oldRoleTopic = prefs.getString('current_fcm_role_topic');
    
    if (oldRoleTopic != null) {
      await unsubscribeRole(oldRoleTopic);
      await prefs.remove('current_fcm_role_topic');
    }

    if (role != 'student') {
      final newRoleTopic = 'role_${role}_${sanitizeTopic(division)}';
      await subscribeRole(newRoleTopic);
      await prefs.setString('current_fcm_role_topic', newRoleTopic);
    }
  }

  static Future<void> _updateBatchSubscription(String division, String batch) async {
    final prefs = await SharedPreferences.getInstance();
    final oldBatchTopic = prefs.getString('current_fcm_batch_topic');
    final newBatchTopic = 'batch_${sanitizeTopic(batch)}_${sanitizeTopic(division)}';

    if (oldBatchTopic != null && oldBatchTopic != newBatchTopic) {
      await unsubscribeBatch(oldBatchTopic);
    }

    if (oldBatchTopic != newBatchTopic) {
      await subscribeBatch(newBatchTopic);
      await prefs.setString('current_fcm_batch_topic', newBatchTopic);
    }
  }

  static Future<void> subscribeToDivision(String topic) async {
    await _messaging.subscribeToTopic(topic);
    debugPrint('Subscribed to division: $topic');
  }

  static Future<void> unsubscribeDivision(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
    debugPrint('Unsubscribed from division: $topic');
  }

  static Future<void> subscribeRole(String topic) async {
    await _messaging.subscribeToTopic(topic);
    debugPrint('Subscribed to role: $topic');
  }

  static Future<void> unsubscribeRole(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
    debugPrint('Unsubscribed from role: $topic');
  }

  static Future<void> subscribeBatch(String topic) async {
    await _messaging.subscribeToTopic(topic);
    debugPrint('Subscribed to batch: $topic');
  }

  static Future<void> unsubscribeBatch(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
    debugPrint('Unsubscribed from batch: $topic');
  }
}
