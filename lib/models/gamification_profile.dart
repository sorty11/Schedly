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
  final String? lastAttendanceExpDate;
  final int weeklyExp;
  final String? weeklyPeriod;
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
    this.weeklyExp = 0,
    this.weeklyPeriod,
    this.lastDailyExpClaimDate,
    this.lastAttendanceExpDate,
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
      weeklyExp: (data['weeklyExp'] as num?)?.toInt() ?? 0,
      weeklyPeriod: data['weeklyPeriod'] as String? ?? data['weekKey'] as String?,
      lastDailyExpClaimDate: data['lastDailyClaimDate'] as String? ?? data['lastDailyExpClaimDate'] as String?,
      lastAttendanceExpDate: data['lastAttendanceClaimDate'] as String? ?? data['lastAttendanceExpDate'] as String?,
      lastTimetableActionAt: (data['lastTimetableActionAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  factory GamificationProfile.fromChampionDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final championUid = data['championUid'] as String?;
    if (championUid == null || championUid.isEmpty) {
      return const GamificationProfile(
        uid: '',
        displayName: 'No Champion',
      );
    }
    return GamificationProfile(
      uid: championUid,
      displayName: data['displayName'] as String? ?? 'Champion',
      photoUrl: data['photoUrl'] as String?,
      division: data['academicContext'] as String? ?? '',
      weeklyExp: (data['weeklyExp'] as num?)?.toInt() ?? 0,
      weeklyPeriod: data['weekKey'] as String?,
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
