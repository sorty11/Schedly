import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/timetable_entry.dart';
import '../models/course_component.dart';

import '../app_settings.dart';
import '../user_roles.dart';

class ProgressCalculatorService {
  final Map<int, List<TimetableEntry>> weeklyTimetable;
  final DateTime semesterStartDate;
  final Map<String, CourseComponent> subjectMetadata;

  ProgressCalculatorService({
    required this.weeklyTimetable,
    required this.semesterStartDate,
    required this.subjectMetadata,
  });

  static Future<ProgressCalculatorService?> build(String division) async {
    final db = FirebaseFirestore.instance;

    // 1. Get semester start date
    final sectionDoc = await db.collection('sections').doc(division).get();
    DateTime semesterStartDate = DateTime(2026, 7, 13); // Fallback date

    if (sectionDoc.exists) {
      final sectionData = sectionDoc.data()!;
      if (sectionData['semesterStartDate'] != null) {
        semesterStartDate = (sectionData['semesterStartDate'] as Timestamp)
            .toDate();
      }
    }

    // 2. Fetch weekly timetable
    final weeklyTimetable = <int, List<TimetableEntry>>{};
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
    for (int i = 0; i < days.length; i++) {
      final snap = await db
          .collection('timetables')
          .doc(division)
          .collection(days[i])
          .where('isActive', isEqualTo: true)
          .get();
      weeklyTimetable[i + 1] = snap.docs
          .map((d) => TimetableEntry.fromFirestore(d))
          .where((e) {
            if (AppSettings.currentRole == UserRole.student) {
              return e.shouldIncludeForUserBatch(AppSettings.studentBatch);
            }
            return true;
          })
          .toList();
    }

    // 3. Fetch course components (subject config)
    final metaSnap = await db
        .collection('sections')
        .doc(division)
        .collection('subject_metadata')
        .get();
    final subjectMetadata = <String, CourseComponent>{};
    for (var doc in metaSnap.docs) {
      final comp = CourseComponent.fromFirestore(doc);
      // Map using the composite key since components are stored per subject-component type
      subjectMetadata[comp.subjectName] = comp;
    }

    return ProgressCalculatorService(
      weeklyTimetable: weeklyTimetable,
      semesterStartDate: semesterStartDate,
      subjectMetadata: subjectMetadata,
    );
  }

  int getExpectedConductedHours(String subjectCode, String component) {
    int totalScheduledHours = 0;
    DateTime now = DateTime.now();
    DateTime current = semesterStartDate;

    // Loop day-by-day from startDate to now
    while (current.isBefore(now)) {
      int weekday = current.weekday;
      if (weeklyTimetable.containsKey(weekday)) {
        for (var entry in weeklyTimetable[weekday]!) {
          if (entry.subject == subjectCode && entry.component == component) {
            totalScheduledHours += (entry.durationMinutes / 60).round();
          }
        }
      }
      current = current.add(const Duration(days: 1));
    }
    return totalScheduledHours;
  }

  int getCancelledHours(String subjectCode, String component) {
    // Subject names in course_component are sometimes stored as composite like 'SnS Theory'
    final compositeKey = '$subjectCode $component'.trim();
    // Try composite key first, then fallback to base subject code if needed
    final comp = subjectMetadata[compositeKey] ?? subjectMetadata[subjectCode];
    return comp?.cancelledHours ?? 0;
  }

  int getConductedClasses(String subjectCode, String component) {
    return getExpectedConductedHours(subjectCode, component) -
        getCancelledHours(subjectCode, component);
  }

  int getTotalProjectedHours(String subjectCode, String component) {
    int wholeClassHours = 0;
    // Structure: { 'Lab': {'C1': 2, 'C2': 2}, 'Tutorial': {'T1': 1, 'T2': 1} }
    Map<String, Map<String, int>> splitComponentHours = {};

    for (var dayEntries in weeklyTimetable.values) {
      for (var entry in dayEntries) {
        String entrySubj = entry.subject;
        String entryComp = entry.component;

        // Force-normalize DSA variants
        if (entrySubj.toUpperCase().contains('DATA STRUCTURES') ||
            entrySubj.trim().toUpperCase() == 'DSA') {
          entrySubj = 'DSA';
          if (entryComp.toUpperCase().contains('LAB') ||
              entryComp.toUpperCase().contains('PRACTICAL')) {
            entryComp = 'Lab';
          } else {
            entryComp = 'Theory';
          }
        }

        // Determine if we should process this entry based on split/merged rules
        bool isMatch = false;

        if (component == 'Merged' || component == 'All' || component.isEmpty) {
          // Merged Subject -> Match by subject name only, grab all components
          isMatch = (entrySubj == subjectCode);
        } else {
          // Split Subject -> Must match BOTH subject and specific component
          String normEntryComp = entryComp;
          if (normEntryComp.isEmpty || normEntryComp == 'Lecture')
            normEntryComp = 'Theory';
          else if (normEntryComp == 'Practical')
            normEntryComp = 'Lab';

          String normTargetComp = component;
          if (normTargetComp.isEmpty || normTargetComp == 'Lecture')
            normTargetComp = 'Theory';
          else if (normTargetComp == 'Practical')
            normTargetComp = 'Lab';

          isMatch =
              (entrySubj == subjectCode && normEntryComp == normTargetComp);
        }

        if (isMatch) {
          int hours = (entry.durationMinutes / 60).round();
          String batch = entry.batch.isEmpty ? "Whole Class" : entry.batch;

          String comp = entryComp;
          if (comp.isEmpty || comp == 'Lecture')
            comp = 'Theory';
          else if (comp == 'Practical')
            comp = 'Lab';

          if (batch == "Whole Class") {
            // Everyone attends these (Theory)
            wholeClassHours += hours;
          } else {
            // Sub-batches (Labs/Tutorials). Track separately to find the max single-student requirement.
            splitComponentHours.putIfAbsent(comp, () => {});
            splitComponentHours[comp]![batch] =
                (splitComponentHours[comp]![batch] ?? 0) + hours;
          }
        }
      }
    }

    int totalSubBatchHours = 0;
    // For each split component (Lab, Tutorial, etc.), find the max hours any single batch takes, and add it.
    for (var compBatches in splitComponentHours.values) {
      if (compBatches.isNotEmpty) {
        totalSubBatchHours += compBatches.values.reduce(math.max);
      }
    }

    int totalWeeklyHours = wholeClassHours + totalSubBatchHours;
    return totalWeeklyHours * 15;
  }
}
