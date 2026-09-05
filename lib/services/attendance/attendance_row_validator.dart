import '../attendance_date_time_parser.dart';
import 'attendance_document_profile.dart';
import 'attendance_reconciliation_report.dart';
import 'raw_attendance_row.dart';

enum ValidationClassification {
  confirmed,
  reviewRequired,
  rejected,
}

/// A validated intermediate attendance row with complete diagnostic traceability.
class ValidatedAttendanceRow {
  final RawAttendanceRow rawRow;
  final DateTime? date;
  final int? startTimeMinutes;
  final int? endTimeMinutes;
  final String? normalizedStatus;
  final ValidationClassification classification;
  final AttendanceRowDiagnostic? diagnostic;

  const ValidatedAttendanceRow({
    required this.rawRow,
    this.date,
    this.startTimeMinutes,
    this.endTimeMinutes,
    this.normalizedStatus,
    required this.classification,
    this.diagnostic,
  });

  bool get isConfirmed => classification == ValidationClassification.confirmed;
  bool get isReviewRequired =>
      classification == ValidationClassification.reviewRequired;
  bool get isRejected => classification == ValidationClassification.rejected;
}

/// Profile-driven attendance row validator.
/// Accounts for every single row with zero silent drops.
class AttendanceRowValidator {
  static ValidatedAttendanceRow validateRow(
    RawAttendanceRow raw,
    AttendanceDocumentProfile profile,
  ) {
    // 1. Required fields check
    if (raw.rawCourseName.trim().isEmpty ||
        raw.rawDate.trim().isEmpty ||
        raw.rawStatus.trim().isEmpty) {
      final diag = AttendanceRowDiagnostic(
        sourceRowNumber: raw.sourceRowNumber,
        pageNumber: raw.pageNumber,
        rawText: raw.rawText,
        failureCode: FailureCode.missingRequiredField,
        failureDescription:
            'Missing essential field (Course, Date, or Status is empty).',
        suggestedResolution: 'Inspect the document line or supply manually.',
        rawRow: raw,
      );
      return ValidatedAttendanceRow(
        rawRow: raw,
        classification: ValidationClassification.rejected,
        diagnostic: diag,
      );
    }

    // 2. Date parsing
    final date = AttendanceDateTimeParser.parseDate(raw.rawDate);
    if (date == null) {
      final diag = AttendanceRowDiagnostic(
        sourceRowNumber: raw.sourceRowNumber,
        pageNumber: raw.pageNumber,
        rawText: raw.rawText,
        failureCode: FailureCode.invalidDateFormat,
        failureDescription:
            'Date "${raw.rawDate}" could not be parsed into a calendar date.',
        suggestedResolution: 'Verify date formatting on source page.',
        rawRow: raw,
      );
      return ValidatedAttendanceRow(
        rawRow: raw,
        classification: ValidationClassification.rejected,
        diagnostic: diag,
      );
    }

    // 3. Status mapping
    final normalizedStatus = profile.mapStatus(raw.rawStatus);

    // 4. Time validation (profile-driven)
    int? startMins;
    int? endMins;

    if (profile.supportsTimeColumns &&
        raw.rawStartTime != null &&
        raw.rawStartTime!.trim().isNotEmpty &&
        raw.rawEndTime != null &&
        raw.rawEndTime!.trim().isNotEmpty) {
      startMins = AttendanceDateTimeParser.parseTimeToMinutes(raw.rawStartTime!);
      endMins = AttendanceDateTimeParser.parseTimeToMinutes(raw.rawEndTime!);

      if (startMins == null || endMins == null) {
        final diag = AttendanceRowDiagnostic(
          sourceRowNumber: raw.sourceRowNumber,
          pageNumber: raw.pageNumber,
          rawText: raw.rawText,
          failureCode: FailureCode.invalidTimeFormat,
          failureDescription:
              'Time string "${raw.rawStartTime} - ${raw.rawEndTime}" could not be parsed.',
          suggestedResolution: 'Check time column extraction.',
          rawRow: raw,
        );
        return ValidatedAttendanceRow(
          rawRow: raw,
          date: date,
          normalizedStatus: normalizedStatus,
          classification: ValidationClassification.reviewRequired,
          diagnostic: diag,
        );
      }

      if (startMins >= endMins) {
        final diag = AttendanceRowDiagnostic(
          sourceRowNumber: raw.sourceRowNumber,
          pageNumber: raw.pageNumber,
          rawText: raw.rawText,
          failureCode: FailureCode.startAfterEndTime,
          failureDescription:
              'Start time ($startMins mins) is at or after end time ($endMins mins).',
          suggestedResolution: 'Check column boundary alignment.',
          rawRow: raw,
        );
        return ValidatedAttendanceRow(
          rawRow: raw,
          date: date,
          startTimeMinutes: startMins,
          endTimeMinutes: endMins,
          normalizedStatus: normalizedStatus,
          classification: ValidationClassification.rejected,
          diagnostic: diag,
        );
      }

      final duration = endMins - startMins;
      if (duration < profile.minDurationMinutes ||
          duration > profile.maxDurationMinutes) {
        final diag = AttendanceRowDiagnostic(
          sourceRowNumber: raw.sourceRowNumber,
          pageNumber: raw.pageNumber,
          rawText: raw.rawText,
          failureCode: FailureCode.durationOutOfRange,
          failureDescription:
              'Duration ($duration mins) is outside profile limits (${profile.minDurationMinutes}-${profile.maxDurationMinutes} mins).',
          suggestedResolution: 'Confirm if this was an irregular lecture session.',
          rawRow: raw,
        );
        return ValidatedAttendanceRow(
          rawRow: raw,
          date: date,
          startTimeMinutes: startMins,
          endTimeMinutes: endMins,
          normalizedStatus: normalizedStatus,
          classification: ValidationClassification.reviewRequired,
          diagnostic: diag,
        );
      }
    }

    if (normalizedStatus == null) {
      final diag = AttendanceRowDiagnostic(
        sourceRowNumber: raw.sourceRowNumber,
        pageNumber: raw.pageNumber,
        rawText: raw.rawText,
        failureCode: FailureCode.unknownStatus,
        failureDescription:
            'Status code "${raw.rawStatus}" is not recognized by ${profile.institutionName}.',
        suggestedResolution:
            'Review status code and assign Present/Absent/Exemption manually.',
        rawRow: raw,
      );
      return ValidatedAttendanceRow(
        rawRow: raw,
        date: date,
        startTimeMinutes: startMins,
        endTimeMinutes: endMins,
        classification: ValidationClassification.reviewRequired,
        diagnostic: diag,
      );
    }

    // 5. Confirmed valid row
    return ValidatedAttendanceRow(
      rawRow: raw,
      date: date,
      startTimeMinutes: startMins,
      endTimeMinutes: endMins,
      normalizedStatus: normalizedStatus,
      classification: ValidationClassification.confirmed,
    );
  }

