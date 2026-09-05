import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/timetable_entry.dart';
import '../models/course_component.dart';
import '../models/attendance_log.dart';
import 'course_configuration_service.dart';
import 'subject_identity_service.dart';

import '../app_settings.dart';
import '../user_roles.dart';

class ProgressCalculatorService {
  final Map<int, List<TimetableEntry>> weeklyTimetable;
  final DateTime semesterStartDate;
  final Map<String, CourseComponent> subjectMetadata;
  final List<CourseComponent> courseComponents;

  ProgressCalculatorService({
    required this.weeklyTimetable,
    required this.semesterStartDate,
    required this.subjectMetadata,
    this.courseComponents = const [],
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

    // 3. Fetch course components (subject config from Course Details)
    List<CourseComponent> courseComponents = [];
    try {
      courseComponents = await CourseConfigurationService.getMetadata(division);
    } catch (e) {
      debugPrint(
        'ProgressCalculatorService: Error fetching from CourseConfigurationService: $e',
      );
    }

    if (courseComponents.isEmpty) {
      try {
        final metaSnap = await db
            .collection('sections')
            .doc(division)
            .collection('subjects')
            .get();
        courseComponents = metaSnap.docs
            .map((d) => CourseComponent.fromFirestore(d))
            .toList();
      } catch (e) {
        debugPrint('ProgressCalculatorService: Error fetching subjects: $e');
      }
    }

    final subjectMetadata = <String, CourseComponent>{};
    for (var comp in courseComponents) {
      subjectMetadata[comp.componentId] = comp;
      if (comp.courseName.isNotEmpty) {
        subjectMetadata.putIfAbsent(comp.courseName, () => comp);
      }
    }

    return ProgressCalculatorService(
      weeklyTimetable: weeklyTimetable,
      semesterStartDate: semesterStartDate,
      subjectMetadata: subjectMetadata,
      courseComponents: courseComponents,
    );
  }

  static bool _eq(String a, String b) =>
      a.trim().toUpperCase() == b.trim().toUpperCase();

  /// Returns the authoritative configured course hours from Course Details
  /// (`sections/{division}/subjects/{componentId}.targetHours` with `totalHours` fallback).
  ///
  /// Returns null if the course hours are not configured or <= 0.
  /// Does NOT estimate from weekly timetable.
  int? getConfiguredCourseHours(String subjectCode, String component) {
    if (courseComponents.isEmpty && subjectMetadata.isEmpty) {
      return null;
    }

    final canonSubj = AttendanceLog.canonicalSubjectCode(subjectCode);
    final normComp = component.trim().toLowerCase();

    bool matchCourseName(CourseComponent c) {
      final compCanon = AttendanceLog.canonicalSubjectCode(c.courseName);
      final idCanon = AttendanceLog.canonicalSubjectCode(c.componentId);
      final codeCanon = c.courseCode.isNotEmpty
          ? AttendanceLog.canonicalSubjectCode(c.courseCode)
          : '';
      return _eq(compCanon, canonSubj) ||
          _eq(idCanon, canonSubj) ||
          (codeCanon.isNotEmpty && _eq(codeCanon, canonSubj)) ||
          _eq(c.courseName, subjectCode) ||
          _eq(c.componentId, subjectCode) ||
          (c.courseCode.isNotEmpty && _eq(c.courseCode, subjectCode)) ||
          SubjectIdentityService.isMatch(c.courseName, subjectCode, configuredCourses: courseComponents) ||
          SubjectIdentityService.isMatch(c.componentId, subjectCode, configuredCourses: courseComponents) ||
          (c.courseCode.isNotEmpty &&
              SubjectIdentityService.isMatch(c.courseCode, subjectCode, configuredCourses: courseComponents));
    }

    // 1. Specific component lookup (e.g. Theory or Lab for split courses like DSA)
    if (normComp != 'merged' && normComp != 'all' && normComp.isNotEmpty) {
      for (final comp in courseComponents) {
        if (matchCourseName(comp)) {
          final type = comp.componentType.toLowerCase();
          final matchesType =
              type == normComp ||
              (normComp.contains('lab') && comp.isLab) ||
              (normComp.contains('theory') &&
                  (type == 'theory' || type == 'lecture'));
          if (matchesType && comp.targetHours > 0) {
            return comp.targetHours;
          }
        }
      }
    }

    // 2. Merged or course-level lookup: Sum all components of this course
    final matchingComps = courseComponents.where(matchCourseName).toList();
    if (matchingComps.isNotEmpty) {
      final sum = matchingComps.fold<int>(0, (acc, c) => acc + c.targetHours);
      if (sum > 0) return sum;
    }

    // 3. Fallback to direct key lookup in subjectMetadata
    final direct =
        subjectMetadata[subjectCode] ??
        subjectMetadata[canonSubj] ??
        subjectMetadata['$subjectCode $component'] ??
        subjectMetadata['${canonSubj}_$component'];
    if (direct != null && direct.targetHours > 0) {
      return direct.targetHours;
    }

    return null;
  }

  /// Returns the remaining lectures in the semester for the given subject and component:
  /// (configured semester assigned hours) - (completed lecture occurrences).
  ///
  /// Clamped at 0 (never negative).
  /// Returns null if configured semester assigned hours are not available or <= 0.
  int? getRemainingLectures(
    String subjectCode,
    String component,
    int conductedLectures,
  ) {
    final assignedHours = getConfiguredCourseHours(subjectCode, component);
    if (assignedHours == null || assignedHours <= 0) {
      return null;
    }
    final remaining = assignedHours - conductedLectures;
    return remaining < 0 ? 0 : remaining;
  }

  /// Returns the fixed total course hours for the semester from Course Details configuration.
  /// Falls back to estimating from the weekly timetable only if Course Details is unconfigured.
  int getFixedTotalCourseHours(String subjectCode, String component) {
    final configured = getConfiguredCourseHours(subjectCode, component);
    if (configured != null && configured > 0) {
      return configured;
    }

    // Fallback to timetable estimation if Course Details is unconfigured
    return _getEstimatedTimetableHours(subjectCode, component);
  }

  /// Calculates maximum remaining skips/missable hours for a course in the semester.
  ///
  /// Formula:
  /// allowedAbsenceHours = (totalCourseHours * (1 - requiredAttendance)).floor()
  /// remainingSkipHours = max(0, allowedAbsenceHours - absentHours)
  static int calculateSkips({
    required int totalCourseHours,
    required int absentHours,
    double requiredAttendance = 0.80,
  }) {
    if (totalCourseHours <= 0) return 0;
    final double allowedAbsenceExact =
        totalCourseHours * (1.0 - requiredAttendance);
    final int allowedAbsenceHours = (allowedAbsenceExact + 1e-9).floor();
    final int remaining = allowedAbsenceHours - absentHours;
    return remaining < 0 ? 0 : remaining;
  }

  /// Convenience method to compute remaining skips for a given subject & component.
  int getRemainingSkips(
    String subjectCode,
    String component,
    int absentHours, {
    double requiredAttendance = 0.80,
  }) {
    final totalHours = getFixedTotalCourseHours(subjectCode, component);
    return calculateSkips(
      totalCourseHours: totalHours,
      absentHours: absentHours,
      requiredAttendance: requiredAttendance,
    );
  }

  int getExpectedConductedHours(String subjectCode, String component) {
    int totalScheduledHours = 0;
    DateTime now = DateTime.now();
    DateTime current = semesterStartDate;

    final normTargetComp = AttendanceLog.normalizeComponent(component);
    final isDsa = AttendanceLog.isDsa(subjectCode);

    // Loop day-by-day from startDate to now
    while (current.isBefore(now)) {
      int weekday = current.weekday;
      if (weeklyTimetable.containsKey(weekday)) {
        for (var entry in weeklyTimetable[weekday]!) {
          final isSubjMatch = SubjectIdentityService.isMatch(
            entry.subject,
            subjectCode,
            configuredCourses: courseComponents,
          );
          if (!isSubjMatch) continue;

          if (isDsa) {
            final entryNormComp =
                AttendanceLog.normalizeComponent(entry.component);
            if (entryNormComp == normTargetComp) {
              totalScheduledHours += (entry.durationMinutes / 60).round();
            }
          } else {
            // Merged subject accumulates all components
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
    if (subjectMetadata.containsKey(compositeKey)) {
      return subjectMetadata[compositeKey]!.cancelledHours;
    }
    if (subjectMetadata.containsKey(subjectCode)) {
      return subjectMetadata[subjectCode]!.cancelledHours;
    }

    final canonSubj = AttendanceLog.canonicalSubjectCode(subjectCode);
    if (subjectMetadata.containsKey(canonSubj)) {
      return subjectMetadata[canonSubj]!.cancelledHours;
    }

    for (final comp in courseComponents) {
      if (SubjectIdentityService.isMatch(
            comp.courseName,
            subjectCode,
            configuredCourses: courseComponents,
          ) ||
          SubjectIdentityService.isMatch(
            comp.componentId,
            subjectCode,
            configuredCourses: courseComponents,
          )) {
        return comp.cancelledHours;
      }
    }
    return 0;
  }

  int getConductedClasses(String subjectCode, String component) {
    return getExpectedConductedHours(subjectCode, component) -
        getCancelledHours(subjectCode, component);
  }

  /// Returns total projected hours. Uses fixed Course Details hours if configured,
  /// otherwise falls back to estimating from the weekly timetable.
  int getTotalProjectedHours(String subjectCode, String component) {
    final fixedHours = getFixedTotalCourseHours(subjectCode, component);
    if (fixedHours > 0) return fixedHours;
    return _getEstimatedTimetableHours(subjectCode, component);
  }

  int _getEstimatedTimetableHours(String subjectCode, String component) {
    int wholeClassHours = 0;
    // Structure: { 'Lab': {'C1': 2, 'C2': 2}, 'Tutorial': {'T1': 1, 'T2': 1} }
    Map<String, Map<String, int>> splitComponentHours = {};

    final normTargetComp = AttendanceLog.normalizeComponent(component);
    final isDsa = AttendanceLog.isDsa(subjectCode);

    for (var dayEntries in weeklyTimetable.values) {
      for (var entry in dayEntries) {
        String entrySubj = entry.subject;
        String entryComp = entry.component;

        final isSubjMatch = SubjectIdentityService.isMatch(
          entrySubj,
          subjectCode,
          configuredCourses: courseComponents,
        );
        if (!isSubjMatch) continue;

        // Determine if we should process this entry based on split/merged rules
        bool isMatch = false;

        if (!isDsa ||
            component == 'Merged' ||
            component == 'All' ||
            component.isEmpty) {
          // Merged Subject -> Match by subject name only, grab all components
          isMatch = true;
        } else {
          // Split Subject (DSA) -> Must match BOTH subject and specific component
          final normEntryComp = AttendanceLog.normalizeComponent(entryComp);
          isMatch = (normEntryComp == normTargetComp);
        }

        if (isMatch) {
          int hours = (entry.durationMinutes / 60).round();
          String batch = entry.batch.isEmpty ? "Whole Class" : entry.batch;

          String comp = AttendanceLog.normalizeComponent(entryComp);

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
