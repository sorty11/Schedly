import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';


import 'package:shared_preferences/shared_preferences.dart';
import '../app_settings.dart';
import '../models/timetable_entry.dart';
import 'pdf_timetable_import_service.dart';
import 'package:flutter/foundation.dart';
import 'package:schedly/exceptions.dart';

class MigrationService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const List<String> _days = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'
  ];

  static Future<bool> migrateFacultyIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final version = prefs.getInt('faculty_id_migration_version') ?? 0;
      if (version >= 2) return true; 

      final role = prefs.getString('user_role');
      if (role != 'faculty') {
        await prefs.setInt('faculty_id_migration_version', 2);
        return true;
      }

      final name = prefs.getString('faculty_name');
      if (name == null || name.isEmpty) return false;

      final legacyId = 'fac_${name.replaceAll(' ', '').toLowerCase()}';
      final newId = _db.collection('faculty_profiles').doc().id;

      // STEP 1: Copy
      final profileSnap = await _db.collection('faculty_profiles').doc(legacyId).get();
      if (profileSnap.exists) {
        await _db.collection('faculty_profiles').doc(newId).set(profileSnap.data()!);
      } else {
        await _db.collection('faculty_profiles').doc(newId).set({
          'name': name,
          'createdAt': FieldValue.serverTimestamp(),
          'department': prefs.getString('faculty_department'),
          'designation': prefs.getString('faculty_designation'),
          'cabin': prefs.getString('faculty_cabin'),
          'assignedDivisions': prefs.getStringList('faculty_assigned_divisions'),
        });
      }

      final userSnap = await _db.collection('users').doc(legacyId).get();
      if (userSnap.exists) {
        await _db.collection('users').doc(newId).set(userSnap.data()!);
      } else {
        await _db.collection('users').doc(newId).set({
          'role': 'FACULTY',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // STEP 2: Verify Copied Data
      final verifyProfile = await _db.collection('faculty_profiles').doc(newId).get();
      final verifyUser = await _db.collection('users').doc(newId).get();
      if (!verifyProfile.exists || !verifyUser.exists) {
        throw AppException("Verification failed: Copied documents do not exist.");
      }

      // STEP 3: Mark migration successful locally
      await AppSettings.saveFacultyDetails(
        name: name,
        email: prefs.getString('faculty_email') ?? '',
        department: prefs.getString('faculty_department') ?? '',
        designation: prefs.getString('faculty_designation') ?? '',
        cabin: prefs.getString('faculty_cabin') ?? '',
        assignedDivisions: prefs.getStringList('faculty_assigned_divisions') ?? [],
        id: newId,
        migrationVersion: 2,
      );

      // STEP 4: Remove legacy documents
      await _db.collection('faculty_profiles').doc(legacyId).delete();
      await _db.collection('users').doc(legacyId).delete();
      
      debugPrint('MIGRATION: Successfully migrated $legacyId to $newId and deleted legacy docs.');
      return true;
    } catch (e) {
      debugPrint('MIGRATION ERROR: $e');
      return false;
    }
  }

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

  /// Migrates legacy batch names (e.g., "Batch1") to dynamic division batch names (e.g., "C1")
  static Future<void> migrateBatchNames(String division) async {
    final l = _getDivLetter(division);
    if (l.isEmpty) return; // Cannot determine letter for dynamic batches

    final batch1New = '${l}1';
    final batch2New = '${l}2';

    final batch = _db.batch();
    int ops = 0;

    Future<void> commitBatch() async {
      if (ops > 0) {
        await batch.commit();
        ops = 0;
      }
    }

    String? _remapBatch(String? oldBatch) {
      if (oldBatch == null) return null;
      final trimmed = oldBatch.trim().toLowerCase().replaceAll(' ', '');
      if (trimmed == 'batch1') return batch1New;
      if (trimmed == 'batch2') return batch2New;
      return null;
    }

    // 1. Migrate Timetables
    for (final day in _days) {
      final snapshot = await _db.collection('timetables').doc(division).collection(day).get();
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final mapped = _remapBatch(data['batch'] as String?);
        if (mapped != null) {
          batch.update(doc.reference, {'batch': mapped});
          ops++;
          if (ops >= 400) await commitBatch();
        }
      }
    }

    // 2. Migrate Analytics
    final analyticsSnapshot = await _db.collection('sections').doc(division).collection('analytics').get();
    for (final doc in analyticsSnapshot.docs) {
      final data = doc.data();
      final mapped = _remapBatch(data['batch'] as String?);
      if (mapped != null) {
        batch.update(doc.reference, {'batch': mapped});
        ops++;
        if (ops >= 400) await commitBatch();
      }
    }

    // 3. Migrate Conduct Logs
    final logsSnapshot = await _db.collection('sections').doc(division).collection('conduct_logs').get();
    for (final doc in logsSnapshot.docs) {
      final data = doc.data();
      final originalSlot = data['originalSlot'] as Map<String, dynamic>?;
      if (originalSlot != null) {
        final mapped = _remapBatch(originalSlot['batch'] as String?);
        if (mapped != null) {
          originalSlot['batch'] = mapped;
          batch.update(doc.reference, {'originalSlot': originalSlot});
          ops++;
          if (ops >= 400) await commitBatch();
        }
      }
    }

    await commitBatch();
  }

  static String _getDivLetter(String division) {
    if (division.isEmpty) return '';
    final last = division.trim().characters.last.toUpperCase();
    return RegExp(r'[A-Z]').hasMatch(last) ? last : '';
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
          // ignore: use_null_aware_elements
          if (originalSlot != null) 'originalSlot': originalSlot,
          // ignore: use_null_aware_elements
          if (actualSubject != null) 'actualSubject': data['actualSubject'],
        });
        ops++;
        if (ops >= 400) await commitBatch();
      }
    }

    await commitBatch();
  }

  /// Migrates legacy SubjectMetadata models to the new CourseComponent architecture.
  /// Derives courseName and componentType from the document ID exactly once.
  static Future<void> migrateToCourseArchitecture(String division) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'course_architecture_migrated_$division';
    if (prefs.getBool(cacheKey) == true) return;

    final batch = _db.batch();
    int ops = 0;

    Future<void> commitBatch() async {
      if (ops > 0) {
        await batch.commit();
        ops = 0;
      }
    }

    final snapshot = await _db.collection('sections').doc(division).collection('subjects').get();
    for (final doc in snapshot.docs) {
      final data = doc.data();
      
      // If already migrated (has componentType explicitly set), skip
      if (data.containsKey('componentType') && data.containsKey('courseName')) {
        continue;
      }

      final docId = doc.id;
      final subjectName = data['subjectName'] as String? ?? docId;
      
      // Derive from subjectName (which is often the same as docId, but subjectName is safer)
      final courseName = TimetableEntry.stripComponentSuffix(subjectName);
      
      // Determine type
      String componentType = 'Theory';
      final lowerName = subjectName.toLowerCase();
      if (data['isLab'] == true || lowerName.endsWith(' lab')) {
        componentType = 'Lab';
      } else if (lowerName.endsWith(' tutorial')) {
        componentType = 'Tutorial';
      } else if (lowerName.endsWith(' project')) {
        componentType = 'Project';
      } else if (lowerName.endsWith(' seminar')) {
        componentType = 'Seminar';
      } else if (lowerName.endsWith(' workshop')) {
        componentType = 'Workshop';
      } else if (lowerName.endsWith(' viva')) {
        componentType = 'Viva';
      } else if (courseName == subjectName.trim()) {
        // If stripping didn't change it and it's not marked as lab, it's combined
        componentType = 'Combined';
      }

      batch.update(doc.reference, {
        'courseName': courseName,
        'componentType': componentType,
      });
      ops++;
      if (ops >= 400) await commitBatch();
    }

    await commitBatch();
    await prefs.setBool(cacheKey, true);
  }
}
