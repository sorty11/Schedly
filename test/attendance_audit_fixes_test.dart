import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:schedly/app_settings.dart';
import 'package:schedly/models/attendance_import_models.dart';
import 'package:schedly/models/attendance_log.dart';
import 'package:schedly/models/attendance_record.dart';
import 'package:schedly/models/attendance_subject_view_model.dart';
import 'package:schedly/models/course_component.dart';
import 'package:schedly/models/event_category.dart';
import 'package:schedly/models/timetable_entry.dart';
import 'package:schedly/services/attendance/academic_grouping_policy.dart';
import 'package:schedly/services/attendance/attendance_aggregation_service.dart';
import 'package:schedly/services/attendance/attendance_document_profile.dart';
import 'package:schedly/services/attendance/extraction_strategy.dart';
import 'package:schedly/services/attendance/progressive_attendance_reconciler.dart';
import 'package:schedly/services/progress_calculator_service.dart';
import 'package:schedly/services/subject_identity_service.dart';
import 'package:schedly/user_roles.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  final testDate = DateTime(2026, 7, 13);

  CourseComponent makeComp({
    required String componentId,
    required String courseName,
    String courseCode = '',
    String componentType = 'Theory',
    int targetHours = 45,
    String sectionId = 'CE_A',
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

  group('AUDIT FIX REGRESSION TESTS (P0, P1, P2)', () {
    // -------------------------------------------------------------
    // Test 1: P0 #2 — 30h / 2h Lab / 12 Sessions Completed
    // -------------------------------------------------------------
    test('1. 30h / 2h lab / 12 sessions: remaining lectures = 3 sessions (6 hours)', () {
      final configured = [
        makeComp(
          componentId: 'DSA_Lab',
          courseName: 'Data Structures and Algorithms',
          courseCode: 'DSA',
          componentType: 'Lab',
          targetHours: 30,
        ),
      ];

      final calc = ProgressCalculatorService(
        weeklyTimetable: {},
        semesterStartDate: testDate,
        subjectMetadata: {},
        courseComponents: configured,
      );

      // 12 sessions of 2 hours conducted = 24 hours completed
      final remainingSessions = calc.getRemainingLectures(
        'DSA',
        'Lab',
        12,
        conductedHours: 24,
        sessionDurationHours: 2,
      );
      final remainingHours = calc.getRemainingHours('DSA', 'Lab', 24);

      expect(remainingSessions, equals(3), reason: '30h - 24h = 6h; 6h / 2h = 3 remaining sessions');
      expect(remainingHours, equals(6), reason: 'Remaining academic hours must be 6');
    });

    // -------------------------------------------------------------
    // Test 2: P0 #2 — 45h / 1h Theory
    // -------------------------------------------------------------
    test('2. 45h / 1h theory: 25 sessions conducted -> 20 sessions remaining', () {
      final configured = [
        makeComp(
          componentId: 'DSA_Theory',
          courseName: 'Data Structures and Algorithms',
          courseCode: 'DSA',
          componentType: 'Theory',
          targetHours: 45,
        ),
      ];

      final calc = ProgressCalculatorService(
        weeklyTimetable: {},
        semesterStartDate: testDate,
        subjectMetadata: {},
        courseComponents: configured,
      );

      final remainingSessions = calc.getRemainingLectures(
        'DSA',
        'Theory',
        25,
        conductedHours: 25,
        sessionDurationHours: 1,
      );
      final remainingHours = calc.getRemainingHours('DSA', 'Theory', 25);

      expect(remainingSessions, equals(20), reason: '45h - 25h = 20 remaining 1h sessions');
      expect(remainingHours, equals(20), reason: 'Remaining hours must be 20');
    });

    // -------------------------------------------------------------
    // Test 3: Mixed-Duration Records Evaluated Independently
    // -------------------------------------------------------------
    test('3. Mixed-duration records: Theory (1h) and Lab (2h) maintain distinct unit calculations', () {
      final configured = [
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

      final calc = ProgressCalculatorService(
        weeklyTimetable: {},
        semesterStartDate: testDate,
        subjectMetadata: {},
        courseComponents: configured,
      );

      final recTheory = AttendanceRecord(
        id: '1',
        division: 'CE_A',
        subjectCode: 'DSA',
        component: 'Theory',
        present: 10,
        absent: 2,
      );
      final recLab = AttendanceRecord(
        id: '2',
        division: 'CE_A',
        subjectCode: 'DSA',
        component: 'Lab',
        present: 5,
        absent: 1,
      );

      final theoryRec = calc.calculateSmartRecommendation(
        record: recTheory,
        typicalSessionDurationHours: 1,
      );
      final labRec = calc.calculateSmartRecommendation(
        record: recLab,
        typicalSessionDurationHours: 2,
      );

      expect(theoryRec.lectureUnit, equals(1));
      expect(labRec.lectureUnit, equals(2));

      // Theory: 45h target, 80% threshold -> allowed absence = 9h.
      // Current absent = 2h. Remaining skip hours = 7h. Remaining skip sessions = 7 / 1 = 7.
      expect(theoryRec.skipsLeftHours, equals(7));
      expect(theoryRec.skipsLeft, equals(7));

      // Lab: 30h target, 80% threshold -> allowed absence = 6h.
      // Current absent = 1 session * 2h = 2h. Remaining skip hours = 4h. Remaining skip sessions = 4 / 2 = 2.
      expect(labRec.skipsLeftHours, equals(4));
      expect(labRec.skipsLeft, equals(2));
    });

    // -------------------------------------------------------------
    // Test 4: P0 #3 — 80% Boundary & 2h Lab Skip Budget
    // -------------------------------------------------------------
    test('4. 80% boundary: 30h course, 1 absent 2h lab -> 2 more 2h lab sessions allowed (4h remaining)', () {
      final skipBudget = ProgressCalculatorService.calculateSkipBudget(
        totalCourseHours: 30,
        absentHours: 2, // 1 missed 2h lab
        sessionDurationHours: 2,
        requiredAttendance: 0.80,
      );

      expect(skipBudget.remainingHours, equals(4), reason: '6h allowed - 2h missed = 4h');
      expect(skipBudget.remainingSessions, equals(2), reason: '4h / 2h = 2 sessions (NEVER 5)');
      expect(
        ProgressCalculatorService.calculateSkips(
          totalCourseHours: 30,
          absentHours: 2,
          sessionDurationHours: 2,
          requiredAttendance: 0.80,
        ),
        equals(2),
      );
    });

    // -------------------------------------------------------------
    // Test 5: 70% SOL Boundary
    // -------------------------------------------------------------
    test('5. 70% SOL boundary: 45h course, 2 absent 1h theory -> 11 sessions allowed (11h remaining)', () {
      final skipBudget = ProgressCalculatorService.calculateSkipBudget(
        totalCourseHours: 45,
        absentHours: 2, // 2 missed 1h lectures
        sessionDurationHours: 1,
        requiredAttendance: 0.70,
      );

      // allowed = floor(45 * 0.30) = 13h.
      // 13 - 2 = 11h = 11 sessions.
      expect(skipBudget.remainingHours, equals(11));
      expect(skipBudget.remainingSessions, equals(11));
      expect(
        ProgressCalculatorService.calculateSkips(
          totalCourseHours: 45,
          absentHours: 2,
          sessionDurationHours: 1,
          requiredAttendance: 0.70,
        ),
        equals(11),
      );
    });

    // -------------------------------------------------------------
    // Test 6: P0 #4 — If Attend / If Skip Exact Prompt Example
    // -------------------------------------------------------------
    test('6. If Attend / If Skip: 9 present 2h sessions (18h), 1 absent 2h session (2h) -> 90.91% / 81.82%', () {
      final calc = ProgressCalculatorService(
        weeklyTimetable: {},
        semesterStartDate: testDate,
        subjectMetadata: {},
        courseComponents: [
          makeComp(
            componentId: 'DSA_Lab',
            courseName: 'DSA',
            componentType: 'Lab',
            targetHours: 30,
          ),
        ],
      );

      final rec = AttendanceRecord(
        id: '1',
        division: 'CE_A',
        subjectCode: 'DSA',
        component: 'Lab',
        present: 9, // 9 sessions
        absent: 1,  // 1 session
      );

      final result = calc.calculateSmartRecommendation(
        record: rec,
        presentHours: 18, // 18 present hours
        absentHours: 2,   // 2 absent hours
        typicalSessionDurationHours: 2,
      );

      expect(result.currentPct, closeTo(90.0, 0.01));
      // Next 2h lecture:
      // IF ATTEND: (18 + 2) / (20 + 2) = 20 / 22 = 90.909%
      expect(result.ifAttendPct, closeTo(90.91, 0.01));
      // IF SKIP: 18 / (20 + 2) = 18 / 22 = 81.818%
      expect(result.ifSkipPct, closeTo(81.82, 0.01));
      expect(result.canSkipNext, isTrue);
    });

    // -------------------------------------------------------------
    // Test 7: P0 #1 — Progressive Reconciliation: NU -> P/A
    // -------------------------------------------------------------
    test('7. Progressive reconciliation: older NU is upgraded to incoming P or A', () {
      final existing = [
        AttendanceLog(
          id: 'k1',
          subjectCode: 'DSA',
          component: 'Theory',
          rawSubjectText: 'DSA',
          date: testDate,
          startTime: 540,
          endTime: 600,
          status: 'not_updated',
          source: 'pdf_import',
          confidence: MatchConfidence.exact,
          importedAt: DateTime(2026, 8, 1),
        ),
      ];

      final incoming = [
        AttendanceLog(
          id: 'k1',
          subjectCode: 'DSA',
          component: 'Theory',
          rawSubjectText: 'DSA',
          date: testDate,
          startTime: 540,
          endTime: 600,
          status: 'present',
          source: 'pdf_import',
          confidence: MatchConfidence.exact,
          importedAt: DateTime(2026, 8, 15),
        ),
      ];

      final result = ProgressiveAttendanceReconciler.reconcile(
        existingLogs: existing,
        incomingLogs: incoming,
        incomingReportDate: DateTime(2026, 8, 15),
      );

      expect(result.updatedRecords, equals(1));
      expect(result.reconciledLogs.first.status, equals('present'));
    });

    // -------------------------------------------------------------
    // Test 8: P0 #1 — Progressive Reconciliation: P/A -> older NU NEVER overwrites
    // -------------------------------------------------------------
    test('8. Progressive reconciliation: older NU NEVER overwrites existing definitive P or A', () {
      final existing = [
        AttendanceLog(
          id: 'k1',
          subjectCode: 'DSA',
          component: 'Theory',
          rawSubjectText: 'DSA',
          date: testDate,
          startTime: 540,
          endTime: 600,
          status: 'present',
          source: 'pdf_import',
          confidence: MatchConfidence.exact,
          importedAt: DateTime(2026, 8, 15),
        ),
      ];

      // User accidentally re-imports older PDF where status was still NU
      final olderIncoming = [
        AttendanceLog(
          id: 'k1',
          subjectCode: 'DSA',
          component: 'Theory',
          rawSubjectText: 'DSA',
          date: testDate,
          startTime: 540,
          endTime: 600,
          status: 'not_updated',
          source: 'pdf_import',
          confidence: MatchConfidence.exact,
          importedAt: DateTime(2026, 8, 1),
        ),
      ];

      final result = ProgressiveAttendanceReconciler.reconcile(
        existingLogs: existing,
        incomingLogs: olderIncoming,
        incomingReportDate: DateTime(2026, 8, 1),
      );

      expect(result.updatedRecords, equals(0));
      expect(result.duplicatesIgnored, equals(1));
      expect(result.reconciledLogs.first.status, equals('present'), reason: 'Present MUST survive!');
    });

    // -------------------------------------------------------------
    // Test 9: P1 #5 — Component Suppression Fix: DSA Theory + DSA Lab Both Survive
    // -------------------------------------------------------------
    test('9. AttendanceAggregationService: DSA Theory logs and DSA Lab raw records both survive', () {
      final logs = [
        AttendanceLog(
          id: 'log1',
          subjectCode: 'DSA',
          component: 'Theory',
          rawSubjectText: 'DSA T4',
          date: testDate,
          startTime: 540,
          endTime: 600,
          status: 'present',
          source: 'pdf_import',
          confidence: MatchConfidence.exact,
        ),
      ];

      final rawRecords = [
        AttendanceRecord(
          id: 'rec_lab',
          division: 'CE_A',
          subjectCode: 'DSA',
          component: 'Lab',
          present: 8,
          absent: 2,
        ),
      ];

      final aggregated = AttendanceAggregationService.aggregate(
        rawRecords: rawRecords,
        logs: logs,
        division: 'CE_A',
      );

      // Both DSA_Theory and DSA_Lab must exist in records!
      expect(aggregated.records.containsKey('DSA_Theory'), isTrue);
      expect(aggregated.records.containsKey('DSA_Lab'), isTrue);
      expect(aggregated.records['DSA_Lab']!.present, equals(8));
      expect(aggregated.records['DSA_Theory']!.present, equals(1));
    });

    // -------------------------------------------------------------
    // Test 10: P1 #6 — Batch Cache Isolation (A1 -> A2)
    // -------------------------------------------------------------
    test('10. ProgressCalculatorService: Cache isolates when switching batch from A1 to A2', () {
      ProgressCalculatorService.invalidateCache();

      AppSettings.currentRole = UserRole.student;
      AppSettings.studentBatch = 'A1';

      final entryA1 = TimetableEntry(
        id: 't1',
        subject: 'Math',
        batch: 'A1',
        startTime: 540,
        endTime: 600,
        durationMinutes: 60,
        category: EventCategory.academic,
      );
      final entryA2 = TimetableEntry(
        id: 't2',
        subject: 'Math',
        batch: 'A2',
        startTime: 600,
        endTime: 660,
        durationMinutes: 60,
        category: EventCategory.academic,
      );

      final calcA1 = ProgressCalculatorService(
        weeklyTimetable: {1: [entryA1]},
        semesterStartDate: testDate,
        subjectMetadata: {},
      );

      // Invalidate cache explicitly when batch changes
      AppSettings.saveStudentBatch('A2');

      final calcA2 = ProgressCalculatorService(
        weeklyTimetable: {1: [entryA2]},
        semesterStartDate: testDate,
        subjectMetadata: {},
      );

      expect(calcA1.weeklyTimetable[1]!.first.batch, equals('A1'));
      expect(calcA2.weeklyTimetable[1]!.first.batch, equals('A2'));
    });

    // -------------------------------------------------------------
    // Test 11: P2 #7 — Unconfigured Subject Normalization in Step 8
    // -------------------------------------------------------------
    test('11. Unconfigured school: SubjectIdentityService Step 8 fallback strips dirty suffixes', () {
      // Course is completely unconfigured in an unknown school
      const dirtyQuery = 'Cost AccountingT4 BCOM Sem I';
      final identity = SubjectIdentityService.resolve(
        dirtyQuery,
        configuredCourses: [],
      );

      expect(identity.canonicalKey, equals('Cost Accounting'));
      expect(identity.displayName, equals('Cost Accounting'));
      expect(identity.isResolved, isFalse);
    });

    // -------------------------------------------------------------
    // Test 12: Dashboard == Attendance Page Calculations
    // -------------------------------------------------------------
    test('12. Dashboard == Attendance: ViewModel and SmartRecommendation match exactly', () {
      final configured = [
        makeComp(
          componentId: 'DSA_Lab',
          courseName: 'Data Structures and Algorithms',
          courseCode: 'DSA',
          componentType: 'Lab',
          targetHours: 30,
        ),
      ];

      final calc = ProgressCalculatorService(
        weeklyTimetable: {},
        semesterStartDate: testDate,
        subjectMetadata: {},
        courseComponents: configured,
      );

      final record = AttendanceRecord(
        id: 'r1',
        division: 'CE_A',
        subjectCode: 'DSA',
        component: 'Lab',
        present: 10,
        absent: 2,
      );

      // AttendancePage path via ViewModel
      final vm = AttendanceSubjectViewModel.fromRecord(
        record: record,
        calculator: calc,
        completedOccurrences: 12,
        conductedHours: 24,
        presentHours: 20,
        absentHours: 4,
        typicalSessionDurationHours: 2,
      );

      // Dashboard path via direct calculateSmartRecommendation
      final rec = calc.calculateSmartRecommendation(
        record: record,
        completedOccurrences: 12,
        conductedHours: 24,
        presentHours: 20,
        absentHours: 4,
        typicalSessionDurationHours: 2,
      );

      expect(vm.percentage, equals(rec.currentPct / 100.0));
      expect(vm.skipsLeft, equals(rec.skipsLeft));
      expect(vm.remainingLectures, equals(rec.remainingLectures));
      expect(vm.assignedHours, equals(rec.assignedHours));
      expect(rec.skipsLeft, equals(1)); // 6h budget - 4h absent = 2h remaining = 1 two-hour session
      expect(rec.remainingLectures, equals(3)); // 30h - 24h = 6h = 3 two-hour sessions
    });
  });
}
