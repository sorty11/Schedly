import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/batch_analytics.dart';
import '../models/conduct_log.dart';
import '../models/event_category.dart';
import '../models/timetable_entry.dart';

class AnalyticsService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String getAnalyticsDocId(String subject, String component, String batch) {
    return '${subject.trim()}_${component.trim()}_${batch.trim()}'.replaceAll(RegExp(r'\s+'), '_');
  }

  static Stream<List<BatchAnalytics>> streamAnalytics(String division) {
    return _db
        .collection('sections')
        .doc(division)
        .collection('analytics')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
            .map((doc) => BatchAnalytics.fromFirestore(doc))
            .toList();
        });
  }

  static Future<void> initializeSubjectAnalytics(String division) async {
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    final Map<String, int> weeklyOccurrences = {};
    final Set<String> allBatches = {'Whole Class'};
    
    // 1. Calculate weekly occurrences from timetable
    for (final day in days) {
      final snapshot = await _db.collection('timetables').doc(division).collection(day).where('isActive', isEqualTo: true).get();
      for (final doc in snapshot.docs) {
        final entry = TimetableEntry.fromFirestore(doc);
        if (entry.category == EventCategory.academic) {
          final id = getAnalyticsDocId(entry.subject, entry.component, entry.batch);
          weeklyOccurrences[id] = (weeklyOccurrences[id] ?? 0) + 1;
          allBatches.add(entry.batch);
        }
      }
    }

    // 2. Fetch existing analytics to avoid overwriting completed/pending counts
    final existingSnapshot = await _db.collection('sections').doc(division).collection('analytics').get();
    final existingDocs = {for (var doc in existingSnapshot.docs) doc.id: BatchAnalytics.fromFirestore(doc)};

    final batchWriter = _db.batch();

    // 3. Write/Update analytics documents
    for (final id in weeklyOccurrences.keys) {
      final parts = id.split('_');
      final subject = parts[0];
      final component = parts.length > 1 ? parts[1] : 'Theory';
      final batch = parts.length > 2 ? parts.sublist(2).join('_') : 'Whole Class';
      
      final target = weeklyOccurrences[id]! * 15; // 15 teaching weeks
      
      final docRef = _db.collection('sections').doc(division).collection('analytics').doc(id);
      
      if (existingDocs.containsKey(id)) {
        batchWriter.update(docRef, {'targetLectures': target});
      } else {
        final newAnalytics = BatchAnalytics(
          id: id,
          subject: subject,
          component: component,
          batch: batch,
          category: EventCategory.academic,
          targetLectures: target,
        );
        batchWriter.set(docRef, newAnalytics.toFirestore());
      }
    }
    
    await batchWriter.commit();
  }

  static Future<void> updateLectureStatus({
    required ConductLog log,
    required String division,
    required String newStatus,
    required String markedBy,
    required String markedByUid,
    String? actualSubject, 
    String? actualComponent,
    String? actualBatch,
    EventCategory? actualCategory,
  }) async {
    if (log.status == newStatus && 
        log.actualSubject == actualSubject && 
        log.actualBatch == actualBatch) {
      return; 
    }

    final batchWriter = _db.batch();
    
    final logRef = _db
        .collection('sections')
        .doc(division)
        .collection('conduct_logs')
        .doc(log.id);

    final logUpdates = <String, dynamic>{
      'status': newStatus,
      'audit.markedBy': markedBy,
      'audit.markedByUid': markedByUid,
      'audit.clientTimestamp': DateTime.now().toIso8601String(),
      'audit.serverTimestamp': FieldValue.serverTimestamp(),
    };
    
    if (newStatus == 'rescheduled' && actualSubject != null) {
      logUpdates['actualSubject'] = actualSubject;
      logUpdates['actualComponent'] = actualComponent ?? 'Theory';
      logUpdates['actualBatch'] = actualBatch ?? log.originalSlot.batch;
      logUpdates['actualCategory'] = actualCategory?.name.toLowerCase() ?? EventCategory.academic.name.toLowerCase();
    } else if (newStatus != 'rescheduled') {
      logUpdates['actualSubject'] = FieldValue.delete();
      logUpdates['actualComponent'] = FieldValue.delete();
      logUpdates['actualBatch'] = FieldValue.delete();
      logUpdates['actualCategory'] = FieldValue.delete();
    }

    batchWriter.update(logRef, logUpdates);

    // Calculate weight (using duration hours)
    int weight = (log.durationMinutes / 60).round();
    if (weight < 1) weight = 1;

    // Helper to extract contribution for analytics
    Map<String, Map<String, int>> getContributions(
      String status, 
      String origSubj, 
      String origComp,
      String origBatch, 
      String? actSubj, 
      String? actComp,
      String? actBatch,
      EventCategory origCat,
      EventCategory? actCat,
    ) {
      final res = <String, Map<String, int>>{};
      
      void add(String s, String c, String b, String field, int val) {
        final id = getAnalyticsDocId(s, c, b);
        res.putIfAbsent(id, () => {});
        res[id]![field] = (res[id]![field] ?? 0) + val;
      }

      // Original slot (only impacts analytics if it was academic)
      if (origCat == EventCategory.academic) {
        if (status == 'pending' || status == 'rescheduled') {
          add(origSubj, origComp, origBatch, 'pendingLectures', weight);
        } else if (status == 'conducted') {
          add(origSubj, origComp, origBatch, 'completedLectures', weight);
        } else if (status == 'cancelled') {
          add(origSubj, origComp, origBatch, 'cancelledLectures', weight);
        }
      }

      // Actual slot (only impacts analytics if rescheduled AND academic)
      if (status == 'rescheduled' && actSubj != null && actComp != null && actBatch != null) {
        if (actCat == EventCategory.academic) {
          add(actSubj, actComp, actBatch, 'completedLectures', weight);
          add(actSubj, actComp, actBatch, 'pendingLectures', -weight);
        }
      }

      return res;
    }

    final oldContribs = getContributions(
      log.status, 
      log.originalSlot.subject, 
      log.originalSlot.component,
      log.originalSlot.batch,
      log.actualSubject,
      log.actualComponent,
      log.actualBatch,
      log.originalSlot.category,
      log.actualCategory,
    );

    final newContribs = getContributions(
      newStatus, 
      log.originalSlot.subject, 
      log.originalSlot.component,
      log.originalSlot.batch,
      newStatus == 'rescheduled' ? actualSubject : null,
      newStatus == 'rescheduled' ? (actualComponent ?? 'Theory') : null,
      newStatus == 'rescheduled' ? (actualBatch ?? log.originalSlot.batch) : null,
      log.originalSlot.category,
      newStatus == 'rescheduled' ? (actualCategory ?? EventCategory.academic) : null,
    );

    // Compute Net Change
    final netChanges = <String, Map<String, int>>{};
    
    for (final id in oldContribs.keys) {
      for (final field in oldContribs[id]!.keys) {
        netChanges.putIfAbsent(id, () => {});
        netChanges[id]![field] = (netChanges[id]![field] ?? 0) - oldContribs[id]![field]!;
      }
    }
    for (final id in newContribs.keys) {
      for (final field in newContribs[id]!.keys) {
        netChanges.putIfAbsent(id, () => {});
        netChanges[id]![field] = (netChanges[id]![field] ?? 0) + newContribs[id]![field]!;
      }
    }

    // Apply to analytics collection
    for (final id in netChanges.keys) {
      final increments = <String, dynamic>{};
      for (final field in netChanges[id]!.keys) {
        final change = netChanges[id]![field]!;
        if (change != 0) {
          increments[field] = FieldValue.increment(change);
        }
      }
      
      if (increments.isNotEmpty) {
        final analyticsRef = _db
            .collection('sections')
            .doc(division)
            .collection('analytics')
            .doc(id);
            
        batchWriter.set(analyticsRef, increments, SetOptions(merge: true));
      }
    }

    await batchWriter.commit();
  }

  static Stream<List<ConductLog>> streamPendingLogs(String division, String subjectFilter, String? componentFilter, String? batchFilter) {
    return _db
        .collection('sections')
        .doc(division)
        .collection('conduct_logs')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
          final allLogs = snapshot.docs.map((doc) => ConductLog.fromFirestore(doc)).toList();
          return allLogs.where((log) {
            if (!log.originalSlot.isAcademic) return false;
            if (log.originalSlot.subject != subjectFilter) return false;
            if (componentFilter != null && log.originalSlot.component != componentFilter) return false;
            if (batchFilter != null && log.originalSlot.batch != batchFilter) return false;
            return true;
          }).toList();
        });
  }
}
