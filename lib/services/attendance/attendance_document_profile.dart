/// Contract for school- and document-specific format profiles.
/// All format differences live here, keeping generic pipelines clean and decoupled.
abstract class AttendanceDocumentProfile {
  /// Unique identifier for this document profile (e.g. 'nmims_sap', 'generic_table').
  String get profileId;

  /// Human-readable institution name.
  String get institutionName;

  /// True if the document format includes lecture start and end times.
  /// If false, times are nullable and timeless event identity is used.
  bool get supportsTimeColumns;

  /// Minimum allowable duration in minutes for time-aware formats (0 if timeless).
  int get minDurationMinutes;

  /// Maximum allowable duration in minutes for time-aware formats (0 if timeless).
  int get maxDurationMinutes;

  /// Synonyms for the Course / Subject column header.
  List<String> get recognizedCourseHeaders;

  /// Synonyms for the Date column header.
  List<String> get recognizedDateHeaders;

  /// Synonyms for the Start Time column header.
  List<String> get recognizedStartHeaders;

  /// Synonyms for the End Time column header.
  List<String> get recognizedEndHeaders;

  /// Synonyms for the Attendance / Status column header.
  List<String> get recognizedStatusHeaders;

  /// Synonyms for the Serial / Row Number column header.
  List<String> get recognizedSrHeaders;

  /// Maps a raw status code (e.g. 'P', 'A', 'NU', 'E', 'L') to standard normalized status.
  /// Returns null if status code is unknown / requires review.
  String? mapStatus(String rawStatus);

  /// Explicit legacy migration fallback ONLY for existing unconfigured sections.
  /// New and healthy configurations must declare component separation via
  /// section configuration, CourseComponent.trackSeparately, or splitSubjects.
  Set<String> get legacyMigrationSplitSubjects;

  /// Calculates a confidence score (0.0 to 1.0) indicating how well the input lines match this profile.
  double scoreMatch({
    required List<String> sampleLines,
    required Set<String> detectedHeaderTokens,
  });
}

/// Profile for NMIMS / SVKM SAP student attendance reports.
class NmimsSapDocumentProfile implements AttendanceDocumentProfile {
  @override
  String get profileId => 'nmims_sap';

  @override
  String get institutionName => 'NMIMS / SVKM SAP System';

  @override
  bool get supportsTimeColumns => true;

  @override
  int get minDurationMinutes => 15;

  @override
  int get maxDurationMinutes => 360;

  @override
  List<String> get recognizedCourseHeaders => [
        'course name',
        'course',
        'subject',
        'subject name',
      ];

  @override
  List<String> get recognizedDateHeaders => [
        'lecture date',
        'date',
        'class date',
      ];

  @override
  List<String> get recognizedStartHeaders => [
        'start time',
        'from time',
        'from',
        'start',
      ];

  @override
  List<String> get recognizedEndHeaders => [
        'end time',
        'to time',
        'to',
        'end',
      ];

  @override
  List<String> get recognizedStatusHeaders => [
        'attendance',
        'status',
        'attendance status',
        'present/absent',
      ];

  @override
  List<String> get recognizedSrHeaders => [
        'sr no.',
        'sr. no.',
        'sr no',
        'sr.no.',
        'sl no',
        '#',
      ];

  @override
  String? mapStatus(String rawStatus) {
    final s = rawStatus.trim().toUpperCase();
    switch (s) {
      case 'P':
      case 'PRESENT':
        return 'present';
      case 'A':
      case 'ABSENT':
        return 'absent';
      case 'NU':
      case 'NOT UPDATED':
      case 'NOT_UPDATED':
        return 'not_updated';
      case 'E':
      case 'EXEMPTION':
      case 'EXEMPTED':
        return 'exemption';
      case 'L':
      case 'LATE':
      case 'LATE ADMISSION':
      case 'LATE_ADMISSION':
        return 'late_admission';
      default:
        return null;
    }
  }

  @override
  Set<String> get legacyMigrationSplitSubjects => const {'DSA'};

