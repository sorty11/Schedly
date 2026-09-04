import 'package:flutter_test/flutter_test.dart';
import 'package:schedly/models/attendance_import_models.dart';
import 'package:schedly/models/attendance_log.dart';
import 'package:schedly/models/attendance_record.dart';
import 'package:schedly/models/course_component.dart';
import 'package:schedly/services/attendance_course_matcher.dart';
import 'package:schedly/services/attendance_course_normalizer.dart';
import 'package:schedly/services/progress_calculator_service.dart';

void main() {
  group('Multi-Section Attendance Audit Tests', () {
    // -------------------------------------------------------------------------
    // Setup 3 Hypothetical Sections with completely different subjects and hours
    // -------------------------------------------------------------------------
    CourseComponent makeComp({
      required String id,
      required String name,
      required String type,
      required int hours,
      required int credits,
      required String section,
      String code = '',
    }) {
      return CourseComponent(
        componentId: id,
        courseName: name,
        componentType: type,
        courseCode: code,
        targetHours: hours,
        credits: credits,
        sectionId: section,
        createdAt: DateTime(2026, 7, 13),
      );
    }

    // Section A: Mathematics (60h), Physics (45h)
    final sectionAComponents = [
      makeComp(
        id: 'MATH101',
        name: 'Mathematics',
        type: 'Theory',
        hours: 60,
        credits: 4,
        section: 'Section_A',
        code: 'MATH101',
      ),
      makeComp(
        id: 'PHYS101',
        name: 'Physics',
        type: 'Theory',
        hours: 45,
        credits: 3,
        section: 'Section_A',
        code: 'PHYS101',
      ),
    ];

    // Section B: Database (75h = 45h Theory + 30h Lab), Networks (60h Combined)
    final sectionBComponents = [
      makeComp(
        id: 'CS301_Theory',
        name: 'Database',
        type: 'Theory',
        hours: 45,
        credits: 3,
        section: 'Section_B',
        code: 'CS301',
      ),
      makeComp(
        id: 'CS301_Lab',
        name: 'Database',
        type: 'Lab',
        hours: 30,
        credits: 1,
        section: 'Section_B',
        code: 'CS301',
      ),
      makeComp(
        id: 'CS302',
        name: 'Networks',
        type: 'Combined',
        hours: 60,
        credits: 3,
        section: 'Section_B',
        code: 'CS302',
      ),
    ];

    // Section C: AI (45h), Electronics (30h)
    final sectionCComponents = [
      makeComp(
        id: 'AI401',
        name: 'AI',
        type: 'Theory',
        hours: 45,
        credits: 3,
        section: 'Section_C',
        code: 'AI401',
      ),
      makeComp(
        id: 'EC201',
        name: 'Electronics',
        type: 'Theory',
        hours: 30,
        credits: 2,
        section: 'Section_C',
        code: 'EC201',
      ),
    ];

    // -------------------------------------------------------------------------
    // 1. TargetHours Resolution per Section
    // -------------------------------------------------------------------------
    test('1. Each section resolves ONLY its own targetHours configuration', () {
      final calcA = ProgressCalculatorService(
        weeklyTimetable: {},
        semesterStartDate: DateTime(2026, 7, 13),
        subjectMetadata: {for (var c in sectionAComponents) c.componentId: c},
        courseComponents: sectionAComponents,
      );

      final calcB = ProgressCalculatorService(
        weeklyTimetable: {},
        semesterStartDate: DateTime(2026, 7, 13),
        subjectMetadata: {for (var c in sectionBComponents) c.componentId: c},
        courseComponents: sectionBComponents,
      );

      final calcC = ProgressCalculatorService(
        weeklyTimetable: {},
        semesterStartDate: DateTime(2026, 7, 13),
        subjectMetadata: {for (var c in sectionCComponents) c.componentId: c},
        courseComponents: sectionCComponents,
      );

      // Section A
      expect(
        calcA.getFixedTotalCourseHours('Mathematics', 'Theory'),
        equals(60),
      );
      expect(calcA.getFixedTotalCourseHours('Physics', 'Theory'), equals(45));
      // Section A must NOT know about Section B or C
      expect(calcA.getFixedTotalCourseHours('Database', 'Merged'), equals(0));
      expect(calcA.getFixedTotalCourseHours('AI', 'Theory'), equals(0));

      // Section B
      expect(calcB.getFixedTotalCourseHours('Database', 'Theory'), equals(45));
      expect(calcB.getFixedTotalCourseHours('Database', 'Lab'), equals(30));
      expect(
        calcB.getFixedTotalCourseHours('Database', 'Merged'),
        equals(75),
      ); // Sum of components
      expect(
        calcB.getFixedTotalCourseHours('Networks', 'Combined'),
        equals(60),
      );
      expect(calcB.getFixedTotalCourseHours('Networks', 'Merged'), equals(60));
      // Section B must NOT know about Section A or C
      expect(
        calcB.getFixedTotalCourseHours('Mathematics', 'Theory'),
        equals(0),
      );
      expect(
        calcB.getFixedTotalCourseHours('Electronics', 'Theory'),
        equals(0),
      );

      // Section C
      expect(calcC.getFixedTotalCourseHours('AI', 'Theory'), equals(45));
      expect(
        calcC.getFixedTotalCourseHours('Electronics', 'Theory'),
        equals(30),
      );
      // Section C must NOT know about Section A or B
      expect(
        calcC.getFixedTotalCourseHours('Mathematics', 'Theory'),
        equals(0),
      );
      expect(calcC.getFixedTotalCourseHours('Database', 'Merged'), equals(0));
    });

    // -------------------------------------------------------------------------
    // 2. Can Miss / Skips Remaining (80% Minimum Attendance Requirement)
    // -------------------------------------------------------------------------
    test(
      '2. Can Miss / Skips Remaining formula verified for all 3 sections',
      () {
        final calcA = ProgressCalculatorService(
          weeklyTimetable: {},
          semesterStartDate: DateTime(2026, 7, 13),
          subjectMetadata: {for (var c in sectionAComponents) c.componentId: c},
          courseComponents: sectionAComponents,
        );

        final calcB = ProgressCalculatorService(
          weeklyTimetable: {},
          semesterStartDate: DateTime(2026, 7, 13),
          subjectMetadata: {for (var c in sectionBComponents) c.componentId: c},
          courseComponents: sectionBComponents,
        );

        final calcC = ProgressCalculatorService(
          weeklyTimetable: {},
          semesterStartDate: DateTime(2026, 7, 13),
          subjectMetadata: {for (var c in sectionCComponents) c.componentId: c},
          courseComponents: sectionCComponents,
        );

        // Section A: Mathematics (60h, allowed: floor(60 * 0.20) = 12)
        // 0 absent -> 12 remaining
        expect(calcA.getRemainingSkips('Mathematics', 'Theory', 0), equals(12));
        // 4 absent -> 8 remaining
        expect(calcA.getRemainingSkips('Mathematics', 'Theory', 4), equals(8));
        // 12 absent -> 0 remaining
        expect(calcA.getRemainingSkips('Mathematics', 'Theory', 12), equals(0));
        // 15 absent -> 0 remaining (never negative)
        expect(calcA.getRemainingSkips('Mathematics', 'Theory', 15), equals(0));

        // Section A: Physics (45h, allowed: floor(45 * 0.20) = 9)
        expect(calcA.getRemainingSkips('Physics', 'Theory', 2), equals(7));

        // Section B: Database Merged (75h, allowed: floor(75 * 0.20) = 15)
        // 5 absent -> 10 remaining
        expect(calcB.getRemainingSkips('Database', 'Merged', 5), equals(10));
        // Section B: Networks (60h, allowed: 12)
        expect(calcB.getRemainingSkips('Networks', 'Merged', 12), equals(0));

        // Section C: AI (45h, allowed: 9)
        expect(calcC.getRemainingSkips('AI', 'Theory', 0), equals(9));
        // Section C: Electronics (30h, allowed: floor(30 * 0.20) = 6)
        // 8 absent -> 0 remaining (clamped to 0)
        expect(calcC.getRemainingSkips('Electronics', 'Theory', 8), equals(0));
      },
    );

    // -------------------------------------------------------------------------
    // 3. Credits Verification: Pure Academic Metadata, Not Affecting Attendance
    // -------------------------------------------------------------------------
    test('3. Credits do NOT alter attendance percentage or skips remaining', () {
      final highCreditComp = makeComp(
        id: 'HIGH_CR',
        name: 'High Credit Subject',
        type: 'Theory',
        hours: 60,
        credits: 10,
        section: 'Sec_Credit_Test',
      );

      final zeroCreditComp = makeComp(
        id: 'ZERO_CR',
        name: 'Zero Credit Subject',
        type: 'Theory',
        hours: 60,
        credits: 0,
        section: 'Sec_Credit_Test',
      );

      final calc = ProgressCalculatorService(
        weeklyTimetable: {},
        semesterStartDate: DateTime(2026, 7, 13),
        subjectMetadata: {'HIGH_CR': highCreditComp, 'ZERO_CR': zeroCreditComp},
        courseComponents: [highCreditComp, zeroCreditComp],
      );

      // Both have same 60 target hours, but completely different credits (10 vs 0).
      // Skips and hours must be identical!
      expect(
        calc.getRemainingSkips('High Credit Subject', 'Theory', 4),
        equals(calc.getRemainingSkips('Zero Credit Subject', 'Theory', 4)),
      );
      expect(
        calc.getFixedTotalCourseHours('High Credit Subject', 'Theory'),
        equals(calc.getFixedTotalCourseHours('Zero Credit Subject', 'Theory')),
      );

      // AttendanceRecord percentage formula: present / (present + absent), completely unaffected by credits
      final rec1 = AttendanceRecord(
        id: '1',
        division: 'A',
        subjectCode: 'High Credit Subject',
        component: 'Theory',
        present: 20,
        absent: 5,
      );
      final rec2 = AttendanceRecord(
        id: '2',
        division: 'A',
        subjectCode: 'Zero Credit Subject',
        component: 'Theory',
        present: 20,
        absent: 5,
      );
      expect(rec1.percentage, equals(0.80));
      expect(rec2.percentage, equals(0.80));
    });

    // -------------------------------------------------------------------------
    // 4. PDF Parsing & Course Matcher: Cross-Section Alien Subject Rejection
    // -------------------------------------------------------------------------
    test(
      '4. Unknown subjects do not accidentally get mapped to another section alias',
      () {
        final matcherB = AttendanceCourseMatcher(sectionBComponents);

        // Valid course in Section B
        final matchDb = matcherB.match(
          courseName: 'Database',
          componentType: 'Theory',
          rawCourseName: 'DatabaseT4 B',
        );
        expect(matchDb.isResolved, isTrue);
        expect(matchDb.subjectCode, equals('CS301'));

        // Foreign course from CE_C: Signals and Systems
        // Section B has NO Signals and Systems!
        // Must NOT map to SnS, must be unknown!
        final matchForeign = matcherB.match(
          courseName: 'Signals and Systems',
          componentType: 'Theory',
          rawCourseName: 'Signals and SystemsT4 A',
        );
        expect(matchForeign.confidence, equals(MatchConfidence.unknown));
        expect(matchForeign.isResolved, isFalse);
        expect(matchForeign.warning, contains('Could not match'));
      },
    );

    // -------------------------------------------------------------------------
    // 5. CSDS Department PDF Courses Normalization & Matching
    // -------------------------------------------------------------------------
    test(
      '5. Real CSDS Section PDF course names normalize and match correctly',
      () {
        final csdsComponents = [
          makeComp(
            id: 'SE_T',
            name: 'Software Engineering',
            type: 'Theory',
            hours: 45,
            credits: 3,
            section: 'CSDS_A',
            code: 'SE',
          ),
          makeComp(
            id: 'SE_P',
            name: 'Software Engineering',
            type: 'Lab',
            hours: 30,
            credits: 1,
            section: 'CSDS_A',
            code: 'SE',
          ),
          makeComp(
            id: 'DCCA_T',
            name: 'Digital Circuits and Computer Architecture',
            type: 'Theory',
            hours: 45,
            credits: 3,
            section: 'CSDS_A',
            code: 'DCCA',
          ),
          makeComp(
            id: 'WDD_T',
            name: 'Website Designing and Development',
            type: 'Theory',
            hours: 45,
            credits: 3,
            section: 'CSDS_A',
            code: 'WDD',
          ),
          makeComp(
            id: 'PE_T',
            name: 'Prompt Engineering for ChatGPT',
            type: 'Theory',
            hours: 30,
            credits: 2,
            section: 'CSDS_A',
            code: 'PE',
          ),
        ];

        final csdsMatcher = AttendanceCourseMatcher(csdsComponents);

        // Row from real PDF: Software EngineeringT4 CSDS Sem III A
        final normSE = AttendanceCourseNormalizer.normalize(
          'Software EngineeringT4 CSDS Sem III A',
        );
        expect(normSE.courseName, equals('Software Engineering'));
        expect(normSE.componentType, equals('Theory'));
        final matchSE = csdsMatcher.match(
          courseName: normSE.courseName,
          componentType: normSE.componentType,
          rawCourseName: 'Software EngineeringT4 CSDS Sem III A',
        );
        expect(matchSE.isResolved, isTrue);
        expect(matchSE.subjectCode, equals('SE'));

        // Row from real PDF: Website Designing and DevelopmentT4 DS A
        final normWDD = AttendanceCourseNormalizer.normalize(
          'Website Designing and DevelopmentT4 DS A',
        );
        expect(normWDD.courseName, equals('Website Designing and Development'));
        expect(normWDD.componentType, equals('Theory'));
        final matchWDD = csdsMatcher.match(
          courseName: normWDD.courseName,
          componentType: normWDD.componentType,
          rawCourseName: 'Website Designing and DevelopmentT4 DS A',
        );
        expect(matchWDD.isResolved, isTrue);
        expect(matchWDD.subjectCode, equals('WDD'));

        // Row from real PDF: Prompt Engineering for ChatGPTT4 DS-III
        final normPE = AttendanceCourseNormalizer.normalize(
          'Prompt Engineering for ChatGPTT4 DS-III',
        );
        expect(normPE.courseName, equals('Prompt Engineering for ChatGPT'));
        final matchPE = csdsMatcher.match(
          courseName: normPE.courseName,
          componentType: normPE.componentType,
          rawCourseName: 'Prompt Engineering for ChatGPTT4 DS-III',
        );
        expect(matchPE.isResolved, isTrue);
        expect(matchPE.subjectCode, equals('PE'));
      },
    );
  });
}
