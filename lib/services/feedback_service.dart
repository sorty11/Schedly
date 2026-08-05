import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer' as developer;

class FeedbackService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  // Make sure this matches the deployed Render backend URL or test endpoint.
  // Using localhost for Android emulator testing, fallback to generic Render URL.
  // In production, this should come from AppSettings.
  final String _backendUrl = const String.fromEnvironment('BACKEND_URL', defaultValue: 'https://schedly-backend.onrender.com');

  Future<Map<String, dynamic>> _gatherMetadata() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    // Fetch user details from Firestore
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userData = userDoc.data() ?? {};

    // Get App Version
    final packageInfo = await PackageInfo.fromPlatform();
    final appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';

    // Get Device Info
    String deviceModel = 'Unknown Device';
    String platform = kIsWeb ? 'Web' : Platform.operatingSystem;
    
    try {
      if (kIsWeb) {
        final webInfo = await _deviceInfo.webBrowserInfo;
        deviceModel = webInfo.userAgent ?? 'Web Browser';
      } else if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        deviceModel = '${androidInfo.brand} ${androidInfo.model}';
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        deviceModel = iosInfo.utsname.machine;
      }
    } catch (e) {
      developer.log('Failed to get device info: $e');
    }

    return {
      'uid': user.uid,
      'name': userData['name'] ?? 'Unknown',
      'role': userData['role'] ?? 'Student',
      'section': userData['division'] ?? 'Unknown',
      'device': deviceModel,
      'platform': platform,
      'appVersion': appVersion,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }

  Future<void> submitBugReport({
    required String category,
    required String title,
    required String description,
  }) async {
    try {
      final metadata = await _gatherMetadata();
      final data = {
        ...metadata,
        'type': 'bug_report', // using 'type' field since we are saving to a shared 'feedback' collection
        'category': category,
        'title': title,
        'description': description,
        'status': 'Open',
      };

      // 1. Save to Firestore (works offline)
      final docRef = await _firestore.collection('feedback').add(data);

      // 2. Trigger Email via Backend
      await _triggerBackendEmail('bug_report', docRef.id, {
        ...data,
        'timestamp': DateTime.now().toIso8601String(), // replace FieldValue for JSON serialization
      });
    } catch (e) {
      developer.log('Error submitting bug report: $e');
      rethrow;
    }
  }

  Future<void> submitFeatureRequest({
    required String category,
    required String title,
    required String description,
  }) async {
    try {
      final metadata = await _gatherMetadata();
      final data = {
        ...metadata,
        'type': 'feature_request', // using 'type' field since we are saving to a shared 'feedback' collection
        'category': category,
        'title': title,
        'description': description,
        'status': 'New',
      };

      // 1. Save to Firestore (works offline)
      final docRef = await _firestore.collection('feedback').add(data);

      // 2. Trigger Email via Backend
      await _triggerBackendEmail('feature_request', docRef.id, {
        ...data,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      developer.log('Error submitting feature request: $e');
      rethrow;
    }
  }

  Future<void> _triggerBackendEmail(String type, String reportId, Map<String, dynamic> data) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      final idToken = await user.getIdToken();
      final url = Uri.parse('$_backendUrl/api/feedback/email');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'type': type,
          'reportId': reportId,
          'data': data,
        }),
      );
      
      if (response.statusCode != 200) {
        developer.log('Backend email error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      // Don't rethrow here so that offline submission still succeeds in saving to Firestore
      developer.log('Could not trigger backend email: $e');
    }
  }
}
