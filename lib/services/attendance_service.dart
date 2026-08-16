import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/attendance_record.dart';
import '../models/attendance_log.dart';
import 'package:schedly/exceptions.dart';

class AttendanceService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String _recordId(
    String division,
    String subjectCode,
    String component,
  ) => '${division}_${subjectCode}_$component'.replaceAll(RegExp(r'\s+'), '_');

  static CollectionReference _col() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw AppException('Not signed in');
    return _db.collection('users').doc(uid).collection('attendance');
  }

  /// Stream a single subject's attendance record (null = no record yet).
  static Stream<AttendanceRecord?> streamRecord(
    String division,
    String subjectCode,
    String component,
  ) {
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
        .map(
          (snap) =>
              snap.docs.map((d) => AttendanceRecord.fromFirestore(d)).toList(),
        );
  }

  /// Get all attendance records for a division once.
  static Future<List<AttendanceRecord>> getAll(String division) async {
    final snap = await _col()
        .where('division', isEqualTo: division)
        .get(const GetOptions(source: Source.serverAndCache));
    return snap.docs.map((d) => AttendanceRecord.fromFirestore(d)).toList();
  }

  static Future<void> mark({
    required String division,
    required String subjectCode,
    required String component,
    required String instanceId,
    required String?
    markType, // 'present', 'absent', 'cancelled', or null for undo
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

  static CollectionReference _logsCol() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw AppException('Not signed in');
    return _db.collection('users').doc(uid).collection('attendance_logs');
  }

  static Stream<List<AttendanceLog>> streamLogs() {
    return _logsCol()
        .orderBy('date', descending: true)
        .orderBy('startTime', descending: true)
        .limit(200)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => AttendanceLog.fromFirestore(d)).toList(),
        );
  }

  static Future<List<AttendanceLog>> getLogs() async {
    final snap = await _logsCol()
        .orderBy('date', descending: true)
        .orderBy('startTime', descending: true)
        .limit(200)
        .get(const GetOptions(source: Source.serverAndCache));
    return snap.docs.map((d) => AttendanceLog.fromFirestore(d)).toList();
  }

  static Future<void> markLog({
    required String subjectCode,
    required String component,
    required DateTime date,
    required int startTime,
    required int endTime,
    required String status, // 'present', 'absent', 'cancelled', 'delete'
    required String? entryId,
  }) async {
    final dateStr =
        '${date.year}_${date.month.toString().padLeft(2, '0')}_${date.day.toString().padLeft(2, '0')}';
    final id = '${subjectCode}_${component}_${dateStr}_${startTime}_$endTime'
        .replaceAll(RegExp(r'\s+'), '_');

    if (status == 'delete') {
      await _logsCol().doc(id).delete();
      return;
    }

    await _logsCol().doc(id).set({
      'subjectCode': subjectCode,
      'component': component,
      'rawSubjectText': subjectCode,
      'date': Timestamp.fromDate(date),
      'startTime': startTime,
      'endTime': endTime,
      'status': status,
      'source': 'manual',
      'confidence': 'exact',
      'timetableEntryId': entryId,
      'importedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Atomically batches new imported logs and updates aggregate counts
  static Future<Map<String, int>> batchImportAttendance({
    required String division,
    required List<AttendanceLog> logs,
  }) async {
    int newCount = 0;
    int dupCount = 0;

    // Get all existing logs to check duplicates
    final existingLogsSnap = await _logsCol().get();
    final existingKeys = existingLogsSnap.docs.map((d) => d.id).toSet();

    // Group new logs by their composite deduplication key
    final Map<String, AttendanceLog> uniqueNewLogs = {};
    for (final log in logs) {
      final key = log.deduplicationKey;
      if (!existingKeys.contains(key)) {
        uniqueNewLogs[key] = log;
      } else {
        dupCount++;
      }
    }

    if (uniqueNewLogs.isEmpty) {
      return {'new': 0, 'duplicates': dupCount};
    }

    // We need to update aggregate records too. First read them.
    final aggregatesSnap = await _col()
        .where('division', isEqualTo: division)
        .get();
    final aggregates = <String, Map<String, dynamic>>{};
    for (final doc in aggregatesSnap.docs) {
      aggregates[doc.id] = doc.data() as Map<String, dynamic>;
    }

    // Prepare deltas
    final aggregateDeltas = <String, Map<String, int>>{};

    // Chunk into 400 operations (Firebase limit is 500 per batch)
    // 1 op for log insert, 1 op for aggregate update
    WriteBatch? currentBatch;
    int opCount = 0;
    final batches = <WriteBatch>[];

    void commitOp() {
      if (currentBatch == null) {
        currentBatch = _db.batch();
        batches.add(currentBatch!);
      }
      opCount++;
      if (opCount >= 400) {
        currentBatch = null;
        opCount = 0;
      }
    }

    for (final key in uniqueNewLogs.keys) {
      final log = uniqueNewLogs[key]!;
      commitOp();
      final logRef = _logsCol().doc(key);
      currentBatch!.set(logRef, log.toFirestore());
      newCount++;

      if (log.subjectCode.isNotEmpty) {
        final aggId = _recordId(division, log.subjectCode, log.component);
        aggregateDeltas.putIfAbsent(aggId, () => {'present': 0, 'absent': 0});
        if (log.status == 'present' || log.status == 'P')
          aggregateDeltas[aggId]!['present'] =
              aggregateDeltas[aggId]!['present']! + 1;
        if (log.status == 'absent' || log.status == 'A')
          aggregateDeltas[aggId]!['absent'] =
              aggregateDeltas[aggId]!['absent']! + 1;
      }
    }

    // Apply aggregate deltas
    for (final aggId in aggregateDeltas.keys) {
      commitOp();
      final aggRef = _col().doc(aggId);
      final delta = aggregateDeltas[aggId]!;

      final currentData = aggregates[aggId];
      final currPresent = (currentData?['present'] as num?)?.toInt() ?? 0;
      final currAbsent = (currentData?['absent'] as num?)?.toInt() ?? 0;

      // If it's a new aggregate, set division and component
      final splits = aggId.split('_');
      final subj = splits.length > 1 ? splits[1] : '';
      final comp = splits.length > 2 ? splits[2] : 'Theory';

      currentBatch!.set(aggRef, {
        'division': division,
        'subjectCode': subj,
        'component': comp,
        'present': currPresent + delta['present']!,
        'absent': currAbsent + delta['absent']!,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    for (final b in batches) {
      await b.commit();
    }

    return {'new': newCount, 'duplicates': dupCount};
  }
}
