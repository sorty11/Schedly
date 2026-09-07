import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceRecord {
  final String id; // '{division}_{subjectCode}_{component}'
  final String division;
  final String subjectCode;
  final String component;
  final int present;
  final int absent;
  final int cancelled; // student-marked (lecture was cancelled, doesn't count)
  final Map<String, String>
  markedInstances; // Stores instance IDs to mark types ('present', 'absent', 'cancelled')
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

  // How many more lectures can be missed while staying >70% (strict, Smart Attendance target)
  int get canMiss => canMissFor(0.70, strict: true);

  // How many must be attended to recover to ≥70%
  int get needToAttend => needToAttendFor(0.70);

  /// Computes how many lectures can be missed while staying above [targetPct] (e.g. 0.70 or 0.80).
  /// If [strict] is true, enforces strictly `>` (required by SOL 70% rules: 7/10 -> 0, 7/9 -> 0).
  /// If [strict] is false, allows `present / (total + n) >= targetPct`.
  int canMissFor(double targetPct, {bool strict = false}) {
    if (total == 0 || (strict ? percentage <= targetPct : percentage < targetPct)) {
      return 0;
    }
    int n = 0;
    while (true) {
      final nextTotal = total + n + 1;
      final nextPct = present / nextTotal;
      if (strict ? (nextPct > targetPct) : (nextPct >= targetPct - 1e-9)) {
        n++;
      } else {
        break;
      }
    }
    return n;
  }

  /// Computes how many lectures must be attended to recover to >= [targetPct] (e.g. 0.70)
  int needToAttendFor(double targetPct) {
    if (percentage >= targetPct) return 0;
    // (present + x) / (total + x) >= targetPct  →  x >= (targetPct*total - present) / (1 - targetPct)
    final need = ((targetPct * total - present) / (1.0 - targetPct)).ceil();
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