  @override
  double scoreMatch({
    required List<String> sampleLines,
    required Set<String> detectedHeaderTokens,
  }) {
    var score = 0.0;
    final upperTokens = detectedHeaderTokens.map((t) => t.toUpperCase()).toSet();

    if (upperTokens.contains('COURSE') || upperTokens.contains('COURSE NAME')) score += 0.25;
    if (upperTokens.contains('DATE') || upperTokens.contains('LECTURE DATE')) score += 0.25;
    if (upperTokens.contains('ATTENDANCE') || upperTokens.contains('STATUS')) score += 0.25;
    if (upperTokens.contains('START TIME') || upperTokens.contains('FROM')) score += 0.15;
    if (upperTokens.contains('END TIME') || upperTokens.contains('TO')) score += 0.10;

    // Check for SAP specific footer tokens in lines
    for (final line in sampleLines) {
      final l = line.toUpperCase();
      if (l.contains('SVKM') || l.contains('NMIMS') || l.contains('SYSTEM-GENERATED') || l.contains('SAP')) {
        score += 0.20;
        break;
      }
    }

    return score.clamp(0.0, 1.0);
  }
}

/// Generic tabular document profile for unknown or alternative universities.
class GenericTableDocumentProfile implements AttendanceDocumentProfile {
  @override
  final String profileId;

  @override
  final String institutionName;

  @override
  final bool supportsTimeColumns;

  @override
  final int minDurationMinutes;

  @override
  final int maxDurationMinutes; // Accommodates full-day clinical/lab sessions

  const GenericTableDocumentProfile({
    this.profileId = 'generic_table',
    this.institutionName = 'Generic Tabular Institution',
    this.supportsTimeColumns = true,
    this.minDurationMinutes = 5,
    this.maxDurationMinutes = 720,
  });

  @override
  List<String> get recognizedCourseHeaders => [
        'course',
        'subject',
        'module',
        'paper',
        'topic',
        'course name',
        'subject name',
      ];

  @override
  List<String> get recognizedDateHeaders => [
        'date',
        'day',
        'lecture date',
        'class date',
      ];

  @override
  List<String> get recognizedStartHeaders => [
        'start',
        'start time',
        'from',
        'time in',
      ];

  @override
  List<String> get recognizedEndHeaders => [
        'end',
        'end time',
        'to',
        'time out',
      ];

  @override
  List<String> get recognizedStatusHeaders => [
        'attendance',
        'status',
        'mark',
        'present',
      ];

  @override
  List<String> get recognizedSrHeaders => [
        'sr',
        'sr.',
        'sr no',
        'sl',
        '#',
        'no',
      ];

  @override
  String? mapStatus(String rawStatus) {
    final s = rawStatus.trim().toUpperCase();
    switch (s) {
      case 'P':
      case 'PRESENT':
      case '1':
        return 'present';
      case 'A':
      case 'ABSENT':
      case '0':
        return 'absent';
      case 'NU':
      case 'NOT UPDATED':
      case '-':
        return 'not_updated';
      case 'E':
      case 'EXEMPT':
        return 'exemption';
      case 'L':
      case 'LATE':
        return 'late_admission';
      default:
        return null;
    }
  }

  @override
  Set<String> get legacyMigrationSplitSubjects => const {};

  @override
  double scoreMatch({
    required List<String> sampleLines,
    required Set<String> detectedHeaderTokens,
  }) {
    var score = 0.0;
    final upperTokens = detectedHeaderTokens.map((t) => t.toUpperCase()).toSet();

    if (upperTokens.any((t) => t.contains('COURSE') || t.contains('SUBJECT'))) score += 0.3;
    if (upperTokens.any((t) => t.contains('DATE'))) score += 0.3;
    if (upperTokens.any((t) => t.contains('ATTEND') || t.contains('STATUS'))) score += 0.3;

    return score.clamp(0.0, 1.0);
  }
}

/// Central registry and detector for document profiles.
class AttendanceDocumentDetector {
  static final List<AttendanceDocumentProfile> _registeredProfiles = [
    NmimsSapDocumentProfile(),
    GenericTableDocumentProfile(),
  ];

  /// Registers a custom or institution-specific document profile.
  static void registerProfile(AttendanceDocumentProfile profile) {
    _registeredProfiles.removeWhere((p) => p.profileId == profile.profileId);
    _registeredProfiles.insert(0, profile);
  }

  /// Evaluates sample text lines and detected header tokens to pick the best profile.
  static AttendanceDocumentProfile detectProfile({
    required List<String> sampleLines,
    required Set<String> detectedHeaderTokens,
  }) {
    AttendanceDocumentProfile bestProfile = GenericTableDocumentProfile();
    double bestScore = 0.0;

    for (final profile in _registeredProfiles) {
      final score = profile.scoreMatch(
        sampleLines: sampleLines,
        detectedHeaderTokens: detectedHeaderTokens,
      );
      if (score > bestScore) {
        bestScore = score;
        bestProfile = profile;
      }
    }

    return bestProfile;
  }
}
