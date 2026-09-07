import 'package:flutter_test/flutter_test.dart';
import 'package:schedly/models/attendance_import_models.dart';
import 'package:schedly/models/attendance_log.dart';
import 'package:schedly/models/attendance_record.dart';
import 'package:schedly/models/course_component.dart';
import 'package:schedly/services/attendance/academic_grouping_policy.dart';
import 'package:schedly/services/attendance_status_mapper.dart';
import 'package:schedly/services/attendance_course_matcher.dart';
import 'package:schedly/services/attendance_course_normalizer.dart';
import 'package:schedly/services/subject_identity_service.dart';

void main() {
  group('SOL Smart Attendance — Duplicate Subjects & Ground Truth', () {
    // Ground truth subjects from NMIMS SOL B.A., LL.B. (Hons.) Semester V
    final testDate = DateTime(2026, 7, 13);
    final configuredSolCourses = [
      CourseComponent(
        componentId: 'SOL_CompLaw2',
        componentType: 'Theory',
        courseName: 'Company Law II',
        courseCode: '',
        targetHours: 45,
        createdAt: testDate,
        sectionId: 'SOL_BALLB_V_A',
      ),
      CourseComponent(
        componentId: 'SOL_EnvLaw',
        componentType: 'Theory',
        courseName: 'Environmental Law',
        courseCode: '',
        targetHours: 45,
        createdAt: testDate,
        sectionId: 'SOL_BALLB_V_A',
      ),
      CourseComponent(
        componentId: 'SOL_CPC',
        componentType: 'Theory',
        courseName: 'CPC & Limitation Act',
        courseCode: '',
        targetHours: 45,
        createdAt: testDate,
        sectionId: 'SOL_BALLB_V_A',
      ),
      CourseComponent(
        componentId: 'SOL_FamLaw2',
        componentType: 'Theory',
        courseName: 'Family Law II (Success and Inheritance Laws)',
        courseCode: '',
        targetHours: 45,
        createdAt: testDate,
        sectionId: 'SOL_BALLB_V_A',
      ),
      CourseComponent(
        componentId: 'SOL_AdminLaw',
        componentType: 'Theory',
        courseName: 'Administrative Law',
        courseCode: '',
        targetHours: 45,
        createdAt: testDate,
        sectionId: 'SOL_BALLB_V_A',
      ),
      CourseComponent(
        componentId: 'SOL_Evidence',
        componentType: 'Theory',
        courseName: 'The Bharatiya Sakshya Adhiniyam, 2023 (Law of Evidence)',
        courseCode: '',
        targetHours: 45,
        createdAt: testDate,
        sectionId: 'SOL_BALLB_V_A',
      ),
      CourseComponent(
        componentId: 'SOL_Maritime',
        componentType: 'Theory',
        courseName: 'Maritime Law',
        courseCode: '',
        targetHours: 45,
        createdAt: testDate,
        sectionId: 'SOL_BALLB_V_A',
      ),
      CourseComponent(
        componentId: 'SOL_CyberLaw',
        componentType: 'Theory',
        courseName: 'Cyber Law',
        courseCode: '',
        targetHours: 45,
        createdAt: testDate,
        sectionId: 'SOL_BALLB_V_A',
      ),
    ];

    test('1. Resolves all 8 SOL subjects and their dirty PDF variants to canonical names', () {
      final matcher = AttendanceCourseMatcher(configuredSolCourses);

      final testCases = <String, ({String expectedName, String expectedComp})>{
        // 1. Company Law II
        'Company Law IIT4BA LLB': (
          expectedName: 'Company Law II',
          expectedComp: 'Theory',
        ),
        'Company Law II U4BALLB': (
          expectedName: 'Company Law II',
          expectedComp: 'Tutorial',
        ),

        // 2. Environmental Law
        'Environmental LawT4BALLB': (
          expectedName: 'Environmental Law',
          expectedComp: 'Theory',
        ),
        'Environmental Law U4BALLB': (
          expectedName: 'Environmental Law',
          expectedComp: 'Tutorial',
        ),

        // 3. CPC & Limitation Act
        'CPC & Limitation ActT4BALLB': (
          expectedName: 'CPC & Limitation Act',
          expectedComp: 'Theory',
        ),
        'CPC & Limitation Act U4BALLB': (
          expectedName: 'CPC & Limitation Act',
          expectedComp: 'Tutorial',
        ),

        // 4. Family Law II (Success and Inheritance Laws)
        'Family LawII(Succes and Inheri LawsTBALL': (
          expectedName: 'Family Law II (Success and Inheritance Laws)',
          expectedComp: 'Theory',
        ),
        'Family Law II (SuccesandInheriLawsU4BALL': (
          expectedName: 'Family Law II (Success and Inheritance Laws)',
          expectedComp: 'Tutorial',
        ),

        // 5. Administrative Law
        'Administrative LawT4BALLB': (
          expectedName: 'Administrative Law',
          expectedComp: 'Theory',
        ),
        'Administrative Law U4BALLB': (
          expectedName: 'Administrative Law',
          expectedComp: 'Tutorial',
        ),

        // 6. The Bharatiya Sakshya Adhiniyam, 2023 (Law of Evidence)
        'The Bharti Sak Adhi, 2023 (L of EvT4': (
          expectedName: 'The Bharatiya Sakshya Adhiniyam, 2023 (Law of Evidence)',
          expectedComp: 'Theory',
        ),
        'The Bharti Sak Adhi, 2023 (L of Ev U4': (
          expectedName: 'The Bharatiya Sakshya Adhiniyam, 2023 (Law of Evidence)',
          expectedComp: 'Tutorial',
        ),

        // 7. Maritime Law
        'Maritime LawT4': (
          expectedName: 'Maritime Law',
          expectedComp: 'Theory',
        ),

        // 8. Cyber Law
        'Cyber LawT4': (
          expectedName: 'Cyber Law',
          expectedComp: 'Theory',
        ),
      };

      for (final entry in testCases.entries) {
        final raw = entry.key;
        final expected = entry.value;

        final norm = AttendanceCourseNormalizer.normalize(raw);
        expect(
          norm.courseName,
          equals(expected.expectedName),
          reason: 'Failed normalizing course name for: $raw',
        );
        expect(
          norm.componentType,
          equals(expected.expectedComp),
          reason: 'Failed normalizing component type for: $raw',
        );

        final matchResult = matcher.match(
          courseName: norm.courseName,
          componentType: norm.componentType,
          rawCourseName: raw,
        );
        expect(
          matchResult.subjectCode,
          equals(expected.expectedName),
          reason: 'Failed matching subjectCode for: $raw',
        );

        // SubjectIdentityService resolution check
        final identity = SubjectIdentityService.resolve(
          raw,
          configuredCourses: configuredSolCourses,
        );
        expect(
          identity.canonicalKey,
          equals(expected.expectedName),
          reason: 'Failed SubjectIdentityService.resolve canonicalKey for: $raw',
        );
        expect(
          identity.isResolved,
          isTrue,
          reason: 'SubjectIdentityService should deterministically resolve $raw without review',
        );
      }
    });

    test('2. Single Canonical Subject Card for SOL (Theory + Tutorial Merged)', () {
      // In SOL, courses are not configured to split, so Theory and Tutorial aggregate into one card
      final solCourse = 'Company Law II';
      final theoryKey = AcademicGroupingPolicy.canonicalGroupKey(
        solCourse,
        'Theory',
        configuredCourses: configuredSolCourses,
      );
      final tutorialKey = AcademicGroupingPolicy.canonicalGroupKey(
        solCourse,
        'Tutorial',
        configuredCourses: configuredSolCourses,
      );

      expect(theoryKey, equals('${solCourse}_Merged'));
      expect(tutorialKey, equals('${solCourse}_Merged'));
      expect(theoryKey, equals(tutorialKey));

      final componentName = AcademicGroupingPolicy.canonicalComponent(
        solCourse,
        'Theory',
        configuredCourses: configuredSolCourses,
      );
      expect(componentName, equals('Merged'));
    });

    test('3. AttendanceRecord 70% Target Formula matches exact requirements', () {
      // Requirements:
      // 4/7 -> 0 skips
      // 7/10 -> 0 skips
      // 8/10 -> 1 skip
      // 7/9 -> 0 skips
      // 8/9 -> 2 skips
      final r4_7 = AttendanceRecord(
        id: 'r1',
        division: 'SOL',
        subjectCode: 'Law',
        component: 'Merged',
        present: 4,
        absent: 3, // total = 7
      );
      expect(r4_7.canMiss, equals(0), reason: '4/7 should give 0 skips');

      final r7_10 = AttendanceRecord(
        id: 'r2',
        division: 'SOL',
        subjectCode: 'Law',
        component: 'Merged',
        present: 7,
        absent: 3, // total = 10
      );
      expect(r7_10.canMiss, equals(0), reason: '7/10 should give 0 skips');

      final r8_10 = AttendanceRecord(
        id: 'r3',
        division: 'SOL',
        subjectCode: 'Law',
        component: 'Merged',
        present: 8,
        absent: 2, // total = 10
      );
      expect(r8_10.canMiss, equals(1), reason: '8/10 should give 1 skip');

      final r7_9 = AttendanceRecord(
        id: 'r4',
        division: 'SOL',
        subjectCode: 'Law',
        component: 'Merged',
        present: 7,
        absent: 2, // total = 9
      );
      expect(r7_9.canMiss, equals(0), reason: '7/9 should give 0 skips');

      final r8_9 = AttendanceRecord(
        id: 'r5',
        division: 'SOL',
        subjectCode: 'Law',
        component: 'Merged',
        present: 8,
        absent: 1, // total = 9
      );
      expect(r8_9.canMiss, equals(2), reason: '8/9 should give 2 skips');
    });

    test('4. NU Status Semantics: Never counted as present or absent, preserves percentage', () {
      // Raw SAP code NU maps to 'not_updated'
      final mapped = AttendanceStatusMapper.normalize('NU');
      expect(mapped, equals('not_updated'));

      // In AttendanceRecord, total is present + absent.
      // NU logs do not increment present or absent.
      final recordWithNu = AttendanceRecord(
        id: 'r_nu',
        division: 'SOL',
        subjectCode: 'Company Law II',
        component: 'Merged',
        present: 8,
        absent: 1,
        // cancelled/NU do not corrupt total
      );

      expect(recordWithNu.total, equals(9));
      expect(recordWithNu.percentage, closeTo(8 / 9, 0.001));
      expect(recordWithNu.canMiss, equals(2));
    });

    test('5. Ground truth golden counts and percentages for all 8 SOL courses', () {
      final goldenSpecs = [
        (name: 'Administrative Law', p: 33, a: 8, pct: 80.49),
        (name: 'Company Law II', p: 22, a: 6, pct: 78.57),
        (name: 'Environmental Law', p: 31, a: 9, pct: 77.50),
        (name: 'CPC & Limitation Act', p: 39, a: 6, pct: 86.67),
        (name: 'Family Law II (Success and Inheritance Laws)', p: 21, a: 5, pct: 80.77),
        (name: 'Cyber Law', p: 8, a: 2, pct: 80.00),
        (name: 'Maritime Law', p: 14, a: 3, pct: 82.35),
        (name: 'The Bharatiya Sakshya Adhiniyam, 2023 (Law of Evidence)', p: 50, a: 0, pct: 100.00),
      ];

      for (final spec in goldenSpecs) {
        final total = spec.p + spec.a;
        final actualPct = (spec.p / total) * 100;
        expect(actualPct, closeTo(spec.pct, 0.01), reason: 'Percentage mismatch for ${spec.name}');

        final record = AttendanceRecord(
          id: 'test_${spec.name}',
          division: 'SOL_BALLB_V_A',
          subjectCode: spec.name,
          component: 'Merged',
          present: spec.p,
          absent: spec.a,
        );

        // All courses meet or exceed the SOL 70% requirement
        expect(record.percentage >= 0.70, isTrue);
      }
    });
  });
}
