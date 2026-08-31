import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/attendance_record.dart';
import '../models/attendance_log.dart';
import '../models/attendance_import_models.dart';
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

  /// Safely commits PDF-imported logs with upsert + aggregate recomputation.
  /// Existing attendance is unchanged if this throws before any batch commit.
  static Future<AttendanceImportResult> commitPdfImport({
    required String division,
    required List<AttendanceLog> logs,
  }) async {
    if (logs.isEmpty) {
      return const AttendanceImportResult(imported: 0);
    }

    final existingSnap = await _logsCol().get();
    final existingByKey = <String, AttendanceLog>{};
    final staleDocRefsToDelete = <DocumentReference>[];

    for (final doc in existingSnap.docs) {
      final log = AttendanceLog.fromFirestore(doc);
      final key = log.deduplicationKey;
      if (existingByKey.containsKey(key)) {
        staleDocRefsToDelete.add(doc.reference);
      } else {
        existingByKey[key] = log;
        if (doc.id != key) {
          staleDocRefsToDelete.add(doc.reference);
        }
      }
    }

    var imported = 0;
    var updated = 0;
    var skippedDuplicates = 0;

    WriteBatch? currentBatch;
    var opCount = 0;
    final batches = <WriteBatch>[];

    void queueWrite(void Function(WriteBatch batch) write) {
      if (currentBatch == null) {
        currentBatch = _db.batch();
        batches.add(currentBatch!);
      }
      write(currentBatch!);
      opCount++;
      if (opCount >= 450) {
        currentBatch = null;
        opCount = 0;
      }
    }

    for (final ref in staleDocRefsToDelete) {
      queueWrite((batch) => batch.delete(ref));
    }

    final affectedComponents = <({String subjectCode, String component})>{};
    final seenInThisImport = <String>{};
    for (final log in logs) {
      final key = log.deduplicationKey;
      if (seenInThisImport.contains(key)) {
        skippedDuplicates++;
        continue;
      }
      seenInThisImport.add(key);

      final existing = existingByKey[key];

      if (existing != null &&
          existing.status == log.status &&
          !staleDocRefsToDelete.any((r) => r.id == existing.id)) {
        skippedDuplicates++;
        continue;
      }

      queueWrite((batch) {
        batch.set(
          _logsCol().doc(key),
          log.toFirestore(),
          SetOptions(merge: true),
        );
      });

      if (existing != null) {
        updated++;
      } else {
        imported++;
      }

      if (log.subjectCode.isNotEmpty) {
        final groupComp = AttendanceLog.isDsa(log.subjectCode)
            ? log.component
            : 'Merged';
        affectedComponents.add((
          subjectCode: log.subjectCode,
          component: groupComp,
        ));
      }
    }

    if (batches.isEmpty) {
      return AttendanceImportResult(
        imported: 0,
        updated: 0,
        skippedDuplicates: skippedDuplicates,
      );
    }

    try {
      for (final batch in batches) {
        await batch.commit();
      }
    } catch (e) {
      throw AppException(
        'Import failed — existing attendance was not changed. $e',
      );
    }

    var aggregatesUpdated = 0;
    for (final item in affectedComponents) {
      await recomputeAggregateForSubject(
        division: division,
        subjectCode: item.subjectCode,
        component: item.component,
      );
      aggregatesUpdated++;
    }

    return AttendanceImportResult(
      imported: imported,
      updated: updated,
      skippedDuplicates: skippedDuplicates,
      aggregatesUpdated: aggregatesUpdated,
    );
  }

  /// Recomputes all aggregate records for a division from stored attendance logs.
  static Future<void> recomputeAllAggregates(String division) async {
    final logsSnap = await _logsCol().get();
    final pairs = <({String subjectCode, String component})>{};
    for (final doc in logsSnap.docs) {
      final log = AttendanceLog.fromFirestore(doc);
      if (log.subjectCode.isNotEmpty) {
        final groupComp = AttendanceLog.isDsa(log.subjectCode)
            ? log.component
            : 'Merged';
        pairs.add((subjectCode: log.subjectCode, component: groupComp));
      }
    }
    for (final pair in pairs) {
      await recomputeAggregateForSubject(
        division: division,
        subjectCode: pair.subjectCode,
        component: pair.component,
      );
    }
  }

  /// Recomputes present/absent counts from attendance_logs for one subject.
  static Future<void> recomputeAggregateForSubject({
    required String division,
    required String subjectCode,
    required String component,
  }) async {
    final canonSubj = AttendanceLog.canonicalSubjectCode(subjectCode);
    final snapshot = await _logsCol().get();

    // Deduplicate in memory by stable lecture identity to ensure 100% data accuracy
    final uniqueLogs = <String, AttendanceLog>{};
    for (final doc in snapshot.docs) {
      final log = AttendanceLog.fromFirestore(doc);
      final logCanon = AttendanceLog.canonicalSubjectCode(log.subjectCode);
      if (logCanon != canonSubj) continue;

      if (AttendanceLog.isDsa(canonSubj) && component != 'Merged') {
        if (log.component.toLowerCase() != component.toLowerCase()) {
          continue;
        }
      }
      final existing = uniqueLogs[log.deduplicationKey];
      if (existing == null || log.importedAt.isAfter(existing.importedAt)) {
        uniqueLogs[log.deduplicationKey] = log;
      }
    }

    var present = 0;
    var absent = 0;
    for (final log in uniqueLogs.values) {
      if (log.status == 'present') {
        present++;
      } else if (log.status == 'absent') {
        absent++;
      }
    }

    final recordId = _recordId(division, canonSubj, component);
    await _col().doc(recordId).set({
      'division': division,
      'subjectCode': subjectCode,
      'component': component,
      'present': present,
      'absent': absent,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Legacy batch import — delegates to commitPdfImport.
  static Future<Map<String, int>> batchImportAttendance({
    required String division,
    required List<AttendanceLog> logs,
  }) async {
    final result = await commitPdfImport(division: division, logs: logs);
    return {
      'new': result.imported,
      'duplicates': result.skippedDuplicates,
      'updated': result.updated,
    };
  }
}
