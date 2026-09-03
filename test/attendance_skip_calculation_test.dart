import 'package:flutter_test/flutter_test.dart';
import 'package:schedly/models/course_component.dart';
import 'package:schedly/models/attendance_record.dart';
import 'package:schedly/services/progress_calculator_service.dart';

void main() {
  group('1. Required 80% Attendance Formula Tests (from 80% specification)', () {
    test('60 total hours, 80%, 0 absent → 12 remaining', () {
      final skips = ProgressCalculatorService.calculateSkips(
        totalCourseHours: 60,
        absentHours: 0,
        requiredAttendance: 0.80,
      );
      expect(skips, equals(12));
    });

    test('60 total hours, 80%, 4 absent → 8 remaining', () {
      final skips = ProgressCalculatorService.calculateSkips(
        totalCourseHours: 60,
        absentHours: 4,
        requiredAttendance: 0.80,
      );
      expect(skips, equals(8));
    });

    test('60 total hours, 80%, 5 absent → 7 remaining', () {
      final skips = ProgressCalculatorService.calculateSkips(
        totalCourseHours: 60,
        absentHours: 5,
        requiredAttendance: 0.80,
      );
      expect(skips, equals(7));
    });

    test('60 total hours, 80%, 12 absent → 0 remaining', () {
      final skips = ProgressCalculatorService.calculateSkips(
        totalCourseHours: 60,
        absentHours: 12,
        requiredAttendance: 0.80,
      );
      expect(skips, equals(0));
    });

    test(
      '60 total hours, 80%, 13 absent → 0 remaining (never negative, min 0)',
      () {
        final skips = ProgressCalculatorService.calculateSkips(
          totalCourseHours: 60,
          absentHours: 13,
          requiredAttendance: 0.80,
        );
        expect(skips, equals(0));
      },
    );

    test(
      '60 total hours, 80%, 30 absent → 0 remaining (large absences clamp to 0)',
      () {
        final skips = ProgressCalculatorService.calculateSkips(
          totalCourseHours: 60,
          absentHours: 30,
          requiredAttendance: 0.80,
        );
        expect(skips, equals(0));
      },
    );
  });

  group('2. Different Course Totals Tests (80% Requirement)', () {
    test('45 total hours (e.g. COA/PEM/DM): allowed absence = 9 hours', () {
      // Allowed absence: floor(45 * 0.20) = 9 hours
      expect(
        ProgressCalculatorService.calculateSkips(
          totalCourseHours: 45,
          absentHours: 0,
          requiredAttendance: 0.80,
        ),
        equals(9),
      );
      expect(
        ProgressCalculatorService.calculateSkips(
          totalCourseHours: 45,
          absentHours: 4,
          requiredAttendance: 0.80,
        ),
        equals(5),
      );
      expect(
        ProgressCalculatorService.calculateSkips(
          totalCourseHours: 45,
          absentHours: 9,
          requiredAttendance: 0.80,
        ),
        equals(0),
      );
      expect(
        ProgressCalculatorService.calculateSkips(
          totalCourseHours: 45,
          absentHours: 10,
          requiredAttendance: 0.80,
        ),
        equals(0),
      );
    });

    test('75 total hours (e.g. Combined DSA): allowed absence = 15 hours', () {
      // Allowed absence: floor(75 * 0.20) = 15 hours
      expect(
        ProgressCalculatorService.calculateSkips(
          totalCourseHours: 75,
          absentHours: 0,
          requiredAttendance: 0.80,
        ),
        equals(15),
      );
      expect(
        ProgressCalculatorService.calculateSkips(
          totalCourseHours: 75,
          absentHours: 5,
          requiredAttendance: 0.80,
        ),
        equals(10),
      );
      expect(
        ProgressCalculatorService.calculateSkips(
          totalCourseHours: 75,
          absentHours: 15,
          requiredAttendance: 0.80,
        ),
        equals(0),
      );
      expect(
        ProgressCalculatorService.calculateSkips(
          totalCourseHours: 75,
          absentHours: 16,
          requiredAttendance: 0.80,
        ),
        equals(0),
      );
    });

    test('30 total hours (e.g. PEC): allowed absence = 6 hours', () {
      // Allowed absence: floor(30 * 0.20) = 6 hours
      expect(
        ProgressCalculatorService.calculateSkips(
          totalCourseHours: 30,
          absentHours: 0,
          requiredAttendance: 0.80,
        ),
        equals(6),
      );
      expect(
        ProgressCalculatorService.calculateSkips(
          totalCourseHours: 30,
          absentHours: 2,
          requiredAttendance: 0.80,
        ),
        equals(4),
      );
      expect(
        ProgressCalculatorService.calculateSkips(
          totalCourseHours: 30,
          absentHours: 6,
          requiredAttendance: 0.80,
        ),
        equals(0),
      );
      expect(
        ProgressCalculatorService.calculateSkips(
          totalCourseHours: 30,
          absentHours: 7,
          requiredAttendance: 0.80,
        ),
        equals(0),
      );
    });

    test('15 total hours (e.g. TC Tutorial): allowed absence = 3 hours', () {
      // Allowed absence: floor(15 * 0.20) = 3 hours
      expect(
        ProgressCalculatorService.calculateSkips(
          totalCourseHours: 15,
          absentHours: 0,
          requiredAttendance: 0.80,
        ),
        equals(3),
      );
      expect(
        ProgressCalculatorService.calculateSkips(
          totalCourseHours: 15,
          absentHours: 1,
          requiredAttendance: 0.80,
        ),
        equals(2),
      );
      expect(
        ProgressCalculatorService.calculateSkips(
          totalCourseHours: 15,
          absentHours: 3,
          requiredAttendance: 0.80,
        ),
        equals(0),
      );
      expect(
        ProgressCalculatorService.calculateSkips(
          totalCourseHours: 15,
          absentHours: 4,
          requiredAttendance: 0.80,
        ),
        equals(0),
      );
    });
  });

  group('3. Configurable Attendance Requirements Tests', () {
    test('60 total hours with default parameter (should default to 80%)', () {
      expect(
        ProgressCalculatorService.calculateSkips(
          totalCourseHours: 60,
          absentHours: 4,
        ),
        equals(8),
      );
    });

    test('60 total hours with custom 85% requirement', () {
      // Allowed absence: 60 * (1 - 0.85) = 60 * 0.15 = 9 hours
      expect(
        ProgressCalculatorService.calculateSkips(
          totalCourseHours: 60,
          absentHours: 2,
          requiredAttendance: 0.85,
        ),
        equals(7),
      );
      expect(
        ProgressCalculatorService.calculateSkips(
          totalCourseHours: 60,
          absentHours: 9,
          requiredAttendance: 0.85,
        ),
        equals(0),
      );
      expect(
        ProgressCalculatorService.calculateSkips(
          totalCourseHours: 60,
          absentHours: 10,
          requiredAttendance: 0.85,
        ),
        equals(0),
      );
    });

    test('50 total hours with custom 70% requirement', () {
      // Allowed absence: 50 * (1 - 0.70) = 50 * 0.30 = 15 hours
      expect(
        ProgressCalculatorService.calculateSkips(
          totalCourseHours: 50,
          absentHours: 5,
          requiredAttendance: 0.70,
        ),
        equals(10),
      );
      expect(
        ProgressCalculatorService.calculateSkips(
          totalCourseHours: 50,
          absentHours: 15,
          requiredAttendance: 0.70,
        ),
        equals(0),
      );
      expect(
        ProgressCalculatorService.calculateSkips(
          totalCourseHours: 50,
          absentHours: 16,
          requiredAttendance: 0.70,
        ),
        equals(0),
      );
    });
  });

  group('4. Course Details Metadata Integration Tests (80%)', () {
    late ProgressCalculatorService calculator;

    setUp(() {
      final configuredComponents = [
        CourseComponent(
          componentId: 'DSA Theory',
          componentType: 'Theory',
          courseName: 'DSA',
          courseCode: 'CS201',
          targetHours: 45,
          sectionId: 'SecondYear_CE_C',
          createdAt: DateTime(2026, 1, 1),
        ),
        CourseComponent(
          componentId: 'DSA Lab',
          componentType: 'Lab',
          courseName: 'DSA',
          courseCode: 'CS201',
          targetHours: 30,
          sectionId: 'SecondYear_CE_C',
          createdAt: DateTime(2026, 1, 1),
        ),
        CourseComponent(
          componentId: 'COA',
          componentType: 'Combined',
          courseName: 'COA',
          courseCode: 'CS202',
          targetHours: 45,
          sectionId: 'SecondYear_CE_C',
          createdAt: DateTime(2026, 1, 1),
        ),
        CourseComponent(
          componentId: 'SnS',
          componentType: 'Combined',
          courseName: 'SnS',
          courseCode: 'CS203',
          targetHours: 60,
          sectionId: 'SecondYear_CE_C',
          createdAt: DateTime(2026, 1, 1),
        ),
        CourseComponent(
          componentId: 'PnS',
          componentType: 'Combined',
          courseName: 'PnS',
          courseCode: 'CS204',
          targetHours: 60,
          sectionId: 'SecondYear_CE_C',
          createdAt: DateTime(2026, 1, 1),
        ),
      ];

      final metadataMap = <String, CourseComponent>{
        for (var c in configuredComponents) c.componentId: c,
      };

      calculator = ProgressCalculatorService(
        weeklyTimetable: {},
        semesterStartDate: DateTime(2026, 7, 13),
        subjectMetadata: metadataMap,
        courseComponents: configuredComponents,
      );
    });

    test(
      'Reads fixed course hours for split DSA Theory and DSA Lab correctly',
      () {
        expect(
          calculator.getFixedTotalCourseHours('DSA', 'Theory'),
          equals(45),
        );
        expect(calculator.getFixedTotalCourseHours('DSA', 'Lab'), equals(30));
      },
    );

    test('Reads fixed course hours for merged courses correctly', () {
      expect(calculator.getFixedTotalCourseHours('COA', 'Merged'), equals(45));
      expect(calculator.getFixedTotalCourseHours('SnS', 'Merged'), equals(60));
      expect(calculator.getFixedTotalCourseHours('PnS', 'Merged'), equals(60));
    });

    test(
      'Calculates remaining skips using fixed Course Details hours (80% default)',
      () {
        // SnS has 60 hours fixed, 80% required -> allowed absence = 12
        // 4 absent -> 8 skips left
        expect(calculator.getRemainingSkips('SnS', 'Merged', 4), equals(8));

        // DSA Theory has 45 hours fixed, 80% required -> allowed absence = 9
        // 3 absent -> 6 skips left
        expect(calculator.getRemainingSkips('DSA', 'Theory', 3), equals(6));

        // DSA Lab has 30 hours fixed, 80% required -> allowed absence = 6
        // 2 absent -> 4 skips left
        expect(calculator.getRemainingSkips('DSA', 'Lab', 2), equals(4));

        // PnS has 60 hours fixed, 80% required -> allowed absence = 12
        // 12 absent -> 0 skips left
        expect(calculator.getRemainingSkips('PnS', 'Merged', 12), equals(0));

        // PnS has 60 hours fixed, 80% required -> allowed absence = 12
        // 13 absent -> 0 skips left (never negative)
        expect(calculator.getRemainingSkips('PnS', 'Merged', 13), equals(0));
      },
    );
  });

  group('5. Attendance Invariance Verification Tests', () {
    test(
      'Percentage and counts remain completely unchanged while skip calculation changes',
      () {
        final record = AttendanceRecord(
          id: 'CE_SnS_Merged',
          division: 'SecondYear_CE_C',
          subjectCode: 'SnS',
          component: 'Merged',
          present: 23,
          absent: 4,
          cancelled: 0,
        );

        // 1. Total count is unchanged
        expect(record.total, equals(27));

        // 2. Present count is unchanged
        expect(record.present, equals(23));

        // 3. Absent count is unchanged
        expect(record.absent, equals(4));

        // 4. Percentage is unchanged (23 / 27 = 85.185%)
        expect(record.percentage, closeTo(23 / 27, 0.0001));

        // 5. Skip calculation uses fixed semester hours (60) with 80% requirement
        // allowed absence = 12, absent = 4 -> 8 skips left
        final skips = ProgressCalculatorService.calculateSkips(
          totalCourseHours: 60,
          absentHours: record.absent,
          requiredAttendance: 0.80,
        );
        expect(skips, equals(8));
      },
    );
  });
}
