import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedly/attendance_page.dart';
import 'package:schedly/models/attendance_log.dart';
import 'package:schedly/models/attendance_record.dart';
import 'package:schedly/models/attendance_subject_view_model.dart';
import 'package:schedly/models/course_component.dart';
import 'package:schedly/services/attendance_status_mapper.dart';
import 'package:schedly/services/progress_calculator_service.dart';
import 'package:schedly/theme/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. AttendanceSubjectViewModel Unit Tests', () {
    test('assignedHoursLabel formats correctly when configured vs missing', () {
      const vmWithHours = AttendanceSubjectViewModel(
        subjectCode: 'DATA STRUCTURES AND ALGORITHMS',
        component: 'Theory',
        present: 18,
        absent: 3,
        total: 21,
        percentage: 0.857,
        skipsLeft: 6,
        assignedHours: 45,
      );
      expect(vmWithHours.assignedHoursLabel, equals('45 hrs assigned'));

      const vmWithoutHours = AttendanceSubjectViewModel(
        subjectCode: 'DATA STRUCTURES AND ALGORITHMS',
        component: 'Lab',
        present: 12,
        absent: 2,
        total: 14,
        percentage: 0.857,
        skipsLeft: 4,
        assignedHours: null,
      );
      expect(vmWithoutHours.assignedHoursLabel, equals('Hours not configured'));

      const vmWithZeroHours = AttendanceSubjectViewModel(
        subjectCode: 'PE',
        component: 'Theory',
        present: 4,
        absent: 0,
        total: 4,
        percentage: 1.0,
        skipsLeft: 0,
        assignedHours: 0,
      );
      expect(vmWithZeroHours.assignedHoursLabel, equals('Hours not configured'));
    });

    test('remainingLecturesLabel formats correctly when available vs unavailable', () {
      const vmWithRemaining = AttendanceSubjectViewModel(
        subjectCode: 'COA',
        component: 'Theory',
        present: 19,
        absent: 2,
        total: 21,
        percentage: 0.905,
        skipsLeft: 7,
        assignedHours: 45,
        remainingLectures: 12,
      );
      expect(vmWithRemaining.remainingLecturesLabel, equals('12 lectures remaining'));

      const vmWithoutRemaining = AttendanceSubjectViewModel(
        subjectCode: 'COA',
        component: 'Theory',
        present: 19,
        absent: 2,
        total: 21,
        percentage: 0.905,
        skipsLeft: 7,
        assignedHours: 45,
        remainingLectures: null,
      );
      expect(
        vmWithoutRemaining.remainingLecturesLabel,
        equals('Remaining lectures unavailable'),
      );
    });

    test('fromRecord constructs accurate view-model via calculator', () {
      final dsaTheory = CourseComponent(
        componentId: 'dsa_theory',
        componentType: 'Theory',
        courseName: 'Data Structures and Algorithms',
        courseCode: 'DSA',
        targetHours: 45,
        createdAt: DateTime(2026, 1, 1),
        sectionId: 'CSDS_A',
      );
      final dsaLab = CourseComponent(
        componentId: 'dsa_lab',
        componentType: 'Lab',
        courseName: 'Data Structures and Algorithms',
        courseCode: 'DSA',
        targetHours: 30,
        createdAt: DateTime(2026, 1, 1),
        sectionId: 'CSDS_A',
      );

      final calc = ProgressCalculatorService(
        weeklyTimetable: {},
        semesterStartDate: DateTime(2026, 7, 13),
        subjectMetadata: {
          'dsa_theory': dsaTheory,
          'dsa_lab': dsaLab,
        },
        courseComponents: [dsaTheory, dsaLab],
      );

      final recordTheory = AttendanceRecord(
        id: 'CSDS_A_DSA_Theory',
        division: 'CSDS_A',
        subjectCode: 'DATA STRUCTURES AND ALGORITHMS',
        component: 'Theory',
        present: 18,
        absent: 3,
      );

      final vmTheory = AttendanceSubjectViewModel.fromRecord(
        record: recordTheory,
        calculator: calc,
      );

      expect(vmTheory.subjectCode, equals('DATA STRUCTURES AND ALGORITHMS'));
      expect(vmTheory.component, equals('Theory'));
      expect(vmTheory.present, equals(18));
      expect(vmTheory.absent, equals(3));
      expect(vmTheory.total, equals(21));
      expect(vmTheory.percentage, closeTo(18 / 21, 0.001));
      expect(vmTheory.assignedHours, equals(45));
      expect(vmTheory.assignedHoursLabel, equals('45 hrs assigned'));
      // Skips: floor(45 * 0.20) - 3 = 9 - 3 = 6
      expect(vmTheory.skipsLeft, equals(6));
      expect(vmTheory.remainingLectures, equals(24));
      expect(vmTheory.remainingLecturesLabel, equals('24 lectures remaining'));

      final recordLab = AttendanceRecord(
        id: 'CSDS_A_DSA_Lab',
        division: 'CSDS_A',
        subjectCode: 'DATA STRUCTURES AND ALGORITHMS',
        component: 'Lab',
        present: 12,
        absent: 2,
      );

      final vmLab = AttendanceSubjectViewModel.fromRecord(
        record: recordLab,
        calculator: calc,
      );

      expect(vmLab.assignedHours, equals(30));
      expect(vmLab.assignedHoursLabel, equals('30 hrs assigned'));
      // Skips: floor(30 * 0.20) - 2 = 6 - 2 = 4
      expect(vmLab.skipsLeft, equals(4));
      expect(vmLab.remainingLectures, equals(16));
      expect(vmLab.remainingLecturesLabel, equals('16 lectures remaining'));
    });
  });

  group('2. ProgressCalculatorService Authoritative Course Hours Tests', () {
    test('getConfiguredCourseHours resolves split DSA components independently', () {
      final dsaTheory = CourseComponent(
        componentId: 'dsa_theory',
        componentType: 'Theory',
        courseName: 'Data Structures and Algorithms',
        courseCode: 'DSA',
        targetHours: 45,
        createdAt: DateTime(2026, 1, 1),
        sectionId: 'CSDS_A',
      );
      final dsaLab = CourseComponent(
        componentId: 'dsa_lab',
        componentType: 'Lab',
        courseName: 'Data Structures and Algorithms',
        courseCode: 'DSA',
        targetHours: 30,
        createdAt: DateTime(2026, 1, 1),
        sectionId: 'CSDS_A',
      );

      final calc = ProgressCalculatorService(
        weeklyTimetable: {},
        semesterStartDate: DateTime(2026, 7, 13),
        subjectMetadata: {},
        courseComponents: [dsaTheory, dsaLab],
      );

      expect(calc.getConfiguredCourseHours('DATA STRUCTURES AND ALGORITHMS', 'Theory'), equals(45));
      expect(calc.getConfiguredCourseHours('DATA STRUCTURES AND ALGORITHMS', 'Lab'), equals(30));
    });

    test('getConfiguredCourseHours sums component hours for merged courses', () {
      final snsTheory = CourseComponent(
        componentId: 'sns_theory',
        componentType: 'Theory',
        courseName: 'Signals and Systems',
        courseCode: 'SnS',
        targetHours: 45,
        createdAt: DateTime(2026, 1, 1),
        sectionId: 'CSDS_A',
      );
      final snsLab = CourseComponent(
        componentId: 'sns_lab',
        componentType: 'Lab',
        courseName: 'Signals and Systems',
        courseCode: 'SnS',
        targetHours: 30,
        createdAt: DateTime(2026, 1, 1),
        sectionId: 'CSDS_A',
      );

      final calc = ProgressCalculatorService(
        weeklyTimetable: {},
        semesterStartDate: DateTime(2026, 7, 13),
        subjectMetadata: {},
        courseComponents: [snsTheory, snsLab],
      );

      // In merged mode, Signals and Systems has 45 + 30 = 75 total course hours
      expect(calc.getConfiguredCourseHours('Signals and Systems', 'Merged'), equals(75));
      expect(calc.getConfiguredCourseHours('SnS', 'Merged'), equals(75));
    });

    test('getConfiguredCourseHours returns null when not configured (no timetable fallback)', () {
      final calc = ProgressCalculatorService(
        weeklyTimetable: {},
        semesterStartDate: DateTime(2026, 7, 13),
        subjectMetadata: {},
        courseComponents: [],
      );

      expect(calc.getConfiguredCourseHours('Unknown Subject', 'Merged'), isNull);
    });

    test('Multi-section isolation: Division A hours do not leak to Division B', () {
      final sectionACoa = CourseComponent(
        componentId: 'coa_a',
        componentType: 'Theory',
        courseName: 'Computer Organization and Architecture',
        targetHours: 60,
        createdAt: DateTime(2026, 1, 1),
        sectionId: 'CSDS_A',
      );
      final sectionBCoa = CourseComponent(
        componentId: 'coa_b',
        componentType: 'Theory',
        courseName: 'Computer Organization and Architecture',
        targetHours: 45,
        createdAt: DateTime(2026, 1, 1),
        sectionId: 'CSDS_B',
      );

      final calcA = ProgressCalculatorService(
        weeklyTimetable: {},
        semesterStartDate: DateTime(2026, 7, 13),
        subjectMetadata: {},
        courseComponents: [sectionACoa],
      );
      final calcB = ProgressCalculatorService(
        weeklyTimetable: {},
        semesterStartDate: DateTime(2026, 7, 13),
        subjectMetadata: {},
        courseComponents: [sectionBCoa],
      );

      expect(calcA.getConfiguredCourseHours('Computer Organization and Architecture', 'Theory'), equals(60));
      expect(calcB.getConfiguredCourseHours('Computer Organization and Architecture', 'Theory'), equals(45));
    });
  });

  group('3. UI & 360px Responsiveness Widget Tests', () {
    const testViewModel = AttendanceSubjectViewModel(
      subjectCode: 'DATA STRUCTURES AND ALGORITHMS',
      component: 'Theory',
      present: 18,
      absent: 3,
      total: 21,
      percentage: 0.857,
      skipsLeft: 6,
      assignedHours: 45,
      remainingLectures: null,
    );

    for (final isDark in [false, true]) {
      for (final visualTheme in SchedlyVisualTheme.values) {
        testWidgets(
          'Renders without overflow on 360px width (${isDark ? "Dark" : "Light"} - ${visualTheme.name})',
          (tester) async {
            // Set 360px width viewport
            tester.view.physicalSize = const Size(360, 800);
            tester.view.devicePixelRatio = 1.0;
            addTearDown(() {
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
            });

            await tester.pumpWidget(
              MaterialApp(
                theme: AppTheme.buildTheme(isDark: isDark, visualTheme: visualTheme),
                home: const Scaffold(
                  body: Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.x2l),
                    child: _SubjectAttendanceCardTestWrapper(viewModel: testViewModel),
                  ),
                ),
              ),
            );

            await tester.pumpAndSettle();

            // Verify primary elements
            expect(find.text('DATA STRUCTURES AND ALGORITHMS'), findsOneWidget);
            expect(find.text('85.7%'), findsOneWidget);
            expect(find.text('Can miss 6 more'), findsOneWidget);

            // Verify secondary elements
            expect(find.text('Theory'), findsOneWidget);
            expect(find.text('Total: 21  •  Present: 18  •  Absent: 3'), findsOneWidget);

            // Verify tertiary semester context elements
            expect(find.text('45 hrs assigned'), findsOneWidget);
            expect(find.text('Remaining lectures unavailable'), findsOneWidget);

            // No overflow errors should be thrown
            expect(tester.takeException(), isNull);
          },
        );
      }
    }

    testWidgets('Renders "Hours not configured" gracefully when hours are missing', (tester) async {
      const unconfiguredVM = AttendanceSubjectViewModel(
        subjectCode: 'TECHNICAL COMMUNICATION',
        component: 'Tutorial',
        present: 6,
        absent: 1,
        total: 7,
        percentage: 0.857,
        skipsLeft: 0,
        assignedHours: null,
        remainingLectures: null,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.buildTheme(isDark: false, visualTheme: SchedlyVisualTheme.defaultTheme),
          home: const Scaffold(
            body: _SubjectAttendanceCardTestWrapper(viewModel: unconfiguredVM),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Hours not configured'), findsOneWidget);
      expect(find.text('Remaining lectures unavailable'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders "12 lectures remaining" when remainingLectures is provided', (tester) async {
      const remainingVM = AttendanceSubjectViewModel(
        subjectCode: 'COA',
        component: 'Theory',
        present: 19,
        absent: 2,
        total: 21,
        percentage: 0.905,
        skipsLeft: 7,
        assignedHours: 45,
        remainingLectures: 12,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.buildTheme(isDark: true, visualTheme: SchedlyVisualTheme.future),
          home: const Scaffold(
            body: _SubjectAttendanceCardTestWrapper(viewModel: remainingVM),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('45 hrs assigned'), findsOneWidget);
      expect(find.text('12 lectures remaining'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('4. Remaining Lectures Semester Math & Rules', () {
    test('Core Formula: assigned - completed, including exact required scenarios', () {
      final comp75 = CourseComponent(
        componentId: 'comp_75',
        componentType: 'Theory',
        courseName: 'Signals and Systems',
        targetHours: 75,
        createdAt: DateTime(2026, 1, 1),
        sectionId: 'CSDS_A',
      );
      final comp60 = CourseComponent(
        componentId: 'comp_60',
        componentType: 'Theory',
        courseName: 'Computer Organization',
        targetHours: 60,
        createdAt: DateTime(2026, 1, 1),
        sectionId: 'CSDS_A',
      );
      final comp15 = CourseComponent(
        componentId: 'comp_15',
        componentType: 'Theory',
        courseName: 'Technical Communication',
        targetHours: 15,
        createdAt: DateTime(2026, 1, 1),
        sectionId: 'CSDS_A',
      );
      final comp30 = CourseComponent(
        componentId: 'comp_30',
        componentType: 'Lab',
        courseName: 'Data Structures and Algorithms',
        targetHours: 30,
        createdAt: DateTime(2026, 1, 1),
        sectionId: 'CSDS_A',
      );

      final calc = ProgressCalculatorService(
        weeklyTimetable: {},
        semesterStartDate: DateTime(2026, 7, 13),
        subjectMetadata: {},
        courseComponents: [comp75, comp60, comp15, comp30],
      );

      // Scenario 1: assigned 75, completed 37 -> remaining 38
      expect(calc.getRemainingLectures('Signals and Systems', 'Theory', 37), equals(38));

      // Scenario 2: assigned 75, completed 39 -> remaining 36
      expect(calc.getRemainingLectures('Signals and Systems', 'Theory', 39), equals(36));

      // Scenario 3: assigned 60, completed 30 -> remaining 30
      expect(calc.getRemainingLectures('Computer Organization', 'Theory', 30), equals(30));

      // Scenario 4: assigned 15, completed 6 -> remaining 9
      expect(calc.getRemainingLectures('Technical Communication', 'Theory', 6), equals(9));

      // Scenario 5: assigned 15, completed 14 -> remaining 1 (singular label check)
      expect(calc.getRemainingLectures('Technical Communication', 'Theory', 14), equals(1));
      final vmSingular = AttendanceSubjectViewModel(
        subjectCode: 'TC',
        component: 'Theory',
        present: 13,
        absent: 1,
        total: 14,
        percentage: 13 / 14,
        skipsLeft: 2,
        assignedHours: 15,
        remainingLectures: 1,
      );
      expect(vmSingular.remainingLecturesLabel, equals('1 lecture remaining'));

      // Scenario 6: clamped at 0 (never negative), e.g. completed 35 > assigned 30
      expect(calc.getRemainingLectures('Data Structures and Algorithms', 'Lab', 35), equals(0));
      final vmZero = AttendanceSubjectViewModel(
        subjectCode: 'DSA',
        component: 'Lab',
        present: 30,
        absent: 5,
        total: 35,
        percentage: 30 / 35,
        skipsLeft: 1,
        assignedHours: 30,
        remainingLectures: 0,
      );
      expect(vmZero.remainingLecturesLabel, equals('0 lectures remaining'));
    });

    test('Unconfigured Course Hours: returns null and renders "Remaining lectures unavailable", never fabricated', () {
      final calc = ProgressCalculatorService(
        weeklyTimetable: {},
        semesterStartDate: DateTime(2026, 7, 13),
        subjectMetadata: {},
        courseComponents: [],
      );

      // Prompt Engineering or missing subject
      final remaining = calc.getRemainingLectures('Prompt Engineering for ChatGPT', 'Theory', 5);
      expect(remaining, isNull);

      final rec = AttendanceRecord(
        id: 'pe_rec',
        division: 'CSDS_A',
        subjectCode: 'Prompt Engineering for ChatGPT',
        component: 'Theory',
        present: 5,
        absent: 0,
      );

      final vm = AttendanceSubjectViewModel.fromRecord(
        record: rec,
        calculator: calc,
      );

      expect(vm.assignedHours, isNull);
      expect(vm.assignedHoursLabel, equals('Hours not configured'));
      expect(vm.remainingLectures, isNull);
      expect(vm.remainingLecturesLabel, equals('Remaining lectures unavailable'));
    });

    test('NU Semantics: NU increments completed occurrences but does NOT affect present/absent percentage', () {
      final comp = CourseComponent(
        componentId: 'dsa_theory',
        componentType: 'Theory',
        courseName: 'Data Structures and Algorithms',
        targetHours: 45,
        createdAt: DateTime(2026, 1, 1),
        sectionId: 'CSDS_A',
      );

      final calc = ProgressCalculatorService(
        weeklyTimetable: {},
        semesterStartDate: DateTime(2026, 7, 13),
        subjectMetadata: {},
        courseComponents: [comp],
      );

      // Suppose logs have 18 Present, 2 Absent, and 5 Not Updated (NU)
      // Present = 18, Absent = 2. Total for percentage = 20.
      // Total completed occurrences = 18 + 2 + 5 = 25.
      final rec = AttendanceRecord(
        id: 'dsa_rec',
        division: 'CSDS_A',
        subjectCode: 'Data Structures and Algorithms',
        component: 'Theory',
        present: 18,
        absent: 2,
      );

      final vm = AttendanceSubjectViewModel.fromRecord(
        record: rec,
        calculator: calc,
        completedOccurrences: 25,
      );

      // Percentage is 18 / 20 = 90%, NOT 18 / 25
      expect(vm.present, equals(18));
      expect(vm.absent, equals(2));
      expect(vm.total, equals(20));
      expect(vm.percentage, equals(0.9));

      // Skips left is based on absent (2) and assigned hours (45): floor(45 * 0.20) - 2 = 9 - 2 = 7
      expect(vm.skipsLeft, equals(7));

      // Remaining lectures is assigned (45) - completedOccurrences (25) = 20
      expect(vm.remainingLectures, equals(20));
      expect(vm.remainingLecturesLabel, equals('20 lectures remaining'));
    });

    test('AttendanceStatusMapper.countsAsCompletedOccurrence correctly classifies statuses', () {
      // P, A, E, L, NU count as completed lecture occurrences
      expect(AttendanceStatusMapper.countsAsCompletedOccurrence('present'), isTrue);
      expect(AttendanceStatusMapper.countsAsCompletedOccurrence('absent'), isTrue);
      expect(AttendanceStatusMapper.countsAsCompletedOccurrence('exemption'), isTrue);
      expect(AttendanceStatusMapper.countsAsCompletedOccurrence('late_admission'), isTrue);
      expect(AttendanceStatusMapper.countsAsCompletedOccurrence('not_updated'), isTrue);
      expect(AttendanceStatusMapper.countsAsCompletedOccurrence('P'), isTrue);
      expect(AttendanceStatusMapper.countsAsCompletedOccurrence('A'), isTrue);
      expect(AttendanceStatusMapper.countsAsCompletedOccurrence('NU'), isTrue);

      // Cancelled, unknown, or empty do NOT count
      expect(AttendanceStatusMapper.countsAsCompletedOccurrence('cancelled'), isFalse);
      expect(AttendanceStatusMapper.countsAsCompletedOccurrence('unknown'), isFalse);
      expect(AttendanceStatusMapper.countsAsCompletedOccurrence(''), isFalse);
    });

    test('Idempotent Deduplication: Re-importing duplicate logs does not double-count completed lectures', () {
      final log1 = AttendanceLog(
        id: 'log1',
        subjectCode: 'DATA STRUCTURES AND ALGORITHMS',
        component: 'Theory',
        rawSubjectText: 'DATA STRUCTURES AND ALGORITHMS',
        date: DateTime(2026, 8, 1),
        startTime: 540,
        endTime: 600,
        status: 'present',
        source: 'pdf',
        confidence: MatchConfidence.exact,
        importedAt: DateTime(2026, 8, 1, 12, 0),
      );
      // Identical lecture imported later
      final log1Duplicate = AttendanceLog(
        id: 'log1_dup',
        subjectCode: 'DATA STRUCTURES AND ALGORITHMS',
        component: 'Theory',
        rawSubjectText: 'DATA STRUCTURES AND ALGORITHMS',
        date: DateTime(2026, 8, 1),
        startTime: 540,
        endTime: 600,
        status: 'present',
        source: 'pdf',
        confidence: MatchConfidence.exact,
        importedAt: DateTime(2026, 8, 2, 12, 0),
      );
      final log2 = AttendanceLog(
        id: 'log2',
        subjectCode: 'DATA STRUCTURES AND ALGORITHMS',
        component: 'Theory',
        rawSubjectText: 'DATA STRUCTURES AND ALGORITHMS',
        date: DateTime(2026, 8, 2),
        startTime: 540,
        endTime: 600,
        status: 'not_updated',
        source: 'pdf',
        confidence: MatchConfidence.exact,
        importedAt: DateTime(2026, 8, 2, 12, 0),
      );

      // Deduplicate by stable deduplicationKey
      final logs = [log1, log1Duplicate, log2];
      final uniqueLogs = <String, AttendanceLog>{};
      for (final log in logs) {
        final key = log.deduplicationKey;
        final existing = uniqueLogs[key];
        if (existing == null || log.importedAt.isAfter(existing.importedAt)) {
          uniqueLogs[key] = log;
        }
      }
      expect(uniqueLogs.length, equals(2));

      // Completed count across unique logs
      int completed = 0;
      for (final log in uniqueLogs.values) {
        if (AttendanceStatusMapper.countsAsCompletedOccurrence(log.status)) {
          completed++;
        }
      }
      expect(completed, equals(2)); // exactly 2, not 3!
    });
  });
}

/// Helper wrapper to instantiate _SubjectAttendanceCard in widget tests since it is a private widget
/// in attendance_page.dart (or we expose a public/visibleForTesting wrapper).
class _SubjectAttendanceCardTestWrapper extends StatelessWidget {
  final AttendanceSubjectViewModel viewModel;

  const _SubjectAttendanceCardTestWrapper({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return SubjectAttendanceCard(viewModel: viewModel);
  }
}
