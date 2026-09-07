import 'package:flutter_test/flutter_test.dart';
import 'package:schedly/models/attendance_import_models.dart';
import 'package:schedly/models/attendance_log.dart';
import 'package:schedly/models/attendance_record.dart';
import 'package:schedly/models/course_component.dart';
import 'package:schedly/models/event_category.dart';
import 'package:schedly/models/intelligence_models.dart';
import 'package:schedly/models/timetable_entry.dart';
import 'package:schedly/services/attendance/academic_grouping_policy.dart';
import 'package:schedly/services/attendance_course_matcher.dart';
import 'package:schedly/services/attendance_course_normalizer.dart';
import 'package:schedly/services/attendance_intelligence_service.dart';
import 'package:schedly/services/progress_calculator_service.dart';
import 'package:schedly/services/subject_identity_service.dart';

void main() {
  final testDate = DateTime(2026, 7, 13);

  CourseComponent makeComp({
    required String componentId,
    required String courseName,
    String courseCode = 'DSA',
    String componentType = 'Theory',
    int targetHours = 45,
    String sectionId = 'CE_C',
  }) {
    return CourseComponent(
      componentId: componentId,
      componentType: componentType,
      courseName: courseName,
      courseCode: courseCode,
      targetHours: targetHours,
      createdAt: testDate,
      sectionId: sectionId,
    );
  }

  group('SCHEDLY V11 — SURGICAL DSA FIX TESTS', () {
    final configuredDsa = [
      makeComp(
        componentId: 'DSA_Theory',
        courseName: 'Data Structures and Algorithms',
        courseCode: 'DSA',
        componentType: 'Theory',
        targetHours: 45,
      ),
      makeComp(
        componentId: 'DSA_Lab',
        courseName: 'Data Structures and Algorithms',
        courseCode: 'DSA',
        componentType: 'Lab',
        targetHours: 30,
      ),
    ];

    test('Fix 1 — PDF Parsing & Matching: Strictly distinguishes DSA Theory vs DSA Lab', () {
      final matcher = AttendanceCourseMatcher(configuredDsa);

      // Theory variants
      final theoryVariants = [
        'DSA T4',
        'DATA STRUCTURES AND ALGORITHMS T4',
        'DATA STRUCTURES & ALGORITHMS T4',
        'Data Structures and Algorithms',
        'DSA',
      ];

      for (final variant in theoryVariants) {
        final norm = AttendanceCourseNormalizer.normalize(variant);
        expect(
          norm.componentType,
          equals('Theory'),
          reason: '$variant should normalize to Theory component',
        );

        final matchResult = matcher.match(
          courseName: norm.courseName,
          componentType: norm.componentType,
          rawCourseName: variant,
        );
        expect(
          matchResult.component.toLowerCase(),
          equals('theory'),
          reason: '$variant must match DSA Theory component',
        );

        final groupKey = AcademicGroupingPolicy.canonicalGroupKey(
          matchResult.subjectCode,
          matchResult.component,
          configuredCourses: configuredDsa,
          sectionSplitSubjects: {'DSA', 'DATA STRUCTURES AND ALGORITHMS'},
        );
        expect(groupKey, equals('DSA_Theory'));
      }

      // Lab variants
      final labVariants = [
        'DSA P4',
        'DSA LAB P4',
        'DATA STRUCTURES AND ALGORITHMS LAB P4',
        'DATA STRUCTURES & ALGORITHMS LAB P4',
        'Data Structures and Algorithms Lab',
        'DSA LAB',
        'DSA Lab',
      ];

      for (final variant in labVariants) {
        final norm = AttendanceCourseNormalizer.normalize(variant);
        expect(
          norm.componentType,
          equals('Lab'),
          reason: '$variant should normalize to Lab component',
        );

        final matchResult = matcher.match(
          courseName: norm.courseName,
          componentType: norm.componentType,
          rawCourseName: variant,
        );
        expect(
          matchResult.component.toLowerCase(),
          equals('lab'),
          reason: '$variant must match DSA Lab component',
        );

        final groupKey = AcademicGroupingPolicy.canonicalGroupKey(
          matchResult.subjectCode,
          matchResult.component,
          configuredCourses: configuredDsa,
          sectionSplitSubjects: {'DSA', 'DATA STRUCTURES AND ALGORITHMS'},
        );
        expect(groupKey, equals('DSA_Lab'));
      }
    });

    test('Fix 2 — Attendance Aggregation: DSA Theory and DSA Lab are independent and never merged', () {
      final logs = [
        // 3 DSA Theory lectures: 2 present, 1 absent
        AttendanceLog(
          id: 'l1',
          subjectCode: 'DSA',
          component: 'Theory',
          rawSubjectText: 'DSA T4',
          date: DateTime(2026, 8, 1, 9, 0),
          confidence: MatchConfidence.exact,
          status: 'present',
          source: 'pdf',
        ),
        AttendanceLog(
          id: 'l2',
          subjectCode: 'DSA',
          component: 'Theory',
          rawSubjectText: 'DSA T4',
          date: DateTime(2026, 8, 2, 9, 0),
          confidence: MatchConfidence.exact,
          status: 'present',
          source: 'pdf',
        ),
        AttendanceLog(
          id: 'l3',
          subjectCode: 'DSA',
          component: 'Theory',
          rawSubjectText: 'DSA T4',
          date: DateTime(2026, 8, 3, 9, 0),
          confidence: MatchConfidence.exact,
          status: 'absent',
          source: 'pdf',
        ),

        // 2 DSA Lab sessions: 1 present, 1 absent
        AttendanceLog(
          id: 'l4',
          subjectCode: 'DSA',
          component: 'Lab',
          rawSubjectText: 'DSA LAB P4',
          date: DateTime(2026, 8, 4, 11, 0),
          confidence: MatchConfidence.exact,
          status: 'present',
          source: 'pdf',
        ),
        AttendanceLog(
          id: 'l5',
          subjectCode: 'DSA',
          component: 'Lab',
          rawSubjectText: 'DSA LAB P4',
          date: DateTime(2026, 8, 5, 11, 0),
          confidence: MatchConfidence.exact,
          status: 'absent',
          source: 'pdf',
        ),
      ];

      final aggregated = <String, ({int present, int absent})>{};

      for (final log in logs) {
        final canonSubj = AttendanceLog.canonicalSubjectCode(log.subjectCode);
        final groupKey = AttendanceLog.canonicalGroupKey(canonSubj, log.component);

        final cur = aggregated[groupKey] ?? (present: 0, absent: 0);
        int p = cur.present;
        int a = cur.absent;
        if (log.status == 'present') p++;
        if (log.status == 'absent') a++;
        aggregated[groupKey] = (present: p, absent: a);
      }

      expect(aggregated.keys.toSet(), equals({'DSA_Theory', 'DSA_Lab'}));

      // Verify no cross-contamination
      expect(aggregated['DSA_Theory']!.present, equals(2));
      expect(aggregated['DSA_Theory']!.absent, equals(1));

      expect(aggregated['DSA_Lab']!.present, equals(1));
      expect(aggregated['DSA_Lab']!.absent, equals(1));
    });

    test('Fix 3 — Smart Recommendations: Evaluates DSA Theory and DSA Lab independently', () {
      final entries = [
        TimetableEntry(
          id: 't1',
          subject: 'DSA',
          component: 'Theory',
          category: EventCategory.academic,
          batch: 'Whole Class',
          startTime: 540,
          endTime: 660,
          durationMinutes: 120,
        ),
        TimetableEntry(
          id: 't2',
          subject: 'DSA',
          component: 'Lab',
          category: EventCategory.academic,
          batch: 'C1',
          startTime: 675,
          endTime: 795,
          durationMinutes: 120,
        ),
      ];

      final records = [
        // DSA Theory has 96% attendance (comfortableMargin)
        AttendanceRecord(
          id: 'CE_C_DSA_Theory',
          division: 'CE_C',
          subjectCode: 'DSA',
          component: 'Theory',
          present: 24,
          absent: 1, // 24/25 = 96%
        ),
        // DSA Lab has 60% attendance (critically low -> mustAttend)
        AttendanceRecord(
          id: 'CE_C_DSA_Lab',
          division: 'CE_C',
          subjectCode: 'DSA',
          component: 'Lab',
          present: 6,
          absent: 4, // 6/10 = 60%
        ),
      ];

      final recs = AttendanceIntelligenceService.generateTodayRecommendations(
        entries,
        records,
      );

      expect(recs.length, equals(2));

      final theoryRec = recs.firstWhere((r) => r.component == 'Theory');
      final labRec = recs.firstWhere((r) => r.component == 'Lab');

      expect(theoryRec.level, equals(RecommendationLevel.comfortableMargin));
      expect(labRec.level, equals(RecommendationLevel.mustAttend));
      expect(labRec.priority, lessThan(theoryRec.priority)); // Higher priority (1 vs 5)
    });

    test('Fix 4 — Course Hours: Resolves targetHours dynamically (45h Theory, 30h Lab)', () {
      final calc = ProgressCalculatorService(
        weeklyTimetable: {},
        semesterStartDate: DateTime(2026, 7, 13),
        subjectMetadata: {},
        courseComponents: configuredDsa,
      );

      final theoryHours = calc.getConfiguredCourseHours('DSA', 'Theory');
      final labHours = calc.getConfiguredCourseHours('DSA', 'Lab');

      expect(theoryHours, equals(45));
      expect(labHours, equals(30));

      // Remaining lectures with 25 conducted theory and 12 conducted lab
      final remainingTheory = calc.getRemainingLectures('DSA', 'Theory', 25);
      final remainingLab = calc.getRemainingLectures('DSA', 'Lab', 12);

      expect(remainingTheory, equals(20)); // 45 - 25 = 20
      expect(remainingLab, equals(18)); // 30 - 12 = 18
    });
  });
}
