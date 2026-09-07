import '../models/attendance_import_models.dart';

/// Separates logical course names from component codes and batch/section suffixes.
class AttendanceCourseNormalizer {
  static final _componentSuffixRegex = RegExp(
    r'^(.*?)(?:\s+([TPUL][1-9]?)|(?<=[a-zA-Z0-9])([TPUL][1-9]))(?:\s+(.*)|$)',
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
    var raw = rawCourseName.trim();
    if (raw.isEmpty) {
      return const NormalizedCourseInfo(courseName: '', parsed: false);
    }

    // Pre-clean recognized SOL attached metadata (e.g. T4BALLB, U4BALLB, TBALL, U4BALL, etc.)
    // Only strip when anchored at the end of the course string so course name words like 'LAW' are preserved.
    final solAttachedMatch = RegExp(
      r'^(.*?)[\s\-_]*([TU](?:[1-9])?)\s*(?:BA\s*LLB|BBALLB|BALLB|BALL|LLB)\s*$',
      caseSensitive: false,
    ).firstMatch(raw);

    if (solAttachedMatch != null) {
      raw = solAttachedMatch.group(1)!.trim();
      final code = solAttachedMatch.group(2)!.toUpperCase();
      final component = _componentTypeFromCode(code);
      var courseName = _canonicalizeSolSubjectName(raw);
      return NormalizedCourseInfo(
        courseName: courseName,
        componentType: component,
        componentCode: code,
        parsed: true,
      );
    }

    final match = _componentSuffixRegex.firstMatch(raw);
    if (match == null) {
      // Check for explicit SOL Theory/Tutorial notations: (U), [U], (T), [T], Tutorial, Theory
      final explicit = _extractExplicitComponent(raw);
      var courseName = explicit.name;
      courseName = _canonicalizeSolSubjectName(courseName);

      return NormalizedCourseInfo(
        courseName: courseName,
        componentType: explicit.component,
        componentCode: explicit.code,
        parsed: explicit.parsed,
      );
    }

    var courseName = match.group(1)!.trim();
    final rawCompCode = match.group(2) ?? match.group(3);
    final componentCode = rawCompCode?.toUpperCase() ?? 'T';
    final trailing = (match.group(4) ?? '').trim();

    if (courseName.isEmpty) {
      final explicit = _extractExplicitComponent(raw);
      var name = _canonicalizeSolSubjectName(explicit.name);
      return NormalizedCourseInfo(
        courseName: name,
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

    // Canonicalize well-known truncated course names
    courseName = _canonicalizeSolSubjectName(courseName);

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

  static String _canonicalizeSolSubjectName(String name) {
    var trimmed = name.replaceAll(RegExp(r'[\s.]+$'), '').trim();
    final upper = trimmed.toUpperCase();

    // DCCA normalization
    if (upper.contains('DIGITAL CIRCUITS') &&
        (upper.endsWith('ARCH') ||
            upper.endsWith('ARCHI') ||
            upper.endsWith('ARCHITECTURE'))) {
      return 'Digital Circuits and Computer Architecture';
    }

    // Family Law II truncated variants:
    // e.g. "Family LawII(Succes and Inheri Laws", "Family Law II (SuccesandInheriLaws"
    if (upper.contains('FAMILY LAW') &&
        (upper.contains('SUCCES') || upper.contains('INHERI'))) {
      return 'Family Law II (Success and Inheritance Laws)';
    }

    // The Bharatiya Sakshya Adhiniyam, 2023 (Law of Evidence) truncated variants:
    // e.g. "The Bharti Sak Adhi, 2023 (L of Ev", "The Bharti Sak Adhi, 2023 (Law of Evidence)"
    if (upper.contains('BHARTI SAK') ||
        upper.contains('BHARATIYA') ||
        upper.contains('BHARTIYA SAKSHYA') ||
        (upper.contains('SAK ADHI') && (upper.contains('EV') || upper.contains('EVIDENCE')))) {
      return 'The Bharatiya Sakshya Adhiniyam, 2023 (Law of Evidence)';
    }

    // Company Law II
    if (upper == 'COMPANY LAW II' || upper == 'COMPANY LAWII') {
      return 'Company Law II';
    }

    // Environmental Law
    if (upper == 'ENVIRONMENTAL LAW') {
      return 'Environmental Law';
    }

    // CPC & Limitation Act
    if (upper == 'CPC & LIMITATION ACT' || upper == 'CPC AND LIMITATION ACT') {
      return 'CPC & Limitation Act';
    }

    // Administrative Law
    if (upper == 'ADMINISTRATIVE LAW') {
      return 'Administrative Law';
    }

    // Maritime Law
    if (upper == 'MARITIME LAW') {
      return 'Maritime Law';
    }

    // Cyber Law
    if (upper == 'CYBER LAW') {
      return 'Cyber Law';
    }

    return trimmed;
  }

  /// Removes semester/branch noise for fuzzy matching comparisons.
  static String normalizeForMatching(String name) {
    var normalized = _canonicalizeSolSubjectName(name).toUpperCase();
    normalized = normalized.replaceAll('&', ' AND ');
    normalized = normalized.replaceAll(RegExp(r'(?<=[A-Z0-9])([TPUL][1-9]?)\b'), '');
    normalized = normalized.replaceAll(RegExp(r'\b([TPUL][1-9]?)\b'), '');
    normalized = normalized.replaceAll(_semesterRegex, '');
    normalized = normalized.replaceAll(_batchRegex, '');
    normalized = normalized.replaceAll(_branchRegex, '');
    normalized = normalized.replaceAll(RegExp(r'[^A-Z0-9\s]'), ' ');
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized;
  }
}
