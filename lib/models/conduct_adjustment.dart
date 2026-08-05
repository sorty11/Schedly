import 'package:cloud_firestore/cloud_firestore.dart';

class ConductAdjustment {
  final String id;
  final String subject;
  final String component;
  final String batch;
  final int adjustmentHours;
  final String reason;
  final String createdBy;
  final String createdByUid;
  final DateTime createdAt;

  ConductAdjustment({
    required this.id,
    required this.subject,
    required this.component,
    required this.batch,
    required this.adjustmentHours,
    required this.reason,
    required this.createdBy,
    required this.createdByUid,
    required this.createdAt,
  });

  factory ConductAdjustment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ConductAdjustment(
      id: doc.id,
      subject: data['subject'] ?? '',
      component: data['component'] ?? 'Theory',
      batch: data['batch'] ?? 'Whole Class',
      adjustmentHours: data['adjustmentHours'] ?? 0,
      reason: data['reason'] ?? 'Manual correction',
      createdBy: data['createdBy'] ?? 'Unknown',
      createdByUid: data['createdByUid'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'subject': subject,
      'component': component,
      'batch': batch,
      'adjustmentHours': adjustmentHours,
      'reason': reason,
      'createdBy': createdBy,
      'createdByUid': createdByUid,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
