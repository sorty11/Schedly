import 'package:flutter_test/flutter_test.dart';
import 'package:schedly/models/attendance_log.dart';
import 'package:schedly/models/attendance_record.dart';
import 'package:schedly/models/course_component.dart';
import 'package:schedly/models/event_category.dart';
import 'package:schedly/models/intelligence_models.dart';
import 'package:schedly/models/timetable_entry.dart';
import 'package:schedly/services/attendance/academic_grouping_policy.dart';
import 'package:schedly/services/attendance_intelligence_service.dart';
import 'package:schedly/services/progress_calculator_service.dart';
import 'package:schedly/services/subject_identity_service.dart';

void main() {
  group('1. STME DSA SPECIAL CASE & SEPARATION', () {
    test('STME DSA Theory and Lab are separate courses and never merge', () {
      final keyTheory = AcademicGroupingPolicy.canonicalGroupKey('DSA', 'Theory');
      final keyLab = AcademicGroupingPolicy.canonicalGroupKey('DSA', 'Lab');

      expect(keyTheory, equals('DSA_Theory'));
      expect(keyLab, equals('DSA_Lab'));
      expect(keyTheory, isNot(equals(keyLab)));

      expect(AcademicGroupingPolicy.isSplitCourse('DSA'), isTrue);
      expect(AcademicGroupingPolicy.isSplitCourse('DATA STRUCTURES AND ALGORITHMS'), isTrue);
      expect(AcademicGroupingPolicy.isSplitCourse('DSA_THEORY'), isTrue);
      expect(AcademicGroupingPolicy.isSplitCourse('DSA_LAB'), isTrue);
    });

    test('STME DSA has hard-coded assigned hours: 45 hrs Theory, 30 hrs Lab (even without courseComponents)', () {
      final calcEmpty = ProgressCalculatorService(
        weeklyTimetable: {},
        semesterStartDate: DateTime(2026, 7, 13),
        subjectMetadata: {},
        courseComponents: const [],
      );

      // STME DSA Theory -> 45 hrs
      expect(calcEmpty.getConfiguredCourseHours('DSA', 'Theory'), equals(45));
      expect(calcEmpty.getConfiguredCourseHours('DATA STRUCTURES AND ALGORITHMS', 'Theory'), equals(45));

      // STME DSA Lab -> 30 hrs
      expect(calcEmpty.getConfiguredCourseHours('DSA', 'Lab'), equals(30));
      expect(calcEmpty.getConfiguredCourseHours('DATA STRUCTURES AND ALGORITHMS LAB', 'Lab'), equals(30));
      expect(calcEmpty.getConfiguredCourseHours('DSA LAB', 'Practical'), equals(30));

      // Fixed total course hours fallback
      expect(calcEmpty.getFixedTotalCourseHours('DSA', 'Theory'), equals(45));
      expect(calcEmpty.getFixedTotalCourseHours('DSA', 'Lab'), equals(30));

      // Remaining lectures
      expect(calcEmpty.getRemainingLectures('DSA', 'Theory', 20), equals(25)); // 45 - 20 = 25
      expect(calcEmpty.getRemainingLectures('DSA', 'Lab', 10), equals(20)); // 30 - 10 = 20

      // Remaining skips (80% requirement)
      // 45 * 0.20 = 9 max absences allowed. With 2 absent -> 7 skips left
      expect(calcEmpty.getRemainingSkips('DSA', 'Theory', 2, requiredAttendance: 0.80), equals(7));
      // 30 * 0.20 = 6 max absences allowed. With 1 absent -> 5 skips left
      expect(calcEmpty.getRemainingSkips('DSA', 'Lab', 1, requiredAttendance: 0.80), equals(5));
    });

    test('STME DSA hardcoded hours do NOT affect SOL or other subjects', () {
      final solComp = CourseComponent(
        componentId: 'SOL_COMP_LAW',
        componentType: 'Theory',
        courseName: 'Company Law II',
        courseCode: 'LAW501',
        targetHours: 60,
        createdAt: DateTime(2026, 7, 13),
        sectionId: 'SOL_A',
      );

      final calcSol = ProgressCalculatorService(
        weeklyTimetable: {},
        semesterStartDate: DateTime(2026, 7, 13),
        subjectMetadata: {},
        courseComponents: [solComp],
      );

      // SOL course gets its configured hours (60 hrs), NOT 45 or 30
      expect(calcSol.getConfiguredCourseHours('Company Law II', 'Theory'), equals(60));

      // Unconfigured subject in STME returns null (safe behavior)
      expect(calcSol.getConfiguredCourseHours('Software Engineering', 'Theory'), isNull);
    });
  });

  group('2. SMART RECOMMENDATIONS & SUBJECT MATCHING', () {
    test('Smart Recommendations for STME Section A (including DSA Theory + Lab, SE)', () {
      final entries = [
        TimetableEntry(
          id: 't_dsa_th',
          subject: 'DATA STRUCTURES AND ALGORITHMS',
          component: 'Theory',
          category: EventCategory.academic,
          batch: 'Whole Class',
          startTime: 540,
          endTime: 660,
          durationMinutes: 120,
        ),
        TimetableEntry(
          id: 't_dsa_lab',
          subject: 'DATA STRUCTURES AND ALGORITHMS LAB',
          component: 'Lab',
          category: EventCategory.academic,
          batch: 'A1',
          startTime: 675,
          endTime: 795,
          durationMinutes: 120,
        ),
        TimetableEntry(
          id: 't_se',
          subject: 'SE',
          component: 'Theory',
          category: EventCategory.academic,
          batch: 'Whole Class',
          startTime: 810,
          endTime: 870,
          durationMinutes: 60,
        ),
      ];

      final records = [
        AttendanceRecord(
          id: 'STME_A_DSA_Theory',
          division: 'STME_A',
          subjectCode: 'DSA',
          component: 'Theory',
          present: 20,
          absent: 2,
        ),
        AttendanceRecord(
          id: 'STME_A_DSA_Lab',
          division: 'STME_A',
          subjectCode: 'DSA',
          component: 'Lab',
          present: 10,
          absent: 1,
        ),
        AttendanceRecord(
          id: 'STME_A_SE_Merged',
          division: 'STME_A',
          subjectCode: 'Software Engineering',
          component: 'Merged',
          present: 15,
          absent: 3,
        ),
      ];

      final calc = ProgressCalculatorService(
        weeklyTimetable: {},
        semesterStartDate: DateTime(2026, 7, 13),
        subjectMetadata: {},
        courseComponents: const [],
      );

      final recs = AttendanceIntelligenceService.generateTodayRecommendations(
        entries,
        records,
        calculator: calc,
      );

      expect(recs.length, equals(3));

      // DSA Theory recommendation
      final dsaThRec = recs.firstWhere((r) => r.component == 'Theory' && r.subjectCode.contains('DATA STRUCTURES'));
      expect(dsaThRec.assignedHours, equals(45));
      expect(dsaThRec.remainingLectures, equals(23)); // 45 - 22 = 23
      expect(dsaThRec.remainingSkips, equals(7)); // 9 - 2 = 7
      expect(dsaThRec.reason, contains('safely miss 7'));

      // DSA Lab recommendation
      final dsaLabRec = recs.firstWhere((r) => r.component == 'Lab');
      expect(dsaLabRec.assignedHours, equals(30));
      expect(dsaLabRec.remainingLectures, equals(19)); // 30 - 11 = 19
      expect(dsaLabRec.remainingSkips, equals(5)); // 6 - 1 = 5
      expect(dsaLabRec.reason, contains('safely miss 5'));

      // SE recommendation (matched via SubjectIdentityService alias 'SE' <-> 'Software Engineering')
      final seRec = recs.firstWhere((r) => r.subjectCode == 'SE');
      expect(seRec.level, isNotNull);
      // Since SE is unconfigured in courseComponents, assignedHours is null (safe behavior)
      expect(seRec.assignedHours, isNull);
    });

    test('Smart Recommendations for SOL Section A (Company Law 2, Family Law 2, Bharatiya Sakshya)', () {
      final entries = [
        TimetableEntry(
          id: 't_sol_1',
          subject: 'Company Law 2 Theory',
          component: 'Theory',
          category: EventCategory.academic,
          batch: 'Whole Class',
          startTime: 540,
          endTime: 660,
          durationMinutes: 120,
        ),
        TimetableEntry(
          id: 't_sol_2',
          subject: 'Family Law 2 Theory',
          component: 'Theory',
          category: EventCategory.academic,
          batch: 'Whole Class',
          startTime: 675,
          endTime: 795,
          durationMinutes: 120,
        ),
        TimetableEntry(
          id: 't_sol_3',
          subject: 'The Bharti Sak Adhi, 2023 (Law of Evidence)',
          component: 'Theory',
          category: EventCategory.academic,
          batch: 'Whole Class',
          startTime: 810,
          endTime: 870,
          durationMinutes: 60,
        ),
      ];

      final records = [
        AttendanceRecord(
          id: 'SOL_A_Company_Law_II_Merged',
          division: 'SOL_A',
          subjectCode: 'Company Law II',
          component: 'Merged',
          present: 18,
          absent: 2, // 90%
        ),
        AttendanceRecord(
          id: 'SOL_A_Family_Law_II_Merged',
          division: 'SOL_A',
          subjectCode: 'Family Law II (Success and Inheritance Laws)',
          component: 'Merged',
          present: 14,
          absent: 6, // 70%
        ),
        AttendanceRecord(
          id: 'SOL_A_Sakshya_Merged',
          division: 'SOL_A',
          subjectCode: 'The Bharatiya Sakshya Adhiniyam, 2023 (Law of Evidence)',
          component: 'Merged',
          present: 20,
          absent: 1, // 95.2%
        ),
      ];

      final solComponents = [
        CourseComponent(
          componentId: 'Company Law II',
          componentType: 'Theory',
          courseName: 'Company Law II',
          courseCode: 'LAW501',
          targetHours: 60,
          createdAt: DateTime(2026, 7, 13),
          sectionId: 'SOL_A',
        ),
      ];

      final calc = ProgressCalculatorService(
        weeklyTimetable: {},
        semesterStartDate: DateTime(2026, 7, 13),
        subjectMetadata: {},
        courseComponents: solComponents,
      );

      final recs = AttendanceIntelligenceService.generateTodayRecommendations(
        entries,
        records,
        calculator: calc,
      );

      expect(recs.length, equals(3));

      // Company Law 2 matches Company Law II
      final compLawRec = recs.firstWhere((r) => r.subjectCode.contains('Company Law'));
      expect(compLawRec.assignedHours, equals(60));
      expect(compLawRec.remainingLectures, equals(40)); // 60 - 20 = 40
      // SOL 70% threshold: 60 * 0.30 = 18 allowed absences. With 2 absent -> 16 skips left
      expect(compLawRec.remainingSkips, equals(16));

      // Family Law 2 matches Family Law II
      final famLawRec = recs.firstWhere((r) => r.subjectCode.contains('Family Law'));
      expect(famLawRec.level, isNotNull);

      // Bharatiya Sakshya variant matches canonical
      final sakshyaRec = recs.firstWhere((r) => r.subjectCode.contains('Bharti'));
      expect(sakshyaRec.level, equals(RecommendationLevel.comfortableMargin));
    });

    test('Preserves existing attendance percentage calculation P / (P + A)', () {
      final record = AttendanceRecord(
        id: 'rec_1',
        division: 'CE_A',
        subjectCode: 'DSA',
        component: 'Theory',
        present: 24,
        absent: 6,
      );
      expect(record.total, equals(30));
      expect(record.percentage, closeTo(0.80, 0.0001));

      // What-if simulation
      final int p = record.present;
      final int a = record.absent;
      final double attendPct = (p + 1) / (p + a + 1) * 100;
      final double skipPct = p / (p + a + 1) * 100;

      expect(attendPct, closeTo(80.645, 0.01));
      expect(skipPct, closeTo(77.419, 0.01));
    });
  });
}
