import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_settings.dart';
import '../user_roles.dart';
import 'notification_service.dart';
import 'package:schedly/exceptions.dart';
import '../utils/security_utils.dart';

class FacultyAuthService {
  /// Verifies the master password and elevates the current user to Faculty.
  /// Returns a boolean indicating if this is their first-time setup.
  static Future<bool> elevateToFaculty({
    required String name,
    required String masterPassword,
  }) async {
    final legacyId = 'fac_${name.replaceAll(' ', '').toLowerCase()}';
    
    // 1. Try Legacy ID first
    DocumentSnapshot<Map<String, dynamic>> legacySnap;
    try {
      legacySnap = await FirebaseFirestore.instance.collection('faculty_profiles').doc(legacyId).get();
    } catch (e) {
      debugPrint('[FS_ERROR] faculty_profiles READ exception: $e');
      rethrow;
    }
    
    String uidToUse;
    Map<String, dynamic> profileData = {};
    bool isNew = false;

    if (legacySnap.exists) {
      uidToUse = legacyId;
      profileData = legacySnap.data()!;
    } else {
      // 2. Try querying by name for migrated profiles
      QuerySnapshot<Map<String, dynamic>> querySnap;
      try {
        querySnap = await FirebaseFirestore.instance.collection('faculty_profiles').where('name', isEqualTo: name).get();
      } catch (e) {
        debugPrint('[FS_ERROR] faculty_profiles QUERY exception: $e');
        rethrow;
      }
      
      if (querySnap.docs.isNotEmpty) {
        if (querySnap.docs.length > 1) {
           throw AppException('Multiple profiles found for this name. Please contact admin.');
        }
        uidToUse = querySnap.docs.first.id;
        profileData = querySnap.docs.first.data();
      } else {
        // 3. Completely new profile
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          throw AppException('You must be logged in to create a faculty profile');
        }
        uidToUse = user.uid;
        isNew = true;
      }
    }

    try {
      // 1. Verify Master Password locally
      if (!SecurityUtils.verifyMasterPassword(masterPassword)) {
        throw Exception('Incorrect Master Password');
      }

      // 2. Perform client-side update
      final batch = FirebaseFirestore.instance.batch();
      
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw AppException('You must be logged in to verify');
      }
      
      if (uidToUse != user.uid && uidToUse.startsWith('fac_')) {
        // This is a legacy ID migration on the fly
        final legacyData = profileData;
        final legacyId = uidToUse;
        uidToUse = user.uid; // Force new uid
        
        batch.set(FirebaseFirestore.instance.collection('faculty_profiles').doc(uidToUse), legacyData);
        batch.delete(FirebaseFirestore.instance.collection('faculty_profiles').doc(legacyId));
        batch.delete(FirebaseFirestore.instance.collection('users').doc(legacyId));
      } else if (uidToUse != user.uid && !isNew) {
        // It's a migrated profile with a random ID, let's fix it.
        final legacyData = profileData;
        final legacyId = uidToUse;
        uidToUse = user.uid;
        batch.set(FirebaseFirestore.instance.collection('faculty_profiles').doc(uidToUse), legacyData);
        batch.delete(FirebaseFirestore.instance.collection('faculty_profiles').doc(legacyId));
      }

      final actionRef = FirebaseFirestore.instance.collection('admin_actions').doc('${user.uid}_facultySetup');
      batch.set(actionRef, {
        'masterHash': SecurityUtils.masterHash,
        'action': 'verifyFaculty',
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      final profileRef = FirebaseFirestore.instance.collection('faculty_profiles').doc(uidToUse);
      if (isNew) {
        batch.set(profileRef, {
          'name': name,
          'uid': uidToUse,
          'assignedDivisions': [],
          'setupComplete': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      batch.set(userRef, {
        'role': 'Faculty',
        'facultyProfileId': uidToUse,
      }, SetOptions(merge: true));

      await batch.commit();

      // Re-fetch profile data in case it was just created
      if (isNew) {
        final newSnap = await FirebaseFirestore.instance.collection('faculty_profiles').doc(uidToUse).get();
        if (newSnap.exists) profileData = newSnap.data()!;
      }
    } catch (e) {
      debugPrint('[FS_ERROR] Faculty verification exception: $e');
      rethrow;
    }

    final assignedDivisions = List<String>.from(profileData['assignedDivisions'] ?? []);
    final setupComplete = profileData['setupComplete'] as bool? ?? false;
    
    await _finishLogin(
      uid: uidToUse,
      name: profileData['name'] ?? name,
      email: profileData['email'] ?? '',
      department: profileData['department'] ?? '',
      designation: profileData['designation'] ?? '',
      cabin: profileData['cabin'] ?? '',
      assignedDivisions: assignedDivisions,
      setupComplete: setupComplete,
    );
    
    return !setupComplete; // return true if setup is NOT complete (needs wizard)
  }

  static Future<void> _finishLogin({
    required String uid,
    required String name,
    required String email,
    required String department,
    required String designation,
    required String cabin,
    required List<String> assignedDivisions,
    required bool setupComplete,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_logged_in', true);
    
    await AppSettings.saveRole(UserRole.faculty);
    
    if (setupComplete) {
      await AppSettings.completeFacultySetup();
    }

    await AppSettings.saveFacultyDetails(
      name: name,
      email: email,
      department: department,
      designation: designation,
      cabin: cabin,
      assignedDivisions: assignedDivisions,
      id: uid,
    );

    NotificationService.reRegisterToken().catchError((e) {
      debugPrint('Token registration error: $e');
    });
  }
}
