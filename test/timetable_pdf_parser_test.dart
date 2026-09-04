import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedly/services/pdf_timetable_import_service.dart';

void main() {
  test('NMIMS Section A Timetable PDF parses with 100% precision', () async {
    final file = File('test/fixtures/NMIMS_Section_A_Timetable.pdf');
    expect(file.existsSync(), isTrue);

    final bytes = await file.readAsBytes();

    final text = await PdfTimetableImportService.extractText(bytes);
    expect(text, contains("SVKM's NMIMS Deemed to be University"));
    expect(text, contains("School of Technology Management & Engineering"));
    expect(text, contains("Class: - 2nd Year B Tech- (CSEDS) Div-A"));
    expect(text, contains("Class Room: 1417, 4th floor"));
    expect(text, contains("Class in-charge: - Dr. Amit Saini"));
    expect(text, contains("w.e.f: 17-08-2026"));

    final division = PdfTimetableImportService.extractDivision(text);
    expect(division, equals('A'));

    final parsed = await PdfTimetableImportService.parseTimetable(
      bytes,
      '1417',
    );

    // Monday
    expect(parsed['Monday'], isNotEmpty);
    expect(
      parsed['Monday']!.any(
        (e) => e.subject == 'DSA' && e.startTime == 9 * 60 + 15,
      ),
      isTrue,
    );
    expect(
      parsed['Monday']!.any(
        (e) => e.subject.contains('Software') && e.startTime == 10 * 60 + 15,
      ),
      isTrue,
    );
    expect(
      parsed['Monday']!.any(
        (e) => e.subject == 'DCCA' && e.startTime == 11 * 60 + 15,
      ),
      isTrue,
    );
    expect(parsed['Monday']!.any((e) => e.subject == 'Lunch Break'), isTrue);
    expect(
      parsed['Monday']!.any(
        (e) => e.subject == 'Python' && e.startTime == 15 * 60,
      ),
      isTrue,
    );
    expect(
      parsed['Monday']!.any(
        (e) => e.subject == 'PEC-GPT' && e.startTime == 16 * 60,
      ),
      isTrue,
    );

    // Tuesday
    expect(
      parsed['Tuesday']!.any(
        (e) => e.subject == 'PnS' && e.startTime == 9 * 60 + 15,
      ),
      isTrue,
    );
    expect(
      parsed['Tuesday']!.any(
        (e) => e.subject == 'DSA' && e.startTime == 10 * 60 + 15,
      ),
      isTrue,
    );
    expect(
      parsed['Tuesday']!.any(
        (e) => e.subject.contains('Website') && e.startTime == 11 * 60 + 15,
      ),
      isTrue,
    );
    expect(
      parsed['Tuesday']!.any(
        (e) => e.subject == 'DCCA' && e.startTime == 15 * 60,
      ),
      isTrue,
    );

    // Wednesday
    expect(
      parsed['Wednesday']!.any(
        (e) => e.subject == 'PnS' && e.startTime == 9 * 60 + 15,
      ),
      isTrue,
    );
    expect(
      parsed['Wednesday']!.any(
        (e) => e.component == 'Lab' && e.startTime == 10 * 60 + 15,
      ),
      isTrue,
    );
    expect(
      parsed['Wednesday']!.any(
        (e) => e.subject.contains('Software') && e.startTime == 15 * 60,
      ),
      isTrue,
    );

    // Thursday
    expect(
      parsed['Thursday']!.any(
        (e) => e.subject.contains('TC') && e.startTime == 9 * 60 + 15,
      ),
      isTrue,
    );
    expect(
      parsed['Thursday']!.any(
        (e) => e.subject.contains('Software') && e.startTime == 10 * 60 + 15,
      ),
      isTrue,
    );
    expect(
      parsed['Thursday']!.any(
        (e) => e.subject == 'DSA' && e.startTime == 11 * 60 + 15,
      ),
      isTrue,
    );
    expect(
      parsed['Thursday']!.any(
        (e) => e.subject.contains('TC') && e.startTime == 15 * 60,
      ),
      isTrue,
    );
    expect(
      parsed['Thursday']!.any(
        (e) => e.subject == 'PEC-GPT' && e.startTime == 16 * 60,
      ),
      isTrue,
    );

    // Friday
    expect(
      parsed['Friday']!.any(
        (e) => e.subject == 'DCCA' && e.startTime == 9 * 60 + 15,
      ),
      isTrue,
    );
    expect(parsed['Friday']!.any((e) => e.component == 'Lab'), isTrue);

    // Saturday
    expect(parsed['Saturday']!.any((e) => e.subject == 'Lunch Break'), isTrue);
  });
}
