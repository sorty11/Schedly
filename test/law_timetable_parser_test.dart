import 'dart:io';
import 'dart:typed_data';
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
    test('Unmarked academic subject defaults to Theory and strips faculty', () {
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

      final empty3 = LawTimetableParser.parseCellContent(
        cellText: '---',
        day: 'Saturday',
        slotIndex: 2,
        startTime: 672,
        endTime: 732,
      );
      expect(empty3, isNull);

      final empty4 = LawTimetableParser.parseCellContent(
        cellText: 'N/A',
        day: 'Saturday',
        slotIndex: 3,
        startTime: 733,
        endTime: 793,
      );
      expect(empty4, isNull);
    });

    test('Multiline subject and multiline faculty line parsing', () {
      const text = '''
Constitutional Law
& Public Policy
Prof. Ramanathan
Swaminathan
''';
      final entry = LawTimetableParser.parseCellContent(
        cellText: text,
        day: 'Monday',
        slotIndex: 0,
        startTime: 550,
        endTime: 610,
      );

      expect(entry, isNotNull);
      expect(entry!.subject, equals('Constitutional Law & Public Policy'));
      expect(entry.component, equals('Theory'));
      expect(entry.subject, isNot(contains('Ramanathan')));
      expect(entry.subject, isNot(contains('Swaminathan')));
    });

    test('Component notation variations: (U), [U], (Tutorial), (T), [T]', () {
      final u1 = LawTimetableParser.parseCellContent(
        cellText: 'Environmental Law [U]\nProf. Alisha',
        day: 'Friday',
        slotIndex: 2,
        startTime: 672,
        endTime: 732,
      );
      expect(u1!.component, equals('Tutorial'));
      expect(u1.subject, equals('Environmental Law'));

      final u2 = LawTimetableParser.parseCellContent(
        cellText: 'Taxation Law (Tutorial)\nDr. Nishit',
        day: 'Wednesday',
        slotIndex: 3,
        startTime: 733,
        endTime: 793,
      );
      expect(u2!.component, equals('Tutorial'));
      expect(u2.subject, equals('Taxation Law'));

      final t1 = LawTimetableParser.parseCellContent(
        cellText: 'Company Law II (T)\nProf. Veddant',
        day: 'Monday',
        slotIndex: 1,
        startTime: 611,
        endTime: 671,
      );
      expect(t1!.component, equals('Theory'));
      expect(t1.subject, equals('Company Law II'));
    });

    test('Long subject names parse cleanly', () {
      const longSubj = 'Interpretation of Statutes & Principles of Legislation\nAdv. Krishna Mohan';
      final entry = LawTimetableParser.parseCellContent(
        cellText: longSubj,
        day: 'Tuesday',
        slotIndex: 0,
        startTime: 550,
        endTime: 610,
      );
      expect(entry, isNotNull);
      expect(entry!.subject, equals('Interpretation of Statutes & Principles of Legislation'));
      expect(entry.component, equals('Theory'));
    });

    test('Header format variations parse robustly', () {
      const variedHeader = '''
SVKM's NMIMS School of Law
BBA LL.B. (Hons.)
THIRD YEAR
SEM - V
BATCH: 2024-2029
ACADEMIC YEAR: 2026-2027
W.E.F. 20/07/2026
TIMETABLE
''';
      expect(LawTimetableParser.isLawTimetable(variedHeader), isTrue);

      final meta = LawTimetableParser.extractMetadata(variedHeader);
      expect(meta.program, equals('B.B.A. LL.B. (Hons.)'));
      expect(meta.year, equals('Third Year'));
      expect(meta.semester, equals('Semester V'));
      expect(meta.batch, equals('2024-2029'));
      expect(meta.academicYear, equals('2026-2027'));
      expect(meta.effectiveDate, equals('20/07/2026'));
    });
  });

  group('LawTimetableParser Synthetic Deterministic Regression Fixture Test', () {
    // NOTE: This test uses a synthetic vector PDF fixture generated by scripts/generate_sol_pdf.py
    // to match the exact visual, structural, and text layout of the NMIMS School of Law sample image.
    // It verifies PDF extraction deterministically, NOT an official NMIMS-issued PDF file.
    test('NMIMS SOL Timetable Sample PDF parses directly to TimetableEntry models', () async {
      final file = File('test/fixtures/NMIMS_SOL_Timetable_Sample.pdf');
      expect(file.existsSync(), isTrue, reason: 'SOL test fixture PDF must exist');

      final Uint8List pdfBytes = await file.readAsBytes();

      // Verify text extraction
      final text = await LawTimetableParser.extractText(pdfBytes);
      expect(LawTimetableParser.isLawTimetable(text), isTrue);

      final meta = LawTimetableParser.extractMetadata(text);
      expect(meta.school, equals('School of Law'));
      expect(meta.program, equals('B.A. LL.B. (Hons.)'));
      expect(meta.year, equals('Third Year'));
      expect(meta.semester, equals('Semester V'));

      // Real PDF parse via coordinate extraction
      final parsed = await LawTimetableParser.parseTimetable(pdfBytes, 'SOL');

      expect(parsed.keys, containsAll(['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']));

      // Monday verification
      final mon = parsed['Monday']!;
      expect(mon, isNotEmpty);
      expect(mon.any((e) => e.subject == 'Lunch Break' && e.category == EventCategory.lunch), isTrue);
      expect(mon.any((e) => e.subject == 'Administrative Law' && e.component == 'Theory'), isTrue);
      expect(mon.any((e) => e.subject == 'Company Law II' && e.component == 'Theory'), isTrue);
      expect(mon.any((e) => e.subject.contains('CPC') && e.startTime == 15 * 60 + 1), isTrue);

      // Thursday verification: must parse Administrative Law (U) as Tutorial
      final thu = parsed['Thursday']!;
      expect(thu, isNotEmpty);
      final adminTut = thu.where((e) => e.subject == 'Administrative Law' && e.component == 'Tutorial').toList();
      expect(adminTut.isNotEmpty, isTrue, reason: 'Administrative Law (U) on Thursday must be Tutorial');
      expect(adminTut.first.startTime, equals(11 * 60 + 12));
      expect(adminTut.first.endTime, equals(12 * 60 + 12));

      // Friday verification: must parse Environmental Law (U) as Tutorial and late Administrative Law
      final fri = parsed['Friday']!;
      final envTut = fri.where((e) => e.subject == 'Environmental Law' && e.component == 'Tutorial').toList();
      expect(envTut.isNotEmpty, isTrue, reason: 'Environmental Law (U) on Friday must be Tutorial');

      final lateAdmin = fri.where((e) => e.subject == 'Administrative Law' && e.startTime == 17 * 60 + 3).toList();
      expect(lateAdmin.isNotEmpty, isTrue, reason: 'Administrative Law 5:03-6:03 on Friday must exist');

      // Saturday verification: all periods empty, only Lunch Break present
      final sat = parsed['Saturday']!;
      expect(sat.length, equals(1));
      expect(sat.first.subject, equals('Lunch Break'));
    });
  });
}
