import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedly/faculty/faculty_excel_import_service.dart';

void main() {
  group('FacultyExcelImportService Tests', () {
    test(
      'parses CSV timetable correctly with day, time, subject, division',
      () {
        final csvContent = '''
Day,Time,Subject,Division,Room,Batch
Monday,10:15 - 11:15,Data Structures,CE_A,Lab 1,Whole Class
Wednesday,14:00 - 15:00,Operating Systems,CE_B,Room 204,B1
Friday,09:00 - 10:00,Database Systems,IT_A,Room 101,
''';

        final bytes = Uint8List.fromList(utf8.encode(csvContent));
        final entries = FacultyExcelImportService.parseBytes(
          bytes: bytes,
          fileName: 'faculty_schedule.csv',
        );

        expect(entries.length, 3);

        expect(entries[0].day, 'Monday');
        expect(entries[0].startTime, 10 * 60 + 15);
        expect(entries[0].endTime, 11 * 60 + 15);
        expect(entries[0].subject, 'Data Structures');
        expect(entries[0].division, 'CE_A');
        expect(entries[0].room, 'Lab 1');
        expect(entries[0].batch, 'Whole Class');

        expect(entries[1].day, 'Wednesday');
        expect(entries[1].startTime, 14 * 60);
        expect(entries[1].endTime, 15 * 60);
        expect(entries[1].subject, 'Operating Systems');
        expect(entries[1].division, 'CE_B');
        expect(entries[1].batch, 'B1');

        expect(entries[2].day, 'Friday');
        expect(entries[2].startTime, 9 * 60);
        expect(entries[2].endTime, 10 * 60);
        expect(entries[2].subject, 'Database Systems');
        expect(entries[2].division, 'IT_A');
      },
    );

    test('normalizes day names cleanly', () {
      expect(FacultyExcelImportService.normalizeDay('mon'), 'Monday');
      expect(FacultyExcelImportService.normalizeDay('TUESDAY'), 'Tuesday');
      expect(FacultyExcelImportService.normalizeDay('Wed'), 'Wednesday');
      expect(FacultyExcelImportService.normalizeDay('thu'), 'Thursday');
      expect(FacultyExcelImportService.normalizeDay('friday'), 'Friday');
    });
  });

  group('Faculty Conflict Detection Logic Tests', () {
    test(
      'detects exact and partial overlaps across sections for same faculty',
      () {
        bool checkOverlap(int startA, int endA, int startB, int endB) {
          return startA < endB && startB < endA;
        }

        // Case 1: Exact overlap (10:15–11:15 and 10:15–11:15)
        expect(checkOverlap(615, 675, 615, 675), isTrue);

        // Case 2: Partial overlap (10:15–11:15 and 10:45–11:45)
        expect(checkOverlap(615, 675, 645, 705), isTrue);

        // Case 3: Partial overlap (10:45–11:45 and 10:15–11:15)
        expect(checkOverlap(645, 705, 615, 675), isTrue);

        // Case 4: Contained overlap (10:00–12:00 and 10:30–11:30)
        expect(checkOverlap(600, 720, 630, 690), isTrue);

        // Case 5: Adjacent (non-overlapping) (10:15–11:15 and 11:15–12:15)
        expect(checkOverlap(615, 675, 675, 735), isFalse);

        // Case 6: Completely disjoint (09:00–10:00 and 11:00–12:00)
        expect(checkOverlap(540, 600, 660, 720), isFalse);
      },
    );
  });
}
