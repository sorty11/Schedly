import 'raw_attendance_row.dart';

/// Machine-readable failure codes for non-confirmed attendance rows.
enum FailureCode {
  invalidDateFormat,
  invalidTimeFormat,
  startAfterEndTime,
  durationOutOfRange,
  unknownStatus,
  ambiguousCourse,
  missingRequiredField,
  malformedRow,
}

/// Rich diagnostic information explaining why a specific row was rejected or flagged for review.
class AttendanceRowDiagnostic {
  final int sourceRowNumber;
  final int pageNumber;
  final String rawText;
  final FailureCode failureCode;
  final String failureDescription;
  final String suggestedResolution;
  final RawAttendanceRow? rawRow;

  const AttendanceRowDiagnostic({
    required this.sourceRowNumber,
    required this.pageNumber,
    required this.rawText,
    required this.failureCode,
    required this.failureDescription,
    required this.suggestedResolution,
    this.rawRow,
  });

  @override
  String toString() =>
      'Diagnostic(row: $sourceRowNumber, code: ${failureCode.name}, reason: $failureDescription)';
}

/// Universal two-stage reconciliation report guaranteeing 100% row accounting.
/// Never silently drops or loses an extracted PDF row.
class AttendanceReconciliationReport {
  // --- Stage 1: Source Document Extraction Accounting ---
  /// Total rows extracted from the source document.
  final int sourceRows;

  /// Rows that passed validation with high confidence.
  final int confirmed;

  /// Rows requiring user review or disambiguation.
  final int reviewRequired;

  /// Completely invalid or malformed rows that cannot be imported.
  final int rejected;

  /// Detailed diagnostics for every rejected or review row.
  final List<AttendanceRowDiagnostic> diagnostics;

  // --- Stage 2: Database / Storage Operations Accounting ---
  /// Newly created unique attendance records in storage.
  final int newRecords;

  /// Existing records whose status was updated (e.g., NU -> P/A).
  final int updatedRecords;

  /// Redundant identical records skipped without state modification.
  final int duplicatesIgnored;

  /// Conflicting records requiring review.
  final int conflicts;

  const AttendanceReconciliationReport({
    required this.sourceRows,
    required this.confirmed,
    required this.reviewRequired,
    required this.rejected,
    this.diagnostics = const [],
    this.newRecords = 0,
    this.updatedRecords = 0,
    this.duplicatesIgnored = 0,
    this.conflicts = 0,
  });

  /// Invariant: Source rows must exactly equal confirmed + review + rejected.
  bool get isSourceReconciled =>
      sourceRows == (confirmed + reviewRequired + rejected);

  /// Invariant: Storage writes must match processed input.
  bool isStorageReconciled(int acceptedReviewRows) =>
      (confirmed + acceptedReviewRows) ==
      (newRecords + updatedRecords + duplicatesIgnored);

  AttendanceReconciliationReport copyWithStorage({
    required int newRecords,
    required int updatedRecords,
    required int duplicatesIgnored,
    int conflicts = 0,
  }) {
    return AttendanceReconciliationReport(
      sourceRows: sourceRows,
      confirmed: confirmed,
      reviewRequired: reviewRequired,
      rejected: rejected,
      diagnostics: diagnostics,
      newRecords: newRecords,
      updatedRecords: updatedRecords,
      duplicatesIgnored: duplicatesIgnored,
      conflicts: conflicts,
    );
  }

  @override
  String toString() =>
      'ReconciliationReport(source: $sourceRows == confirmed: $confirmed + review: $reviewRequired + rejected: $rejected | storage: new: $newRecords, updated: $updatedRecords, duplicates: $duplicatesIgnored, conflicts: $conflicts)';
}
