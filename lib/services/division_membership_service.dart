import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class DivisionMembershipService {
  static final _db = FirebaseFirestore.instance;

  /// Joins a division. Creates an active membership and updates legacy profile fields.
  static Future<void> joinDivision({
    required String uid,
    required String sectionId,
    required String role,
    String? name,
    String? rollNo,
    String? email,
  }) async {
    final membershipId = '${sectionId}_$uid';

    final batch = _db.batch();

    // 1. Create/Update Membership Record
    final membershipRef = _db.collection('section_memberships').doc(membershipId);
    batch.set(
      membershipRef,
      {
        'userId': uid,
        'sectionId': sectionId,
        'role': role,
        'status': 'active',
        'joinedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    // 2. Update Legacy Users Document
    final userRef = _db.collection('users').doc(uid);
    final userData = <String, dynamic>{
      'role': role,
      'division': sectionId,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (name != null) userData['name'] = name;
    if (rollNo != null) userData['rollNo'] = rollNo;
    if (email != null) userData['email'] = email;

    batch.set(userRef, userData, SetOptions(merge: true));

    // 3. Update Legacy Students Subcollection (if student)
    if (role == 'Student' && rollNo != null && name != null) {
      final studentRef = _db.collection('sections').doc(sectionId).collection('students').doc(rollNo);
      batch.set(
        studentRef,
        {
          'name': name,
          'rollNo': rollNo,
          'joinedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  static Future<void> removeStudent({
    required String targetUid,
    required String sectionId,
    required String crUid,
    required String targetName,
    required String crName,
    String? reason,
  }) async {
    final callable = FirebaseFunctions.instance.httpsCallable('removeStudent');
    await callable.call({
      'targetUserId': targetUid,
      'sectionId': sectionId,
      'reason': reason,
    });
  }

  /// Listens to the current membership status of a user in a specific section.
  static Stream<String> listenToMembershipStatus(String uid, String sectionId) {
    final membershipId = '${sectionId}_$uid';
    return _db.collection('section_memberships').doc(membershipId).snapshots().map((doc) {
      if (!doc.exists) return 'unknown';
      return doc.data()?['status'] as String? ?? 'unknown';
    });
  }

  /// Fetches the roster (active members) for a given section.
  /// Returns a list of maps containing combined membership and user profile data.
  static Future<List<Map<String, dynamic>>> getSectionRoster(String sectionId) async {
    try {
      // 1. Get all active memberships for the section
      final snapshot = await _db
          .collection('section_memberships')
          .where('sectionId', isEqualTo: sectionId)
          .where('status', isEqualTo: 'active')
          .get();

      if (snapshot.docs.isEmpty) return [];

      // 2. Extract UIDs
      final uids = snapshot.docs.map((doc) => doc.data()['userId'] as String).toList();
      
      // 3. Chunk UIDs into groups of 10 for Firestore 'whereIn' limitation
      List<List<String>> chunks = [];
      for (var i = 0; i < uids.length; i += 10) {
        chunks.add(uids.sublist(i, i + 10 > uids.length ? uids.length : i + 10));
      }

      // 4. Fetch User Profiles
      final List<Map<String, dynamic>> roster = [];
      
      for (var chunk in chunks) {
        final usersSnap = await _db.collection('users').where(FieldPath.documentId, whereIn: chunk).get();
        final usersMap = {for (var doc in usersSnap.docs) doc.id: doc.data()};
        
        // Match user profiles with memberships
        for (var membershipDoc in snapshot.docs) {
          final mData = membershipDoc.data();
          final uid = mData['userId'] as String;
          if (chunk.contains(uid) && usersMap.containsKey(uid)) {
            roster.add({
              'uid': uid,
              'membership': mData,
              'profile': usersMap[uid],
            });
          }
        }
      }
      
      return roster;
    } catch (e) {
      debugPrint('Error fetching roster: \$e');
      return [];
    }
  }
}
