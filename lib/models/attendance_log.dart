import 'package:cloud_firestore/cloud_firestore.dart';

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
    this.normalizedSubject,
    this.canonicalSubjectId,
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
    final trimmed = rawCode.trim();
    if (trimmed.isEmpty) return trimmed;
    final upper = trimmed.toUpperCase();

    if (upper == 'DSA' || upper.contains('DATA STRUCTURES')) return 'DSA';
    if (upper == 'COA' || upper.contains('ORGANIZATION AND ARCHITECTUR')) {
      return 'COA';
    }
    if (upper == 'PEM' || upper.contains('ECONOMICS AND MANAGEMEN')) {
      return 'PEM';
    }
    if (upper == 'DM' || upper.contains('DISCRETE MATHEMATICS')) return 'DM';
    if (upper == 'SNS' || upper.contains('SIGNALS AND SYSTEMS')) return 'SnS';
    if (upper == 'PNS' || upper.contains('PROBABILITY AND STATISTICS')) {
      return 'PnS';
    }
    if (upper == 'PYTHON' || upper.contains('PYTHON')) return 'Python';
    if (upper == 'TC' || upper.contains('TECHNICAL COMMUNICATION')) return 'TC';
    if (upper == 'PE' || upper.contains('PROMPT ENGINEERING')) {
      return 'Prompt Engineering for ChatGPT';
    }

    return trimmed;
  }

  static bool isDsa(String subjectCode) {
    final upper = subjectCode.trim().toUpperCase();
    return upper == 'DSA' || upper.contains('DATA STRUCTURES');
  }

  /// Deterministic identity:
  /// For DSA: course + component + date + start/end
  /// For merged courses: course + date + start/end
  static String buildDeduplicationKey({
    required DateTime date,
    required int startTime,
    required int endTime,
    required String subjectCode,
    required String component,
  }) {
    final canonSubj = canonicalSubjectCode(subjectCode);
    final compPart = isDsa(canonSubj) ? '_$component' : '';
    return '${date.year}-${date.month}-${date.day}_${startTime}_${endTime}_$canonSubj$compPart'
        .replaceAll(RegExp(r'\s+'), '_');
  }
}
