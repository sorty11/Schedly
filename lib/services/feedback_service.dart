import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../app_settings.dart';
import '../user_roles.dart';

class FeedbackService {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;
  DeviceInfoPlugin get _deviceInfo => DeviceInfoPlugin();

  final String _backendUrl = const String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://schedly-p61g.onrender.com',
  );

  Future<Map<String, dynamic>> _gatherMetadata() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    // Fetch user details from Firestore if available
    Map<String, dynamic> userData = {};
    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      userData = userDoc.data() ?? {};
    } catch (e) {
      developer.log('Warning: Could not fetch user doc for feedback: $e');
    }

    // Get App Version
    String appVersion = '1.0.11';
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
    } catch (_) {}

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

    // Resolve Role & Identity accurately
    String role = 'Student';
    String name = 'Student';
    String section = 'Unknown';
    String email = user.email ?? '';

    if (AppSettings.currentRole == UserRole.faculty) {
      role = 'Faculty';
      name = AppSettings.facultyName ?? userData['name'] ?? 'Faculty Member';
      section =
          AppSettings.facultyDepartment ?? userData['department'] ?? 'Faculty';
      if (email.isEmpty && AppSettings.facultyEmail != null) {
        email = AppSettings.facultyEmail!;
      }
    } else if (AppSettings.currentRole == UserRole.cr) {
      role = 'CR';
      name =
          userData['name'] ?? AppSettings.studentName ?? 'Class Representative';
      section =
          userData['division'] ??
          AppSettings.sectionId ??
          AppSettings.division ??
          'Unknown';
    } else if (AppSettings.currentRole == UserRole.sr) {
      role = 'SR';
      name =
          userData['name'] ??
          AppSettings.studentName ??
          'Subject Representative';
      section =
          userData['division'] ??
          AppSettings.sectionId ??
          AppSettings.division ??
          'Unknown';
    } else {
      role = (userData['role'] as String?) ?? 'Student';
      name = userData['name'] ?? AppSettings.studentName ?? 'Student';
      section =
          userData['division'] ??
          AppSettings.sectionId ??
          AppSettings.division ??
          'Unknown';
    }

    return {
      'uid': user.uid,
      'email': email,
      'name': name,
      'role': role,
      'section': section,
      'device': deviceModel,
      'platform': platform,
      'appVersion': appVersion,
    };
  }

  Future<void> submitBugReport({
    required String category,
    required String title,
    required String description,
  }) async {
    await _submitFeedback(
      type: 'bug',
      category: category,
      title: title,
      description: description,
    );
  }

  Future<void> submitFeatureRequest({
    required String category,
    required String title,
    required String description,
  }) async {
    await _submitFeedback(
      type: 'feature',
      category: category,
      title: title,
      description: description,
    );
  }

  Future<void> submitGeneralFeedback({
    required String category,
    required String title,
    required String description,
  }) async {
    await _submitFeedback(
      type: 'other',
      category: category,
      title: title,
      description: description,
    );
  }

  Future<void> _submitFeedback({
    required String type,
    required String category,
    required String title,
    required String description,
  }) async {
    final metadata = await _gatherMetadata();
    final timestampMs = DateTime.now().millisecondsSinceEpoch;
    final reportId = 'fb_${metadata['uid']}_$timestampMs';

    final data = {
      ...metadata,
      'id': reportId,
      'type': type,
      'category': category,
      'title': title,
      'description': description,
      'status': 'new',
      'emailStatus': 'pending',
      'emailAttempts': 0,
      'timestamp': FieldValue.serverTimestamp(),
    };

    // 1. Save to Firestore with deterministic ID (always succeeds even offline)
    await _firestore.collection('feedback').doc(reportId).set(data);

    // 2. Trigger asynchronous email dispatch on Render backend
    // Note: If offline or cold start occurs, backend worker sweeps pending documents
    _triggerBackendEmail(type, reportId, {
      ...data,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _triggerBackendEmail(
    String type,
    String reportId,
    Map<String, dynamic> data,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final idToken = await user.getIdToken();
      final url = Uri.parse('$_backendUrl/api/feedback/email');

      final response = await http
          .post(
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
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200 && response.statusCode != 202) {
        developer.log(
          'Backend feedback email notification status: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      // Non-fatal: the feedback document is already saved in Firestore with emailStatus: pending
      // and will be retried automatically by the Render backend worker.
      developer.log('Initial email trigger deferred to background worker: $e');
    }
  }
}
