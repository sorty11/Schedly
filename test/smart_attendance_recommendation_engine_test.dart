import 'package:flutter_test/flutter_test.dart';
import 'package:schedly/models/attendance_log.dart';
import 'package:schedly/models/attendance_record.dart';
import 'package:schedly/models/attendance_subject_view_model.dart';
import 'package:schedly/models/course_component.dart';
import 'package:schedly/models/event_category.dart';
import 'package:schedly/models/timetable_entry.dart';
import 'package:schedly/services/attendance/academic_grouping_policy.dart';
import 'package:schedly/services/attendance/attendance_aggregation_service.dart';
import 'package:schedly/services/progress_calculator_service.dart';

void main() {
  group('1. Authoritative Attendance & Denominator Exclusions', () {
    test('Attendance % strictly excludes NU from denominator: P / (P + A) * 100', () {
      final now = DateTime(2026, 8, 10);
      final logs = [
        AttendanceLog(
          id: 'log1',
          subjectCode: 'SE',
          component: 'Theory',
          rawSubjectText: 'Software Engineering',
          date: now,
          status: 'present',
          source: 'pdf_import',
          confidence: MatchConfidence.exact,
        ),
        AttendanceLog(
          id: 'log2',
          subjectCode: 'SE',
          component: 'Theory',
          rawSubjectText: 'Software Engineering',
          date: now.add(const Duration(days: 1)),
          status: 'absent',
          source: 'pdf_import',
          confidence: MatchConfidence.exact,
        ),
        AttendanceLog(
          id: 'log3',
          subjectCode: 'SE',
          component: 'Theory',
          rawSubjectText: 'Software Engineering',
          date: now.add(const Duration(days: 2)),
          status: 'NU',
          source: 'pdf_import',
          confidence: MatchConfidence.exact,
        ),
      ];

      final aggregated = AttendanceAggregationService.aggregate(
        rawRecords: [],
        logs: logs,
        division: 'STME_A',
      );

      final groupKey = AttendanceLog.canonicalGroupKey('SE', 'Theory');
      final rec = aggregated.records[groupKey]!;
      expect(rec.present, equals(1));
      expect(rec.absent, equals(1));
      expect(rec.total, equals(2)); // P + A only; NU excluded from denominator!

      // But completed occurrence count includes NU!
      expect(aggregated.completedCounts[groupKey], equals(3));
    });
  });

  group('2. Can Skip (Semester Budget) & Non-Estimation', () {
    test('Can Skip = floor(totalAssignedCourseHours * (1.0 - threshold)) - absent', () {
      final comp = CourseComponent(
        componentId: 'SE_Theory',
        componentType: 'Theory',
        courseName: 'Software Engineering',
        targetHours: 45,
        createdAt: DateTime(2026, 7, 13),
        sectionId: 'STME_A',
      );

      final calc = ProgressCalculatorService(
        weeklyTimetable: {},
        semesterStartDate: DateTime(2026, 7, 13),
        subjectMetadata: {comp.componentId: comp},
        courseComponents: [comp],
        requiredAttendance: 0.80,
      );

      // Total hours = 45. 80% threshold.
      // Allowed absences = floor(45 * 0.20) = 9.
      expect(calc.getRemainingSkips('Software Engineering', 'Theory', 0), equals(9));
      expect(calc.getRemainingSkips('Software Engineering', 'Theory', 4), equals(5));
      expect(calc.getRemainingSkips('Software Engineering', 'Theory', 9), equals(0));
      expect(calc.getRemainingSkips('Software Engineering', 'Theory', 12), equals(0)); // clamped at 0
    });

    test('Never uses 15-week timetable estimation when hours are unconfigured', () {
      final calc = ProgressCalculatorService(
        weeklyTimetable: {
          1: [
            TimetableEntry(
              id: 't1',
              subject: 'Unconfigured Course',
              component: 'Theory',
              category: EventCategory.academic,
              batch: 'Whole Class',
              startTime: 540,
              endTime: 600,
              durationMinutes: 60,
            ),
          ],
        },
        semesterStartDate: DateTime(2026, 7, 13),
        subjectMetadata: {},
        courseComponents: const [],
      );

      expect(calc.getConfiguredCourseHours('Unconfigured Course', 'Theory'), isNull);
      expect(calc.getFixedTotalCourseHours('Unconfigured Course', 'Theory'), equals(0));
      expect(calc.getRemainingSkips('Unconfigured Course', 'Theory', 2), equals(0));
    });
  });

  group('3. If You Skip & If You Attend Calculations (Smart Recommendation Engine)', () {
    test('Calculates accurate projected percentages and safe skip for 1h lecture', () {
      final comp = CourseComponent(
        componentId: 'SE_Theory',
        componentType: 'Theory',
        courseName: 'Software Engineering',
        targetHours: 45,
        createdAt: DateTime(2026, 7, 13),
        sectionId: 'STME_A',
      );

      final calc = ProgressCalculatorService(
        weeklyTimetable: {},
        semesterStartDate: DateTime(2026, 7, 13),
        subjectMetadata: {comp.componentId: comp},
        courseComponents: [comp],
        requiredAttendance: 0.80,
      );

      final record = AttendanceRecord(
        id: 'STME_A_SE_Theory',
        division: 'STME_A',
        subjectCode: 'Software Engineering',
        component: 'Theory',
        present: 18,
        absent: 2, // Total = 20 (90.0%)
      );

      final entry1h = TimetableEntry(
        id: 'entry_se',
        subject: 'Software Engineering',
        component: 'Theory',
        category: EventCategory.academic,
        batch: 'Whole Class',
        startTime: 540,
        endTime: 600,
        durationMinutes: 60, // 1 hour
      );

      final rec = calc.calculateSmartRecommendation(
        record: record,
        entry: entry1h,
        completedOccurrences: 20,
      );

      expect(rec.currentPct, closeTo(90.0, 0.01));
      expect(rec.lectureUnit, equals(1));
      // If attend: (18 + 1) / (20 + 1) * 100 = 19 / 21 * 100 = 90.476...%
      expect(rec.ifAttendPct, closeTo(90.48, 0.02));
      // If skip: 18 / (20 + 1) * 100 = 18 / 21 * 100 = 85.714...%
      expect(rec.ifSkipPct, closeTo(85.71, 0.02));
      // 85.71% >= 80% -> canSkipNext = true
      expect(rec.canSkipNext, isTrue);
      // Skips left = floor(45 * 0.20) - 2 = 9 - 2 = 7
      expect(rec.skipsLeft, equals(7));
      // Remaining lectures = 45 - 20 = 25
      expect(rec.remainingLectures, equals(25));
    });

    test('Calculates 2h unit for 2-hour lab block correctly and evaluates unsafe skip', () {
      final compLab = CourseComponent(
        componentId: 'DSA_Lab',
        componentType: 'Lab',
        courseName: 'DSA',
        targetHours: 30,
        createdAt: DateTime(2026, 7, 13),
        sectionId: 'STME_A',
      );

      final calc = ProgressCalculatorService(
        weeklyTimetable: {},
        semesterStartDate: DateTime(2026, 7, 13),
        subjectMetadata: {compLab.componentId: compLab},
        courseComponents: [compLab],
        requiredAttendance: 0.80,
      );

      // Student has 8 present, 2 absent out of 10 = 80.0%
      final record = AttendanceRecord(
        id: 'STME_A_DSA_Lab',
        division: 'STME_A',
        subjectCode: 'DSA',
        component: 'Lab',
        present: 8,
        absent: 2,
      );

      final entryLab2h = TimetableEntry(
        id: 'entry_dsa_lab',
        subject: 'DSA',
        component: 'Lab',
        category: EventCategory.academic,
        batch: 'A1',
        startTime: 660,
        endTime: 780,
        durationMinutes: 120, // 2-hour block!
      );

      final rec = calc.calculateSmartRecommendation(
        record: record,
        entry: entryLab2h,
        completedOccurrences: 10,
      );

      expect(rec.currentPct, closeTo(80.0, 0.01));
      expect(rec.lectureUnit, equals(2)); // Evaluated as 2h unit!
      // If attend: (16 + 2) / (20 + 2) * 100 = 18 / 22 * 100 = 81.82%
      expect(rec.ifAttendPct, closeTo(81.82, 0.02));
      // If skip: 16 / (20 + 2) * 100 = 16 / 22 * 100 = 72.73%
      expect(rec.ifSkipPct, closeTo(72.73, 0.02));
      // 72.73% < 80% -> canSkipNext = false (unsafe to skip!)
      expect(rec.canSkipNext, isFalse);
    });

    test('SOL 70% threshold is respected for SOL sections', () {
      final solComp = CourseComponent(
        componentId: 'Company_Law_II',
        componentType: 'Theory',
        courseName: 'Company Law II',
        targetHours: 60,
        createdAt: DateTime(2026, 7, 13),
        sectionId: 'SOL_A',
      );

      final calcSol = ProgressCalculatorService(
        weeklyTimetable: {},
        semesterStartDate: DateTime(2026, 7, 13),
        subjectMetadata: {solComp.componentId: solComp},
        courseComponents: [solComp],
        requiredAttendance: 0.70, // SOL 70% threshold
      );

      // Student has 15 present, 5 absent out of 20 = 75.0%
      final record = AttendanceRecord(
        id: 'SOL_A_Company_Law_II_Merged',
        division: 'SOL_A',
        subjectCode: 'Company Law II',
        component: 'Merged',
        present: 15,
        absent: 5,
      );

      final entry = TimetableEntry(
        id: 'sol_entry',
        subject: 'Company Law II',
        component: 'Theory',
        category: EventCategory.academic,
        batch: 'Whole Class',
        startTime: 540,
        endTime: 600,
        durationMinutes: 60,
      );

      final rec = calcSol.calculateSmartRecommendation(
        record: record,
        entry: entry,
      );

      expect(rec.requiredThreshold, equals(0.70));
      // If skip: 15 / (20 + 1) * 100 = 71.43% >= 70% -> safe to skip!
      expect(rec.ifSkipPct, closeTo(71.43, 0.02));
      expect(rec.canSkipNext, isTrue);

      // Allowed absences for 60h at 70%: floor(60 * 0.30) = 18.
      // Skips left = 18 - 5 = 13.
      expect(rec.skipsLeft, equals(13));
    });
  });

  group('4. Remaining Lectures & NU Progress Accounting', () {
    test('Remaining lectures: max(0, capacity - completedOccurrences) with NU counted', () {
      final calc = ProgressCalculatorService(
        weeklyTimetable: {},
        semesterStartDate: DateTime(2026, 7, 13),
        subjectMetadata: {},
        courseComponents: const [],
      );

      // DSA Theory: hardcoded 45 hrs
      // Conducted = 15 present + 3 absent + 2 NU = 20 completed occurrences
      expect(calc.getRemainingLectures('DSA', 'Theory', 20), equals(25)); // 45 - 20 = 25
      // If 48 completed occurrences (exceeded capacity), clamped to 0
      expect(calc.getRemainingLectures('DSA', 'Theory', 48), equals(0));
    });
  });

  group('5. Single Source of Truth Invariant', () {
    test('AttendanceSubjectViewModel values match calculateSmartRecommendation exactly', () {
      final comp = CourseComponent(
        componentId: 'DSA_Theory',
        componentType: 'Theory',
        courseName: 'DSA',
        targetHours: 45,
        createdAt: DateTime(2026, 7, 13),
        sectionId: 'STME_A',
      );

      final calc = ProgressCalculatorService(
        weeklyTimetable: {},
        semesterStartDate: DateTime(2026, 7, 13),
        subjectMetadata: {comp.componentId: comp},
        courseComponents: [comp],
        requiredAttendance: 0.80,
      );

      final record = AttendanceRecord(
        id: 'STME_A_DSA_Theory',
        division: 'STME_A',
        subjectCode: 'DSA',
        component: 'Theory',
        present: 20,
        absent: 2,
      );

      const completedWithNU = 24; // 20 P + 2 A + 2 NU

      final rec = calc.calculateSmartRecommendation(
        record: record,
        completedOccurrences: completedWithNU,
      );

      final vm = AttendanceSubjectViewModel.fromRecord(
        record: record,
        calculator: calc,
        completedOccurrences: completedWithNU,
      );

      expect(vm.percentage, equals(rec.currentPct / 100.0));
      expect(vm.skipsLeft, equals(rec.skipsLeft));
      expect(vm.remainingLectures, equals(rec.remainingLectures));
      expect(vm.assignedHours, equals(rec.assignedHours));
      expect(vm.recommendation, isNotNull);
      expect(vm.recommendation!.canSkipNext, equals(rec.canSkipNext));
      expect(vm.recommendation!.ifAttendPct, equals(rec.ifAttendPct));
      expect(vm.recommendation!.ifSkipPct, equals(rec.ifSkipPct));
    });
  });

  group('6. STME DSA Separation & Independence', () {
    test('DSA Theory (45h) and Lab (30h) calculate independently', () {
      final calc = ProgressCalculatorService(
        weeklyTimetable: {},
        semesterStartDate: DateTime(2026, 7, 13),
        subjectMetadata: {},
        courseComponents: const [],
      );

      final recTheory = AttendanceRecord(
        id: 'STME_A_DSA_Theory',
        division: 'STME_A',
        subjectCode: 'DSA',
        component: 'Theory',
        present: 20,
        absent: 3,
      );

      final recLab = AttendanceRecord(
        id: 'STME_A_DSA_Lab',
        division: 'STME_A',
        subjectCode: 'DSA',
        component: 'Lab',
        present: 12,
        absent: 1,
      );

      final thRecommendation = calc.calculateSmartRecommendation(record: recTheory);
      final labRecommendation = calc.calculateSmartRecommendation(record: recLab);

      // Theory has 45h assigned, max allowed absence = 9. With 3 absent -> 6 skips left.
      expect(thRecommendation.assignedHours, equals(45));
      expect(thRecommendation.skipsLeft, equals(6));

      // Lab has 30h assigned (2h lab blocks), max allowed absence = 6h.
      // With 1 absent (2h) -> remaining absence budget = 4h -> 2 sessions skips left.
      expect(labRecommendation.assignedHours, equals(30));
      expect(labRecommendation.skipsLeft, equals(2));
      expect(labRecommendation.skipsLeftHours, equals(4));

      // Independent remaining lectures
      expect(thRecommendation.remainingLectures, equals(22)); // 45h - 23h = 22 sessions
      expect(labRecommendation.remainingLectures, equals(2)); // (30h - 26h) / 2 = 2 sessions (4h remaining)
      expect(labRecommendation.remainingHours, equals(4));
    });
  });
}
