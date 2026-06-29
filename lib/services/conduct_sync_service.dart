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
    final divRef = _db.collection('sections').doc(division);

    try {
      final startDate = await _db.runTransaction((transaction) async {
        final divSnapshot = await transaction.get(divRef);
        final data = divSnapshot.data();

        if (data == null && !forceToday) return null;

        final now = DateTime.now();
        final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        
        final lastSyncDateStr = data?['lastSyncDate'] as String?;
        if (lastSyncDateStr == todayStr && !forceToday) {
          return null; // Already synced today
        }

        DateTime start;
        if (forceToday) {
          start = DateTime(now.year, now.month, now.day);
        } else if (lastSyncDateStr == null) {
          start = DateTime(now.year, now.month, now.day);
        } else {
          final parts = lastSyncDateStr.split('-');
          start = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2])).add(const Duration(days: 1));
        }

        if (now.difference(start).inDays > 7) {
          start = now.subtract(const Duration(days: 7));
          start = DateTime(start.year, start.month, start.day);
        }

        transaction.set(divRef, {'lastSyncDate': todayStr}, SetOptions(merge: true));
        return start;
      });

      if (startDate == null) return;

      final now = DateTime.now();
      final endDate = DateTime(now.year, now.month, now.day);
      DateTime currentDate = startDate;
      
      while (!currentDate.isAfter(endDate)) {
        final dayName = _weekdays[currentDate.weekday - 1];
        final dateStr = '${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}';

        final timetableSnapshot = await _db
            .collection('timetables')
            .doc(division)
            .collection(dayName)
            .where('isActive', isEqualTo: true)
            .get();

        if (timetableSnapshot.docs.isNotEmpty) {
          final batchWriter = _db.batch();
          bool hasWrites = false;

          for (var doc in timetableSnapshot.docs) {
            final entry = TimetableEntry.fromFirestore(doc);
            
            // Only create conduct logs for academic entries to keep things clean.
            // Non-academic entries don't need conduct logs unless we want to track them.
            // The architecture says: "Only Academic events should contribute to analytics. Everything else should automatically be ignored."
            if (!entry.isAcademic) continue;

            final logRef = _db
                .collection('sections')
                .doc(division)
                .collection('conduct_logs')
                .doc(); // Auto-ID

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
            await batchWriter.commit();
          }
        }
        currentDate = currentDate.add(const Duration(days: 1));
      }
    } catch (e) {
      // print('Error in ConductSyncService: $e');
    }
  }
}
