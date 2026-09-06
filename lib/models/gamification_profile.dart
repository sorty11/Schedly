import 'package:cloud_firestore/cloud_firestore.dart';

class GamificationProfile {
  final String uid;
  final String displayName;
  final String? photoUrl;
  final String academicYear;
  final String branch;
  final String division;
  final String role;
  final int exp;
  final int crPoints;
  final int srPoints;
  final String? lastDailyExpClaimDate;
  final DateTime? lastTimetableActionAt;
  final DateTime? updatedAt;

  const GamificationProfile({
    required this.uid,
    required this.displayName,
    this.photoUrl,
    this.academicYear = '',
    this.branch = '',
    this.division = '',
    this.role = 'Student',
    this.exp = 0,
    this.crPoints = 0,
    this.srPoints = 0,
    this.lastDailyExpClaimDate,
    this.lastTimetableActionAt,
    this.updatedAt,
  });

  factory GamificationProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return GamificationProfile(
      uid: doc.id,
      displayName: data['displayName'] as String? ?? 'Student',
      photoUrl: data['photoUrl'] as String?,
      academicYear: data['academicYear'] as String? ?? '',
      branch: data['branch'] as String? ?? '',
      division: data['division'] as String? ?? '',
      role: data['role'] as String? ?? 'Student',
      exp: (data['exp'] as num?)?.toInt() ?? 0,
      crPoints: (data['crPoints'] as num?)?.toInt() ?? 0,
      srPoints: (data['srPoints'] as num?)?.toInt() ?? 0,
      lastDailyExpClaimDate: data['lastDailyExpClaimDate'] as String?,
      lastTimetableActionAt: (data['lastTimetableActionAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'displayName': displayName,
      if (photoUrl != null && photoUrl!.isNotEmpty) 'photoUrl': photoUrl,
      'academicYear': academicYear,
      'branch': branch,
      'division': division,
      'role': role,
      'exp': exp,
      'crPoints': crPoints,
      'srPoints': srPoints,
      if (lastDailyExpClaimDate != null)
        'lastDailyExpClaimDate': lastDailyExpClaimDate,
      if (lastTimetableActionAt != null)
        'lastTimetableActionAt': Timestamp.fromDate(lastTimetableActionAt!),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  String get academicContext {
    final parts = <String>[];
    if (academicYear.isNotEmpty) parts.add(academicYear);
    if (branch.isNotEmpty) parts.add(branch);
    if (parts.isEmpty && division.isNotEmpty) {
      parts.add(division.replaceAll('_', ' '));
    }
    return parts.join(' • ');
  }
}
