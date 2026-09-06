import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../utils/security_utils.dart';

class SectionAdminResult {
  final bool success;
  final String message;
  final String? error;

  const SectionAdminResult({
    required this.success,
    required this.message,
    this.error,
  });
}

class SectionAdminService {
  static const String _defaultBackendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://schedly-p61g.onrender.com',
  );

  /// Securely updates an existing section's metadata in Firestore.
  /// Preserves the existing section document ID.
  static Future<SectionAdminResult> updateSection({
    required String sectionId,
    required Map<String, dynamic> updatedData,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const SectionAdminResult(
        success: false,
        message: 'Authentication required',
        error: 'No authenticated user found',
      );
    }

    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      // Set admin action document for rules-side authorization
      final actionRef = db
          .collection('admin_actions')
          .doc('${user.uid}_${sectionId}_edit');
      batch.set(actionRef, {
        'masterHash': SecurityUtils.masterHash,
        'action': 'editSection',
        'timestamp': FieldValue.serverTimestamp(),
      });

      final sectionRef = db.collection('sections').doc(sectionId);
      batch.update(sectionRef, updatedData);

      await batch.commit();
      return SectionAdminResult(
        success: true,
        message: 'Section $sectionId updated successfully',
      );
    } catch (e) {
      debugPrint('Error updating section $sectionId: $e');
      return SectionAdminResult(
        success: false,
        message: 'Failed to update section',
        error: e.toString(),
      );
    }
  }

  /// Securely and permanently deletes a section.
  /// Enforces server/rules-side verification with Firebase Auth ID token and master password.
  static Future<SectionAdminResult> deleteSection({
    required String sectionId,
    required String masterPassword,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const SectionAdminResult(
        success: false,
        message: 'Authentication required',
        error: 'No authenticated user found',
      );
    }

    // Verify master password hash client-side before dispatching
    if (!SecurityUtils.verifyMasterPassword(masterPassword)) {
      return const SectionAdminResult(
        success: false,
        message: 'Unauthorized',
        error: 'Incorrect Master Password',
      );
    }

    // 1. Attempt server-side deletion via Render backend (Admin SDK)
    try {
      final idToken = await user.getIdToken(true);
      final response = await http
          .post(
            Uri.parse('$_defaultBackendUrl/api/v1/delete-section'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode({
              'masterPassword': masterPassword,
              'sectionId': sectionId,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return SectionAdminResult(
          success: true,
          message: data['message'] as String? ?? 'Section deleted successfully',
        );
      } else if (response.statusCode == 403 || response.statusCode == 401) {
        final err = jsonDecode(response.body)['error'] ?? 'Unauthorized';
        return SectionAdminResult(
          success: false,
          message: 'Authorization failed',
          error: err.toString(),
        );
      }
    } catch (netErr) {
      debugPrint('Backend delete-section unavailable, using rules-authorized fallback: $netErr');
    }

    // 2. Rules-enforced fallback: Firestore batched delete authorized by admin_actions doc
    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      final actionRef = db
          .collection('admin_actions')
          .doc('${user.uid}_${sectionId}_delete');
      batch.set(actionRef, {
        'masterHash': SecurityUtils.masterHash,
        'action': 'deleteSection',
        'deletedSectionId': sectionId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      final sectionRef = db.collection('sections').doc(sectionId);
      batch.delete(sectionRef);

      // Clean up direct subcollections if any exist
      final subcollections = [
        'sr_assignments',
        'notifications',
        'faculty_requests',
        'students',
        'announcements',
        'history',
        'analytics',
        'conduct_logs',
        'conduct_adjustments',
        'subjects',
        'subject_metadata',
      ];

      for (final sub in subcollections) {
        final snap = await sectionRef.collection(sub).get();
        for (final doc in snap.docs) {
          batch.delete(doc.reference);
        }
      }

      // Associated timetable
      final timetableRef = db.collection('timetables').doc(sectionId);
      final timetableSnap = await timetableRef.get();
      if (timetableSnap.exists) {
        batch.delete(timetableRef);
      }

      // Associated section memberships
      final membershipsSnap = await db
          .collection('section_memberships')
          .where('sectionId', isEqualTo: sectionId)
          .get();
      for (final doc in membershipsSnap.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      return SectionAdminResult(
        success: true,
        message: 'Section $sectionId permanently deleted',
      );
    } catch (e) {
      debugPrint('Rules-enforced fallback deletion error: $e');
      return SectionAdminResult(
        success: false,
        message: 'Failed to delete section',
        error: e.toString(),
      );
    }
  }
}
