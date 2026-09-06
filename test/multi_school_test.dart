import 'package:flutter_test/flutter_test.dart';
import 'package:schedly/nmims_structure.dart';
import 'package:schedly/models/section_config.dart';

void main() {
  group('NMIMSStructure Multi-School Tests', () {
    test('schools catalog contains STME and SOL', () {
      final schoolIds = NMIMSStructure.schools.map((s) => s.id).toList();
      expect(schoolIds, contains('STME'));
      expect(schoolIds, contains('SOL'));

      final sol = NMIMSStructure.getSchool('SOL');
      expect(sol.name, equals('School of Law'));
      expect(sol.programs.any((p) => p.id == 'BALLB'), isTrue);

      final ballb = sol.programs.firstWhere((p) => p.id == 'BALLB');
      expect(ballb.name, equals('B.A. LL.B. (Hons.)'));
    });

    test('solYears and solSemestersByYear contain Law 3rd Year Sem V', () {
      expect(NMIMSStructure.solYears, contains('3rd Year'));
      final semList = NMIMSStructure.solSemestersByYear['3rd Year'];
      expect(semList, isNotNull);
      expect(semList, contains('Semester V'));
      expect(semList, contains('Semester VI'));
    });

    test('Legacy STME section ID generation retains exact format', () {
      final stmeId = NMIMSStructure.generateSectionId(
        school: 'STME',
        year: 'Third Year',
        branchOrProgram: 'CE',
        division: 'A',
      );
      // STME format: '${year}_${branch}_$div' -> 'ThirdYear_CE_A'
      expect(stmeId, equals('ThirdYear_CE_A'));

      final defaultStmeId = NMIMSStructure.generateSectionId(
        year: 'Second Year',
        branchOrProgram: 'DS',
        division: 'B',
      );
      expect(defaultStmeId, equals('SecondYear_DS_B'));
    });

    test('SOL section ID generation creates collision-safe canonical format', () {
      final solId = NMIMSStructure.generateSectionId(
        school: 'SOL',
        year: '3rd Year',
        branchOrProgram: 'B.A. LL.B. (Hons.)',
        semester: 'Semester V',
        division: 'A',
      );
      expect(solId, equals('SOL_3rdYear_BALLB_SemV_A'));

      final solIdShortSem = NMIMSStructure.generateSectionId(
        school: 'SOL',
        year: '1st Year',
        branchOrProgram: 'B.B.A. LL.B. (Hons.)',
        semester: 'Sem I',
        division: 'B',
      );
      expect(solIdShortSem, equals('SOL_1stYear_BBALLB_SemI_B'));
    });
  });

  group('SectionConfig Multi-School Serialization Tests', () {
    test('Default/legacy JSON without school or program defaults to STME and branch', () {
      final legacyJson = <String, dynamic>{
        'academicYear': 'Third Year',
        'branch': 'Computer Engineering',
        'division': 'A',
        'workingDays': <String>['Monday', 'Tuesday'],
        'batches': <String>['A1', 'A2'],
        'periods': <Map<String, dynamic>>[],
      };

      final config = SectionConfig.fromJson(legacyJson, 'ThirdYear_CE_A');
      expect(config.school, equals('STME'));
      expect(config.program, equals('Computer Engineering'));
      expect(config.branch, equals('Computer Engineering'));
      expect(config.semester, isNull);

      final serialized = config.toJson();
      expect(serialized['school'], equals('STME'));
      expect(serialized['program'], equals('Computer Engineering'));
      expect(serialized['academicYear'], equals('Third Year'));
      expect(serialized['branch'], equals('Computer Engineering'));
      expect(serialized['division'], equals('A'));
    });

    test('SOL SectionConfig preserves school, program, semester and division', () {
      final solConfig = SectionConfig(
        id: 'SOL_3rdYear_BALLB_SemV_A',
        school: 'SOL',
        program: 'B.A. LL.B. (Hons.)',
        academicYear: '3rd Year',
        branch: 'B.A. LL.B. (Hons.)',
        semester: 'Semester V',
        division: 'A',
        workingDays: ['Monday', 'Tuesday', 'Wednesday'],
        batches: ['A1'],
        periods: [],
      );

      final json = solConfig.toJson();
      expect(json['school'], equals('SOL'));
      expect(json['program'], equals('B.A. LL.B. (Hons.)'));
      expect(json['semester'], equals('Semester V'));
      expect(json['academicYear'], equals('3rd Year'));
      expect(json['division'], equals('A'));

      final reconstructed = SectionConfig.fromJson(json, 'SOL_3rdYear_BALLB_SemV_A');
      expect(reconstructed.id, equals('SOL_3rdYear_BALLB_SemV_A'));
      expect(reconstructed.school, equals('SOL'));
      expect(reconstructed.program, equals('B.A. LL.B. (Hons.)'));
      expect(reconstructed.semester, equals('Semester V'));
      expect(reconstructed.academicYear, equals('3rd Year'));
      expect(reconstructed.branch, equals('B.A. LL.B. (Hons.)'));
      expect(reconstructed.division, equals('A'));
    });
  });
}
