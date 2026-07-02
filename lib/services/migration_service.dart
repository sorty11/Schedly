import 'package:cloud_firestore/cloud_firestore.dart';


import '../models/timetable_entry.dart';
import 'pdf_timetable_import_service.dart';

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

  /// Fixes corrupted subject names (e.g., "CTPS Theory Theory") across timetables, analytics, and conduct_logs.
  static Future<void> sanitizeSubjectNames(String division) async {
    final batch = _db.batch();
    int ops = 0;

    Future<void> commitBatch() async {
      if (ops > 0) {
        await batch.commit();
        ops = 0;
      }
    }

    // 1. Sanitize Timetables
    for (final day in _days) {
      final snapshot = await _db.collection('timetables').doc(division).collection(day).get();
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final rawSubject = data['subject'] as String?;
        if (rawSubject != null) {
          final cleaned = TimetableEntry.stripComponentSuffix(rawSubject);
          if (cleaned != rawSubject) {
            batch.update(doc.reference, {'subject': cleaned});
            ops++;
            if (ops >= 400) await commitBatch();
          }
        }
      }
    }

    // 2. Sanitize Analytics
    final analyticsSnapshot = await _db.collection('sections').doc(division).collection('analytics').get();
    for (final doc in analyticsSnapshot.docs) {
      final data = doc.data();
      final rawSubject = data['subject'] as String?;
      if (rawSubject != null) {
        final cleaned = TimetableEntry.stripComponentSuffix(rawSubject);
        if (cleaned != rawSubject) {
          batch.update(doc.reference, {'subject': cleaned});
          ops++;
          if (ops >= 400) await commitBatch();
        }
      }
    }

    // 3. Sanitize Conduct Logs
    final logsSnapshot = await _db.collection('sections').doc(division).collection('conduct_logs').get();
    for (final doc in logsSnapshot.docs) {
      final data = doc.data();
      bool changed = false;
      
      final originalSlot = data['originalSlot'] as Map<String, dynamic>?;
      if (originalSlot != null) {
        final rawSubject = originalSlot['subject'] as String?;
        if (rawSubject != null) {
          final cleaned = TimetableEntry.stripComponentSuffix(rawSubject);
          if (cleaned != rawSubject) {
            originalSlot['subject'] = cleaned;
            changed = true;
          }
        }
      }

      final actualSubject = data['actualSubject'] as String?;
      if (actualSubject != null) {
        final cleaned = TimetableEntry.stripComponentSuffix(actualSubject);
        if (cleaned != actualSubject) {
          data['actualSubject'] = cleaned;
          changed = true;
        }
      }

      if (changed) {
        batch.update(doc.reference, {
          if (originalSlot != null) 'originalSlot': originalSlot,
          if (actualSubject != null) 'actualSubject': data['actualSubject'],
        });
        ops++;
        if (ops >= 400) await commitBatch();
      }
    }

    await commitBatch();
  }
}
