import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/timetable_entry.dart';
import '../models/course_component.dart';
import '../models/attendance_log.dart';
import '../models/attendance_record.dart';
import 'course_configuration_service.dart';
import 'subject_identity_service.dart';

import '../app_settings.dart';
import '../user_roles.dart';

/// Authoritative result of Smart Attendance calculations for a course / lecture slot.
class SmartAttendanceRecommendation {
  /// Current attendance percentage (0.0 - 100.0). Excludes NU from denominator.
  final double currentPct;

  /// Projected attendance percentage if the student attends this lecture/unit.
  final double ifAttendPct;

  /// Projected attendance percentage if the student skips this lecture/unit.
  final double ifSkipPct;

  /// Whether the student can safely skip this next lecture (projectedIfSkip >= requiredThreshold).
  final bool canSkipNext;

  /// Remaining missable/skip lecture sessions in the semester without falling below threshold:
  /// floor(remainingSkipHours / sessionDurationHours).
  final int skipsLeft;

  /// Remaining missable/skip academic hours in the semester without falling below threshold:
  /// floor(totalAssignedCourseHours * (1.0 - threshold)) - currentAbsentHours (clamped >= 0).
  final int? skipsLeftHours;

  /// Exact remaining lecture sessions in the semester:
  /// ceil( (assignedCourseHours - completedHours) / sessionDurationHours ).
  final int? remainingLectures;

  /// Exact remaining academic hours in the semester: max(0, assignedHours - completedHours).
  final int? remainingHours;

  /// Authoritative configured course hours from Course Details (targetHours/totalHours).
  final int? assignedHours;

  /// The unit size in hours (or 1 for occurrence-based subjects) of the evaluated lecture slot.
  final int lectureUnit;

  /// The effective required attendance threshold for this subject/section (e.g. 0.80 or 0.70).
  final double requiredThreshold;

  const SmartAttendanceRecommendation({
    required this.currentPct,
    required this.ifAttendPct,
    required this.ifSkipPct,
    required this.canSkipNext,
    required this.skipsLeft,
    this.skipsLeftHours,
    required this.remainingLectures,
    this.remainingHours,
    required this.assignedHours,
    required this.lectureUnit,
    required this.requiredThreshold,
  });
}

class ProgressCalculatorService {
  final Map<int, List<TimetableEntry>> weeklyTimetable;
  final DateTime semesterStartDate;
  final Map<String, CourseComponent> subjectMetadata;
  final List<CourseComponent> courseComponents;
  final double requiredAttendance;

  ProgressCalculatorService({
    required this.weeklyTimetable,
    required this.semesterStartDate,
    required this.subjectMetadata,
    this.courseComponents = const [],
    this.requiredAttendance = 0.80,
  });

  static final Map<String, ({ProgressCalculatorService calc, DateTime timestamp})> _cachedInstances = {};

  static String _cacheKey(String division) =>
      '$division|${AppSettings.studentBatch ?? "ALL"}|${AppSettings.currentRole.name}';

  static void invalidateCache([String? division]) {
    if (division != null) {
      _cachedInstances.removeWhere(
        (key, _) => key.startsWith('$division|') || key == division,
      );
    } else {
      _cachedInstances.clear();
    }
  }

  static Future<ProgressCalculatorService?> build(String division, {bool forceRefresh = false}) async {
    final now = DateTime.now();
    final cacheKey = _cacheKey(division);
    if (!forceRefresh && _cachedInstances.containsKey(cacheKey)) {
      final entry = _cachedInstances[cacheKey]!;
      if (now.difference(entry.timestamp) < const Duration(minutes: 5)) {
        return entry.calc;
      }
    }

    final db = FirebaseFirestore.instance;
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];

    // Parallelize all independent queries: section metadata, 5-day timetables, and course metadata
    final results = await Future.wait([
      db.collection('sections').doc(division).get(),
      Future.wait(
        days.map(
          (day) => db
              .collection('timetables')
              .doc(division)
              .collection(day)
              .where('isActive', isEqualTo: true)
              .get(),
        ),
      ),
      CourseConfigurationService.getMetadata(division).catchError((e) {
        debugPrint(
          'ProgressCalculatorService: Error fetching from CourseConfigurationService: $e',
        );
        return <CourseComponent>[];
      }),
    ]);

