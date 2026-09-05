import '../data/course_aliases.dart';
import '../models/attendance_log.dart';
import '../models/course_component.dart';
import 'attendance_course_normalizer.dart';

/// Encapsulates the resolved identity of a subject across Timetable, Attendance,
/// PDF import, and Course Details configurations.
class SubjectIdentity {
  /// Authoritative canonical key used for aggregation and card grouping
  /// (e.g. 'Software Engineering', 'DSA', 'PnS', etc.).
  final String canonicalKey;

  /// User-facing, clean, formatted full name (e.g. 'Software Engineering').
  final String displayName;

  /// Standard short code or abbreviation if applicable (e.g. 'SE', 'DSA', 'PnS').
  final String? shortCode;

  /// Confidence level of the match.
  final MatchConfidence confidence;

  /// Whether the subject was deterministically resolved.
  final bool isResolved;

  /// True if multiple candidates matched and could not be disambiguated safely.
  final bool isAmbiguous;

  /// The matching configured CourseComponent from the section, if found.
  final CourseComponent? matchedComponent;

  /// Human-readable status or warning message when review is required.
  final String? statusMessage;

  const SubjectIdentity({
    required this.canonicalKey,
    required this.displayName,
    this.shortCode,
    required this.confidence,
    required this.isResolved,
    this.isAmbiguous = false,
    this.matchedComponent,
    this.statusMessage,
  });

  @override
  String toString() =>
      'SubjectIdentity($canonicalKey, display: $displayName, resolved: $isResolved, conf: ${confidence.name})';
}

/// Normalizer utility for course strings with token expansion and component stripping.
class SubjectNormalizer {
  static const Map<String, String> _abbreviationExpansions = {
    'ENGG': 'ENGINEERING',
    'MGMT': 'MANAGEMENT',
    'ARCH': 'ARCHITECTURE',
    'ARCHI': 'ARCHITECTURE',
    'DEPT': 'DEPARTMENT',
    'PRIN': 'PRINCIPLES',
    'PROG': 'PROGRAMMING',
    'DEV': 'DEVELOPMENT',
    'DES': 'DESIGNING',
    'SYS': 'SYSTEMS',
    'COMM': 'COMMUNICATION',
    'STATS': 'STATISTICS',
    'STAT': 'STATISTICS',
    'MATH': 'MATHEMATICS',
    'MATHS': 'MATHEMATICS',
    'ORG': 'ORGANIZATION',
    'DIFF': 'DIFFERENTIAL',
    'DIFFER': 'DIFFERENTIAL',
    'EQUAT': 'EQUATIONS',
    'ALG': 'ALGORITHMS',
    'ALGO': 'ALGORITHMS',
    'ARCHITECTUR': 'ARCHITECTURE',
    'MANAGEMEN': 'MANAGEMENT',
  };

  static final _componentSuffixRegex = RegExp(
    r'^(.*?)(?:\s+|(?<=[a-zA-Z0-9]))([TPUL][1-9])(?:\s+(.*)|$)',
    caseSensitive: false,
  );

  static final _batchRegex = RegExp(r'\b([A-Z][1-9])\b', caseSensitive: false);

  static final _semesterRegex = RegExp(
    r'\bSem(?:ester)?\s*(I{1,3}|IV|V|VI|VII|VIII|IX|X|\d+)\b',
    caseSensitive: false,
  );

  static final _branchRegex = RegExp(
    r'\b(CE|CS|CSDS|IT|DS|AIDS|AIML|EXTC|ME)\b',
    caseSensitive: false,
  );

  /// Strips component codes, batches, and semesters, then expands standard tokens.
  static String normalize(String input) {
    if (input.trim().isEmpty) return '';

    // 1. First strip component codes like T4, P4, U4
    String stripped = input.trim();
    final match = _componentSuffixRegex.firstMatch(stripped);
    if (match != null) {
      final base = match.group(1)!.trim();
      if (base.isNotEmpty) {
        stripped = base;
      }
    }

    // 2. Remove semester and batch noise
    stripped = stripped.replaceAll(_semesterRegex, ' ');
    stripped = stripped.replaceAll(_batchRegex, ' ');
    stripped = stripped.replaceAll(_branchRegex, ' ');

    // 3. Replace & with AND, strip remaining non-alphanumeric chars
    stripped = stripped.replaceAll('&', ' AND ');
    stripped = stripped.replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), ' ');

    // 4. Tokenize and expand abbreviations
    final tokens = stripped.toUpperCase().split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
    final expandedTokens = tokens.map((token) {
      return _abbreviationExpansions[token] ?? token;
    }).toList();

    return expandedTokens.join(' ').trim();
  }
}

