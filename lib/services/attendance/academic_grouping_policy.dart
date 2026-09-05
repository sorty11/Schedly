import '../../models/course_component.dart';
import 'attendance_document_profile.dart';

/// Centralized academic policy governing how courses and their components are grouped.
/// Completely removes hardcoded subject-name checks (e.g. 'DSA') from generic business logic.
class AcademicGroupingPolicy {
  /// Determines if a canonical subject is configured to split into independent components
  /// (e.g. Theory and Lab) vs merged into a single course card.
  static bool isSplitCourse(
    String canonicalSubject, {
    List<CourseComponent> configuredCourses = const [],
    AttendanceDocumentProfile? profile,
    Set<String> sectionSplitSubjects = const {},
  }) {
    if (canonicalSubject.trim().isEmpty) return false;
    final upperSubj = canonicalSubject.trim().toUpperCase();

    // 1. Explicit section metadata split list (first priority)
    if (sectionSplitSubjects.isNotEmpty) {
      if (sectionSplitSubjects.any((s) => s.trim().toUpperCase() == upperSubj)) {
        return true;
      }
    }

    // 2. Section CourseComponent metadata inspection
    if (configuredCourses.isNotEmpty) {
      // Check if configured courses for this subject explicitly specify split components
      final matchingComps = configuredCourses.where((c) {
        final cNameUpper = c.courseName.trim().toUpperCase();
        final cCodeUpper = c.courseCode.trim().toUpperCase();
        final cIdUpper = c.componentId.trim().toUpperCase();
        return cNameUpper == upperSubj ||
            cCodeUpper == upperSubj ||
            cIdUpper.startsWith('${upperSubj}_');
      }).toList();

      if (matchingComps.isNotEmpty) {
        // If components have separate credit/hour configurations and different component types
        final distinctTypes = matchingComps
            .map((c) => normalizeComponent(c.componentType))
            .toSet();
        if (distinctTypes.length > 1) {
          // If the section configured split metadata, respect it
          if (matchingComps.any((c) => c.componentId.toUpperCase().contains('SPLIT'))) {
            return true;
          }
        }
      }
    }

    // 3. Document profile legacy migration fallback ONLY when section configuration is missing
    if (profile != null && profile.legacyMigrationSplitSubjects.isNotEmpty) {
      if (profile.legacyMigrationSplitSubjects.contains(canonicalSubject)) {
        return true;
      }
    }

    // 4. Default: All components merge into one canonical attendance subject
    return false;
  }

  /// Normalizes a component name into a standard semantic representation.
  static String normalizeComponent(String comp) {
    final lower = comp.trim().toLowerCase();
    if (lower.contains('lab') || lower.contains('practical') || lower == 'p4') {
      return 'Lab';
    }
    if (lower.contains('tutorial') || lower == 'u4') {
      return 'Tutorial';
    }
    if (lower.contains('project')) {
      return 'Project';
    }
    if (lower == 'merged') {
      return 'Merged';
    }
    return 'Theory';
  }

  /// Returns the canonical display component for a subject:
  /// Returns normalized component if split is configured for this course, else 'Merged'.
  static String canonicalComponent(
    String canonicalSubject,
    String rawComponent, {
    List<CourseComponent> configuredCourses = const [],
    AttendanceDocumentProfile? profile,
    Set<String> sectionSplitSubjects = const {},
  }) {
    if (isSplitCourse(
      canonicalSubject,
      configuredCourses: configuredCourses,
      profile: profile,
      sectionSplitSubjects: sectionSplitSubjects,
    )) {
      return normalizeComponent(rawComponent);
    }
    return 'Merged';
  }

  /// Returns the canonical card and aggregation key for a subject and component.
  static String canonicalGroupKey(
    String canonicalSubject,
    String rawComponent, {
    List<CourseComponent> configuredCourses = const [],
    AttendanceDocumentProfile? profile,
    Set<String> sectionSplitSubjects = const {},
  }) {
    final comp = canonicalComponent(
      canonicalSubject,
      rawComponent,
      configuredCourses: configuredCourses,
      profile: profile,
      sectionSplitSubjects: sectionSplitSubjects,
    );
    return '${canonicalSubject}_$comp';
  }

  /// Builds a deterministic deduplication identity for an attendance event.
  /// Supports both time-aware and timeless attendance formats cleanly.
  static String buildDeduplicationKey({
    required DateTime date,
    int? startTime,
    int? endTime,
    required String canonicalSubject,
    required String component,
    String? sessionIdentifier,
    List<CourseComponent> configuredCourses = const [],
    AttendanceDocumentProfile? profile,
    Set<String> sectionSplitSubjects = const {},
  }) {
    final isSplit = isSplitCourse(
      canonicalSubject,
      configuredCourses: configuredCourses,
      profile: profile,
      sectionSplitSubjects: sectionSplitSubjects,
    );
    final compPart = isSplit ? '_${normalizeComponent(component)}' : '';

    final datePart = '${date.year}-${date.month}-${date.day}';

    if (startTime != null && endTime != null) {
      return '${datePart}_${startTime}_${endTime}_$canonicalSubject$compPart'
          .replaceAll(RegExp(r'\s+'), '_');
    } else {
      // Timeless attendance event identity
      final sessionPart = sessionIdentifier != null && sessionIdentifier.isNotEmpty
          ? '_$sessionIdentifier'
          : '';
      return '${datePart}_timeless_$canonicalSubject$compPart$sessionPart'
          .replaceAll(RegExp(r'\s+'), '_');
    }
  }
}
