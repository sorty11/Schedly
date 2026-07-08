import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceRecord {
  final String id; // '{division}_{subjectCode}_{component}'
  final String division;
  final String subjectCode;
  final String component;
  final int present;
  final int absent;
  final int cancelled; // student-marked (lecture was cancelled, doesn't count)
  final Map<String, String> markedInstances; // Stores instance IDs to mark types ('present', 'absent', 'cancelled')
  final DateTime updatedAt;

  AttendanceRecord({
    required this.id,
    required this.division,
    required this.subjectCode,
    required this.component,
    this.present = 0,
    this.absent = 0,
    this.cancelled = 0,
    this.markedInstances = const {},
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  int get total => present + absent; // cancelled doesn't count toward total
  double get percentage => total == 0 ? 0 : present / total;

  // How many more lectures can be missed while staying ≥75%
  int get canMiss {
    // present / (total + x) >= 0.75  →  x <= (present/0.75) - total
    final maxTotal = (present / 0.75).floor();
    final canMissVal = maxTotal - total;
    return canMissVal < 0 ? 0 : canMissVal;
  }

  // How many must be attended to recover to ≥75%
  int get needToAttend {
    if (percentage >= 0.75) return 0;
    // (present + x) / (total + x) >= 0.75  →  x >= (0.75*total - present) / 0.25
    final need = ((0.75 * total - present) / 0.25).ceil();
    return need < 0 ? 0 : need;
  }

  factory AttendanceRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    
    Map<String, String> parsedInstances = {};
    if (data['markedInstances'] is Map) {
      parsedInstances = Map<String, String>.from(data['markedInstances']);
    } else if (data['markedInstances'] is List) {
      // Legacy support if someone already clicked it as a list
      for (final id in data['markedInstances'] as List) {
        parsedInstances[id.toString()] = 'present';
      }
    }

    return AttendanceRecord(
      id: doc.id,
      division: data['division'] ?? '',
      subjectCode: data['subjectCode'] ?? '',
      component: data['component'] ?? 'Theory',
      present: data['present'] ?? 0,
      absent: data['absent'] ?? 0,
      cancelled: data['cancelled'] ?? 0,
      markedInstances: parsedInstances,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'division': division,
    'subjectCode': subjectCode,
    'component': component,
    'present': present,
    'absent': absent,
    'cancelled': cancelled,
    'markedInstances': markedInstances,
    'updatedAt': FieldValue.serverTimestamp(),
  };
}
