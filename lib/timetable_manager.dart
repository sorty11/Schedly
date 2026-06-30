import 'package:cloud_firestore/cloud_firestore.dart';

import 'system_update_manager.dart';
import 'services/app_notification_service.dart';
import 'models/timetable_entry.dart';
import 'models/event_category.dart';
import 'system_update_manager.dart';
import 'services/timetable_event_service.dart';

class ValidationException implements Exception {
  final String title;
  final String message;
  ValidationException(this.title, this.message);
  @override
  String toString() => message;
}

class TimetableManager {
  static const List<String> allSlots = [
    '9:00 AM - 10:00 AM',
    '10:00 AM - 11:00 AM',
    '11:00 AM - 12:00 PM',
    '12:00 PM - 1:00 PM',
    '2:00 PM - 3:00 PM',
    '3:00 PM - 4:00 PM',
    '4:00 PM - 5:00 PM',
  ];

  static Future<void> addLecture({
    required String division,
    required String day,
    required TimetableEntry entry,
    TimetableEntry? oldEntry,
  }) async {
    final snap = await FirebaseFirestore.instance
        .collection('timetables')
        .doc(division)
        .collection(day)
        .where('isActive', isEqualTo: true)
        .get();

    final activeLectures = snap.docs
        .map((d) => TimetableEntry.fromFirestore(d))
        .where((l) => l.id != entry.id)
        .toList();

    final overlaps = activeLectures.where((l) => 
        l.startTime < entry.endTime && l.endTime > entry.startTime
    ).toList();

    if (overlaps.isNotEmpty) {
      if (entry.batch == 'Whole Class') {
        final conflictList = overlaps.map((l) => '• ${l.batch} - ${l.displaySubject}').join('\n');
        throw ValidationException(
          'Cannot Replace Lecture',
          'Whole Class cannot be scheduled because this period already contains:\n\n$conflictList\n\nDelete the existing batch lectures first or replace them individually.'
        );
      } else {
        final wholeClassConflict = overlaps.where((l) => l.batch == 'Whole Class').toList();
        if (wholeClassConflict.isNotEmpty) {
           final l = wholeClassConflict.first;
           throw ValidationException(
             'Time Conflict',
             'This lecture overlaps with a Whole Class lecture (${l.displaySubject}).\n\nPlease choose another period or replace the Whole Class lecture.'
           );
        }
        
        final sameBatchConflict = overlaps.where((l) => l.batch == entry.batch).toList();
        if (sameBatchConflict.isNotEmpty) {
           final l = sameBatchConflict.first;
           if (l.subject == entry.subject) {
             throw ValidationException(
               'Duplicate Lecture',
               'A lecture with the same subject already exists in this slot for Batch ${entry.batch}.'
             );
           }
           throw ValidationException(
             'Time Conflict',
             'Batch ${entry.batch} already has a lecture (${l.displaySubject}) in this period.\n\nPlease choose another period.'
           );
        }
      }
    }

    await FirebaseFirestore.instance
        .collection('timetables')
        .doc(division)
        .collection(day)
        .doc(entry.id)
        .set(entry.toFirestore());

    await TimetableEventService.handleModification(
      division: division,
      day: day,
      oldEntry: oldEntry,
      newEntry: entry,
    );
  }

  // Helper method used by legacy code during migration to format time
  static String formatTime(int startTime, int endTime) {
    String formatMins(int mins) {
      final h = (mins ~/ 60) % 24;
      final m = mins % 60;
      final suffix = h >= 12 ? 'PM' : 'AM';
      final hour12 = h % 12 == 0 ? 12 : h % 12;
      return '$hour12:${m.toString().padLeft(2, '0')} $suffix';
    }
    return '${formatMins(startTime)} - ${formatMins(endTime)}';
  }

  static int parseTime(String t) {
    final isPM = t.toLowerCase().contains('pm');
    final isAM = t.toLowerCase().contains('am');
    final match = RegExp(r'(\d+)\s*:\s*(\d+)').firstMatch(t);
    int h = 0, m = 0;
    if (match != null) {
      h = int.tryParse(match.group(1)!) ?? 0;
      m = int.tryParse(match.group(2)!) ?? 0;
    } else {
      final hMatch = RegExp(r'\d+').firstMatch(t);
      if (hMatch != null) {
        h = int.tryParse(hMatch.group(0)!) ?? 0;
      }
    }
    if (isPM && h < 12) h += 12;
    if (isAM && h == 12) h = 0;
    if (!isPM && !isAM && h >= 1 && h <= 7) h += 12;
    return h * 60 + m;
  }

  static int computeDurationHours(String timeString) {
    try {
      final parts = timeString.split('-');
      if (parts.length != 2) return 1;
      final start = parseTime(parts[0].trim());
      final end = parseTime(parts[1].trim());
      int diffMins = end - start;
      if (diffMins < 0) diffMins += 24 * 60;
      return (diffMins / 60).round();
    } catch (e) {
      return 1;
    }
  }

  static Future<List<TimetableEntry>> getEntriesForDay({required String division, required String day}) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('timetables')
        .doc(division)
        .collection(day)
        .get();
        
    final entries = snapshot.docs
        .map((doc) => TimetableEntry.fromFirestore(doc))
        .toList();
        
    entries.sort((a, b) => a.startTime.compareTo(b.startTime));
    return entries;
  }

  static Future<List<String>> getUniqueSubjects({required String division}) async {
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    final unique = <String>{};
    for (final day in days) {
      final entries = await getEntriesForDay(division: division, day: day);
      for (final e in entries) {
        if (e.category == EventCategory.academic) {
          unique.add(e.displaySubject);
        }
      }
    }
    return unique.toList()..sort();
  }

  static Future<int> getSubjectRequiredDuration({required String division, required String subject}) async {
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    int maxDuration = 60; // default 1 hour
    for (final day in days) {
      final entries = await getEntriesForDay(division: division, day: day);
      for (final e in entries) {
        if ((e.displaySubject == subject || e.subject == subject) && e.durationMinutes > maxDuration) {
          maxDuration = e.durationMinutes;
        }
      }
    }
    return maxDuration;
  }

  static Future<List<SrIdentity>> getUniqueSrIdentities({required String division}) async {
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    final Map<String, SrIdentity> uniqueMap = {};
    for (final day in days) {
      final entries = await getEntriesForDay(division: division, day: day);
      for (final e in entries) {
        if (e.category == EventCategory.academic) {
          final id = '${e.subject}_${e.component}_${e.batch}';
          uniqueMap[id] = SrIdentity(
            subject: e.subject,
            component: e.component,
            batch: e.batch,
          );
        }
      }
    }
    final list = uniqueMap.values.toList();
    list.sort((a, b) {
      int cmp = a.subject.compareTo(b.subject);
      if (cmp != 0) return cmp;
      cmp = a.component.compareTo(b.component);
      if (cmp != 0) return cmp;
      return a.batch.compareTo(b.batch);
    });
    return list;
  }
}

class SrIdentity {
  final String subject;
  final String component;
  final String batch;

  SrIdentity({
    required this.subject,
    required this.component,
    required this.batch,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SrIdentity &&
          runtimeType == other.runtimeType &&
          subject == other.subject &&
          component == other.component &&
          batch == other.batch;

  @override
  int get hashCode => subject.hashCode ^ component.hashCode ^ batch.hashCode;
}
