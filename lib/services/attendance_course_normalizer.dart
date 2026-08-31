import '../models/attendance_import_models.dart';

/// Separates logical course names from component codes and batch/section suffixes.
class AttendanceCourseNormalizer {
  static final _componentSuffixRegex = RegExp(
    r'^(.*?)(?:\s+|(?<=[a-zA-Z0-9]))([TPUL][1-9])(?:\s+(.*)|$)',
    caseSensitive: false,
  );

  static final _batchRegex = RegExp(r'\b([A-Z][1-9])\b', caseSensitive: false);

  static final _semesterRegex = RegExp(
    r'\bSem(?:ester)?\s*(I{1,3}|IV|V|VI|VII|VIII|IX|X|\d+)\b',
    caseSensitive: false,
  );

  static NormalizedCourseInfo normalize(String rawCourseName) {
    final raw = rawCourseName.trim();
    if (raw.isEmpty) {
      return const NormalizedCourseInfo(courseName: '', parsed: false);
    }

    final match = _componentSuffixRegex.firstMatch(raw);
    if (match == null) {
      return NormalizedCourseInfo(
        courseName: raw,
        componentType: _inferComponentFromKeywords(raw),
        parsed: false,
      );
    }

    var courseName = match.group(1)!.trim();
    final componentCode = match.group(2)!.toUpperCase();
    final trailing = (match.group(3) ?? '').trim();

    if (courseName.isEmpty) {
      return NormalizedCourseInfo(
        courseName: raw,
        componentType: _inferComponentFromKeywords(raw),
        parsed: false,
      );
    }

    // Trim trailing punctuation artifacts from course name.
    courseName = courseName.replaceAll(RegExp(r'[\s.]+$'), '').trim();

    final componentType = _componentTypeFromCode(componentCode);

    // Strip trailing component label from base course name so sibling components share base name
    final upperCourse = courseName.toUpperCase();
    if (componentType == 'Lab' && upperCourse.endsWith(' LAB')) {
      courseName = courseName.substring(0, courseName.length - 4).trim();
    } else if (componentType == 'Lab' && upperCourse.endsWith(' PRACTICAL')) {
      courseName = courseName.substring(0, courseName.length - 10).trim();
    } else if (componentType == 'Tutorial' &&
        upperCourse.endsWith(' TUTORIAL')) {
      courseName = courseName.substring(0, courseName.length - 9).trim();
    }

    final batch = _extractBatch(trailing.isNotEmpty ? trailing : raw);

    return NormalizedCourseInfo(
      courseName: courseName,
      componentCode: componentCode,
      componentType: componentType,
      batchOrSection: batch,
      parsed: true,
    );
  }

  static String _componentTypeFromCode(String code) {
    final prefix = code.toUpperCase().substring(0, 1);
    switch (prefix) {
      case 'P':
      case 'L':
        return 'Lab';
      case 'U':
        return 'Tutorial';
      case 'T':
      default:
        return 'Theory';
    }
  }

  static String _inferComponentFromKeywords(String raw) {
    final upper = raw.toUpperCase();
    if (upper.contains('LAB') || upper.contains('PRACTICAL')) return 'Lab';
    if (upper.contains('TUTORIAL')) return 'Tutorial';
    return 'Theory';
  }

  static String? _extractBatch(String text) {
    final match = _batchRegex.firstMatch(text);
    return match?.group(1)?.toUpperCase();
  }

  /// Removes semester/branch noise for fuzzy matching comparisons.
  static String normalizeForMatching(String name) {
    var normalized = name.toUpperCase();
    normalized = normalized.replaceAll(_semesterRegex, '');
    normalized = normalized.replaceAll(_batchRegex, '');
    normalized = normalized.replaceAll(RegExp(r'\bCE\b'), '');
    normalized = normalized.replaceAll(RegExp(r'[^A-Z0-9\s&]'), ' ');
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized;
  }
}
