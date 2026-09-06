import 'package:flutter_test/flutter_test.dart';
import 'package:schedly/models/attendance_import_models.dart';
import 'package:schedly/models/attendance_log.dart';
import 'package:schedly/models/course_component.dart';
import 'package:schedly/services/attendance_course_matcher.dart';
import 'package:schedly/services/attendance_course_normalizer.dart';
import 'package:schedly/services/subject_identity_service.dart';

void main() {
  final solSectionId = 'SOL_3rdYear_BALLB_SemV_A';
  final testDate = DateTime(2026, 7, 20);

  CourseComponent makeSolComp({
    required String componentId,
    required String courseName,
    String componentType = 'Theory',
    int targetHours = 60,
  }) {
    return CourseComponent(
      componentId: componentId,
      componentType: componentType,
      courseName: courseName,
      courseCode: '', // In SOL, courseCode is empty or full name (never acronym)
      targetHours: targetHours,
      facultyId: '',
      createdAt: testDate,
      sectionId: solSectionId,
    );
  }

  group('SOL Attendance Normalization Tests', () {
    test('1. Normalizes SAP course string with BALLB and Sem V noise', () {
      final norm = AttendanceCourseNormalizer.normalize(
        'Administrative LawT1 BALLB Sem V',
      );
      expect(norm.courseName, equals('Administrative Law'));
      expect(norm.componentCode, equals('T1'));
      expect(norm.componentType, equals('Theory'));
      expect(norm.parsed, isTrue);
    });

    test('2. Normalizes SAP Tutorial code U1 to Tutorial component', () {
      final norm = AttendanceCourseNormalizer.normalize(
        'Administrative LawU1 BALLB Sem V',
      );
      expect(norm.courseName, equals('Administrative Law'));
      expect(norm.componentCode, equals('U1'));
      expect(norm.componentType, equals('Tutorial'));
      expect(norm.parsed, isTrue);
    });

    test('3. Normalizes Environmental Law Tutorial with batch A', () {
      final norm = AttendanceCourseNormalizer.normalize(
        'Environmental LawU1 BALLB Sem V A',
      );
      expect(norm.courseName, equals('Environmental Law'));
      expect(norm.componentCode, equals('U1'));
      expect(norm.componentType, equals('Tutorial'));
    });

    test('4. Handles explicit (U) and (T) notations without SAP suffix code', () {
      final uNorm = AttendanceCourseNormalizer.normalize(
        'Administrative Law (U)',
      );
      expect(uNorm.courseName, equals('Administrative Law'));
      expect(uNorm.componentType, equals('Tutorial'));
      expect(uNorm.componentCode, equals('U'));

      final tNorm = AttendanceCourseNormalizer.normalize(
        'Company Law II (T)',
      );
      expect(tNorm.courseName, equals('Company Law II'));
      expect(tNorm.componentType, equals('Theory'));

      final bracketNorm = AttendanceCourseNormalizer.normalize(
        'Environmental Law [U]',
      );
      expect(bracketNorm.courseName, equals('Environmental Law'));
      expect(bracketNorm.componentType, equals('Tutorial'));
    });

    test('5. Unmarked raw academic subject defaults to Theory', () {
      final norm = AttendanceCourseNormalizer.normalize('Family Law II');
      expect(norm.courseName, equals('Family Law II'));
      expect(norm.componentType, equals('Theory'));
    });

    test('6. normalizeForMatching strips component, BALLB, BBALLB, LLB, and Sem noise', () {
      final input1 = AttendanceCourseNormalizer.normalizeForMatching(
        'Administrative LawT1 BALLB Sem V',
      );
      final target1 = AttendanceCourseNormalizer.normalizeForMatching(
        'Administrative Law',
      );
      expect(input1, equals(target1));

      final input2 = AttendanceCourseNormalizer.normalizeForMatching(
        'Company Law II BBALLB Sem V A',
      );
      final target2 = AttendanceCourseNormalizer.normalizeForMatching(
        'Company Law II',
      );
      expect(input2, equals(target2));
    });
  });

  group('SOL Attendance Course Matcher & Full-Name Preservation Tests', () {
    final configuredSolCourses = [
      makeSolComp(
        componentId: 'Administrative_Law_Theory',
        courseName: 'Administrative Law',
        componentType: 'Theory',
      ),
      makeSolComp(
        componentId: 'Administrative_Law_Tutorial',
        courseName: 'Administrative Law',
        componentType: 'Tutorial',
      ),
      makeSolComp(
        componentId: 'Company_Law_II_Theory',
        courseName: 'Company Law II',
        componentType: 'Theory',
      ),
      makeSolComp(
        componentId: 'Environmental_Law_Theory',
        courseName: 'Environmental Law',
        componentType: 'Theory',
      ),
      makeSolComp(
        componentId: 'Environmental_Law_Tutorial',
        courseName: 'Environmental Law',
        componentType: 'Tutorial',
      ),
      makeSolComp(
        componentId: 'CPC_Limitation_Act_Theory',
        courseName: 'CPC & Limitation Act',
        componentType: 'Theory',
      ),
    ];

    test('7. Exact match preserves FULL subject name (never shortened or underscored)', () {
      final matcher = AttendanceCourseMatcher(configuredSolCourses);
      final match = matcher.match(
        courseName: 'Administrative Law',
        componentType: 'Theory',
        rawCourseName: 'Administrative LawT1 BALLB Sem V',
      );

      expect(match.isResolved, isTrue);
      expect(match.subjectCode, equals('Administrative Law'));
      expect(match.subjectCode, isNot(equals('Administrative_Law')));
      expect(match.component, equals('Theory'));
      expect(match.confidence, equals(MatchConfidence.exact));
    });

    test('8. Matches Tutorial component cleanly with full name', () {
      final matcher = AttendanceCourseMatcher(configuredSolCourses);
      final match = matcher.match(
        courseName: 'Administrative Law',
        componentType: 'Tutorial',
        rawCourseName: 'Administrative LawU1 BALLB Sem V',
      );

      expect(match.isResolved, isTrue);
      expect(match.subjectCode, equals('Administrative Law'));
      expect(match.component, equals('Tutorial'));
    });

    test('9. Normalized match resolves SAP string against configured SOL course', () {
      final matcher = AttendanceCourseMatcher(configuredSolCourses);
      final match = matcher.match(
        courseName: 'CPC & Limitation Act',
        componentType: 'Theory',
        rawCourseName: 'CPC & Limitation ActT1 BALLB Sem V',
      );

      expect(match.isResolved, isTrue);
      expect(match.subjectCode, equals('CPC & Limitation Act'));
      expect(match.component, equals('Theory'));
    });

    test('10. STME courseAliases logic NEVER intercepts SOL courses', () {
      final matcher = AttendanceCourseMatcher(configuredSolCourses);
      final match = matcher.match(
        courseName: 'Environmental Law',
        componentType: 'Theory',
        rawCourseName: 'Environmental LawT1 BALLB Sem V',
      );

      expect(match.isResolved, isTrue);
      expect(match.subjectCode, equals('Environmental Law'));
      expect(match.confidence, isNot(equals(MatchConfidence.alias)));
    });
  });

  group('SOL Subject Identity & Timetable Reconciliation Tests', () {
    final configuredSolCourses = [
      makeSolComp(
        componentId: 'Administrative_Law_Theory',
        courseName: 'Administrative Law',
        componentType: 'Theory',
      ),
      makeSolComp(
        componentId: 'Administrative_Law_Tutorial',
        courseName: 'Administrative Law',
        componentType: 'Tutorial',
      ),
      makeSolComp(
        componentId: 'Company_Law_II_Theory',
        courseName: 'Company Law II',
        componentType: 'Theory',
      ),
    ];

    test('11. SubjectIdentityService resolves full displayName and canonicalKey for SOL', () {
      final identity = SubjectIdentityService.resolve(
        'Administrative Law',
        configuredCourses: configuredSolCourses,
      );

      expect(identity.isResolved, isTrue);
      expect(identity.displayName, equals('Administrative Law'));
      expect(identity.canonicalKey, equals('Administrative Law'));
      expect(identity.shortCode, isNull);
    });

    test('12. isMatch reliably reconciles Timetable full name with Attendance raw SAP string', () {
      final match = SubjectIdentityService.isMatch(
        'Administrative Law',
        'Administrative LawT1 BALLB Sem V',
        configuredCourses: configuredSolCourses,
      );

      expect(match, isTrue);
    });

    test('13. STME Engineering aliases remain 100% functional and untouched', () {
      expect(SubjectIdentityService.isMatch('SE', 'Software Engineering'), isTrue);
      expect(SubjectIdentityService.isMatch('DSA', 'Data Structures and Algorithms'), isTrue);
      expect(SubjectIdentityService.isMatch('COA', 'Computer Organization and Architecture'), isTrue);

      final seIdentity = SubjectIdentityService.resolve('SE');
      expect(seIdentity.canonicalKey, equals('Software Engineering'));
      expect(seIdentity.shortCode, equals('SE'));

      final dsaIdentity = SubjectIdentityService.resolve('DSA');
      expect(dsaIdentity.canonicalKey, equals('DSA'));
      expect(dsaIdentity.shortCode, equals('DSA'));
    });
  });
}
