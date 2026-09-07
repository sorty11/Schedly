import '../models/attendance_import_models.dart';

/// Separates logical course names from component codes and batch/section suffixes.
class AttendanceCourseNormalizer {
  static final _componentSuffixRegex = RegExp(
    r'^(.*?)(?:\s+|(?<=[a-zA-Z0-9]))([TPUL][1-9])(?:\s+(.*)|$)',
    caseSensitive: false,
  );

  static final _batchRegex = RegExp(r'\b([A-Z][1-9])\b', caseSensitive: false);

  static final _semesterRegex = RegExp(
    r'\bSem(?:ester)?\s*(I{1,3}|IV|V|VI|VII|VIII|IX|X|\d+)(?:\s+[-_]?\s*[A-Z])?\b',
    caseSensitive: false,
  );

  static final _branchRegex = RegExp(
    r'\b(CE|CS|CSDS|IT|DS|AIDS|AIML|EXTC|ME|BALLB|BBALLB|LLB|SOL)\b',
    caseSensitive: false,
  );

  static NormalizedCourseInfo normalize(String rawCourseName) {
    final raw = rawCourseName.trim();
    if (raw.isEmpty) {
      return const NormalizedCourseInfo(courseName: '', parsed: false);
    }

    final match = _componentSuffixRegex.firstMatch(raw);
    if (match == null) {
      // Check for explicit SOL Theory/Tutorial notations: (U), [U], (T), [T], Tutorial, Theory
      final explicit = _extractExplicitComponent(raw);
      return NormalizedCourseInfo(
        courseName: explicit.name,
        componentType: explicit.component,
        componentCode: explicit.code,
        parsed: explicit.parsed,
      );
    }

    var courseName = match.group(1)!.trim();
    final componentCode = match.group(2)!.toUpperCase();
    final trailing = (match.group(3) ?? '').trim();

    if (courseName.isEmpty) {
      final explicit = _extractExplicitComponent(raw);
      return NormalizedCourseInfo(
        courseName: explicit.name,
        componentType: explicit.component,
        componentCode: explicit.code,
        parsed: explicit.parsed,
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

    // Normalize SAP-truncated course endings so sibling components share the same base name
    final cleanedUpper = courseName.toUpperCase();
    if (cleanedUpper.contains('DIGITAL CIRCUITS') &&
        (cleanedUpper.endsWith('ARCH') ||
            cleanedUpper.endsWith('ARCHI') ||
            cleanedUpper.endsWith('ARCHITECTURE'))) {
      courseName = 'Digital Circuits and Computer Architecture';
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

  static ({String name, String component, String? code, bool parsed})
      _extractExplicitComponent(String raw) {
    var cleaned = raw.trim();
    final upper = cleaned.toUpperCase();

    if (upper.contains('(U)') ||
        upper.contains('[U]') ||
        upper.contains('(TUTORIAL)') ||
        upper.contains('(TUT)') ||
        upper.endsWith(' U') ||
        upper.endsWith(' - U') ||
        RegExp(r'\bU\b').hasMatch(upper) ||
        upper.endsWith('U')) {
      cleaned = cleaned
          .replaceAll(RegExp(r'\([Uu]\)'), '')
          .replaceAll(RegExp(r'\[[Uu]\]'), '')
          .replaceAll(RegExp(r'\([Tt]utorial\)', caseSensitive: false), '')
          .replaceAll(RegExp(r'\([Tt]ut\)', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s+-\s+[Uu]$'), '')
          .replaceAll(RegExp(r'\s+[Uu]$'), '')
          .replaceAll(RegExp(r'(?<=[a-z])[Uu]$'), '')
          .replaceAll(RegExp(r'[\s\-_\/–—]+$'), '')
          .trim();
      cleaned = cleaned.replaceAll(_semesterRegex, ' ');
      cleaned = cleaned.replaceAll(_batchRegex, ' ');
      cleaned = cleaned.replaceAll(_branchRegex, ' ');
      cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
      return (
        name: cleaned.isEmpty ? raw : cleaned,
        component: 'Tutorial',
        code: 'U',
        parsed: true,
      );
    } else if (upper.contains('(T)') ||
        upper.contains('[T]') ||
        upper.contains('(THEORY)') ||
        upper.endsWith(' T') ||
        upper.endsWith(' - T') ||
        RegExp(r'\bT\b').hasMatch(upper) ||
        upper.endsWith('T')) {
      cleaned = cleaned
          .replaceAll(RegExp(r'\([Tt]\)'), '')
          .replaceAll(RegExp(r'\[[Tt]\]'), '')
          .replaceAll(RegExp(r'\([Tt]heory\)', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s+-\s+[Tt]$'), '')
          .replaceAll(RegExp(r'\s+[Tt]$'), '')
          .replaceAll(RegExp(r'(?<=[a-z])[Tt]$'), '')
          .replaceAll(RegExp(r'[\s\-_\/–—]+$'), '')
          .trim();
      // Clean any trailing branch/semester noise
      cleaned = cleaned.replaceAll(_semesterRegex, ' ');
      cleaned = cleaned.replaceAll(_batchRegex, ' ');
      cleaned = cleaned.replaceAll(_branchRegex, ' ');
      cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
      return (
        name: cleaned.isEmpty ? raw : cleaned,
        component: 'Theory',
        code: 'T',
        parsed: true,
      );
    } else if (upper.contains('(P)') ||
        upper.contains('[P]') ||
        upper.contains('(LAB)') ||
        upper.contains('(PRACTICAL)') ||
        upper.endsWith(' LAB') ||
        upper.endsWith(' PRACTICAL') ||
        upper.endsWith(' P') ||
        upper.endsWith(' - P')) {
      cleaned = cleaned
          .replaceAll(RegExp(r'\([Pp]\)'), '')
          .replaceAll(RegExp(r'\[[Pp]\]'), '')
          .replaceAll(RegExp(r'\([Ll]ab\)', caseSensitive: false), '')
          .replaceAll(RegExp(r'\([Pp]ractical\)', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s+-\s+[Pp]$'), '')
          .replaceAll(RegExp(r'\s+[Pp]$'), '')
          .replaceAll(RegExp(r'\s+LAB$', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s+PRACTICAL$', caseSensitive: false), '')
          .replaceAll(RegExp(r'[\s\-_\/–—]+$'), '')
          .trim();
      cleaned = cleaned.replaceAll(_semesterRegex, ' ');
      cleaned = cleaned.replaceAll(_batchRegex, ' ');
      cleaned = cleaned.replaceAll(_branchRegex, ' ');
      cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
      return (
        name: cleaned.isEmpty ? raw : cleaned,
        component: 'Lab',
        code: 'P',
        parsed: true,
      );
    }

    // Strip branch, semester, and batch noise from unmarked subject
    cleaned = cleaned.replaceAll(_semesterRegex, ' ');
    cleaned = cleaned.replaceAll(_batchRegex, ' ');
    cleaned = cleaned.replaceAll(_branchRegex, ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    return (
      name: cleaned.isEmpty ? raw : cleaned,
      component: _inferComponentFromKeywords(raw),
      code: null,
      parsed: cleaned != raw,
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
    if (upper.contains('TUTORIAL') ||
        upper.contains('(U)') ||
        upper.contains('[U]') ||
        upper.contains('(TUT)') ||
        upper.endsWith(' U') ||
        upper.endsWith(' - U')) {
      return 'Tutorial';
    }
    return 'Theory';
  }

  static String? _extractBatch(String text) {
    final match = _batchRegex.firstMatch(text);
    return match?.group(1)?.toUpperCase();
  }

  /// Removes semester/branch noise for fuzzy matching comparisons.
  static String normalizeForMatching(String name) {
    var normalized = name.toUpperCase();
    normalized = normalized.replaceAll('&', ' AND ');
    normalized = normalized.replaceAll(RegExp(r'(?<=[A-Z0-9])([TPUL][1-9])\b'), '');
    normalized = normalized.replaceAll(RegExp(r'\b([TPUL][1-9])\b'), '');
    normalized = normalized.replaceAll(_semesterRegex, '');
    normalized = normalized.replaceAll(_batchRegex, '');
    normalized = normalized.replaceAll(_branchRegex, '');
    normalized = normalized.replaceAll(RegExp(r'[^A-Z0-9\s]'), ' ');
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized;
  }
}
