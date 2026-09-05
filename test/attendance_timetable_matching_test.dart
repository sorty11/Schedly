import 'package:flutter_test/flutter_test.dart';
import 'package:schedly/models/attendance_log.dart';
import 'package:schedly/models/attendance_record.dart';
import 'package:schedly/models/attendance_subject_view_model.dart';
import 'package:schedly/models/course_component.dart';
import 'package:schedly/models/event_category.dart';
import 'package:schedly/models/timetable_entry.dart';
import 'package:schedly/services/progress_calculator_service.dart';
import 'package:schedly/services/subject_identity_service.dart';

void main() {
  final testDate = DateTime(2026, 7, 13);

  CourseComponent makeComp({
    required String componentId,
    required String courseName,
    String courseCode = '',
    String componentType = 'Theory',
    int targetHours = 45,
    String facultyId = '',
    String sectionId = 'CE_C',
  }) {
    return CourseComponent(
      componentId: componentId,
      componentType: componentType,
      courseName: courseName,
      courseCode: courseCode,
      targetHours: targetHours,
      facultyId: facultyId,
      createdAt: testDate,
      sectionId: sectionId,
    );
  }

  group('Attendance ↔ Timetable Subject Matching & Identity Tests', () {
    test('1. High-confidence deterministic aliases resolve correctly bidirectionally', () {
      final pairs = [
        ('SE', 'Software Engineering'),
        ('IPS', 'Interpersonal Skills'),
        ('DSA', 'Data Structures and Algorithms'),
        ('TC', 'Technical Communication'),
        ('COA', 'Computer Organization and Architecture'),
        ('SnS', 'Signals and Systems'),
        ('PnS', 'Probability and Statistics'),
        ('DM', 'Discrete Mathematics'),
        ('Python', 'Programming with Python'),
        ('DCCA', 'Digital Circuits and Computer Architecture'),
      ];

      for (final (shortCode, fullName) in pairs) {
        expect(
          SubjectIdentityService.isMatch(shortCode, fullName),
          isTrue,
          reason: '$shortCode should match $fullName',
        );
        expect(
          SubjectIdentityService.isMatch(fullName, shortCode),
          isTrue,
          reason: '$fullName should match $shortCode',
        );

        final idShort = SubjectIdentityService.resolve(shortCode);
        final idFull = SubjectIdentityService.resolve(fullName);

        expect(idShort.isResolved, isTrue);
        expect(idFull.isResolved, isTrue);
        expect(
          idShort.canonicalKey.toUpperCase(),
          equals(idFull.canonicalKey.toUpperCase()),
          reason: 'Canonical keys for $shortCode and $fullName must match',
        );
      }
    });

    test('2. canonicalSubjectCode maps SE and IPS consistently to full names', () {
      expect(
        AttendanceLog.canonicalSubjectCode('SE'),
        equals('Software Engineering'),
      );
      expect(
        AttendanceLog.canonicalSubjectCode('Software Engineering'),
        equals('Software Engineering'),
      );
      expect(
        AttendanceLog.canonicalSubjectCode('IPS'),
        equals('Interpersonal Skills'),
      );
      expect(
        AttendanceLog.canonicalSubjectCode('Interpersonal Skills'),
        equals('Interpersonal Skills'),
      );
    });

    test('3. PEM context-aware resolution handles Electrical vs Economics', () {
      // Electrical machines section
      final electricalCourses = [
        makeComp(
          componentId: 'PEM_Theory',
          courseName: 'Principles of Electrical Machines',
          courseCode: 'PEM',
        ),
      ];
      final electricalId = SubjectIdentityService.resolve(
        'PEM',
        configuredCourses: electricalCourses,
      );
      expect(electricalId.displayName, equals('Principles of Electrical Machines'));
      expect(electricalId.canonicalKey, equals('PEM'));

      // Economics section
      final economicsCourses = [
        makeComp(
          componentId: 'PEM_Theory',
          courseName: 'Principles of Economics and Management',
          courseCode: 'PEM',
          targetHours: 30,
        ),
      ];
      final economicsId = SubjectIdentityService.resolve(
        'PEM',
        configuredCourses: economicsCourses,
      );
      expect(economicsId.displayName, equals('Principles of Economics and Management'));
      expect(economicsId.canonicalKey, equals('PEM'));
    });

    test('4. PEC resolution: exactly 1 elective in section resolves deterministically', () {
      final sectionCourses = [
        makeComp(
          componentId: 'DSA_Theory',
          courseName: 'Data Structures and Algorithms',
          courseCode: 'DSA',
        ),
        makeComp(
          componentId: 'PEC_DL',
          courseName: 'Deep Learning',
          courseCode: 'PEC-1',
        ),
      ];

      final id = SubjectIdentityService.resolve('PEC', configuredCourses: sectionCourses);
      expect(id.isResolved, isTrue);
      expect(id.displayName, equals('Deep Learning'));
      expect(id.matchedComponent?.componentId, equals('PEC_DL'));
    });

    test('5. PEC resolution: multiple electives without disambiguation marks needs review (never guess)', () {
      final sectionCourses = [
        makeComp(
          componentId: 'PEC_DL',
          courseName: 'Deep Learning',
          courseCode: 'PEC-1',
        ),
        makeComp(
          componentId: 'PEC_NLP',
          courseName: 'Natural Language Processing',
          courseCode: 'PEC-2',
        ),
      ];

      final id = SubjectIdentityService.resolve('PEC', configuredCourses: sectionCourses);
      expect(id.isResolved, isFalse);
      expect(id.isAmbiguous, isTrue);
      expect(id.statusMessage, equals('Subject matching needs review'));
      expect(id.confidence, equals(MatchConfidence.unknown));
    });

    test('6. Multi-section compatibility: Works dynamically for non-CE_C custom subjects', () {
      final meCourses = [
        makeComp(
          componentId: 'TD_Theory',
          courseName: 'Thermodynamics',
          courseCode: 'TD',
          targetHours: 60,
          sectionId: 'ME_A',
        ),
        makeComp(
          componentId: 'FM_Theory',
          courseName: 'Fluid Mechanics',
          courseCode: 'FM',
          targetHours: 45,
          sectionId: 'ME_A',
        ),
      ];

      expect(
        SubjectIdentityService.isMatch('TD', 'Thermodynamics', configuredCourses: meCourses),
        isTrue,
      );
      expect(
        SubjectIdentityService.isMatch('FM', 'Fluid Mechanics', configuredCourses: meCourses),
        isTrue,
      );
      expect(
        SubjectIdentityService.isMatch('TD', 'Fluid Mechanics', configuredCourses: meCourses),
        isFalse,
      );

      final id = SubjectIdentityService.resolve('TD', configuredCourses: meCourses);
      expect(id.isResolved, isTrue);
      expect(id.displayName, equals('Thermodynamics'));
      expect(id.matchedComponent?.targetHours, equals(60));
    });

    test('7. ProgressCalculatorService gets configured course hours for short form SE/IPS', () {
      final configured = [
        makeComp(
          componentId: 'SE_Theory',
          courseName: 'Software Engineering',
          courseCode: 'SE',
          componentType: 'Theory',
          targetHours: 45,
        ),
        makeComp(
          componentId: 'SE_Lab',
          courseName: 'Software Engineering',
          courseCode: 'SE',
          componentType: 'Lab',
          targetHours: 30,
        ),
        makeComp(
          componentId: 'IPS_Lab',
          courseName: 'Interpersonal Skills',
          courseCode: 'IPS',
          componentType: 'Lab',
          targetHours: 30,
        ),
      ];

      final calc = ProgressCalculatorService(
        weeklyTimetable: {},
        semesterStartDate: DateTime(2026, 7, 13),
        subjectMetadata: {},
        courseComponents: configured,
      );

      // Querying with 'Software Engineering' Merged sums Theory (45) + Lab (30) = 75
      expect(calc.getConfiguredCourseHours('Software Engineering', 'Merged'), equals(75));

      // Querying with short form 'SE' Merged ALSO returns 75!
      expect(calc.getConfiguredCourseHours('SE', 'Merged'), equals(75));

      // Querying with short form 'IPS' Merged returns 30
      expect(calc.getConfiguredCourseHours('IPS', 'Merged'), equals(30));
    });

    test('8. ProgressCalculatorService matches timetable entries with short forms for conducted hours', () {
      final timetable = <int, List<TimetableEntry>>{
        // Monday (weekday 1): 2 hours of SE (Theory)
        1: [
          TimetableEntry(
            id: 'entry_1',
            subject: 'SE',
            component: 'Theory',
            category: EventCategory.academic,
            batch: 'Whole Class',
            startTime: 540,
            endTime: 660,
            durationMinutes: 120,
            room: '101',
            facultyId: 'fac_1',
          ),
          TimetableEntry(
            id: 'entry_2',
            subject: 'IPS',
            component: 'Lab',
            category: EventCategory.academic,
            batch: 'Whole Class',
            startTime: 675,
            endTime: 795,
            durationMinutes: 120,
            room: 'Lab 2',
            facultyId: 'fac_2',
          ),
        ],
      };

      // Set semester start to exactly 7 days ago (1 Monday has passed)
      final now = DateTime.now();
      final oneWeekAgo = now.subtract(const Duration(days: 7));

      final calc = ProgressCalculatorService(
        weeklyTimetable: timetable,
        semesterStartDate: oneWeekAgo,
        subjectMetadata: {},
        courseComponents: [
          makeComp(
            componentId: 'SE_Theory',
            courseName: 'Software Engineering',
            courseCode: 'SE',
            componentType: 'Theory',
            targetHours: 45,
          ),
        ],
      );

      // Conducted hours queried by full name 'Software Engineering' Merged matches 'SE' in timetable!
      final conductedSE = calc.getExpectedConductedHours('Software Engineering', 'Merged');
      expect(conductedSE, greaterThanOrEqualTo(2));

      // Conducted hours queried by full name 'Interpersonal Skills' Merged matches 'IPS' in timetable!
      final conductedIPS = calc.getExpectedConductedHours('Interpersonal Skills', 'Merged');
      expect(conductedIPS, greaterThanOrEqualTo(2));
    });

    test('9. AttendanceSubjectViewModel correctly sets needsReview badge for unresolved electives', () {
      final multiElectiveSection = [
        makeComp(
          componentId: 'PEC_1',
          courseName: 'Cloud Computing Elective',
          targetHours: 45,
        ),
        makeComp(
          componentId: 'PEC_2',
          courseName: 'Blockchain Elective',
          targetHours: 45,
        ),
      ];

      final calc = ProgressCalculatorService(
        weeklyTimetable: {},
        semesterStartDate: DateTime(2026, 7, 13),
        subjectMetadata: {},
        courseComponents: multiElectiveSection,
      );

      // Record with ambiguous 'PEC'
      final rec = AttendanceRecord(
        id: 'A_PEC_Merged',
        division: 'A',
        subjectCode: 'PEC',
        component: 'Merged',
        present: 10,
        absent: 2,
      );

      final vm = AttendanceSubjectViewModel.fromRecord(
        record: rec,
        calculator: calc,
      );

      expect(vm.needsReview, isTrue);
      expect(vm.reviewMessage, equals('Subject matching needs review'));

      // Clean record with resolved subject 'Software Engineering'
      final recSE = AttendanceRecord(
        id: 'A_SE_Merged',
        division: 'A',
        subjectCode: 'Software Engineering',
        component: 'Merged',
        present: 10,
        absent: 2,
      );

      final vmSE = AttendanceSubjectViewModel.fromRecord(
        record: recSE,
        calculator: calc,
      );

      expect(vmSE.needsReview, isFalse);
    });

    test('10. Non-negotiable grouping rule: DSA Theory and Lab split, all other courses merged', () {
      expect(AttendanceLog.canonicalComponent('DSA', 'Theory'), equals('Theory'));
      expect(AttendanceLog.canonicalComponent('DSA', 'Lab'), equals('Lab'));
      expect(AttendanceLog.canonicalComponent('DSA', 'P4'), equals('Lab'));
      expect(AttendanceLog.canonicalComponent('DSA', 'T4'), equals('Theory'));

      expect(AttendanceLog.canonicalComponent('Software Engineering', 'T4'), equals('Merged'));
      expect(AttendanceLog.canonicalComponent('Software Engineering', 'P4'), equals('Merged'));
      expect(AttendanceLog.canonicalComponent('SE', 'Lab'), equals('Merged'));
      expect(AttendanceLog.canonicalComponent('IPS', 'P4'), equals('Merged'));
      expect(AttendanceLog.canonicalComponent('PnS', 'P4'), equals('Merged'));
      expect(AttendanceLog.canonicalComponent('Python', 'P4'), equals('Merged'));

      // Check canonicalGroupKey
      expect(AttendanceLog.canonicalGroupKey('SE', 'T4'), equals('Software Engineering_Merged'));
      expect(AttendanceLog.canonicalGroupKey('SE', 'P4'), equals('Software Engineering_Merged'));
      expect(AttendanceLog.canonicalGroupKey('Software Engineering', 'Lab'), equals('Software Engineering_Merged'));
      expect(AttendanceLog.canonicalGroupKey('IPS', 'P4'), equals('Interpersonal Skills_Merged'));
      expect(AttendanceLog.canonicalGroupKey('DSA', 'T4'), equals('DSA_Theory'));
      expect(AttendanceLog.canonicalGroupKey('DSA', 'P4'), equals('DSA_Lab'));
    });
  });
}
