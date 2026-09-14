import 'attendance_log.dart';
import 'attendance_record.dart';
import '../services/progress_calculator_service.dart';
import '../services/subject_identity_service.dart';

/// Clean view-model encapsulating all presentation data for a single subject
/// card on the Student Attendance page.
class AttendanceSubjectViewModel {
  /// The canonical subject code (e.g., 'DATA STRUCTURES AND ALGORITHMS').
  final String subjectCode;

  /// The component type ('Theory', 'Lab', or 'Merged').
  final String component;

  /// Total present lectures recorded.
  final int present;

  /// Total absent lectures recorded.
  final int absent;

  /// Total conducted lectures recorded (present + absent).
  final int total;

  /// Attendance percentage between 0.0 and 1.0.
  final double percentage;

  /// Number of skips remaining before falling below 80%.
  /// Negative values indicate defaulter deficit.
  final int skipsLeft;

  /// Authoritative configured course hours from Course Details
  /// (`sections/{division}/subjects/{componentId}.targetHours`).
  /// Null if not configured or missing in Firestore.
  final int? assignedHours;

  /// Exact remaining lectures in the semester, or null if the semester
  /// capacity cannot be reliably calculated without fabricating data.
  final int? remainingLectures;

  /// Raw underlying attendance records.
  final List<AttendanceRecord> rawRecords;

  /// Whether the subject matching is unresolved or ambiguous and needs review.
  final bool needsReview;

  /// Non-blocking message or note when needsReview is true.
  final String? reviewMessage;

  /// Authoritative Smart Attendance Recommendation.
  final SmartAttendanceRecommendation? recommendation;

  const AttendanceSubjectViewModel({
    required this.subjectCode,
    required this.component,
    required this.present,
    required this.absent,
    required this.total,
    required this.percentage,
    required this.skipsLeft,
    this.assignedHours,
    this.remainingLectures,
    this.rawRecords = const [],
    this.needsReview = false,
    this.reviewMessage,
    this.recommendation,
  });

  /// Factory constructor to build an [AttendanceSubjectViewModel] from an
  /// [AttendanceRecord] and [ProgressCalculatorService].
  factory AttendanceSubjectViewModel.fromRecord({
    required AttendanceRecord record,
    required ProgressCalculatorService calculator,
    List<AttendanceRecord> rawRecords = const [],
    int? completedOccurrences,
    int? conductedHours,
    int? presentHours,
    int? absentHours,
    int? typicalSessionDurationHours,
    double? requiredAttendance,
  }) {
    final rec = calculator.calculateSmartRecommendation(
      record: record,
      completedOccurrences: completedOccurrences,
      conductedHours: conductedHours,
      presentHours: presentHours,
      absentHours: absentHours,
      typicalSessionDurationHours: typicalSessionDurationHours,
      requiredAttendance: requiredAttendance,
    );

    final identity = SubjectIdentityService.resolve(
      record.subjectCode,
      configuredCourses: calculator.courseComponents,
    );
    final needsReview = !identity.isResolved ||
        identity.isAmbiguous ||
        identity.confidence == MatchConfidence.unknown;
    final reviewMessage = identity.statusMessage ??
        (needsReview ? 'Subject matching needs review' : null);

    return AttendanceSubjectViewModel(
      subjectCode: record.subjectCode,
      component: record.component,
      present: record.present,
      absent: record.absent,
      total: record.present + record.absent,
      percentage: rec.currentPct / 100.0,
      skipsLeft: rec.skipsLeft,
      assignedHours: rec.assignedHours,
      remainingLectures: rec.remainingLectures,
      rawRecords: rawRecords,
      needsReview: needsReview,
      reviewMessage: reviewMessage,
      recommendation: rec,
    );
  }

  /// Formatted assigned hours label, e.g. "45 hrs assigned" or "Hours not configured".
  String get assignedHoursLabel {
    if (assignedHours != null && assignedHours! > 0) {
      return '$assignedHours hrs assigned';
    }
    return 'Hours not configured';
  }

  /// Formatted remaining lectures label, e.g. "38 lectures remaining", "1 lecture remaining", or "Remaining lectures unavailable".
  String get remainingLecturesLabel {
    if (remainingLectures != null) {
      return remainingLectures == 1
          ? '1 lecture remaining'
          : '$remainingLectures lectures remaining';
    }
    return 'Remaining lectures unavailable';
  }
}
