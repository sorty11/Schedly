import 'package:flutter_test/flutter_test.dart';
import 'package:schedly/data/course_aliases.dart';
import 'package:schedly/models/attendance_log.dart';
import 'package:schedly/models/course_component.dart';
import 'package:schedly/services/attendance_course_matcher.dart';
import 'package:schedly/services/attendance_course_normalizer.dart';
import 'package:schedly/services/attendance_status_mapper.dart';
import 'package:schedly/services/progress_calculator_service.dart';
import 'package:schedly/services/subject_identity_service.dart';

void main() {
  group('1. Python Attendance Pipeline Regression Tests', () {
    test('courseAliases maps Python variants to PROGRAMMING WITH PYTHON', () {
      expect(courseAliases['Python'], equals('PROGRAMMING WITH PYTHON'));
      expect(courseAliases['Python Programming'], equals('PROGRAMMING WITH PYTHON'));
      expect(courseAliases['Programming in Python'], equals('PROGRAMMING WITH PYTHON'));
    });

    test('SubjectIdentityService resolves all Python variations to canonical Python', () {
      final variants = [
        'Python',
        'PYTHON',
        'Programming with Python',
        'PROGRAMMING WITH PYTHON',
        'Python Programming',
        'PYTHON PROGRAMMING',
        'Programming in Python',
        'PROGRAMMING IN PYTHON',
        'Python Lab',
        'PYTHON LAB',
        'Python Theory',
        'PYTHON THEORY',
        'Programming with Python Lab',
        'PROGRAMMING WITH PYTHON LAB',
        'Programming with Python Theory',
        'PROGRAMMING WITH PYTHON THEORY',
      ];

      for (final variant in variants) {
        final key = SubjectIdentityService.getCanonicalKey(variant);
        expect(key, equals('Python'), reason: 'Failed for variant: "$variant"');

        final isMatch = SubjectIdentityService.isMatch(variant, 'Python');
        expect(isMatch, isTrue, reason: 'isMatch failed for variant: "$variant" with "Python"');

        final isMatchFull = SubjectIdentityService.isMatch(variant, 'Programming with Python');
        expect(isMatchFull, isTrue, reason: 'isMatch failed for variant: "$variant" with "Programming with Python"');
      }
    });

    test('AttendanceCourseMatcher resolves Python with configured section courses', () {
      final configured = [
        CourseComponent(
          componentId: 'Python_Theory',
          componentType: 'Theory',
          courseName: 'PROGRAMMING WITH PYTHON',
          courseCode: 'Python',
          targetHours: 45,
          createdAt: DateTime.now(),
          sectionId: 'STME_CE_A',
        ),
        CourseComponent(
          componentId: 'Python_Lab',
          componentType: 'Lab',
          courseName: 'PROGRAMMING WITH PYTHON',
          courseCode: 'Python',
          targetHours: 30,
          createdAt: DateTime.now(),
          sectionId: 'STME_CE_A',
        ),
      ];

      final matcher = AttendanceCourseMatcher(configured);

      final testCases = [
        (name: 'PROGRAMMING WITH PYTHON', comp: 'Theory', raw: 'PROGRAMMING WITH PYTHONT4 CE Sem III'),
        (name: 'PROGRAMMING WITH PYTHON', comp: 'Lab', raw: 'PROGRAMMING WITH PYTHONP4 CE Sem III C2'),
        (name: 'Python Programming', comp: 'Theory', raw: 'Python Programming T4'),
        (name: 'Python Programming', comp: 'Lab', raw: 'Python Programming P4'),
        (name: 'Python', comp: 'Theory', raw: 'Python T'),
        (name: 'Python', comp: 'Lab', raw: 'Python P'),
      ];

      for (final tc in testCases) {
        final res = matcher.match(
          courseName: tc.name,
          componentType: tc.comp,
          rawCourseName: tc.raw,
        );
        expect(res.isResolved, isTrue, reason: 'Failed to resolve: ${tc.raw}');
        expect(res.subjectCode, equals('Python'));
        expect(res.component.toLowerCase(), equals(tc.comp.toLowerCase()));
      }
    });

    test('AttendanceCourseMatcher fallback matches Python when section is unconfigured', () {
      final matcher = AttendanceCourseMatcher([]);

      final res1 = matcher.match(
        courseName: 'Programming with Python',
        componentType: 'Theory',
        rawCourseName: 'PROGRAMMING WITH PYTHONT4 CE Sem III',
      );
      expect(res1.isResolved, isTrue);
      expect(res1.subjectCode, equals('Python'));

      final res2 = matcher.match(
        courseName: 'Python Programming',
        componentType: 'Lab',
        rawCourseName: 'Python Programming P4',
      );
      expect(res2.isResolved, isTrue);
      expect(res2.subjectCode, equals('Python'));
    });

    test('Python Theory and Lab merge into ONE Python_Merged card', () {
      final logs = [
        AttendanceLog(
          id: 'log1',
          subjectCode: 'Python',
          component: 'Theory',
          rawSubjectText: 'PROGRAMMING WITH PYTHONT4',
          normalizedSubject: 'Programming with Python',
          date: DateTime(2026, 8, 1, 9, 0),
          startTime: 9 * 60,
          endTime: 10 * 60,
          status: 'present',
          source: 'pdf_import',
          confidence: MatchConfidence.exact,
        ),
        AttendanceLog(
          id: 'log2',
          subjectCode: 'Python',
          component: 'Lab',
          rawSubjectText: 'PROGRAMMING WITH PYTHONP4',
          normalizedSubject: 'Programming with Python',
          date: DateTime(2026, 8, 1, 10, 0),
          startTime: 10 * 60,
          endTime: 12 * 60,
          status: 'absent',
          source: 'pdf_import',
          confidence: MatchConfidence.exact,
        ),
      ];

      final key1 = AttendanceLog.canonicalGroupKey(logs[0].subjectCode, logs[0].component);
      final key2 = AttendanceLog.canonicalGroupKey(logs[1].subjectCode, logs[1].component);

      expect(key1, equals('Python_Merged'));
      expect(key2, equals('Python_Merged'));
      expect(key1, equals(key2));
    });
  });

  group('2. Smart Attendance Recommendations & Hours Tests', () {
    test('NU counts as completed occurrence for semester progress but NOT absent', () {
      expect(AttendanceStatusMapper.countsAsCompletedOccurrence('not_updated'), isTrue);
      expect(AttendanceStatusMapper.countsAsCompletedOccurrence('present'), isTrue);
      expect(AttendanceStatusMapper.countsAsCompletedOccurrence('absent'), isTrue);

      final present = 18;
      final absent = 2;
      final notUpdated = 5;

      final pct = present / (present + absent);
      expect(pct, closeTo(0.90, 0.001));

      final completedOccurrences = present + absent + notUpdated;
      expect(completedOccurrences, equals(25));

      final calculator = ProgressCalculatorService(
        weeklyTimetable: {},
        semesterStartDate: DateTime(2026, 7, 13),
        subjectMetadata: {},
        courseComponents: [
          CourseComponent(
            componentId: 'COA',
            componentType: 'Theory',
            courseName: 'COA',
            targetHours: 45,
            createdAt: DateTime.now(),
            sectionId: 'STME_CE_A',
          ),
        ],
      );

      final remaining = calculator.getRemainingLectures('COA', 'Theory', completedOccurrences);
      expect(remaining, equals(20));
    });

    test('Allowed absences and canMiss formula: floor(targetHours * (1 - threshold)) - absent', () {
      expect(ProgressCalculatorService.calculateSkips(totalCourseHours: 60, absentHours: 4, requiredAttendance: 0.80), equals(8));
      expect(ProgressCalculatorService.calculateSkips(totalCourseHours: 60, absentHours: 12, requiredAttendance: 0.80), equals(0));
      expect(ProgressCalculatorService.calculateSkips(totalCourseHours: 60, absentHours: 15, requiredAttendance: 0.80), equals(0));

      expect(ProgressCalculatorService.calculateSkips(totalCourseHours: 60, absentHours: 5, requiredAttendance: 0.70), equals(13));
      expect(ProgressCalculatorService.calculateSkips(totalCourseHours: 60, absentHours: 18, requiredAttendance: 0.70), equals(0));

      expect(ProgressCalculatorService.calculateSkips(totalCourseHours: 45, absentHours: 3, requiredAttendance: 0.80), equals(6));
    });

    test('STME DSA Theory and Lab remain independent with dynamic configured hours', () {
      final configured = [
        CourseComponent(
          componentId: 'DSA_Theory',
          componentType: 'Theory',
          courseName: 'DATA STRUCTURES AND ALGORITHMS',
          courseCode: 'DSA',
          targetHours: 45,
          createdAt: DateTime.now(),
          sectionId: 'STME_CE_A',
        ),
        CourseComponent(
          componentId: 'DSA_Lab',
          componentType: 'Lab',
          courseName: 'DATA STRUCTURES AND ALGORITHMS',
          courseCode: 'DSA',
          targetHours: 30,
          createdAt: DateTime.now(),
          sectionId: 'STME_CE_A',
        ),
      ];

      final calculator = ProgressCalculatorService(
        weeklyTimetable: {},
        semesterStartDate: DateTime(2026, 7, 13),
        subjectMetadata: {},
        courseComponents: configured,
      );

      expect(calculator.getConfiguredCourseHours('DSA', 'Theory'), equals(45));
      expect(calculator.getConfiguredCourseHours('DSA', 'Lab'), equals(30));

      final remTheory = calculator.getRemainingLectures('DSA', 'Theory', 15);
      expect(remTheory, equals(30));
      final skipsTheory = calculator.getRemainingSkips('DSA', 'Theory', 2, requiredAttendance: 0.80);
      expect(skipsTheory, equals(7));

      final remLab = calculator.getRemainingLectures('DSA', 'Lab', 10);
      expect(remLab, equals(20));
      final skipsLab = calculator.getRemainingSkips('DSA', 'Lab', 1, requiredAttendance: 0.80);
      expect(skipsLab, equals(5));
    });

    test('getFixedTotalCourseHours returns 0 when unconfigured (never 15-week timetable estimation)', () {
      final calculator = ProgressCalculatorService(
        weeklyTimetable: {},
        semesterStartDate: DateTime(2026, 7, 13),
        subjectMetadata: {},
        courseComponents: [],
      );

      expect(calculator.getFixedTotalCourseHours('UnknownSubject', 'Theory'), equals(0));
    });
  });
}
