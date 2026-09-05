/// Intermediate internal representation of an extracted attendance row from a document.
/// Completely decoupled from Firestore models.
class RawAttendanceRow {
  final String? sourceDocumentId;
  final int pageNumber;
  final int sourceRowNumber;
  final String rawCourseName;
  final String? rawSubjectCode;
  final String? rawComponent;
  final String? rawSection;
  final String? rawBatch;
  final String rawDate;
  final String? rawStartTime; // Nullable for timeless attendance formats
  final String? rawEndTime;   // Nullable for timeless attendance formats
  final String rawStatus;
  final String rawText;
  final double extractionConfidence;

  const RawAttendanceRow({
    this.sourceDocumentId,
    required this.pageNumber,
    required this.sourceRowNumber,
    required this.rawCourseName,
    this.rawSubjectCode,
    this.rawComponent,
    this.rawSection,
    this.rawBatch,
    required this.rawDate,
    this.rawStartTime,
    this.rawEndTime,
    required this.rawStatus,
    required this.rawText,
    this.extractionConfidence = 1.0,
  });

  @override
  String toString() =>
      'RawAttendanceRow(row: $sourceRowNumber, page: $pageNumber, course: $rawCourseName, date: $rawDate, status: $rawStatus)';
}
