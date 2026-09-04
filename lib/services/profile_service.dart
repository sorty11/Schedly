import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../app_settings.dart';
import '../exceptions.dart';

/// Service responsible for updating user profile information (Name, SAP ID / Roll Number).
/// Ensures UID remains permanent, prevents duplicate SAP IDs within a section,
/// safely migrates legacy document IDs, and executes changes atomically.
class ProfileService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Validates a user's full name.
  static String? validateName(String? name) {
    if (name == null) return 'Name cannot be empty';
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Name cannot be empty';
    if (trimmed.length < 2) return 'Name must be at least 2 characters';
    if (trimmed.length > 60) return 'Name cannot exceed 60 characters';
    return null;
  }

  /// Validates a user's SAP ID / Roll Number.
  static String? validateSapId(String? sapId) {
    if (sapId == null) return 'SAP ID / Roll Number cannot be empty';
    final trimmed = sapId.trim();
    if (trimmed.isEmpty) return 'SAP ID / Roll Number cannot be empty';
    if (trimmed.length < 2) return 'Must be at least 2 characters';
    if (trimmed.length > 30) return 'Cannot exceed 30 characters';
    final alphanumericRegex = RegExp(r'^[A-Za-z0-9_-]+$');
    if (!alphanumericRegex.hasMatch(trimmed)) {
      return 'Must be alphanumeric (letters, numbers, hyphen or underscore)';
    }
    return null;
  }

  /// Checks whether a SAP ID is available in the target section.
  /// Throws [AppException] if the SAP ID is already claimed by another user.
  static Future<void> checkSapIdAvailability({
    required String sapId,
    required String? sectionId,
    required String currentUid,
  }) async {
    if (sectionId == null || sectionId.isEmpty) return;

    final trimmedSapId = sapId.trim();

    // 1. Check legacy sections/{sectionId}/students/{sapId}
    final existingStudentDoc = await _firestore
        .collection('sections')
        .doc(sectionId)
        .collection('students')
        .doc(trimmedSapId)
        .get();

    if (existingStudentDoc.exists) {
      final data = existingStudentDoc.data();
      final docUserId = data?['userId'] ?? data?['uid'];
      if (docUserId != null && docUserId != currentUid) {
        throw AppException(
          'SAP ID "$trimmedSapId" is already registered to another student in section $sectionId.',
        );
      }
    }

    // 2. Query users in the same division
    try {
      final userQuery = await _firestore
          .collection('users')
          .where('division', isEqualTo: sectionId)
          .where('rollNo', isEqualTo: trimmedSapId)
          .limit(3)
          .get();

      for (final doc in userQuery.docs) {
        if (doc.id != currentUid) {
          throw AppException(
            'SAP ID "$trimmedSapId" is already registered to another student in section $sectionId.',
          );
        }
      }
    } catch (e) {
      developer.log('Notice checking users division/rollNo: $e');
    }
  }

  /// Updates profile information (Name and SAP ID) for the authenticated user.
  /// Executes atomic writes via [WriteBatch].
  static Future<void> updateProfileInfo({
    required String name,
    required String sapId,
    required bool isFaculty,
  }) async {
    final nameError = validateName(name);
    if (nameError != null) throw AppException(nameError);

    final sapError = validateSapId(sapId);
    if (sapError != null) throw AppException(sapError);

    final trimmedName = name.trim();
    final trimmedSapId = sapId.trim().toUpperCase();

    final user = _auth.currentUser;
    if (user == null) {
      throw AppException('User is not signed in.');
    }
    final uid = user.uid;

    if (isFaculty) {
      await _updateFacultyProfile(
        uid: uid,
        user: user,
        name: trimmedName,
        sapId: trimmedSapId,
      );
    } else {
      await _updateStudentProfile(
        uid: uid,
        user: user,
        name: trimmedName,
        sapId: trimmedSapId,
      );
    }
  }

  static Future<void> _updateFacultyProfile({
    required String uid,
    required User user,
    required String name,
    required String sapId,
  }) async {
    final batch = _firestore.batch();

    // 1. Update users/{uid}
    final userRef = _firestore.collection('users').doc(uid);
    batch.set(userRef, {
      'name': name,
      'facultyId': sapId,
      'sapId': sapId,
      'rollNo': sapId,
      'draftProfile': {'name': name, 'facultyId': sapId, 'sapId': sapId},
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 2. Update faculty_profiles/{facultyDocId}
    final facultyDocId = AppSettings.facultyId ?? uid;
    if (facultyDocId.isNotEmpty) {
      final facProfileRef = _firestore
          .collection('faculty_profiles')
          .doc(facultyDocId);
      batch.set(facProfileRef, {
        'name': name,
        'facultyId': sapId,
        'sapId': sapId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    // Atomic commit
    await batch.commit();

    // 3. Update local state
    await AppSettings.updateFacultyProfileNameAndId(name: name, sapId: sapId);

    // 4. Update Auth display name
    try {
      await user.updateDisplayName(name);
    } catch (e) {
      developer.log('Notice updating display name: $e');
    }
  }

  static Future<void> _updateStudentProfile({
    required String uid,
    required User user,
    required String name,
    required String sapId,
  }) async {
    final oldSapId = AppSettings.studentRollNo;
    final sectionId = AppSettings.sectionId ?? AppSettings.division;

    // Check duplicate SAP ID if it changed
    if (oldSapId != sapId && sectionId != null && sectionId.isNotEmpty) {
      await checkSapIdAvailability(
        sapId: sapId,
        sectionId: sectionId,
        currentUid: uid,
      );
    }

    // Read old legacy student document if migrating ID
    Map<String, dynamic>? oldStudentData;
    DocumentReference? oldStudentRef;
    if (sectionId != null &&
        sectionId.isNotEmpty &&
        oldSapId != null &&
        oldSapId.isNotEmpty &&
        oldSapId != sapId) {
      try {
        oldStudentRef = _firestore
            .collection('sections')
            .doc(sectionId)
            .collection('students')
            .doc(oldSapId);
        final oldSnap = await oldStudentRef.get();
        if (oldSnap.exists) {
          oldStudentData = oldSnap.data() as Map<String, dynamic>?;
        }
      } catch (e) {
        developer.log('Notice reading old student doc: $e');
      }
    }

    final batch = _firestore.batch();

    // 1. Update users/{uid}
    final userRef = _firestore.collection('users').doc(uid);
    batch.set(userRef, {
      'name': name,
      'rollNo': sapId,
      'sapId': sapId,
      'draftProfile': {'name': name, 'rollNo': sapId, 'sapId': sapId},
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 2. Update section membership & legacy students collection if in a section
    if (sectionId != null && sectionId.isNotEmpty) {
      final membershipRef = _firestore
          .collection('section_memberships')
          .doc('${sectionId}_$uid');
      batch.set(membershipRef, {
        'name': name,
        'rollNo': sapId,
        'sapId': sapId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Build migrated student data preserving all original fields
      final Map<String, dynamic> newStudentData = oldStudentData != null
          ? Map<String, dynamic>.from(oldStudentData)
          : <String, dynamic>{};

      newStudentData['name'] = name;
      newStudentData['rollNo'] = sapId;
      newStudentData['sapId'] = sapId;
      newStudentData['userId'] = uid;
      newStudentData['updatedAt'] = FieldValue.serverTimestamp();
      if (oldSapId != null && oldSapId != sapId) {
        newStudentData['migratedFrom'] = oldSapId;
      }

      final newStudentRef = _firestore
          .collection('sections')
          .doc(sectionId)
          .collection('students')
          .doc(sapId);

      batch.set(newStudentRef, newStudentData, SetOptions(merge: true));

      // Only delete old document within the same atomic batch if it differed and existed
      if (oldStudentRef != null && oldStudentData != null) {
        batch.delete(oldStudentRef);
      }
    }

    // Atomic commit
    await batch.commit();

    // 3. Update local state
    await AppSettings.updateStudentProfileNameAndRoll(
      name: name,
      rollNo: sapId,
    );

    // 4. Update Auth display name
    try {
      await user.updateDisplayName(name);
    } catch (e) {
      developer.log('Notice updating display name: $e');
    }
  }
}
