import 'package:cloud_firestore/cloud_firestore.dart';

enum MatchConfidence {
  perfect(90, 'Perfect match'),
  normalized(80, 'Matched after normalization'),
  fuzzy(60, 'Fuzzy match'),
  unmatched(0, 'Unmatched');

  final int score;
  final String description;
  const MatchConfidence(this.score, this.description);
}

class AttendanceLog {
  final String id; // format: {division}_{dateStr}_{startTime}_{endTime}
  final String subjectCode; // Extracted or matched subject code
  final String component; // Extracted or matched component
  final String rawSubjectText; // What was actually in the PDF
  final DateTime date;
  final int startTime; // minutes from midnight
  final int endTime;
  final String status; // 'present' or 'absent'
  final String source; // 'pdf_import' or 'manual'
  final MatchConfidence confidence;
  final String? timetableEntryId; // Optional link to timetable
  final DateTime importedAt;

  AttendanceLog({
    required this.id,
    required this.subjectCode,
    required this.component,
    required this.rawSubjectText,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.source,
    required this.confidence,
    this.timetableEntryId,
    DateTime? importedAt,
  }) : importedAt = importedAt ?? DateTime.now();

  factory AttendanceLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    
    // Fallback parsing for confidence
    final score = data['confidenceScore'] as int? ?? 0;
    MatchConfidence conf = MatchConfidence.unmatched;
    if (score >= 90) conf = MatchConfidence.perfect;
    else if (score >= 80) conf = MatchConfidence.normalized;
    else if (score >= 60) conf = MatchConfidence.fuzzy;

    return AttendanceLog(
      id: doc.id,
      subjectCode: data['subjectCode'] ?? '',
      component: data['component'] ?? 'Theory',
      rawSubjectText: data['rawSubjectText'] ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      startTime: data['startTime'] ?? 0,
      endTime: data['endTime'] ?? 0,
      status: data['status'] ?? 'unknown',
      source: data['source'] ?? 'unknown',
      confidence: conf,
      timetableEntryId: data['timetableEntryId'],
      importedAt: (data['importedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'subjectCode': subjectCode,
      'component': component,
      'rawSubjectText': rawSubjectText,
      'date': Timestamp.fromDate(date),
      'startTime': startTime,
      'endTime': endTime,
      'status': status,
      'source': source,
      'confidenceScore': confidence.score,
      'timetableEntryId': timetableEntryId,
      'importedAt': FieldValue.serverTimestamp(),
    };
  }

  // Idempotent key for deduplication
  String get deduplicationKey => '\${date.year}-\${date.month}-\${date.day}_\${startTime}_\${subjectCode}_\$component';
}
