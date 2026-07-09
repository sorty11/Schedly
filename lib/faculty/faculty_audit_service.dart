import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../app_settings.dart';

enum FacultyActionType {
  requestCancel,
  requestExtra,
  announcementCreated,
  login,
  setupCompleted,
  conflictReported,
  other,
}

class FacultyAuditService {
  static Future<void> logAction({
    required FacultyActionType actionType,
    required String description,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      
      final name = AppSettings.facultyName ?? 'Unknown Faculty';

      await FirebaseFirestore.instance.collection('faculty_audit_log').add({
        'facultyId': uid,
        'facultyName': name,
        'action': actionType.name,
        'description': description,
        'metadata': metadata ?? {},
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error logging faculty action: $e');
    }
  }
}
