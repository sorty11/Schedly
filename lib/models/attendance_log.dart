import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/attendance/academic_grouping_policy.dart';
import '../services/subject_identity_service.dart';

enum MatchConfidence {
  exact(100, 'Exact match'),
  alias(90, 'Matched via alias'),
  normalized(80, 'Matched after normalization'),
  fuzzy(60, 'Fuzzy match'),
  unknown(0, 'Unknown subject');

  final int score;
  final String description;
  const MatchConfidence(this.score, this.description);
}

class AttendanceLog {
  final String id; // format: {division}_{dateStr}_{startTime}_{endTime}
  final String
  subjectCode; // Extracted or matched subject code (this might be the canonical id or the raw fallback)
  final String component; // Extracted or matched component
  final String rawSubjectText; // What was actually in the PDF
  final String? normalizedSubject; // Stripped string
  final String? canonicalSubjectId; // The resolved canonical ID
  final DateTime date;
  final int? startTime; // minutes from midnight (nullable for timeless formats)
  final int? endTime;
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
    this.normalizedSubject,
    this.canonicalSubjectId,
    required this.date,
    this.startTime,
    this.endTime,
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
    MatchConfidence conf = MatchConfidence.unknown;
    if (score >= 100)
      conf = MatchConfidence.exact;
    else if (score >= 90)
      conf = MatchConfidence.alias;
    else if (score >= 80)
      conf = MatchConfidence.normalized;
    else if (score >= 60)
      conf = MatchConfidence.fuzzy;

    return AttendanceLog(
      id: doc.id,
      subjectCode: data['subjectCode'] ?? '',
      component: data['component'] ?? 'Theory',
      rawSubjectText: data['rawSubjectText'] ?? '',
      normalizedSubject: data['normalizedSubject'],
      canonicalSubjectId: data['canonicalSubjectId'],
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      startTime: data['startTime'] ?? 0,
      endTime: data['endTime'] ?? 0,
      status: data['status'] ?? 'unknown',
      source: data['source'] ?? 'unknown',
      confidence: conf,
      timetableEntryId: data['timetableEntryId'],
      importedAt:
          (data['importedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'subjectCode': subjectCode,
      'component': component,
      'rawSubjectText': rawSubjectText,
      'normalizedSubject': normalizedSubject,
      'canonicalSubjectId': canonicalSubjectId,
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

  /// Deterministic identity: date + start + end + course + component.
  String get deduplicationKey => buildDeduplicationKey(
    date: date,
    startTime: startTime,
    endTime: endTime,
    subjectCode: subjectCode,
    component: component,
  );

  static String canonicalSubjectCode(String rawCode) {
    return SubjectIdentityService.getCanonicalKey(rawCode);
  }

  /// Normalizes a component name into a standard form.
  static String normalizeComponent(String comp) {
    return AcademicGroupingPolicy.normalizeComponent(comp);
  }

  /// Deprecated: Generic business logic should use AcademicGroupingPolicy.isSplitCourse.
  @Deprecated('Use AcademicGroupingPolicy.isSplitCourse instead')
  static bool isDsa(String subjectCode) {
    final canon = canonicalSubjectCode(subjectCode);
    return AcademicGroupingPolicy.isSplitCourse(
      canon,
      sectionSplitSubjects: {'DSA', 'DATA STRUCTURES AND ALGORITHMS'},
    );
  }

  /// Returns the canonical display component for a subject.
  /// Delegates to AcademicGroupingPolicy.
  static String canonicalComponent(String subjectCode, String rawComponent) {
    final canon = canonicalSubjectCode(subjectCode);
    return AcademicGroupingPolicy.canonicalComponent(
      canon,
      rawComponent,
      sectionSplitSubjects: {'DSA', 'DATA STRUCTURES AND ALGORITHMS'},
    );
  }

  /// Returns the canonical card/grouping key.
  /// Delegates to AcademicGroupingPolicy.
  static String canonicalGroupKey(String subjectCode, String rawComponent) {
    final canon = canonicalSubjectCode(subjectCode);
    return AcademicGroupingPolicy.canonicalGroupKey(
      canon,
      rawComponent,
      sectionSplitSubjects: {'DSA', 'DATA STRUCTURES AND ALGORITHMS'},
    );
  }

  /// Deterministic event identity.
  /// Delegates to AcademicGroupingPolicy. Supports both time-aware and timeless events.
  static String buildDeduplicationKey({
    required DateTime date,
    int? startTime,
    int? endTime,
    required String subjectCode,
    required String component,
  }) {
    final canonSubj = canonicalSubjectCode(subjectCode);
    return AcademicGroupingPolicy.buildDeduplicationKey(
      date: date,
      startTime: startTime,
      endTime: endTime,
      canonicalSubject: canonSubj,
      component: component,
      sectionSplitSubjects: {'DSA', 'DATA STRUCTURES AND ALGORITHMS'},
    );
  }
}