  /// Validates a list of raw rows and generates an exact reconciliation report.
  static ({
    List<ValidatedAttendanceRow> confirmed,
    List<ValidatedAttendanceRow> reviewRequired,
    List<ValidatedAttendanceRow> rejected,
    AttendanceReconciliationReport report,
  }) validateAll(
    List<RawAttendanceRow> rows,
    AttendanceDocumentProfile profile,
  ) {
    final confirmed = <ValidatedAttendanceRow>[];
    final reviewRequired = <ValidatedAttendanceRow>[];
    final rejected = <ValidatedAttendanceRow>[];
    final diagnostics = <AttendanceRowDiagnostic>[];

    for (final raw in rows) {
      final val = validateRow(raw, profile);
      switch (val.classification) {
        case ValidationClassification.confirmed:
          confirmed.add(val);
        case ValidationClassification.reviewRequired:
          reviewRequired.add(val);
          if (val.diagnostic != null) diagnostics.add(val.diagnostic!);
        case ValidationClassification.rejected:
          rejected.add(val);
          if (val.diagnostic != null) diagnostics.add(val.diagnostic!);
      }
    }

    final report = AttendanceReconciliationReport(
      sourceRows: rows.length,
      confirmed: confirmed.length,
      reviewRequired: reviewRequired.length,
      rejected: rejected.length,
      diagnostics: diagnostics,
    );

    assert(
      report.isSourceReconciled,
      'CRITICAL: Source rows must reconcile exactly! Total: ${rows.length} != ${confirmed.length} + ${reviewRequired.length} + ${rejected.length}',
    );

    return (
      confirmed: confirmed,
      reviewRequired: reviewRequired,
      rejected: rejected,
      report: report,
    );
  }
}