/// Centralized identity and deterministic matching service for timetable entries,
/// attendance logs, and configured section course details.
class SubjectIdentityService {
  /// Known deterministic canonical identities.
  /// Map key: uppercase query (short code or full name).
  /// Value: (canonicalKey, displayName, shortCode).
  static const Map<String, (String, String, String)> _knownIdentities = {
    // Software Engineering
    'SE': ('Software Engineering', 'Software Engineering', 'SE'),
    'SOFTWARE ENGINEERING': ('Software Engineering', 'Software Engineering', 'SE'),

    // Interpersonal Skills
    'IPS': ('Interpersonal Skills', 'Interpersonal Skills', 'IPS'),
    'INTERPERSONAL SKILLS': ('Interpersonal Skills', 'Interpersonal Skills', 'IPS'),

    // Data Structures and Algorithms
    'DSA': ('DSA', 'Data Structures and Algorithms', 'DSA'),
    'DATA STRUCTURES': ('DSA', 'Data Structures and Algorithms', 'DSA'),
    'DATA STRUCTURES AND ALGORITHMS': ('DSA', 'Data Structures and Algorithms', 'DSA'),

    // Computer Organization and Architecture
    'COA': ('COA', 'Computer Organization and Architecture', 'COA'),
    'COMPUTER ORGANIZATION AND ARCHITECTURE': ('COA', 'Computer Organization and Architecture', 'COA'),
    'COMPUTER ORGANIZATION AND ARCHITECTUR': ('COA', 'Computer Organization and Architecture', 'COA'),

    // Principles of Economics and Management
    'PEM': ('PEM', 'Principles of Economics and Management', 'PEM'),
    'PRINCIPLES OF ECONOMICS AND MANAGEMENT': ('PEM', 'Principles of Economics and Management', 'PEM'),
    'PRINCIPLES OF ECONOMICS AND MANAGEMEN': ('PEM', 'Principles of Economics and Management', 'PEM'),

    // Signals and Systems
    'SNS': ('SnS', 'Signals and Systems', 'SnS'),
    'SIGNALS AND SYSTEMS': ('SnS', 'Signals and Systems', 'SnS'),

    // Probability and Statistics
    'PNS': ('PnS', 'Probability and Statistics', 'PnS'),
    'PROBABILITY AND STATISTICS': ('PnS', 'Probability and Statistics', 'PnS'),

    // Discrete Mathematics
    'DM': ('DM', 'Discrete Mathematics', 'DM'),
    'DISCRETE MATHEMATICS': ('DM', 'Discrete Mathematics', 'DM'),

    // Technical Communication
    'TC': ('TC', 'Technical Communication', 'TC'),
    'TECHNICAL COMMUNICATION': ('TC', 'Technical Communication', 'TC'),

    // Programming with Python
    'PYTHON': ('Python', 'Programming with Python', 'Python'),
    'PROGRAMMING WITH PYTHON': ('Python', 'Programming with Python', 'Python'),

    // Digital Circuits and Computer Architecture
    'DCCA': ('Digital Circuits and Computer Architecture', 'Digital Circuits and Computer Architecture', 'DCCA'),
    'DIGITAL CIRCUITS AND COMPUTER ARCHITECTURE': ('Digital Circuits and Computer Architecture', 'Digital Circuits and Computer Architecture', 'DCCA'),

    // Prompt Engineering
    'PE': ('Prompt Engineering for ChatGPT', 'Prompt Engineering for ChatGPT', 'PE'),
    'PROMPT ENGINEERING': ('Prompt Engineering for ChatGPT', 'Prompt Engineering for ChatGPT', 'PE'),
    'PROMPT ENGINEERING FOR CHATGPT': ('Prompt Engineering for ChatGPT', 'Prompt Engineering for ChatGPT', 'PE'),

    // Website Designing and Development
    'WDD': ('Website Designing and Development', 'Website Designing and Development', 'WDD'),
    'WEBSITE DESIGNING AND DEVELOPMENT': ('Website Designing and Development', 'Website Designing and Development', 'WDD'),
  };