    // 1. Get semester start date & attendance threshold
    final sectionDoc = results[0] as DocumentSnapshot<Map<String, dynamic>>;
    DateTime semesterStartDate = DateTime(2026, 7, 13); // Fallback date
    double requiredAttendance = division.toUpperCase().startsWith('SOL_') ? 0.70 : 0.80;

    if (sectionDoc.exists) {
      final sectionData = sectionDoc.data()!;
      if (sectionData['semesterStartDate'] != null) {
        semesterStartDate = (sectionData['semesterStartDate'] as Timestamp)
            .toDate();
      }
      if (sectionData['attendanceThreshold'] != null) {
        requiredAttendance =
            (sectionData['attendanceThreshold'] as num).toDouble();
      } else if (sectionData['requiredAttendance'] != null) {
        requiredAttendance =
            (sectionData['requiredAttendance'] as num).toDouble();
      }
    }

    // 2. Build weekly timetable from parallel day snapshots
    final weeklyTimetable = <int, List<TimetableEntry>>{};
    final daySnaps = results[1] as List<QuerySnapshot<Map<String, dynamic>>>;
    for (int i = 0; i < daySnaps.length; i++) {
      weeklyTimetable[i + 1] = daySnaps[i].docs
          .map((d) => TimetableEntry.fromFirestore(d))
          .where((e) {
            if (AppSettings.currentRole == UserRole.student) {
              return e.shouldIncludeForUserBatch(AppSettings.studentBatch);
            }
            return true;
          })
          .toList();
    }

    // 3. Course components (subject config from Course Details)
    List<CourseComponent> courseComponents = results[2] as List<CourseComponent>;

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

