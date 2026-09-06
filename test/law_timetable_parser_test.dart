import 'package:flutter_test/flutter_test.dart';
import 'package:schedly/services/law_timetable_parser.dart';
import 'package:schedly/models/event_category.dart';

void main() {
  group('LawTimetableParser Header & Metadata Tests', () {
    const rawHeaderText = '''
SVKM's NMIMS
School of Law, Hyderabad Campus
TIME-TABLE
B.A. LL. B (HONS.) (THIRD YEAR), SEMESTER-V (BATCH- 2024-29) – ACADEMIC YEAR 2026-27
WEF: 20.07.2026
''';

    test('isLawTimetable correctly identifies School of Law timetable', () {
      expect(LawTimetableParser.isLawTimetable(rawHeaderText), isTrue);
      expect(
        LawTimetableParser.isLawTimetable("School of Technology Management & Engineering Class Time Table"),
        isFalse,
      );
    });

    test('extractMetadata correctly parses all header fields', () {
      final meta = LawTimetableParser.extractMetadata(rawHeaderText);
      expect(meta.school, equals('School of Law'));
      expect(meta.campus, equals('Hyderabad Campus'));
      expect(meta.program, equals('B.A. LL.B. (Hons.)'));
      expect(meta.year, equals('Third Year'));
      expect(meta.semester, equals('Semester V'));
      expect(meta.batch, equals('2024-29'));
      expect(meta.academicYear, equals('2026-27'));
      expect(meta.effectiveDate, equals('20.07.2026'));
    });
  });

  group('LawTimetableParser Standard Time Slots Tests', () {
    test('standardSlots reflects real Law timetable timings', () {
      final slots = LawTimetableParser.standardSlots;
      expect(slots.length, equals(9)); // 4 morning + 1 lunch + 4 afternoon

      // Morning 1: 9:10 - 10:10 (550 to 610)
      expect(slots[0]['start'], equals(9 * 60 + 10));
      expect(slots[0]['end'], equals(10 * 60 + 10));

      // Morning 2: 10:11 - 11:11 (611 to 671)
      expect(slots[1]['start'], equals(10 * 60 + 11));
      expect(slots[1]['end'], equals(11 * 60 + 11));

      // Morning 3: 11:12 - 12:12 (672 to 732)
      expect(slots[2]['start'], equals(11 * 60 + 12));
      expect(slots[2]['end'], equals(12 * 60 + 12));

      // Morning 4: 12:13 - 1:13 (733 to 793)
      expect(slots[3]['start'], equals(12 * 60 + 13));
      expect(slots[3]['end'], equals(13 * 60 + 13));

      // Lunch: 1:13 - 2:00 (793 to 840)
      expect(slots[4]['isLunch'], isTrue);
      expect(slots[4]['start'], equals(13 * 60 + 13));
      expect(slots[4]['end'], equals(14 * 60 + 0));

      // Afternoon 1: 2:00 - 3:00 (840 to 900)
      expect(slots[5]['start'], equals(14 * 60 + 0));
      expect(slots[5]['end'], equals(15 * 60 + 0));

      // Afternoon 2: 3:01 - 4:01 (901 to 961)
      expect(slots[6]['start'], equals(15 * 60 + 1));
      expect(slots[6]['end'], equals(16 * 60 + 1));

      // Afternoon 3: 4:02 - 5:02 (962 to 1022)
      expect(slots[7]['start'], equals(16 * 60 + 2));
      expect(slots[7]['end'], equals(17 * 60 + 2));

      // Afternoon 4: 5:03 - 6:03 (1023 to 1083)
      expect(slots[8]['start'], equals(17 * 60 + 3));
      expect(slots[8]['end'], equals(18 * 60 + 3));
    });
  });

  group('LawTimetableParser Cell Parsing & (U) Tutorial Convention Tests', () {
    test('Unmarked academic subject defaults to Theory', () {
      final entry = LawTimetableParser.parseCellContent(
        cellText: 'Administrative Law\nProf. Anurag',
        day: 'Monday',
        slotIndex: 0,
        startTime: 550,
        endTime: 610,
      );

      expect(entry, isNotNull);
      expect(entry!.subject, equals('Administrative Law'));
      expect(entry.component, equals('Theory'));
      expect(entry.category, equals(EventCategory.academic));
      expect(entry.batch, equals('Whole Class'));
      expect(entry.startTime, equals(550));
      expect(entry.endTime, equals(610));
    });

    test('(U) notation correctly parses as Tutorial', () {
      final entry = LawTimetableParser.parseCellContent(
        cellText: 'Administrative Law (U)\nProf. Anurag',
        day: 'Thursday',
        slotIndex: 2,
        startTime: 672,
        endTime: 732,
      );

      expect(entry, isNotNull);
      expect(entry!.subject, equals('Administrative Law'));
      expect(entry.component, equals('Tutorial'));
      expect(entry.category, equals(EventCategory.academic));
      expect(entry.batch, equals('Whole Class'));
    });

    test('Environmental Law (U) parses cleanly without trailing (U) in subjectCode', () {
      final entry = LawTimetableParser.parseCellContent(
        cellText: 'Environmental Law (U)\nProf. Alisha',
        day: 'Friday',
        slotIndex: 2,
        startTime: 672,
        endTime: 732,
      );

      expect(entry, isNotNull);
      expect(entry!.subject, equals('Environmental Law'));
      expect(entry.component, equals('Tutorial'));
      expect(entry.displaySubject, equals('Environmental Law Tutorial'));
    });

    test('Empty / free slots return null', () {
      final empty1 = LawTimetableParser.parseCellContent(
        cellText: '',
        day: 'Saturday',
        slotIndex: 0,
        startTime: 550,
        endTime: 610,
      );
      expect(empty1, isNull);

      final empty2 = LawTimetableParser.parseCellContent(
        cellText: 'Free Slot',
        day: 'Saturday',
        slotIndex: 1,
        startTime: 611,
        endTime: 671,
      );
      expect(empty2, isNull);
    });
  });

  group('LawTimetableParser Full Real-World Grid Test', () {
    // 8 academic slots per day (excluding lunch in middle)
    // Real Law Timetable Matrix from provided image:
    // Mon: Administrative Law, Company Law II, Environmental Law, Company Law II, [Lunch], Family Law II, CPC & Limitation Act, Environmental Law, (Empty)
    // Tue: Administrative Law, Company Law II, Sports Law, Maritime Law, [Lunch], Maritime Law, CPC & Limitation Act, Family Law II, Sports Law
    // Wed: Administrative Law, BSA, Environmental Law, BSA, [Lunch], Family Law II, CPC & Limitation Act, Environmental Law, (Empty)
    // Thu: Cyber Law, BSA, Administrative Law (U), BSA, [Lunch], Company Law II, CPC & Limitation Act, Family Law II, (Empty)
    // Fri: Cyber Law, BSA, Environmental Law (U), Media Law, [Lunch], Family Law II, CPC & Limitation Act, Media Law, Administrative Law
    // Sat: All empty
    final realGridByDay = <String, List<String>>{
      'Monday': [
        'Administrative Law\nProf. Anurag',
        'Company Law II\nProf. Veddant',
        'Environmental Law\nProf. Alisha',
        'Company Law II\nProf. Veddant',
        'Family Law II\nProf. Ishant Jain',
        'CPC & Limitation Act\nProf. Mayank Singh',
        'Environmental Law\nProf. Alisha',
        '', // slot 8 empty
      ],
      'Tuesday': [
        'Administrative Law\nProf. Anurag',
        'Company Law II\nProf. Veddant',
        'Sports Law\nDr. Nishit',
        'Maritime Law\nProf. Anurag',
        'Maritime Law\nProf. Anurag',
        'CPC & Limitation Act\nProf. Mayank Singh',
        'Family Law II\nProf. Ishant Jain',
        'Sports Law\nDr. Nishit',
      ],
      'Wednesday': [
        'Administrative Law\nProf. Anurag',
        'BSA\nProf. Anoushka',
        'Environmental Law\nProf. Alisha',
        'BSA\nProf. Anoushka',
        'Family Law II\nProf. Ishant Jain',
        'CPC & Limitation Act\nProf. Mayank Singh',
        'Environmental Law\nProf. Alisha',
        '',
      ],
      'Thursday': [
        'Cyber Law\nProf. Aakash Satyadeo',
        'BSA\nProf. Anoushka',
        'Administrative Law (U)\nProf. Anurag',
        'BSA\nProf. Anoushka',
        'Company Law II\nProf. Veddant',
        'CPC & Limitation Act\nProf. Mayank Singh',
        'Family Law II\nProf. Ishant Jain',
        '',
      ],
      'Friday': [
        'Cyber Law\nProf. Aakash Satyadeo',
        'BSA\nProf. Anoushka',
        'Environmental Law (U)\nProf. Alisha',
        'Media Law\nProf. Alisha',
        'Family Law II\nProf. Ishant Jain',
        'CPC & Limitation Act\nProf. Mayank Singh',
        'Media Law\nProf. Alisha',
        'Administrative Law\nProf. Anurag',
      ],
      'Saturday': [
        '', '', '', '', '', '', '', ''
      ],
    };

    test('Parses full weekly schedule with exact slot components and lunch break', () {
      final parsed = LawTimetableParser.parseTimetableGrid(gridByDay: realGridByDay);

      expect(parsed.keys, containsAll(['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']));

      // Monday verification
      final mon = parsed['Monday']!;
      // 7 academic entries + 1 lunch = 8 entries
      expect(mon.length, equals(8));
      expect(mon.any((e) => e.subject == 'Lunch Break' && e.category == EventCategory.lunch), isTrue);
      expect(mon.any((e) => e.subject == 'Administrative Law' && e.component == 'Theory'), isTrue);
      expect(mon.any((e) => e.subject == 'CPC & Limitation Act' && e.startTime == 15 * 60 + 1), isTrue);

      // Thursday verification (contains Administrative Law (U))
      final thu = parsed['Thursday']!;
      final adminLawTut = thu.firstWhere((e) => e.subject == 'Administrative Law');
      expect(adminLawTut.component, equals('Tutorial'));
      expect(adminLawTut.startTime, equals(11 * 60 + 12));
      expect(adminLawTut.endTime, equals(12 * 60 + 12));

      // Friday verification (contains Environmental Law (U) and late slot Administrative Law)
      final fri = parsed['Friday']!;
      final envLawTut = fri.firstWhere((e) => e.subject == 'Environmental Law');
      expect(envLawTut.component, equals('Tutorial'));

      final lateAdmin = fri.lastWhere((e) => e.subject == 'Administrative Law');
      expect(lateAdmin.startTime, equals(17 * 60 + 3));
      expect(lateAdmin.endTime, equals(18 * 60 + 3));

      // Saturday verification (all empty except Lunch Break)
      final sat = parsed['Saturday']!;
      expect(sat.length, equals(1));
      expect(sat.first.subject, equals('Lunch Break'));
    });
  });
}
