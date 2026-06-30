import 'package:cloud_firestore/cloud_firestore.dart';
import 'event_category.dart';
import 'subject_metadata.dart';

class BatchAnalytics {
  final String id; // usually '{subject}_{component}_{batch}'
  final String subject;
  final String component; // 'Theory', 'Lab', 'Tutorial'
  final String batch;
  final EventCategory category;
  final int targetLectures; 
  final int? overrideTarget; // manual CR override
  final int completedLectures;
  final int pendingLectures;
  final int cancelledLectures;

  BatchAnalytics({
    required this.id,
    required this.subject,
    this.component = 'Theory',
    required this.batch,
    required this.category,
    this.targetLectures = 0,
    this.overrideTarget,
    this.completedLectures = 0,
    this.pendingLectures = 0,
    this.cancelledLectures = 0,
  });

  String get displaySubject {
    return '$subject $component'.trim();
  }

  factory BatchAnalytics.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    
    // Attempt to extract subject/batch from ID if missing
    final parts = doc.id.split('_');
    final extractedSubject = data['subject'] ?? (parts.isNotEmpty ? parts[0] : '');
    final extractedBatch = data['batch'] ?? (parts.length > 2 ? parts[2] : 'Whole Class');

    return BatchAnalytics(
      id: doc.id,
      subject: extractedSubject,
      component: data['component'] ?? 'Theory',
      batch: extractedBatch,
      category: EventCategoryExtension.fromString(data['category'] ?? 'academic'),
      targetLectures: data['targetLectures'] ?? 0,
      overrideTarget: data['overrideTarget'],
      completedLectures: data['completedLectures'] ?? 0,
      pendingLectures: data['pendingLectures'] ?? 0,
      cancelledLectures: data['cancelledLectures'] ?? 0,
    );
  }

  int get activeTarget => overrideTarget ?? targetLectures;

  Map<String, dynamic> toFirestore() {
    return {
      'subject': subject,
      'component': component,
      'batch': batch,
      'category': category.name.toLowerCase(),
      'targetLectures': targetLectures,
      if (overrideTarget != null) 'overrideTarget': overrideTarget,
      'completedLectures': completedLectures,
      'pendingLectures': pendingLectures,
      'cancelledLectures': cancelledLectures,
    };
  }
}

class SubjectAnalytics {
  final String subject;
  final List<BatchAnalytics> batches;
  final SubjectMetadata? metadata;

  SubjectAnalytics({required this.subject, required this.batches, this.metadata});

  int get totalCompleted => batches.fold(0, (acc, b) => acc + b.completedLectures);
  int get totalPending => batches.fold(0, (acc, b) => acc + b.pendingLectures);
  int get totalCancelled => batches.fold(0, (acc, b) => acc + b.cancelledLectures);
  
  // Use metadata totalHours if available, else sum up batch targets
  int get totalTarget => metadata?.totalHours ?? batches.fold(0, (acc, b) => acc + b.activeTarget);

  double get completionPercentage {
    if (totalTarget == 0) return 0;
    return totalCompleted / totalTarget;
  }
  
  int get remaining {
    final rem = totalTarget - totalCompleted - totalCancelled;
    return rem < 0 ? 0 : rem;
  }
}