    final instance = ProgressCalculatorService(
      weeklyTimetable: weeklyTimetable,
      semesterStartDate: semesterStartDate,
      subjectMetadata: subjectMetadata,
      courseComponents: courseComponents,
      requiredAttendance: requiredAttendance,
    );
    _cachedInstances[cacheKey] = (calc: instance, timestamp: now);
    return instance;
  }

  static bool _eq(String a, String b) =>
      a.trim().toUpperCase() == b.trim().toUpperCase();

  /// Returns the authoritative configured course hours from Course Details
  /// (`sections/{division}/subjects/{componentId}.targetHours` with `totalHours` fallback).
  ///
  /// Returns null if the course hours are not configured or <= 0.
  /// Does NOT estimate from weekly timetable.
  int? getConfiguredCourseHours(String subjectCode, String component) {
    final bool isSol = courseComponents.any((c) => c.sectionId.toUpperCase().startsWith('SOL_')) ||
        subjectMetadata.values.any((c) => c.sectionId.toUpperCase().startsWith('SOL_')) ||
        SubjectIdentityService.isSolSubject(subjectCode);

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

    // 4. Dedicated STME DSA fallback ONLY when unconfigured in Course Details:
    // STME DSA Theory = 45 hrs, STME DSA Lab = 30 hrs.
    if (!isSol) {
      final upperSubj = subjectCode.trim().toUpperCase();
      final isDsa = upperSubj == 'DSA' ||
          upperSubj == 'DSA_THEORY' ||
          upperSubj == 'DSA_LAB' ||
          upperSubj.contains('DATA STRUCTURE') ||
          AttendanceLog.isDsa(subjectCode) ||
          SubjectIdentityService.isMatch(subjectCode, 'DSA');

      if (isDsa) {
        final isLab = normComp.contains('lab') ||
            normComp.contains('practical') ||
            normComp == 'p4' ||
            upperSubj.contains('LAB');
        return isLab ? 30 : 45;
      }
    }

    return null;
  }

  /// Returns the remaining lecture sessions in the semester for the given subject and component:
  /// ceil( (assignedHours - completedHours) / sessionDurationHours ).
  ///
  /// Clamped at 0 (never negative).
  /// Returns null if configured semester assigned hours are not available or <= 0.
  int? getRemainingLectures(
    String subjectCode,
    String component,
    int conductedLectures, {
    int? conductedHours,
    int sessionDurationHours = 1,
  }) {
    final assignedHours = getConfiguredCourseHours(subjectCode, component);
    if (assignedHours == null || assignedHours <= 0) {
      return null;
    }
    final unit = sessionDurationHours > 0 ? sessionDurationHours : 1;
    final effectiveConductedHours = conductedHours ?? (conductedLectures * unit);
    final remainingHours = assignedHours - effectiveConductedHours;
    if (remainingHours <= 0) return 0;
    return (remainingHours / unit).ceil();
  }

  /// Returns the remaining academic hours in the semester:
  /// max(0, assignedHours - conductedHours).
  int? getRemainingHours(
    String subjectCode,
    String component,
    int conductedHours,
  ) {
    final assignedHours = getConfiguredCourseHours(subjectCode, component);
    if (assignedHours == null || assignedHours <= 0) {
      return null;
    }
    final remaining = assignedHours - conductedHours;
    return remaining < 0 ? 0 : remaining;
  }

  /// Returns the fixed total course hours for the semester from Course Details configuration.
  /// Returns 0 if unconfigured (never estimates from timetable).
  int getFixedTotalCourseHours(String subjectCode, String component) {
    final configured = getConfiguredCourseHours(subjectCode, component);
    if (configured != null && configured > 0) {
      return configured;
    }

    return 0;
  }

  /// Calculates maximum remaining skips/missable sessions for a course in the semester.
  ///
  /// Formula:
  /// allowedAbsenceHours = floor(totalCourseHours * (1 - requiredAttendance))
  /// remainingSkipHours = max(0, allowedAbsenceHours - absentHours)
  /// remainingSkipSessions = floor(remainingSkipHours / sessionDurationHours)
  static int calculateSkips({
    required int totalCourseHours,
    required int absentHours,
    int sessionDurationHours = 1,
    double requiredAttendance = 0.80,
  }) {
    return calculateSkipBudget(
      totalCourseHours: totalCourseHours,
      absentHours: absentHours,
      sessionDurationHours: sessionDurationHours,
      requiredAttendance: requiredAttendance,
    ).remainingSessions;
  }

  /// Calculates detailed remaining skip budget in both academic hours and lecture sessions.
  static ({int remainingHours, int remainingSessions}) calculateSkipBudget({
    required int totalCourseHours,
    required int absentHours,
    int sessionDurationHours = 1,
    double requiredAttendance = 0.80,
  }) {
    if (totalCourseHours <= 0) return (remainingHours: 0, remainingSessions: 0);
    final double allowedAbsenceExact =
        totalCourseHours * (1.0 - requiredAttendance);
    final int allowedAbsenceHours = (allowedAbsenceExact + 1e-9).floor();
    final int remaining = allowedAbsenceHours - absentHours;
    final int remHours = remaining < 0 ? 0 : remaining;
    final unit = sessionDurationHours > 0 ? sessionDurationHours : 1;
    final int remSessions = (remHours / unit).floor();
    return (
      remainingHours: remHours,
      remainingSessions: remSessions,
    );
  }

  /// Convenience method to compute remaining skips for a given subject & component.
  int getRemainingSkips(
    String subjectCode,
    String component,
    int absentHours, {
    int sessionDurationHours = 1,
    double requiredAttendance = 0.80,
  }) {
    final totalHours = getFixedTotalCourseHours(subjectCode, component);
    return calculateSkips(
      totalCourseHours: totalHours,
      absentHours: absentHours,
      sessionDurationHours: sessionDurationHours,
      requiredAttendance: requiredAttendance,
    );
  }

  /// Returns the effective attendance requirement for a subject/section.
  /// Defaults to 0.70 for SOL and section-configured requirement or 0.80.
  double getEffectiveThreshold(String subjectCode, {String? division}) {
    final bool isSol = (division != null && division.toUpperCase().startsWith('SOL_')) ||
        courseComponents.any((c) => c.sectionId.toUpperCase().startsWith('SOL_')) ||
        subjectMetadata.values.any((c) => c.sectionId.toUpperCase().startsWith('SOL_')) ||
        SubjectIdentityService.isSolSubject(subjectCode);
    if (isSol) return 0.70;
    return requiredAttendance;
  }

  /// Calculates the authoritative Smart Attendance Recommendation for a lecture/subject.
  ///
  /// Mathematical Specification:
  /// - Current Attendance: present / (present + absent) * 100 in academic hours (NU strictly excluded).
  /// - Can Skip (Semester Skip Budget):
  ///     allowedAbsenceHours = floor(totalAssignedCourseHours * (1.0 - threshold))
  ///     remainingSkipHours = max(0, allowedAbsenceHours - currentAbsentHours)
  ///     skipsLeft (sessions) = floor(remainingSkipHours / lectureUnit)
  /// - If You Skip:
  ///     projected = currentPresentHours / (currentTotalHours + nextUnitHours) * 100
  /// - If You Attend:
  ///     projected = (currentPresentHours + nextUnitHours) / (currentTotalHours + nextUnitHours) * 100
  /// - canSkipNext: projectedIfSkip >= (threshold * 100).
  /// - Remaining Lectures: ceil( max(0, assignedHours - completedHours) / lectureUnit ).
  SmartAttendanceRecommendation calculateSmartRecommendation({
    required AttendanceRecord record,
    TimetableEntry? entry,
    int? completedOccurrences,
    int? conductedHours,
    int? presentHours,
    int? absentHours,
    int? typicalSessionDurationHours,
    double? requiredAttendance,
  }) {
    final threshold = requiredAttendance ??
        getEffectiveThreshold(record.subjectCode, division: record.division);

    final int? assignedHours = getConfiguredCourseHours(
      record.subjectCode,
      record.component,
    );

    // 1. Determine lecture/hour unit corresponding to academic unit
    int lectureUnit = 1;
    if (entry != null) {
      final duration = entry.durationMinutes > 0
          ? entry.durationMinutes
          : (entry.endTime - entry.startTime);
      final hours = (duration / 60).round();
      lectureUnit = hours.clamp(1, 4);
    } else if (typicalSessionDurationHours != null && typicalSessionDurationHours > 0) {
      lectureUnit = typicalSessionDurationHours;
    } else {
      final normComp = AttendanceLog.normalizeComponent(record.component);
      lectureUnit = normComp == 'Lab' ? 2 : 1;
    }

    // 2. Unit-safe academic hours conversion: prefer hours over occurrences
    final int effPresentHours = presentHours ?? (record.present * lectureUnit);
    final int effAbsentHours = absentHours ?? (record.absent * lectureUnit);
    final int totalHours = effPresentHours + effAbsentHours;

    final double currentPct =
        totalHours == 0 ? 0.0 : (effPresentHours / totalHours) * 100.0;

    final double ifAttendPct;
    final double ifSkipPct;

    if (totalHours == 0) {
      ifAttendPct = 100.0;
      ifSkipPct = 0.0;
    } else {
      ifAttendPct =
          ((effPresentHours + lectureUnit) / (totalHours + lectureUnit)) * 100.0;
      ifSkipPct = (effPresentHours / (totalHours + lectureUnit)) * 100.0;
    }

    final double thresholdPct = threshold * 100.0;
    final bool canSkipNext = ifSkipPct >= (thresholdPct - 1e-9);

    final skipBudget = calculateSkipBudget(
      totalCourseHours: assignedHours ?? 0,
      absentHours: effAbsentHours,
      sessionDurationHours: lectureUnit,
      requiredAttendance: threshold,
    );

    final actualCompletedHours = conductedHours ??
        (completedOccurrences != null
            ? completedOccurrences * lectureUnit
            : totalHours);

    final int? remainingSessions = getRemainingLectures(
      record.subjectCode,
      record.component,
      completedOccurrences ?? record.total,
      conductedHours: actualCompletedHours,
      sessionDurationHours: lectureUnit,
    );

    final int? remainingHrs = getRemainingHours(
      record.subjectCode,
      record.component,
      actualCompletedHours,
    );

    return SmartAttendanceRecommendation(
      currentPct: currentPct,
      ifAttendPct: ifAttendPct,
      ifSkipPct: ifSkipPct,
      canSkipNext: canSkipNext,
      skipsLeft: skipBudget.remainingSessions,
      skipsLeftHours: skipBudget.remainingHours,
      remainingLectures: remainingSessions,
      remainingHours: remainingHrs,
      assignedHours: assignedHours,
      lectureUnit: lectureUnit,
      requiredThreshold: threshold,
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
