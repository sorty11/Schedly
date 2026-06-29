import 'package:cloud_firestore/cloud_firestore.dart';

import 'system_update_manager.dart';
import 'services/app_notification_service.dart';
import 'models/timetable_entry.dart';
import 'models/event_category.dart';

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
  }) async {
    // We do NOT block overlapping batches anymore, because C1 and C2 can share the same time.
    // However, if the exact same batch has the exact same time, we block it.
    final existing = await FirebaseFirestore.instance
        .collection('timetables')
        .doc(division)
        .collection(day)
        .where('startTime', isEqualTo: entry.startTime)
        .where('batch', isEqualTo: entry.batch)
        .where('isActive', isEqualTo: true)
        .get();

    if (existing.docs.isNotEmpty) {
      throw Exception('This batch already has an active lecture at this time.');
    }

    await FirebaseFirestore.instance
        .collection('timetables')
        .doc(division)
        .collection(day)
        .doc(entry.id)
        .set(entry.toFirestore());

    SystemUpdateManager.addUpdate(
      title: 'Lecture Added',
      description: '${entry.subject} added on $day for ${entry.batch}',
      type: 'add',
    );

    await AppNotificationService.createNotification(
      title: 'Lecture Added',
      message: '${entry.subject} added on $day for ${entry.batch}',
      division: division,
      type: 'add',
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
        .where((e) => e.isActive)
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
