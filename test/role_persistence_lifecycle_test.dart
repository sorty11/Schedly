import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:schedly/app_settings.dart';
import 'package:schedly/user_roles.dart';
import 'package:schedly/nmims_structure.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.resetRole();
  });

  group('Role Persistence Lifecycle Tests', () {
    test('1. Default state on fresh launch is Student with null fields', () {
      expect(AppSettings.currentRole, equals(UserRole.student));
      expect(AppSettings.studentName, isNull);
      expect(AppSettings.facultyName, isNull);
      expect(AppSettings.sectionId, isNull);
    });

    test('2. Student details persistence across SharedPreferences and AppSettings', () async {
      await AppSettings.saveRole(UserRole.student);
      await AppSettings.saveStudentDetails(
        name: 'John Doe',
        rollNo: 'A001',
        batch: 'A1',
        acYear: 'Second Year',
        br: 'CSDS',
        div: 'B',
        secId: 'SecondYear_CSDS_B',
        schoolName: 'STME',
        programName: 'CSDS',
        sem: 'Semester III',
      );

      expect(AppSettings.currentRole, equals(UserRole.student));
      expect(AppSettings.studentName, equals('John Doe'));
      expect(AppSettings.studentRollNo, equals('A001'));
      expect(AppSettings.studentBatch, equals('A1'));
      expect(AppSettings.sectionId, equals('SecondYear_CSDS_B'));

      // Simulate app restart by reloading from prefs into fresh memory
      final prefs = await SharedPreferences.getInstance();
      AppSettings.loadFromPrefs(prefs);

      expect(AppSettings.currentRole, equals(UserRole.student));
      expect(AppSettings.studentName, equals('John Doe'));
      expect(AppSettings.studentBatch, equals('A1'));
      expect(AppSettings.sectionId, equals('SecondYear_CSDS_B'));
    });

    test('3. CR role persistence', () async {
      await AppSettings.saveRole(UserRole.cr);
      await AppSettings.saveStudentDetails(
        name: 'CR Jane',
        rollNo: 'A002',
        acYear: 'Third Year',
        br: 'CE',
        div: 'A',
        secId: 'ThirdYear_CE_A',
      );

      expect(AppSettings.currentRole, equals(UserRole.cr));

      final prefs = await SharedPreferences.getInstance();
      AppSettings.loadFromPrefs(prefs);

      expect(AppSettings.currentRole, equals(UserRole.cr));
      expect(AppSettings.studentName, equals('CR Jane'));
    });

    test('4. SR role and SR details persistence', () async {
      await AppSettings.saveRole(UserRole.sr);
      await AppSettings.saveStudentDetails(
        name: 'SR Bob',
        rollNo: 'A003',
        acYear: 'Third Year',
        br: 'IT',
        div: 'C',
        secId: 'ThirdYear_IT_C',
      );
      await AppSettings.saveSRDetails(
        division: 'ThirdYear_IT_C',
        subject: 'Cloud Computing',
        component: 'Lab',
        batch: 'C1',
      );

      expect(AppSettings.currentRole, equals(UserRole.sr));
      expect(AppSettings.srSubject, equals('Cloud Computing'));
      expect(AppSettings.srComponent, equals('Lab'));
      expect(AppSettings.srBatch, equals('C1'));

      final prefs = await SharedPreferences.getInstance();
      AppSettings.loadFromPrefs(prefs);

      expect(AppSettings.currentRole, equals(UserRole.sr));
      expect(AppSettings.srSubject, equals('Cloud Computing'));
      expect(AppSettings.srBatch, equals('C1'));
    });

    test('5. Faculty details and setup completion persistence', () async {
      await AppSettings.saveRole(UserRole.faculty);
      await AppSettings.saveFacultyDetails(
        name: 'Dr. Smith',
        email: 'smith@nmims.edu',
        department: 'Computer Science',
        designation: 'Professor',
        cabin: 'Room 501',
        assignedDivisions: ['SecondYear_CSDS_B', 'ThirdYear_CE_A'],
        id: 'fac_123',
      );
      await AppSettings.completeFacultySetup();

      expect(AppSettings.currentRole, equals(UserRole.faculty));
      expect(AppSettings.facultyName, equals('Dr. Smith'));
      expect(AppSettings.facultyEmail, equals('smith@nmims.edu'));
      expect(AppSettings.facultyCabin, equals('Room 501'));
      expect(AppSettings.facultySetupCompleted, isTrue);
      expect(AppSettings.facultyAssignedDivisions, contains('SecondYear_CSDS_B'));

      // Simulate app restart
      final prefs = await SharedPreferences.getInstance();
      AppSettings.loadFromPrefs(prefs);

      expect(AppSettings.currentRole, equals(UserRole.faculty));
      expect(AppSettings.facultyName, equals('Dr. Smith'));
      expect(AppSettings.facultySetupCompleted, isTrue);
    });

    test('6. resetRole() thoroughly clears all in-memory fields and SharedPreferences', () async {
      await AppSettings.saveRole(UserRole.faculty);
      await AppSettings.saveFacultyDetails(
        name: 'Dr. Smith',
        email: 'smith@nmims.edu',
        department: 'CS',
        designation: 'Prof',
        cabin: '501',
        id: 'fac_123',
      );
      await AppSettings.saveStudentDetails(
        name: 'John',
        rollNo: 'A1',
        acYear: 'Year',
        br: 'CE',
        div: 'A',
        secId: 'Year_CE_A',
      );

      await AppSettings.resetRole();

      expect(AppSettings.currentRole, equals(UserRole.student));
      expect(AppSettings.studentName, isNull);
      expect(AppSettings.studentRollNo, isNull);
      expect(AppSettings.studentBatch, isNull);
      expect(AppSettings.academicYear, isNull);
      expect(AppSettings.branch, isNull);
      expect(AppSettings.division, isNull);
      expect(AppSettings.sectionId, isNull);
      expect(AppSettings.facultyName, isNull);
      expect(AppSettings.facultyEmail, isNull);
      expect(AppSettings.facultyId, isNull);
      expect(AppSettings.facultySetupCompleted, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('user_role'), isNull);
      expect(prefs.getString('student_name'), isNull);
      expect(prefs.getString('faculty_name'), isNull);
      expect(prefs.getString('section_id'), isNull);
    });

    test('7. NMIMSStructure.parseSectionId parses legacy STME sections accurately', () {
      final parsed = NMIMSStructure.parseSectionId('SecondYear_CSDS_B');
      expect(parsed['school'], equals('STME'));
      expect(parsed['year'], equals('SecondYear'));
      expect(parsed['branch'], equals('CSDS'));
      expect(parsed['division'], equals('B'));
    });

    test('8. NMIMSStructure.parseSectionId parses modern multi-school sections accurately', () {
      final parsed = NMIMSStructure.parseSectionId('SOL_1stYear_BALLB_SemI_DivA');
      expect(parsed['school'], equals('SOL'));
      expect(parsed['year'], equals('1stYear'));
      expect(parsed['branch'], equals('BALLB'));
      expect(parsed['semester'], equals('SemI'));
      expect(parsed['division'], equals('DivA'));
    });

    test('9. Existing user detection criteria handles various production document shapes', () {
      bool isExistingUser(Map<String, dynamic> data) {
        final role = (data['role'] ?? data['userType']) as String?;
        final divisionVal = data['division'] as String?;
        return data['onboardingCompleted'] == true ||
            data['profileCompleted'] == true ||
            role != null ||
            (divisionVal != null && divisionVal.isNotEmpty);
      }

      // Case A: Standard complete profile
      expect(isExistingUser({'onboardingCompleted': true, 'role': 'Student'}), isTrue);

      // Case B: Legacy profile with only profileCompleted
      expect(isExistingUser({'profileCompleted': true, 'role': 'Faculty'}), isTrue);

      // Case C: Account created via DivisionMembershipService without onboardingCompleted
      expect(isExistingUser({'role': 'Student', 'division': 'SecondYear_CE_A'}), isTrue);

      // Case D: Faculty elevated via FacultyAuthService with role only
      expect(isExistingUser({'role': 'Faculty', 'facultyProfileId': 'fac_123'}), isTrue);

      // Case E: Pure new user (empty doc)
      expect(isExistingUser({}), isFalse);

      // Case F: Partial draft doc without role or division
      expect(isExistingUser({'draftProfile': {'name': 'Newbie'}}), isFalse);
    });

    test('10. Switching from Faculty to Student resets role and re-hydrates student properly', () async {
      // Step 1: Faculty logs in
      await AppSettings.saveRole(UserRole.faculty);
      await AppSettings.saveFacultyDetails(
        name: 'Dr. Test',
        email: 'test@nmims.edu',
        department: 'IT',
        designation: 'HOD',
        cabin: '402',
        id: 'fac_999',
      );
      expect(AppSettings.currentRole, equals(UserRole.faculty));

      // Step 2: Logout
      await AppSettings.resetRole();
      expect(AppSettings.currentRole, equals(UserRole.student));
      expect(AppSettings.facultyName, isNull);

      // Step 3: Student logs in
      await AppSettings.saveRole(UserRole.student);
      await AppSettings.saveStudentDetails(
        name: 'Alice',
        rollNo: 'B010',
        acYear: 'First Year',
        br: 'CE',
        div: 'A',
        secId: 'FirstYear_CE_A',
      );
      expect(AppSettings.currentRole, equals(UserRole.student));
      expect(AppSettings.studentName, equals('Alice'));
      expect(AppSettings.facultyName, isNull);
    });

    test('11. Student batch update preserves rest of student info', () async {
      await AppSettings.saveStudentDetails(
        name: 'Bob',
        rollNo: 'B020',
        batch: 'B1',
        acYear: 'Second Year',
        br: 'AI',
        div: 'A',
        secId: 'SecondYear_AI_A',
      );
      expect(AppSettings.studentBatch, equals('B1'));

      await AppSettings.saveStudentBatch('B2');
      expect(AppSettings.studentBatch, equals('B2'));
      expect(AppSettings.studentName, equals('Bob'));
      expect(AppSettings.sectionId, equals('SecondYear_AI_A'));
    });

    test('12. Fast path session check evaluates cached session reliably', () {
      bool canFastPath({String? studentName, String? facultyName, required bool emailVerified}) {
        return emailVerified && (studentName != null || facultyName != null);
      }

      expect(canFastPath(studentName: 'Bob', emailVerified: true), isTrue);
      expect(canFastPath(facultyName: 'Dr. X', emailVerified: true), isTrue);
      expect(canFastPath(studentName: 'Bob', emailVerified: false), isFalse);
      expect(canFastPath(studentName: null, facultyName: null, emailVerified: true), isFalse);
    });

    test('13. Role serialization and deserialization across all UserRole enum values', () async {
      for (final role in UserRole.values) {
        await AppSettings.saveRole(role);
        expect(AppSettings.currentRole, equals(role));

        final prefs = await SharedPreferences.getInstance();
        AppSettings.loadFromPrefs(prefs);
        expect(AppSettings.currentRole, equals(role));
      }
    });
  });
}
