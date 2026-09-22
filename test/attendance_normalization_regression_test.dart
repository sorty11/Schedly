import 'package:flutter_test/flutter_test.dart';
import 'package:schedly/services/attendance_course_normalizer.dart';
import 'package:schedly/services/subject_identity_service.dart';
import 'package:schedly/models/course_component.dart';
import 'package:schedly/models/attendance_record.dart';
import 'package:schedly/models/attendance_log.dart';
import 'package:schedly/services/attendance/attendance_aggregation_service.dart';
import 'package:schedly/services/progress_calculator_service.dart';
import 'package:schedly/models/attendance_subject_view_model.dart';

void main() {
  group('Attendance Normalization Regression Tests', () {
    test('1. BEE variants resolve to exactly one canonical identity', () {
      const v1 = 'Basic Electrical and Electr Eng';
      const v2 = 'Basic Electrical and Electr Engg';
      const v3 = 'Basic Electrical and Electronics Engineering';

      final norm1 = AttendanceCourseNormalizer.canonicalizeCourseName(v1);
      final norm2 = AttendanceCourseNormalizer.canonicalizeCourseName(v2);
      final norm3 = AttendanceCourseNormalizer.canonicalizeCourseName(v3);

      expect(norm1, 'Basic Electrical and Electronics Engineering');
      expect(norm2, 'Basic Electrical and Electronics Engineering');
      expect(norm3, 'Basic Electrical and Electronics Engineering');

      final id1 = SubjectIdentityService.resolve(v1);
      final id2 = SubjectIdentityService.resolve(v2);
      final id3 = SubjectIdentityService.resolve(v3);

      expect(id1.canonicalKey, 'BEE');
      expect(id2.canonicalKey, 'BEE');
      expect(id3.canonicalKey, 'BEE');

      expect(id1.displayName, 'Basic Electrical and Electronics Engineering');
      expect(id2.displayName, 'Basic Electrical and Electronics Engineering');
      expect(id3.displayName, 'Basic Electrical and Electronics Engineering');

      expect(SubjectIdentityService.isMatch(v1, v2), isTrue);
      expect(SubjectIdentityService.isMatch(v2, v3), isTrue);
      expect(SubjectIdentityService.isMatch(v1, v3), isTrue);
    });

    test('2. COA variants resolve to exactly one canonical identity', () {
      const v1 = 'Computer Organization and Architectur';
      const v2 = 'Computer Organization and Architecture';

      final norm1 = AttendanceCourseNormalizer.canonicalizeCourseName(v1);
      final norm2 = AttendanceCourseNormalizer.canonicalizeCourseName(v2);

      expect(norm1, 'Computer Organization and Architecture');
      expect(norm2, 'Computer Organization and Architecture');

      final id1 = SubjectIdentityService.resolve(v1);
      final id2 = SubjectIdentityService.resolve(v2);

      expect(id1.canonicalKey, 'COA');
      expect(id2.canonicalKey, 'COA');
      expect(id1.displayName, 'Computer Organization and Architecture');
      expect(id2.displayName, 'Computer Organization and Architecture');

      expect(SubjectIdentityService.isMatch(v1, v2), isTrue);
    });

    test('3. Genuinely different subjects remain strictly different', () {
      final subjects = [
        'Software Engineering',
        'Computer Organization and Architecture',
        'Discrete Mathematics',
        'Signals and Systems',
        'Programming with Python',
        'Website Designing and Development',
      ];

      for (int i = 0; i < subjects.length; i++) {
        for (int j = i + 1; j < subjects.length; j++) {
          final s1 = subjects[i];
          final s2 = subjects[j];
          expect(
            SubjectIdentityService.isMatch(s1, s2),
            isFalse,
            reason: '$s1 should NOT match $s2',
          );

          final id1 = SubjectIdentityService.resolve(s1);
          final id2 = SubjectIdentityService.resolve(s2);
          expect(
            id1.canonicalKey,
            isNot(equals(id2.canonicalKey)),
            reason: '$s1 and $s2 must have distinct canonicalKeys',
          );
        }
      }
    });

    test('4. DSA Theory and DSA Lab remain strictly separate identities with 45h/30h', () {
      final calc = ProgressCalculatorService(
        weeklyTimetable: {},
        semesterStartDate: DateTime(2026, 7, 13),
        subjectMetadata: {},
        courseComponents: [],
      );

      final theoryHours = calc.getConfiguredCourseHours('DSA', 'Theory');
      final labHours = calc.getConfiguredCourseHours('DSA', 'Lab');

      expect(theoryHours, 45, reason: 'DSA Theory must default to 45 academic hours');
      expect(labHours, 30, reason: 'DSA Lab must default to 30 academic hours');

      final keyTheory = AttendanceLog.canonicalGroupKey('DSA', 'Theory');
      final keyLab = AttendanceLog.canonicalGroupKey('DSA', 'Lab');

      expect(keyTheory, isNot(equals(keyLab)), reason: 'DSA Theory and Lab group keys must not collapse');
      expect(keyTheory, contains('Theory'));
      expect(keyLab, contains('Lab'));
    });

    test('5. SOL subjects remain independent and preserve full titles', () {
      const solSubjects = [
        'Company Law II',
        'Family Law II (Success and Inheritance Laws)',
        'The Bharatiya Sakshya Adhiniyam, 2023 (Law of Evidence)',
        'Environmental Law',
        'CPC & Limitation Act',
        'Administrative Law',
        'Maritime Law',
        'Cyber Law',
      ];

      for (int i = 0; i < solSubjects.length; i++) {
        for (int j = i + 1; j < solSubjects.length; j++) {
          final s1 = solSubjects[i];
          final s2 = solSubjects[j];
          expect(
            SubjectIdentityService.isMatch(s1, s2),
            isFalse,
            reason: 'SOL subjects $s1 and $s2 must remain distinct',
          );
        }
      }

      // Truncated SOL variants still resolve to their respective canonical forms
      final evId = SubjectIdentityService.resolve('The Bharti Sak Adhi, 2023 (L of Ev');
      expect(evId.canonicalKey, 'The Bharatiya Sakshya Adhiniyam, 2023 (Law of Evidence)');

      final famId = SubjectIdentityService.resolve('Family LawII(Succes and Inheri Laws');
      expect(famId.canonicalKey, 'Family Law II (Success and Inheritance Laws)');
    });

    test('6. Unknown/unconfigured course fails closed safely', () {
      const unknownCourse = 'Advanced Quantum Computing Special Topic';
      final id = SubjectIdentityService.resolve(unknownCourse);

      expect(id.isResolved, isFalse, reason: 'Unconfigured course must have isResolved = false');
      expect(id.matchedComponent, isNull, reason: 'Unconfigured course must have no matchedComponent');

      final calc = ProgressCalculatorService(
        weeklyTimetable: {},
        semesterStartDate: DateTime(2026, 7, 13),
        subjectMetadata: {},
        courseComponents: [],
      );

      final rec = AttendanceRecord(
        id: 'rec_1',
        division: 'CE_D',
        subjectCode: unknownCourse,
        component: 'Theory',
        present: 15,
        absent: 5,
        cancelled: 0,
      );

      final vm = AttendanceSubjectViewModel.fromRecord(
        record: rec,
        calculator: calc,
      );

      // Percentage calculated accurately from raw P/A: 15 / 20 = 75.0%
      expect(vm.percentage, closeTo(0.75, 1e-4));
      expect(vm.total, 20);
      expect(vm.present, 15);
      expect(vm.absent, 5);

      // Fail-closed target hours:
      expect(vm.assignedHours, isNull, reason: 'No fabricated targetHours');
      expect(vm.assignedHoursLabel, 'Hours not configured');
      expect(vm.remainingLectures, isNull, reason: 'No fabricated remaining lectures');
      expect(vm.remainingLecturesLabel, 'Remaining lectures unavailable');
      expect(vm.skipsLeft, 0, reason: 'Cannot recommend skip without assigned hours');
      expect(vm.needsReview, isTrue);
    });

    test('7. Normalization idempotence: normalize(normalize(x)) == normalize(x)', () {
      final sampleInputs = [
        'Basic Electrical and Electr Eng',
        'Basic Electrical and Electr Engg',
        'Basic Electrical and Electronics Engineering',
        'Computer Organization and Architectur',
        'Computer Organization and Architecture',
        'Linear Algebra & Differ. Equat.',
        'Linear Algebra & Differential Equations',
        'Digital Circuits and Computer Arch',
        'Digital Circuits and Computer Architecture',
        'Family LawII(Succes and Inheri Laws',
        'The Bharti Sak Adhi, 2023 (L of Ev',
      ];

      for (final input in sampleInputs) {
        // 1. Course canonicalization idempotence
        final step1 = AttendanceCourseNormalizer.canonicalizeCourseName(input);
        final step2 = AttendanceCourseNormalizer.canonicalizeCourseName(step1);
        expect(step2, equals(step1), reason: 'Canonicalization must be idempotent for "$input"');

        // 2. Subject identity canonical key idempotence
        final key1 = SubjectIdentityService.getCanonicalKey(input);
        final key2 = SubjectIdentityService.getCanonicalKey(key1);
        expect(key2, equals(key1), reason: 'Canonical key must be idempotent for "$input"');
      }
    });
  });
}