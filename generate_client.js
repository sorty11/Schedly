const fs = require('fs');
const path = require('path');

const code = `import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class NotificationApiClient {
  // Use 10.0.2.2 for Android emulator, localhost for web/iOS, or your actual Render URL in production.
  static const String _baseUrl = 'http://10.0.2.2:3000/api/sendNotification';
  static const String _queueKey = 'offline_notification_queue';

  static Future<void> initOfflineQueue() async {
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (results.isNotEmpty && results.first != ConnectivityResult.none) {
        _processOfflineQueue();
      }
    });
    // Try to process immediately on startup
    _processOfflineQueue();
  }

  /// Fire-and-forget method to be called from UI/Controllers.
  static void sendNotificationAsync(Map<String, dynamic> payload) {
    unawaited(_sendWithRetry(payload));
  }

  static Future<void> _sendWithRetry(Map<String, dynamic> payload, {int maxAttempts = 3}) async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.isNotEmpty && connectivityResult.first == ConnectivityResult.none) {
      if (kDebugMode) print('Offline: Queuing notification');
      await _queueLocally(payload);
      return;
    }

    int attempt = 0;
    while (attempt < maxAttempts) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          if (kDebugMode) print('Failed to send: User not logged in.');
          return; // Can't send without auth
        }

        final idToken = await user.getIdToken(true);
        if (idToken == null) {
          if (kDebugMode) print('Failed to send: Could not get ID token.');
          return;
        }

        if (kDebugMode) print('Sending notification (Attempt \${attempt + 1})...');

        final response = await http.post(
          Uri.parse(_baseUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer \$idToken',
          },
          body: jsonEncode(payload),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 202) {
          if (kDebugMode) print('Notification sent successfully (202).');
          return; // Success
        } else if (response.statusCode == 401 || response.statusCode == 403) {
          if (kDebugMode) print('Notification failed: Auth error \${response.statusCode}. Not retrying.');
          return; // Don't retry auth errors
        } else {
          if (kDebugMode) print('Notification failed with status \${response.statusCode}.');
        }
      } catch (e) {
        if (kDebugMode) print('Notification network/timeout error: \$e');
      }

      attempt++;
      if (attempt < maxAttempts) {
        final delaySeconds = 1 << (attempt - 1); // 1, 2, 4 seconds
        if (kDebugMode) print('Retrying in \$delaySeconds seconds...');
        await Future.delayed(Duration(seconds: delaySeconds));
      }
    }

    // If all attempts failed due to network/server issues, queue it.
    if (kDebugMode) print('All retries failed, queuing notification.');
    await _queueLocally(payload);
  }

  static Future<void> _queueLocally(Map<String, dynamic> payload) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList(_queueKey) ?? [];
    queue.add(jsonEncode(payload));
    await prefs.setStringList(_queueKey, queue);
  }

  static Future<void> _processOfflineQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList(_queueKey) ?? [];
    if (queue.isEmpty) return;

    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.isNotEmpty && connectivityResult.first == ConnectivityResult.none) return;

    if (kDebugMode) print('Processing \${queue.length} queued notifications...');
    await prefs.remove(_queueKey); // Clear queue to prevent duplicate processing

    for (final item in queue) {
      try {
        final payload = jsonDecode(item) as Map<String, dynamic>;
        // Process each asynchronously
        sendNotificationAsync(payload);
      } catch (e) {
        if (kDebugMode) print('Failed to parse queued notification: \$e');
      }
    }
  }
}
`;

fs.writeFileSync(path.join(__dirname, 'lib', 'services', 'notification_api_client.dart'), code);
console.log('notification_api_client.dart created');
