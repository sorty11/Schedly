import 'package:flutter_test/flutter_test.dart';
import 'package:schedly/services/pdf_engine/components/subject_matcher.dart';

void main() {
  group('SubjectMatcher', () {
    late SubjectMatcher matcher;
    
    setUp(() {
      matcher = SubjectMatcher([
        'Applied Mathematics',
        'Engineering Mathematics',
        'Database Management Systems',
        'Computer Networks',
      ]);
    });

    test('Exact match', () {
      final res = matcher.findBestMatch('Applied Mathematics');
      expect(res.$1, 'Applied Mathematics');
      expect(res.$2, 0);
    });

    test('Acronym match', () {
      final res1 = matcher.findBestMatch('EM');
      expect(res1.$1, 'Engineering Mathematics');
      expect(res1.$2, 0);

      final res2 = matcher.findBestMatch('DMS');
      expect(res2.$1, 'Database Management Systems');
      expect(res2.$2, 0);
    });

    test('Fuzzy Levenshtein match', () {
      final res = matcher.findBestMatch('Appled Math'); // Missing 'i', abbreviated 'Mathematics'
      expect(res.$1, 'Applied Mathematics');
      expect(res.$2, 20); // Penalty for fuzzy
    });

    test('Unmatched subject', () {
      final res = matcher.findBestMatch('Totally Unknown Subject');
      expect(res.$1, null);
      expect(res.$2, 50); // Unmatched penalty
    });
  });
}
