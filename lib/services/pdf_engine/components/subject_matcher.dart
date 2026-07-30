import 'dart:math';
import '../parser_config.dart';

class SubjectMatcher {
  final List<String> knownSubjects;
  
  // Cache for normalized strings and acronyms
  final Map<String, String> _normalizedCache = {};
  final Map<String, String> _acronymCache = {};

  SubjectMatcher(this.knownSubjects) {
    for (final sub in knownSubjects) {
      _normalizedCache[sub] = _normalize(sub);
      _acronymCache[sub] = _extractAcronym(sub);
    }
  }

  String _fixMergedTokens(String s) {
    // Inserts a space if a component marker like P4, T4, U4, CE, Lab, Tutorial is squashed against text
    return s.replaceAllMapped(
      RegExp(r'([A-Za-z])([PTU]\d|CE|Lab|Tutorial)\b', caseSensitive: false), 
      (match) => '${match.group(1)} ${match.group(2)}'
    );
  }

  String _normalize(String s) {
    return _fixMergedTokens(s).toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  String _extractAcronym(String s) {
    final fixed = _fixMergedTokens(s);
    final words = fixed.split(RegExp(r'\s+'));
    if (words.length <= 1) return '';
    return words.where((w) => w.isNotEmpty).map((w) => w[0].toLowerCase()).join('');
  }

  /// Calculates Levenshtein distance
  int _levenshtein(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    var v0 = List<int>.generate(b.length + 1, (i) => i);
    var v1 = List<int>.filled(b.length + 1, 0);

    for (int i = 0; i < a.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < b.length; j++) {
        final cost = (a[i] == b[j]) ? 0 : 1;
        v1[j + 1] = [v1[j] + 1, v0[j + 1] + 1, v0[j] + cost].reduce(min);
      }
      for (int j = 0; j <= b.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v0[b.length];
  }

  /// Finds the best match. Returns a tuple (matchedSubject, confidencePenalty)
  (String?, int) findBestMatch(String courseRaw) {
    if (courseRaw.isEmpty) return (null, 0);

    final normCourse = _normalize(courseRaw);

    // 1. Exact Match
    for (final sub in knownSubjects) {
      if (normCourse == _normalizedCache[sub]) {
        return (sub, 0); // Perfect exact match
      }
    }

    // 2. Acronym Match (If input is like 'EM' or 'DBMS')
    // We check this before containment to avoid 'em' being found inside 'appliedmathematics'
    for (final sub in knownSubjects) {
      if (_acronymCache[sub] != '' && normCourse == _acronymCache[sub]) {
        return (sub, 0); 
      }
    }

    // 3. Containment Match (Only if input is reasonably long to avoid false positives)
    if (normCourse.length > 4) {
      for (final sub in knownSubjects) {
        final normSub = _normalizedCache[sub]!;
        if (normCourse.contains(normSub) || normSub.contains(normCourse)) {
          return (sub, 0); // Perfect containment match
        }
      }
    }

    // 4. Levenshtein Similarity (Fuzzy)
    String? bestMatch;
    int bestDist = 999;
    
    for (final sub in knownSubjects) {
      final normSub = _normalizedCache[sub]!;
      final dist = _levenshtein(normCourse, normSub);
      if (dist < bestDist) {
        bestDist = dist;
        bestMatch = sub;
      }
    }

    // If it's somewhat close (distance < half the string length), accept it as fuzzy
    if (bestMatch != null) {
      final maxLength = max(normCourse.length, _normalizedCache[bestMatch]!.length);
      if (bestDist <= (maxLength / 2)) {
        return (bestMatch, 20); // 20 penalty for fuzzy match
      }
    }

    return (null, 50); // Unmatched penalty
  }
}
