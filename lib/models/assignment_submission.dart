import 'package:cloud_firestore/cloud_firestore.dart';

enum SubmissionStatus {
  pending,
  submitted,
  overdue,
}

class AssignmentSubmission {
  final String assignmentId;
  final String studentId;
  final String sectionId;
  final bool isSubmitted;
  final DateTime? submittedAt;

  const AssignmentSubmission({
    required this.assignmentId,
    required this.studentId,
    required this.sectionId,
    required this.isSubmitted,
    this.submittedAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'assignmentId': assignmentId,
      'studentId': studentId,
      'sectionId': sectionId,
      'isSubmitted': isSubmitted,
      'submittedAt':
          submittedAt != null ? Timestamp.fromDate(submittedAt!) : null,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory AssignmentSubmission.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return AssignmentSubmission.fromMap(data, id: doc.id);
  }

  factory AssignmentSubmission.fromMap(Map<String, dynamic> map, {String? id}) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return null;
    }

    return AssignmentSubmission(
      assignmentId:
          map['assignmentId']?.toString() ?? id ?? '',
      studentId: map['studentId']?.toString() ?? '',
      sectionId: map['sectionId']?.toString() ?? '',
      isSubmitted: map['isSubmitted'] == true || map['submitted'] == true,
      submittedAt: parseDate(map['submittedAt']),
    );
  }
}

class AssignmentReminderPreference {
  final bool remind24h;
  final bool remind6h;
  final bool remind1h;

  const AssignmentReminderPreference({
    this.remind24h = true,
    this.remind6h = true,
    this.remind1h = true,
  });

  bool isEnabledFor(String window) {
    switch (window.toLowerCase()) {
      case '24h':
        return remind24h;
      case '6h':
        return remind6h;
      case '1h':
        return remind1h;
      default:
        return true;
    }
  }

  AssignmentReminderPreference copyWith({
    bool? remind24h,
    bool? remind6h,
    bool? remind1h,
  }) {
    return AssignmentReminderPreference(
      remind24h: remind24h ?? this.remind24h,
      remind6h: remind6h ?? this.remind6h,
      remind1h: remind1h ?? this.remind1h,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      '24h': remind24h,
      '6h': remind6h,
      '1h': remind1h,
    };
  }

  factory AssignmentReminderPreference.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const AssignmentReminderPreference();
    return AssignmentReminderPreference(
      remind24h: map['24h'] ?? map['remind24h'] ?? true,
      remind6h: map['6h'] ?? map['remind6h'] ?? true,
      remind1h: map['1h'] ?? map['remind1h'] ?? true,
    );
  }
}
