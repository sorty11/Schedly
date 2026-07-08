import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/attendance_record.dart';

class AttendanceService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String _recordId(String division, String subjectCode, String component) =>
      '${division}_${subjectCode}_$component'.replaceAll(RegExp(r'\s+'), '_');

  static CollectionReference _col() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');
    return _db.collection('users').doc(uid).collection('attendance');
  }

  /// Stream a single subject's attendance record (null = no record yet).
  static Stream<AttendanceRecord?> streamRecord(
      String division, String subjectCode, String component) {
    final id = _recordId(division, subjectCode, component);
    return _col().doc(id).snapshots().map((snap) {
      if (!snap.exists) return null;
      return AttendanceRecord.fromFirestore(snap);
    });
  }

  /// Stream all attendance records for a division.
  static Stream<List<AttendanceRecord>> streamAll(String division) {
    return _col()
        .where('division', isEqualTo: division)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => AttendanceRecord.fromFirestore(d))
            .toList());
  }

  static Future<void> mark({
    required String division,
    required String subjectCode,
    required String component,
    required String instanceId,
    required String? markType, // 'present', 'absent', 'cancelled', or null for undo
  }) async {
    final id = _recordId(division, subjectCode, component);
    final ref = _col().doc(id);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() as Map<String, dynamic>? ?? {};
      
      Map<String, String> markedInstances = {};
      if (data['markedInstances'] is Map) {
        markedInstances = Map<String, String>.from(data['markedInstances']);
      } else if (data['markedInstances'] is List) {
        for (final item in data['markedInstances'] as List) {
          markedInstances[item.toString()] = 'present';
        }
      }

      final currentMark = markedInstances[instanceId];
      if (currentMark == markType) return; // No change

      int presentDelta = 0;
      int absentDelta = 0;
      int cancelledDelta = 0;

      // Undo current mark if it exists
      if (currentMark == 'present') presentDelta -= 1;
      if (currentMark == 'absent') absentDelta -= 1;
      if (currentMark == 'cancelled') cancelledDelta -= 1;

      // Apply new mark
      if (markType == 'present') presentDelta += 1;
      if (markType == 'absent') absentDelta += 1;
      if (markType == 'cancelled') cancelledDelta += 1;

      if (markType == null) {
        markedInstances.remove(instanceId);
      } else {
        markedInstances[instanceId] = markType;
      }

      final updates = <String, dynamic>{
        'division': division,
        'subjectCode': subjectCode,
        'component': component,
        'updatedAt': FieldValue.serverTimestamp(),
        'markedInstances': markedInstances,
      };

      // Apply deltas to current values
      final currPresent = (data['present'] as num?)?.toInt() ?? 0;
      final currAbsent = (data['absent'] as num?)?.toInt() ?? 0;
      final currCancelled = (data['cancelled'] as num?)?.toInt() ?? 0;

      updates['present'] = (currPresent + presentDelta).clamp(0, 9999);
      updates['absent'] = (currAbsent + absentDelta).clamp(0, 9999);
      updates['cancelled'] = (currCancelled + cancelledDelta).clamp(0, 9999);

      tx.set(ref, updates, SetOptions(merge: true));
    });
  }
}
