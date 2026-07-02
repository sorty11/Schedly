import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/timetable_entry.dart';
import '../models/event_category.dart';
import 'analytics_service.dart';

class ConductSyncService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const List<String> _weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];

  static Future<void> syncPendingLectures(String division, {bool forceToday = false}) async {
    debugPrint('ConductSyncService.syncPendingLectures() called for division: $division');
    try {
      final now = DateTime.now();
      // Scan last 3 days + today
      final startDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 3));
      final endDate = DateTime(now.year, now.month, now.day);
      DateTime currentDate = startDate;
      
      while (!currentDate.isAfter(endDate)) {
        final dayName = _weekdays[currentDate.weekday - 1];
        final dateStr = '${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}';

        debugPrint('Checking date: $dateStr ($dayName)');

        // Fetch existing logs for this date to ensure idempotency
        final existingLogsSnap = await _db
            .collection('sections')
            .doc(division)
            .collection('conduct_logs')
            .where('date', isEqualTo: dateStr)
            .get();
        final existingLogIds = existingLogsSnap.docs.map((d) => d.id).toSet();
        
        debugPrint('Found ${existingLogIds.length} existing conduct_logs for $dateStr in division $division');

        final timetableSnapshot = await _db
            .collection('timetables')
            .doc(division)
            .collection(dayName)
            .where('isActive', isEqualTo: true)
            .get();

        debugPrint('Found ${timetableSnapshot.docs.length} active timetable entries for $dayName');

        if (timetableSnapshot.docs.isNotEmpty) {
          final batchWriter = _db.batch();
          bool hasWrites = false;

          for (var doc in timetableSnapshot.docs) {
            final entry = TimetableEntry.fromFirestore(doc);
            
            debugPrint('Processing entry: ${entry.id}, Subject: ${entry.subject}, isAcademic: ${entry.isAcademic}');
            
            // Only create conduct logs for academic entries
            if (!entry.isAcademic) {
              debugPrint('Skipping ${entry.id} because it is not academic');
              continue;
            }

            final logId = '${dateStr}_${entry.id}';
            
            // Skip if it already exists
            if (existingLogIds.contains(logId)) {
              debugPrint('Skipping ${entry.id} because conduct log $logId already exists');
              continue;
            }

            debugPrint('Preparing to write conduct log $logId');

            final logRef = _db
                .collection('sections')
                .doc(division)
                .collection('conduct_logs')
                .doc(logId);

            batchWriter.set(logRef, {
              'date': dateStr,
              'originalSlot': entry.toFirestore(),
              'durationMinutes': entry.durationMinutes,
              'status': 'pending',
              'audit': {
                'markedBy': 'System',
                'markedByUid': 'system',
                'clientTimestamp': DateTime.now().toIso8601String(),
                'serverTimestamp': FieldValue.serverTimestamp(),
              }
            });
            hasWrites = true;

            // Increment totalPending in analytics
            int weight = (entry.durationMinutes / 60).round();
            if (weight < 1) weight = 1;

            final analyticsId = AnalyticsService.getAnalyticsDocId(entry.subject, entry.component, entry.batch);
            final analyticsRef = _db
                .collection('sections')
                .doc(division)
                .collection('analytics')
                .doc(analyticsId);
                
            batchWriter.set(analyticsRef, {
              'subject': entry.subject,
              'component': entry.component,
              'batch': entry.batch,
              'category': entry.category.name.toLowerCase(),
              'pendingLectures': FieldValue.increment(weight),
            }, SetOptions(merge: true));
          }

          if (hasWrites) {
            debugPrint('Committing batch write for $dateStr');
            await batchWriter.commit();
            debugPrint('Batch write successful for $dateStr');
          } else {
            debugPrint('No new logs to write for $dateStr');
          }
        }
        currentDate = currentDate.add(const Duration(days: 1));
      }
    } catch (e) {
      debugPrint('Error in ConductSyncService: $e');
    }
  }
}
