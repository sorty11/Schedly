import 'package:flutter_test/flutter_test.dart';
import 'package:schedly/models/attendance_import_models.dart';
import 'package:schedly/models/attendance_log.dart';
import 'package:schedly/services/attendance/academic_grouping_policy.dart';
import 'package:schedly/services/attendance/attendance_document_profile.dart';
import 'package:schedly/services/attendance/attendance_row_validator.dart';
import 'package:schedly/services/attendance/progressive_attendance_reconciler.dart';
import 'package:schedly/services/attendance/raw_attendance_row.dart';

void main() {
  group('Timeless Attendance Format Tests', () {
    const timelessProfile = GenericTableDocumentProfile(
      profileId: 'daily_rollcall_timeless',
      institutionName: 'Law School Rollcall',
      supportsTimeColumns: false,
    );

    test('1. Validates timeless attendance rows where start and end times are null', () {
      const rawTimeless = RawAttendanceRow(
        pageNumber: 1,
        sourceRowNumber: 1,
        rawCourseName: 'Constitutional Law',
        rawDate: '15/08/2026',
        rawStartTime: null,
        rawEndTime: null,
        rawStatus: 'P',
        rawText: '1 Constitutional Law 15/08/2026 P',
      );

      final result = AttendanceRowValidator.validateRow(rawTimeless, timelessProfile);

      expect(result.classification, equals(ValidationClassification.confirmed));
      expect(result.startTimeMinutes, isNull);
      expect(result.endTimeMinutes, isNull);
      expect(result.normalizedStatus, equals('present'));
      expect(result.date, equals(DateTime(2026, 8, 15)));
    });

    test('2. Deduplication key formats stably for timeless events', () {
      final date = DateTime(2026, 8, 15);
      final key = AcademicGroupingPolicy.buildDeduplicationKey(
        date: date,
        startTime: null,
        endTime: null,
        canonicalSubject: 'Constitutional Law',
        component: 'Merged',
      );

      expect(key, equals('2026-8-15_timeless_Constitutional_Law'));

      // Verify AttendanceLog.buildDeduplicationKey produces the exact same key
      final logKey = AttendanceLog.buildDeduplicationKey(
        date: date,
        startTime: null,
        endTime: null,
        subjectCode: 'Constitutional Law',
        component: 'Merged',
      );

      expect(logKey, equals(key));

      // With session identifier
      final keyWithSession = AcademicGroupingPolicy.buildDeduplicationKey(
        date: date,
        startTime: null,
        endTime: null,
        canonicalSubject: 'Constitutional Law',
        component: 'Merged',
        sessionIdentifier: 'slot_2',
      );

      expect(keyWithSession, equals('2026-8-15_timeless_Constitutional_Law_slot_2'));
    });

    test('3. Timeless attendance progressive merging works cleanly', () {
      final date = DateTime(2026, 8, 15);

      final log1 = AttendanceLog(
        id: '2026-8-15_timeless_Tort Law_Merged_0',
        subjectCode: 'Tort Law',
        component: 'Merged',
        rawSubjectText: 'Tort Law',
        normalizedSubject: 'Tort Law',
        date: date,
        startTime: null,
        endTime: null,
        status: 'not_updated',
        source: 'pdf_import',
        confidence: MatchConfidence.exact,
        importedAt: DateTime(2026, 8, 16),
      );

      final log2 = AttendanceLog(
        id: '2026-8-15_timeless_Tort Law_Merged_0',
        subjectCode: 'Tort Law',
        component: 'Merged',
        rawSubjectText: 'Tort Law',
        normalizedSubject: 'Tort Law',
        date: date,
        startTime: null,
        endTime: null,
        status: 'present',
        source: 'pdf_import',
        confidence: MatchConfidence.exact,
        importedAt: DateTime(2026, 8, 17),
      );

      final res = ProgressiveAttendanceReconciler.reconcile(
        incomingLogs: [log2],
        existingLogs: [log1],
      );

      expect(res.updatedRecords, equals(1));
      expect(res.reconciledLogs.length, equals(1));
      expect(res.reconciledLogs.first.status, equals('present'));
      expect(res.reconciledLogs.first.startTime, isNull);
      expect(res.reconciledLogs.first.endTime, isNull);
    });
  });
}
