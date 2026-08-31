import 'attendance_log.dart';

/// Metadata extracted from the NMIMS/SVKM attendance report header.
class AttendanceReportMetadata {
  final String studentName;
  final String studentNumber;
  final String rollNo;
  final String academicYear;
  final String academicSession;
  final String programName;
  final DateTime? reportStartDate;
  final DateTime? reportEndDate;
  final int pageCount;

  const AttendanceReportMetadata({
    this.studentName = '',
    this.studentNumber = '',
    this.rollNo = '',
    this.academicYear = '',
    this.academicSession = '',
    this.programName = '',
    this.reportStartDate,
    this.reportEndDate,
    this.pageCount = 0,
  });
}

/// A single row parsed from the PDF before course matching.
class ParsedAttendanceRow {
  final int srNo;
  final String rawCourseName;
  final String courseName;
  final String? componentCode;
  final String? batchOrSection;
  final DateTime date;
  final int startTimeMinutes;
  final int endTimeMinutes;
  final String rawStatus;
  final String normalizedStatus;
  final int pageIndex;

  const ParsedAttendanceRow({
    required this.srNo,
    required this.rawCourseName,
    required this.courseName,
    this.componentCode,
    this.batchOrSection,
    required this.date,
    required this.startTimeMinutes,
    required this.endTimeMinutes,
    required this.rawStatus,
    required this.normalizedStatus,
    this.pageIndex = 0,
  });

  String get deduplicationKey =>
      '${date.year}-${date.month}-${date.day}_${startTimeMinutes}_${endTimeMinutes}_${courseName}_${componentCode ?? ''}';
}

/// Result of normalizing a raw PDF course name.
class NormalizedCourseInfo {
  final String courseName;
  final String? componentCode;
  final String componentType;
  final String? batchOrSection;
  final bool parsed;

  const NormalizedCourseInfo({
    required this.courseName,
    this.componentCode,
    this.componentType = 'Theory',
    this.batchOrSection,
    this.parsed = true,
  });
}

/// Course match result when mapping to Schedly courses.
class CourseMatchResult {
  final String subjectCode;
  final String component;
  final MatchConfidence confidence;
  final String? warning;

  const CourseMatchResult({
    required this.subjectCode,
    required this.component,
    required this.confidence,
    this.warning,
  });

  bool get isResolved => confidence != MatchConfidence.unknown;
}

/// Preview shown to the user before committing an import.
class AttendanceImportPreview {
  final AttendanceReportMetadata metadata;
  final List<AttendanceLog> logs;
  final List<ParsedAttendanceRow> unresolvedRows;
  final int presentCount;
  final int absentCount;
  final int exemptionCount;
  final int lateAdmissionCount;
  final int notUpdatedCount;
  final int duplicateCount;
  final int updateCount;
  final int unmatchedCourseCount;
  final List<String> warnings;
  final List<String> errors;
  final bool isImageOnly;
  final int totalPagesParsed;

  const AttendanceImportPreview({
    required this.metadata,
    required this.logs,
    this.unresolvedRows = const [],
    this.presentCount = 0,
    this.absentCount = 0,
    this.exemptionCount = 0,
    this.lateAdmissionCount = 0,
    this.notUpdatedCount = 0,
    this.duplicateCount = 0,
    this.updateCount = 0,
    this.unmatchedCourseCount = 0,
    this.warnings = const [],
    this.errors = const [],
    this.isImageOnly = false,
    this.totalPagesParsed = 0,
  });

  int get totalRows =>
      presentCount +
      absentCount +
      exemptionCount +
      lateAdmissionCount +
      notUpdatedCount;

  int get newCount =>
      (logs.length - duplicateCount - updateCount).clamp(0, logs.length);

  bool get canImport => logs.isNotEmpty && errors.isEmpty && !isImageOnly;

  bool get hasWarnings => warnings.isNotEmpty || unmatchedCourseCount > 0;
}

/// Alias for ParsedAttendanceRow matching requirement naming.
typedef AttendanceImportRow = ParsedAttendanceRow;

/// Result returned after a successful import commit.
class AttendanceImportResult {
  final int imported;
  final int updated;
  final int skippedDuplicates;
  final int aggregatesUpdated;

  const AttendanceImportResult({
    required this.imported,
    this.updated = 0,
    this.skippedDuplicates = 0,
    this.aggregatesUpdated = 0,
  });
}

/// Progress callback while parsing large PDFs.
typedef AttendanceParseProgress =
    void Function({
      required int currentPage,
      required int totalPages,
      required int rowsDetected,
      required String message,
    });

/// Exception thrown when PDF parsing fails in a user-visible way.
class AttendancePdfParseException implements Exception {
  final String message;
  final List<String> details;

  AttendancePdfParseException(this.message, {this.details = const []});

  @override
  String toString() =>
      details.isEmpty ? message : '$message\n${details.join('\n')}';
}
