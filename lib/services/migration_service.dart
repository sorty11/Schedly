import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/timetable_entry.dart';
import '../models/event_category.dart';
import 'pdf_timetable_import_service.dart';
import '../timetable_manager.dart';

class MigrationService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const List<String> _days = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'
  ];

  /// Upgrade the database for a specific division to the Architecture v2 data model.
  static Future<void> upgradeToV2(String division) async {
    final divRef = _db.collection('timetables').doc(division);

    // 1. Migrate Timetables
    for (final day in _days) {
      final snapshot = await divRef.collection(day).get();
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        
        // Skip if already migrated (contains 'startTime')
        if (data.containsKey('startTime')) continue;

        final rawSubject = data['subject'] as String? ?? 'Free Slot';
        final rawTime = data['time'] as String? ?? '9:00 AM - 10:00 AM';
        final rawRoom = data['room'] as String? ?? 'L-19';

        // Use the proper PdfTimetableImportService to break down the string
        final entries = PdfTimetableImportService.buildEntriesFromText(rawSubject, rawTime, rawRoom);
        
        final batch = _db.batch();
        batch.delete(doc.reference); // Delete legacy doc
        
        for (final entry in entries) {
          batch.set(divRef.collection(day).doc(entry.id), entry.toFirestore());
        }
        
        await batch.commit();
      }
    }

    // 2. Wipe legacy conduct logs and analytics (since they are incompatible with v2 flat architecture)
    final logsSnapshot = await _db.collection('sections').doc(division).collection('conduct_logs').get();
    for (final doc in logsSnapshot.docs) {
      await doc.reference.delete();
    }

    final analyticsSnapshot = await _db.collection('sections').doc(division).collection('analytics').get();
    for (final doc in analyticsSnapshot.docs) {
      await doc.reference.delete();
    }
  }

  // (Removed duplicate parsing logic as it's now handled by PdfTimetableImportService)
}
