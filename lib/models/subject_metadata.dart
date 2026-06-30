import 'package:cloud_firestore/cloud_firestore.dart';

class SubjectMetadata {
  final String id;
  final String subjectName;
  final String courseCode;
  final int totalHours;
  final int credits;
  final String faculty;
  final bool isLab;
  final DateTime createdAt;
  final String? semesterId;
  final String sectionId;

  SubjectMetadata({
    required this.id,
    required this.subjectName,
    this.courseCode = '',
    required this.totalHours,
    this.credits = 0,
    this.faculty = '',
    this.isLab = false,
    required this.createdAt,
    this.semesterId,
    required this.sectionId,
  });

  factory SubjectMetadata.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return SubjectMetadata(
      id: doc.id,
      subjectName: data['subjectName'] ?? '',
      courseCode: data['courseCode'] ?? '',
      totalHours: data['totalHours'] ?? 0,
      credits: data['credits'] ?? 0,
      faculty: data['faculty'] ?? '',
      isLab: data['isLab'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      semesterId: data['semesterId'],
      sectionId: data['sectionId'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'subjectName': subjectName,
      'courseCode': courseCode,
      'totalHours': totalHours,
      'credits': credits,
      'faculty': faculty,
      'isLab': isLab,
      'createdAt': Timestamp.fromDate(createdAt),
      if (semesterId != null) 'semesterId': semesterId,
      'sectionId': sectionId,
    };
  }
}
