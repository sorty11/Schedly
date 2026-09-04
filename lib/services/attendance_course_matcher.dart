import '../data/course_aliases.dart';
import '../models/attendance_import_models.dart';
import '../models/attendance_log.dart';
import '../models/course_component.dart';
import 'attendance_course_normalizer.dart';

/// Maps parsed PDF course names to configured Schedly course components.
class AttendanceCourseMatcher {
  final List<CourseComponent> configuredCourses;

  AttendanceCourseMatcher(this.configuredCourses);

  CourseMatchResult match({
    required String courseName,
    required String componentType,
    required String rawCourseName,
  }) {
    if (configuredCourses.isEmpty) {
      return _fallbackAliasMatch(courseName, componentType, rawCourseName);
    }

    // Priority 1: Exact configured course/component identity.
    for (final comp in configuredCourses) {
      if (_exactMatch(comp, courseName, componentType)) {
        return CourseMatchResult(
          subjectCode: _cleanSubjectCode(comp),
          component: comp.componentType,
          confidence: MatchConfidence.exact,
        );
      }
    }

    // Priority 2: Normalized course-name match.
    final normalizedInput = AttendanceCourseNormalizer.normalizeForMatching(
      courseName,
    );
    CourseComponent? bestNormalized;
    for (final comp in configuredCourses) {
      final normalizedCourse = AttendanceCourseNormalizer.normalizeForMatching(
        comp.courseName,
      );
      if (normalizedInput == normalizedCourse &&
          _componentTypesCompatible(comp.componentType, componentType)) {
        bestNormalized = comp;
        break;
      }
    }
    if (bestNormalized != null) {
      return CourseMatchResult(
        subjectCode: _cleanSubjectCode(bestNormalized),
        component: bestNormalized.componentType,
        confidence: MatchConfidence.normalized,
      );
    }

    // Priority 3: Alias lookup (short codes).
    final aliasResult = _matchViaAlias(courseName, componentType);
    if (aliasResult != null) return aliasResult;

    // Priority 4: Conservative fuzzy — only when one clear candidate exists.
    final fuzzyResult = _conservativeFuzzyMatch(
      courseName,
      componentType,
      normalizedInput,
    );
    if (fuzzyResult != null) return fuzzyResult;

    // Priority 5: Unresolved — preserve raw, flag for review.
    return CourseMatchResult(
      subjectCode: courseName,
      component: componentType,
      confidence: MatchConfidence.unknown,
      warning:
          'Could not match "$courseName" ($componentType) to a configured course.',
    );
  }

  CourseMatchResult _fallbackAliasMatch(
    String courseName,
    String componentType,
    String rawCourseName,
  ) {
    final aliasResult = _matchViaAlias(courseName, componentType);
    if (aliasResult != null) return aliasResult;

    // Try matching alias against raw text when normalization stripped info.
    for (final entry in courseAliases.entries) {
      if (rawCourseName.toUpperCase().contains(entry.value.toUpperCase())) {
        return CourseMatchResult(
          subjectCode: entry.key,
          component: componentType,
          confidence: MatchConfidence.alias,
        );
      }
    }

    return CourseMatchResult(
      subjectCode: courseName,
      component: componentType,
      confidence: MatchConfidence.unknown,
      warning: 'No configured courses found. Using parsed course name.',
    );
  }

  static String _cleanSubjectCode(CourseComponent comp) {
    if (comp.courseCode.isNotEmpty) return comp.courseCode;
    return comp.componentId
        .replaceAll(
          RegExp(
            r'(_|\s+)(Lab|Theory|Tutorial|Practical|Tut|Lec|Prac)$',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
  }

  bool _exactMatch(
    CourseComponent comp,
    String courseName,
    String componentType,
  ) {
    final cleanCompId = _cleanSubjectCode(comp);
    final nameMatch =
        comp.courseName.toUpperCase() == courseName.toUpperCase() ||
        comp.componentId.toUpperCase() == courseName.toUpperCase() ||
        cleanCompId.toUpperCase() == courseName.toUpperCase();
    return nameMatch &&
        _componentTypesCompatible(comp.componentType, componentType);
  }

  CourseMatchResult? _matchViaAlias(String courseName, String componentType) {
    final upper = courseName.toUpperCase();
    for (final entry in courseAliases.entries) {
      if (upper.contains(entry.value.toUpperCase()) ||
          upper == entry.key.toUpperCase()) {
        if (configuredCourses.isNotEmpty) {
          final exists = configuredCourses.any((c) {
            final cleanId = _cleanSubjectCode(c).toUpperCase();
            final cName = c.courseName.toUpperCase();
            final cCode = c.courseCode.toUpperCase();
            return cleanId == entry.key.toUpperCase() ||
                cName.contains(entry.value.toUpperCase()) ||
                (cCode.isNotEmpty && cCode == entry.key.toUpperCase());
          });
          if (!exists) continue;
        }

        return CourseMatchResult(
          subjectCode: entry.key,
          component: componentType,
          confidence: MatchConfidence.alias,
        );
      }
    }
    return null;
  }

  CourseMatchResult? _conservativeFuzzyMatch(
    String courseName,
    String componentType,
    String normalizedInput,
  ) {
    if (normalizedInput.length < 6) return null;

    final candidates = <CourseComponent>[];
    for (final comp in configuredCourses) {
      final normalizedCourse = AttendanceCourseNormalizer.normalizeForMatching(
        comp.courseName,
      );
      if (!_componentTypesCompatible(comp.componentType, componentType)) {
        continue;
      }
      if (normalizedCourse.contains(normalizedInput) ||
          normalizedInput.contains(normalizedCourse)) {
        if (normalizedCourse.length >= 6 || normalizedInput.length >= 6) {
          candidates.add(comp);
        }
      }
    }

    if (candidates.length == 1) {
      return CourseMatchResult(
        subjectCode: candidates.first.componentId,
        component: candidates.first.componentType,
        confidence: MatchConfidence.fuzzy,
        warning:
            'Fuzzy matched "$courseName" to "${candidates.first.courseName}". Please verify.',
      );
    }

    return null;
  }

  bool _componentTypesCompatible(String configured, String parsed) {
    final c = configured.toLowerCase();
    final p = parsed.toLowerCase();
    if (c == p) return true;
    if ((c.contains('lab') || c.contains('practical')) &&
        (p.contains('lab') || p.contains('practical'))) {
      return true;
    }
    if (c.contains('theory') && p.contains('theory')) return true;
    if (c.contains('tutorial') && p.contains('tutorial')) return true;
    // Combined components accept any parsed type.
    if (c.contains('combined')) return true;
    return false;
  }
}
