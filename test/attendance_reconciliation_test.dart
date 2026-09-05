import 'package:flutter_test/flutter_test.dart';
import 'package:schedly/models/attendance_import_models.dart';
import 'package:schedly/models/attendance_log.dart';
import 'package:schedly/services/attendance/attendance_document_profile.dart';
import 'package:schedly/services/attendance/attendance_reconciliation_report.dart';
import 'package:schedly/services/attendance/attendance_row_validator.dart';
import 'package:schedly/services/attendance/progressive_attendance_reconciler.dart';
import 'package:schedly/services/attendance/raw_attendance_row.dart';

void main() {
  final profile = NmimsSapDocumentProfile();

  group('Attendance Reconciliation Report & Row Accounting Tests', () {
    test('1. Two-Stage Reconciliation Invariant: Source rows == Confirmed + ReviewRequired + Rejected', () {
      final rawRows = [
        // Valid row -> Confirmed
        const RawAttendanceRow(
          pageNumber: 1,
          sourceRowNumber: 1,
          rawCourseName: 'Data Structures and Algorithms',
          rawDate: 'Jul 15, 2026',
          rawStartTime: '09:00:00 AM',
          rawEndTime: '10:00:00 AM',
          rawStatus: 'P',
          rawText: '1 Data Structures and Algorithms Jul 15, 2026 09:00:00 AM 10:00:00 AM P',
        ),
        // Irregular duration (420 mins > 360 mins) -> ReviewRequired
        const RawAttendanceRow(
          pageNumber: 1,
          sourceRowNumber: 2,
          rawCourseName: 'Database Management Systems',
          rawDate: 'Jul 15, 2026',
          rawStartTime: '09:00:00 AM',
          rawEndTime: '04:00:00 PM',
          rawStatus: 'A',
          rawText: '2 Database Management Systems Jul 15, 2026 09:00:00 AM 04:00:00 PM A',
        ),
        // Missing course name -> Rejected
        const RawAttendanceRow(
          pageNumber: 1,
          sourceRowNumber: 3,
          rawCourseName: '',
          rawDate: 'Jul 15, 2026',
          rawStartTime: '10:00:00 AM',
          rawEndTime: '11:00:00 AM',
          rawStatus: 'P',
          rawText: '3 Jul 15, 2026 10:00:00 AM 11:00:00 AM P',
        ),
        // Start time after end time -> Rejected
        const RawAttendanceRow(
          pageNumber: 1,
          sourceRowNumber: 4,
          rawCourseName: 'Computer Networks',
          rawDate: 'Jul 15, 2026',
          rawStartTime: '11:00:00 AM',
          rawEndTime: '10:00:00 AM',
          rawStatus: 'P',
          rawText: '4 Computer Networks Jul 15, 2026 11:00:00 AM 10:00:00 AM P',
        ),
        // Unknown status code -> ReviewRequired
        const RawAttendanceRow(
          pageNumber: 1,
          sourceRowNumber: 5,
          rawCourseName: 'Operating Systems',
          rawDate: 'Jul 15, 2026',
          rawStartTime: '11:00:00 AM',
          rawEndTime: '12:00:00 PM',
          rawStatus: 'UNKNOWN_CODE',
          rawText: '5 Operating Systems Jul 15, 2026 11:00:00 AM 12:00:00 PM UNKNOWN_CODE',
        ),
      ];

      final result = AttendanceRowValidator.validateAll(rawRows, profile);

      expect(result.confirmed.length, equals(1));
      expect(result.reviewRequired.length, equals(2));
      expect(result.rejected.length, equals(2));

      final report = result.report;
      expect(report.sourceRows, equals(5));
      expect(report.confirmed, equals(1));
      expect(report.reviewRequired, equals(2));
      expect(report.rejected, equals(2));
      expect(report.isSourceReconciled, isTrue);

      // Invariant: Source == Confirmed + Review + Rejected
      expect(report.sourceRows, equals(report.confirmed + report.reviewRequired + report.rejected));
    });

    test('2. Diagnostic tracking on rejected and review-required rows (Zero silent drops)', () {
      final rawRows = [
        const RawAttendanceRow(
          pageNumber: 2,
          sourceRowNumber: 42,
          rawCourseName: 'Web Development',
          rawDate: 'Not-A-Date',
          rawStartTime: '09:00:00 AM',
          rawEndTime: '10:00:00 AM',
          rawStatus: 'P',
          rawText: '42 Web Development Not-A-Date 09:00:00 AM 10:00:00 AM P',
        ),
      ];

      final result = AttendanceRowValidator.validateAll(rawRows, profile);
      expect(result.rejected.length, equals(1));
      expect(result.report.diagnostics.length, equals(1));

      final diag = result.report.diagnostics.first;
      expect(diag.sourceRowNumber, equals(42));
      expect(diag.pageNumber, equals(2));
      expect(diag.failureCode, equals(FailureCode.invalidDateFormat));
      expect(diag.failureDescription, contains('could not be parsed into a calendar date'));
      expect(diag.suggestedResolution, isNotEmpty);
    });

    test('3. Storage Operations Accounting (Stage 2) works and reconciles', () {
      const report = AttendanceReconciliationReport(
        sourceRows: 10,
        confirmed: 8,
        reviewRequired: 2,
        rejected: 0,
      );

      final withStorage = report.copyWithStorage(
        newRecords: 6,
        updatedRecords: 2,
        duplicatesIgnored: 2,
        conflicts: 0,
      );

      expect(withStorage.newRecords, equals(6));
      expect(withStorage.updatedRecords, equals(2));
      expect(withStorage.duplicatesIgnored, equals(2));
      expect(withStorage.isStorageReconciled(2), isTrue); // 8 confirmed + 2 accepted review = 10 total written
    });
  });

  group('Order-Independence & Commutativity Invariant Tests', () {
    AttendanceLog makeLog({
      required String id,
      required String subjectCode,
      required String component,
      required DateTime date,
      required int startTime,
      required int endTime,
      required String status,
      required DateTime importedAt,
    }) {
      return AttendanceLog(
        id: id,
        subjectCode: subjectCode,
        component: component,
        rawSubjectText: subjectCode,
        normalizedSubject: subjectCode,
        date: date,
        startTime: startTime,
        endTime: endTime,
        status: status,
        source: 'pdf_import',
        confidence: MatchConfidence.exact,
        importedAt: importedAt,
      );
    }

    test('4. Monotonic progression: NU -> Present overrides, but NU cannot overwrite Present', () {
      final date = DateTime(2026, 7, 20);

      final logNU = makeLog(
        id: 'log1',
        subjectCode: 'DSA',
        component: 'Theory',
        date: date,
        startTime: 540,
        endTime: 600,
        status: 'not_updated',
        importedAt: DateTime(2026, 7, 21),
      );

      final logP = makeLog(
        id: 'log1',
        subjectCode: 'DSA',
        component: 'Theory',
        date: date,
        startTime: 540,
        endTime: 600,
        status: 'present',
        importedAt: DateTime(2026, 7, 22),
      );

      // Reconcile logP over existing logNU
      final updateResult = ProgressiveAttendanceReconciler.reconcile(
        incomingLogs: [logP],
        existingLogs: [logNU],
      );
      expect(updateResult.updatedRecords, equals(1));
      expect(updateResult.reconciledLogs.first.status, equals('present'));

      // Reconcile older logNU over existing logP -> should NOT overwrite
      final noopResult = ProgressiveAttendanceReconciler.reconcile(
        incomingLogs: [logNU],
        existingLogs: [logP],
      );
      expect(noopResult.updatedRecords, equals(0));
      expect(noopResult.duplicatesIgnored, equals(1));
      expect(noopResult.reconciledLogs.first.status, equals('present'));
    });

    test('5. Order independence commutativity invariant: import(A then B) == import(B then A)', () {
      final date1 = DateTime(2026, 7, 10);
      final date2 = DateTime(2026, 7, 11);
      final reportDateA = DateTime(2026, 7, 12);
      final reportDateB = DateTime(2026, 7, 15);

      // Snapshot A has lecture 1 (present) and lecture 2 (not_updated)
      final logsA = [
        makeLog(
          id: 'lec1',
          subjectCode: 'DM',
          component: 'Merged',
          date: date1,
          startTime: 600,
          endTime: 660,
          status: 'present',
          importedAt: reportDateA,
        ),
        makeLog(
          id: 'lec2',
          subjectCode: 'SnS',
          component: 'Merged',
          date: date2,
          startTime: 700,
          endTime: 760,
          status: 'not_updated',
          importedAt: reportDateA,
        ),
      ];

      // Snapshot B has lecture 2 updated to present, and lecture 3 (new)
      final logsB = [
        makeLog(
          id: 'lec2',
          subjectCode: 'SnS',
          component: 'Merged',
          date: date2,
          startTime: 700,
          endTime: 760,
          status: 'present',
          importedAt: reportDateB,
        ),
        makeLog(
          id: 'lec3',
          subjectCode: 'COA',
          component: 'Merged',
          date: DateTime(2026, 7, 13),
          startTime: 540,
          endTime: 600,
          status: 'absent',
          importedAt: reportDateB,
        ),
      ];

      final isCommutative = ProgressiveAttendanceReconciler.verifyCommutativity(
        logsA: logsA,
        logsB: logsB,
        reportDateA: reportDateA,
        reportDateB: reportDateB,
      );

      expect(isCommutative, isTrue);

      // Perform both import orders and inspect states directly
      final orderAB = ProgressiveAttendanceReconciler.reconcile(
        incomingLogs: logsB,
        existingLogs: logsA,
        incomingReportDate: reportDateB,
      );

      final orderBA = ProgressiveAttendanceReconciler.reconcile(
        incomingLogs: logsA,
        existingLogs: logsB,
        incomingReportDate: reportDateA,
      );

      expect(orderAB.reconciledLogs.length, equals(3));
      expect(orderBA.reconciledLogs.length, equals(3));

      final mapAB = {for (final l in orderAB.reconciledLogs) l.deduplicationKey: l.status};
      final mapBA = {for (final l in orderBA.reconciledLogs) l.deduplicationKey: l.status};

      expect(mapAB, equals(mapBA));
      expect(mapAB['2026-7-11_700_760_SnS'], equals('present'));
    });
  });
}