  /// Clean subject code helper from CourseComponent.
  static String cleanSubjectCode(CourseComponent comp) {
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

  /// Resolves the identity of a subject using the given section's configured courses.
  static SubjectIdentity resolve(
    String rawSubject, {
    String? rawText,
    String? componentType,
    List<CourseComponent> configuredCourses = const [],
    String? faculty,
    String? batch,
  }) {
    final query = rawSubject.trim();
    if (query.isEmpty) {
      return const SubjectIdentity(
        canonicalKey: '',
        displayName: '',
        confidence: MatchConfidence.unknown,
        isResolved: false,
        statusMessage: 'Subject matching needs review',
      );
    }

    final upperQuery = query.toUpperCase();
    final normalizedQuery = SubjectNormalizer.normalize(query);

    // --- STEP 1: Context-Aware Special Handling for PEC (Electives) ---
    if (upperQuery == 'PEC' ||
        upperQuery.startsWith('PEC-') ||
        upperQuery.startsWith('PEC ') ||
        upperQuery == 'ELECTIVE') {
      return _resolveElective(
        rawSubject: query,
        upperQuery: upperQuery,
        configuredCourses: configuredCourses,
        faculty: faculty,
        batch: batch,
      );
    }

    // --- STEP 2: Context-Aware Handling for PEM ---
    if (upperQuery == 'PEM' ||
        upperQuery.contains('ECONOMICS') ||
        upperQuery.contains('ELECTRICAL MACHINES')) {
      return _resolvePem(
        rawSubject: query,
        upperQuery: upperQuery,
        rawText: rawText,
        configuredCourses: configuredCourses,
      );
    }

    // --- STEP 3: Priority 1 — Exact match in configured Course Details ---
    if (configuredCourses.isNotEmpty) {
      for (final comp in configuredCourses) {
        final cleanId = cleanSubjectCode(comp).toUpperCase();
        final cCode = comp.courseCode.trim().toUpperCase();
        final cName = comp.courseName.trim().toUpperCase();
        final cId = comp.componentId.trim().toUpperCase();

        if (upperQuery == cleanId ||
            (cCode.isNotEmpty && upperQuery == cCode) ||
            upperQuery == cName ||
            upperQuery == cId) {
          final known = _knownIdentities[upperQuery] ?? _knownIdentities[cName] ?? _knownIdentities[cCode];
          final canon = known?.$1 ?? (comp.courseName.isNotEmpty ? comp.courseName : cleanSubjectCode(comp));
          final display = known?.$2 ?? (comp.courseName.isNotEmpty ? comp.courseName : canon);
          final short = known?.$3 ?? (comp.courseCode.isNotEmpty ? comp.courseCode : null);

          return SubjectIdentity(
            canonicalKey: canon,
            displayName: display,
            shortCode: short,
            confidence: MatchConfidence.exact,
            isResolved: true,
            matchedComponent: comp,
          );
        }
      }
    }

    // --- STEP 4: Priority 2 — Exact Known High-Confidence Deterministic Alias ---
    if (_knownIdentities.containsKey(upperQuery)) {
      final (canon, display, short) = _knownIdentities[upperQuery]!;
      // Link to configured component if available
      final matched = _findComponentMatchingKey(canon, configuredCourses);
      return SubjectIdentity(
        canonicalKey: canon,
        displayName: display,
        shortCode: short,
        confidence: MatchConfidence.alias,
        isResolved: true,
        matchedComponent: matched,
      );
    }

    // --- STEP 5: Priority 3 — Normalized Course Name Match against Configured Courses ---
    if (configuredCourses.isNotEmpty && normalizedQuery.isNotEmpty) {
      CourseComponent? bestComp;
      for (final comp in configuredCourses) {
        final normCompName = SubjectNormalizer.normalize(comp.courseName);
        if (normCompName.isNotEmpty && normCompName == normalizedQuery) {
          bestComp = comp;
          break;
        }
      }

      if (bestComp != null) {
        final known = _knownIdentities[bestComp.courseName.toUpperCase()] ??
            _knownIdentities[bestComp.courseCode.toUpperCase()];
        final canon = known?.$1 ?? bestComp.courseName;
        final display = known?.$2 ?? bestComp.courseName;
        final short = known?.$3 ?? (bestComp.courseCode.isNotEmpty ? bestComp.courseCode : null);

        return SubjectIdentity(
          canonicalKey: canon,
          displayName: display,
          shortCode: short,
          confidence: MatchConfidence.normalized,
          isResolved: true,
          matchedComponent: bestComp,
        );
      }
    }

    // --- STEP 6: Priority 4 — Normalized match against Known Deterministic Identities ---
    for (final entry in _knownIdentities.entries) {
      final normKey = SubjectNormalizer.normalize(entry.key);
      if (normKey.isNotEmpty && normKey == normalizedQuery) {
        final (canon, display, short) = entry.value;
        final matched = _findComponentMatchingKey(canon, configuredCourses);
        return SubjectIdentity(
          canonicalKey: canon,
          displayName: display,
          shortCode: short,
          confidence: MatchConfidence.normalized,
          isResolved: true,
          matchedComponent: matched,
        );
      }
    }

    // --- STEP 7: Priority 5 — Fallback to courseAliases dictionary ---
    for (final entry in courseAliases.entries) {
      if (upperQuery == entry.key.toUpperCase() ||
          upperQuery.contains(entry.value.toUpperCase()) ||
          (rawText != null && rawText.toUpperCase().contains(entry.value.toUpperCase()))) {
        final known = _knownIdentities[entry.key.toUpperCase()];
        final canon = known?.$1 ?? entry.key;
        final display = known?.$2 ?? entry.value;
        final short = known?.$3 ?? entry.key;
        final matched = _findComponentMatchingKey(canon, configuredCourses);

        return SubjectIdentity(
          canonicalKey: canon,
          displayName: display,
          shortCode: short,
          confidence: MatchConfidence.alias,
          isResolved: true,
          matchedComponent: matched,
        );
      }
    }

    // --- STEP 8: Unresolved — Safe fallback, do NOT guess ---
    return SubjectIdentity(
      canonicalKey: query,
      displayName: query,
      confidence: MatchConfidence.unknown,
      isResolved: false,
      statusMessage: 'Subject matching needs review',
    );
  }

  /// Disambiguates PEC / Electives using section context.
  static SubjectIdentity _resolveElective({
    required String rawSubject,
    required String upperQuery,
    required List<CourseComponent> configuredCourses,
    String? faculty,
    String? batch,
  }) {
    if (configuredCourses.isEmpty) {
      return SubjectIdentity(
        canonicalKey: 'PEC',
        displayName: rawSubject,
        shortCode: 'PEC',
        confidence: MatchConfidence.unknown,
        isResolved: false,
        isAmbiguous: false,
        statusMessage: 'Subject matching needs review',
      );
    }

    // Identify candidate elective components in the section
    final electives = configuredCourses.where((c) {
      final idUpper = c.componentId.toUpperCase();
      final codeUpper = c.courseCode.toUpperCase();
      final nameUpper = c.courseName.toUpperCase();
      return idUpper.contains('PEC') ||
          idUpper.contains('ELECTIVE') ||
          codeUpper.contains('PEC') ||
          codeUpper.contains('ELECTIVE') ||
          nameUpper.contains('PEC') ||
          nameUpper.contains('ELECTIVE');
    }).toList();

    // Case 1: Exactly ONE matching elective in section curriculum -> Deterministic resolve!
    if (electives.length == 1) {
      final comp = electives.first;
      return SubjectIdentity(
        canonicalKey: comp.courseName.isNotEmpty ? comp.courseName : cleanSubjectCode(comp),
        displayName: comp.courseName.isNotEmpty ? comp.courseName : 'PEC',
        shortCode: comp.courseCode.isNotEmpty ? comp.courseCode : 'PEC',
        confidence: MatchConfidence.alias,
        isResolved: true,
        isAmbiguous: false,
        matchedComponent: comp,
      );
    }

    // Case 2: Multiple electives -> Attempt deterministic disambiguation via elective number or faculty
    if (electives.length > 1) {
      // Check elective number (e.g. PEC-1, PEC 2)
      final numMatch = RegExp(r'\b([1-9]|I{1,3}|IV|V)\b').firstMatch(upperQuery);
      if (numMatch != null) {
        final numToken = numMatch.group(1)!;
        final matchedByNum = electives.where((c) {
          return c.componentId.toUpperCase().contains(numToken) ||
              c.courseCode.toUpperCase().contains(numToken) ||
              c.courseName.toUpperCase().contains(numToken);
        }).toList();

        if (matchedByNum.length == 1) {
          final comp = matchedByNum.first;
          return SubjectIdentity(
            canonicalKey: comp.courseName.isNotEmpty ? comp.courseName : cleanSubjectCode(comp),
            displayName: comp.courseName.isNotEmpty ? comp.courseName : 'PEC',
            shortCode: comp.courseCode.isNotEmpty ? comp.courseCode : 'PEC',
            confidence: MatchConfidence.alias,
            isResolved: true,
            isAmbiguous: false,
            matchedComponent: comp,
          );
        }
      }

      // Check faculty disambiguation
      if (faculty != null && faculty.trim().isNotEmpty) {
        final facUpper = faculty.trim().toUpperCase();
        final matchedByFac = electives.where((c) {
          return c.facultyId.trim().toUpperCase() == facUpper;
        }).toList();

        if (matchedByFac.length == 1) {
          final comp = matchedByFac.first;
          return SubjectIdentity(
            canonicalKey: comp.courseName.isNotEmpty ? comp.courseName : cleanSubjectCode(comp),
            displayName: comp.courseName.isNotEmpty ? comp.courseName : 'PEC',
            shortCode: comp.courseCode.isNotEmpty ? comp.courseCode : 'PEC',
            confidence: MatchConfidence.alias,
            isResolved: true,
            isAmbiguous: false,
            matchedComponent: comp,
          );
        }
      }

      // Ambiguous: Never guess!
      return const SubjectIdentity(
        canonicalKey: 'PEC',
        displayName: 'PEC (Elective)',
        shortCode: 'PEC',
        confidence: MatchConfidence.unknown,
        isResolved: false,
        isAmbiguous: true,
        statusMessage: 'Subject matching needs review',
      );
    }

    // Case 3: 0 electives found
    return const SubjectIdentity(
      canonicalKey: 'PEC',
      displayName: 'PEC',
      shortCode: 'PEC',
      confidence: MatchConfidence.unknown,
      isResolved: false,
      isAmbiguous: false,
      statusMessage: 'Subject matching needs review',
    );
  }

  /// Disambiguates PEM (Economics & Management vs Electrical Machines).
  static SubjectIdentity _resolvePem({
    required String rawSubject,
    required String upperQuery,
    String? rawText,
    required List<CourseComponent> configuredCourses,
  }) {
    final combined = '$upperQuery ${rawText ?? ''}'.toUpperCase();

    // Check explicit keywords
    if (combined.contains('ELECTRICAL') || combined.contains('MACHINE')) {
      final comp = _findComponentMatchingKeywords(['ELECTRICAL', 'MACHINE'], configuredCourses);
      return SubjectIdentity(
        canonicalKey: 'PEM',
        displayName: 'Principles of Electrical Machines',
        shortCode: 'PEM',
        confidence: MatchConfidence.alias,
        isResolved: true,
        matchedComponent: comp,
      );
    }

    if (combined.contains('ECONOMICS') || combined.contains('MANAGEMENT') || combined.contains('MANAGEMEN')) {
      final comp = _findComponentMatchingKeywords(['ECONOMICS', 'MANAGEMENT', 'MANAGEMEN'], configuredCourses);
      return SubjectIdentity(
        canonicalKey: 'PEM',
        displayName: 'Principles of Economics and Management',
        shortCode: 'PEM',
        confidence: MatchConfidence.alias,
        isResolved: true,
        matchedComponent: comp,
      );
    }

    // Inspect section configuration if available
    for (final comp in configuredCourses) {
      final cName = comp.courseName.toUpperCase();
      if (cName.contains('ELECTRICAL') || cName.contains('MACHINE')) {
        return SubjectIdentity(
          canonicalKey: 'PEM',
          displayName: 'Principles of Electrical Machines',
          shortCode: 'PEM',
          confidence: MatchConfidence.alias,
          isResolved: true,
          matchedComponent: comp,
        );
      }
      if (cName.contains('ECONOMICS') || cName.contains('MANAGEMENT')) {
        return SubjectIdentity(
          canonicalKey: 'PEM',
          displayName: 'Principles of Economics and Management',
          shortCode: 'PEM',
          confidence: MatchConfidence.alias,
          isResolved: true,
          matchedComponent: comp,
        );
      }
    }

    // Default canonical PEM
    return const SubjectIdentity(
      canonicalKey: 'PEM',
      displayName: 'Principles of Economics and Management',
      shortCode: 'PEM',
      confidence: MatchConfidence.alias,
      isResolved: true,
    );
  }

  static CourseComponent? _findComponentMatchingKey(
    String key,
    List<CourseComponent> configuredCourses,
  ) {
    if (configuredCourses.isEmpty) return null;
    final upperKey = key.toUpperCase();
    for (final comp in configuredCourses) {
      if (comp.courseName.toUpperCase() == upperKey ||
          cleanSubjectCode(comp).toUpperCase() == upperKey ||
          comp.courseCode.toUpperCase() == upperKey) {
        return comp;
      }
    }
    return null;
  }

  static CourseComponent? _findComponentMatchingKeywords(
    List<String> keywords,
    List<CourseComponent> configuredCourses,
  ) {
    for (final comp in configuredCourses) {
      final cName = comp.courseName.toUpperCase();
      for (final kw in keywords) {
        if (cName.contains(kw)) return comp;
      }
    }
    return null;
  }

  /// Returns the canonical key for a subject string (used for grouping & aggregation).
  static String getCanonicalKey(
    String rawSubject, {
    List<CourseComponent> configuredCourses = const [],
  }) {
    final trimmed = rawSubject.trim();
    if (trimmed.isEmpty) return trimmed;

    final resolved = resolve(trimmed, configuredCourses: configuredCourses);
    return resolved.canonicalKey;
  }

  /// Returns the clean display name for a subject string.
  static String getDisplayName(
    String rawSubject, {
    List<CourseComponent> configuredCourses = const [],
  }) {
    final trimmed = rawSubject.trim();
    if (trimmed.isEmpty) return trimmed;

    final resolved = resolve(trimmed, configuredCourses: configuredCourses);
    return resolved.displayName;
  }

  /// Deterministic matching check between two subject names (e.g. Timetable vs Attendance).
  /// NEVER uses loose `contains()` or `startsWith()` without token isolation.
  static bool isMatch(
    String subjectA,
    String subjectB, {
    List<CourseComponent> configuredCourses = const [],
  }) {
    final a = subjectA.trim();
    final b = subjectB.trim();
    if (a.isEmpty || b.isEmpty) return false;

    // 1. Exact string equality (case-insensitive)
    if (a.toUpperCase() == b.toUpperCase()) return true;

    // 2. Canonical key equality
    final canonA = getCanonicalKey(a, configuredCourses: configuredCourses);
    final canonB = getCanonicalKey(b, configuredCourses: configuredCourses);
    if (canonA.isNotEmpty && canonA.toUpperCase() == canonB.toUpperCase()) {
      return true;
    }

    // 3. Resolved identity check
    final idA = resolve(a, configuredCourses: configuredCourses);
    final idB = resolve(b, configuredCourses: configuredCourses);

    if (idA.isResolved && idB.isResolved) {
      if (idA.canonicalKey.toUpperCase() == idB.canonicalKey.toUpperCase()) {
        return true;
      }
    }

    // 4. Normalized string equality
    final normA = SubjectNormalizer.normalize(a);
    final normB = SubjectNormalizer.normalize(b);
    if (normA.isNotEmpty && normA == normB) {
      return true;
    }

    return false;
  }
}
