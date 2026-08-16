import 'package:cloud_firestore/cloud_firestore.dart';

enum FacultyRequestType { cancel, addExtra }

enum FacultyRequestStatus { pending, approved, denied }

class FacultyRequest {
  final String id;
  final String facultyId;
  final String facultyName;
  final String division;
  final FacultyRequestType type;
  final FacultyRequestStatus status;
  final String subject;
  final String? reason;

  // For Add Extra
  final DateTime? date;
  final int? startTime;
  final int? endTime;
  final String? room;
  final String? batch;

  // For Cancel
  final String? originalLectureId;

  final DateTime createdAt;
  final DateTime? resolvedAt;

  FacultyRequest({
    required this.id,
    required this.facultyId,
    required this.facultyName,
    required this.division,
    required this.type,
    required this.status,
    required this.subject,
    this.reason,
    this.date,
    this.startTime,
    this.endTime,
    this.room,
    this.batch,
    this.originalLectureId,
    required this.createdAt,
    this.resolvedAt,
  });

  factory FacultyRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return FacultyRequest(
      id: doc.id,
      facultyId: data['facultyId'] ?? '',
      facultyName: data['facultyName'] ?? 'Unknown Faculty',
      division: data['division'] ?? '',
      type: (data['type'] == 'addExtra')
          ? FacultyRequestType.addExtra
          : FacultyRequestType.cancel,
      status: _parseStatus(data['status']),
      subject: data['subject'] ?? '',
      reason: data['reason'],
      date: data['date'] != null ? (data['date'] as Timestamp).toDate() : null,
      startTime: data['startTime'],
      endTime: data['endTime'],
      room: data['room'],
      batch: data['batch'],
      originalLectureId: data['originalLectureId'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      resolvedAt: (data['resolvedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'facultyId': facultyId,
      'facultyName': facultyName,
      'division': division,
      'type': type == FacultyRequestType.addExtra ? 'addExtra' : 'cancel',
      'status': status.name,
      'subject': subject,
      if (reason != null) 'reason': reason,
      if (date != null) 'date': Timestamp.fromDate(date!),
      if (startTime != null) 'startTime': startTime,
      if (endTime != null) 'endTime': endTime,
      if (room != null) 'room': room,
      if (batch != null) 'batch': batch,
      if (originalLectureId != null) 'originalLectureId': originalLectureId,
      'createdAt': Timestamp.fromDate(createdAt),
      if (resolvedAt != null) 'resolvedAt': Timestamp.fromDate(resolvedAt!),
    };
  }

  static FacultyRequestStatus _parseStatus(String? statusStr) {
    switch (statusStr) {
      case 'approved':
        return FacultyRequestStatus.approved;
      case 'denied':
        return FacultyRequestStatus.denied;
      default:
        return FacultyRequestStatus.pending;
    }
  }
}
