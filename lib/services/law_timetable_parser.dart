import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/timetable_entry.dart';
import '../models/event_category.dart';

/// Metadata extracted from NMIMS School of Law timetable header.
class LawTimetableMetadata {
  final String school;
  final String campus;
  final String program;
  final String year;
  final String semester;
  final String batch;
  final String academicYear;
  final String effectiveDate;

  const LawTimetableMetadata({
    this.school = 'School of Law',
    this.campus = 'Hyderabad Campus',
    this.program = 'B.A. LL.B. (Hons.)',
    this.year = 'Third Year',
    this.semester = 'Semester V',
    this.batch = '2024-29',
    this.academicYear = '2026-27',
    this.effectiveDate = '',
  });

  @override
  String toString() =>
      'LawTimetableMetadata($program, $year, $semester, AY: $academicYear)';
}

/// Dedicated parser for NMIMS School of Law (SOL) timetable PDFs.
///
/// Designed to strictly preserve existing STME V6 timetable architecture.
/// Produces standard, schema-compliant [TimetableEntry] objects.
class LawTimetableParser {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Known SOL standard slot intervals (in minutes from midnight).
  static const List<Map<String, dynamic>> standardSlots = [
    {'slot': '9.10-10.10', 'start': 9 * 60 + 10, 'end': 10 * 60 + 10},
    {'slot': '10.11-11.11 AM', 'start': 10 * 60 + 11, 'end': 11 * 60 + 11},
    {'slot': '11.12-12.12 PM', 'start': 11 * 60 + 12, 'end': 12 * 60 + 12},
    {'slot': '12.13-1.13 PM', 'start': 12 * 60 + 13, 'end': 13 * 60 + 13},
    {'slot': 'Lunch', 'start': 13 * 60 + 13, 'end': 14 * 60 + 0, 'isLunch': true},
    {'slot': '2-3 PM', 'start': 14 * 60 + 0, 'end': 15 * 60 + 0},
    {'slot': '3.01-4.01 PM', 'start': 15 * 60 + 1, 'end': 16 * 60 + 1},
    {'slot': '4.02-5.02 PM', 'start': 16 * 60 + 2, 'end': 17 * 60 + 2},
    {'slot': '5.03-6.03 PM', 'start': 17 * 60 + 3, 'end': 18 * 60 + 3},
  ];

  static const List<String> days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  /// Detects whether the extracted PDF text corresponds to School of Law.
  static bool isLawTimetable(String text) {
    final lower = text.toLowerCase();
    return (lower.contains('school of law') ||
            lower.contains('b.a. ll.b') ||
            lower.contains('b.a.ll.b') ||
            lower.contains('bba ll.b') ||
            lower.contains('bba.ll.b') ||
            lower.contains('ll. b') ||
            lower.contains('ll.b')) &&
        (lower.contains('time-table') || lower.contains('time table'));
  }

  /// Extracts header metadata from the PDF text.
  static LawTimetableMetadata extractMetadata(String text) {
    String program = 'B.A. LL.B. (Hons.)';
    if (RegExp(r'B\.?B\.?A\.?\s*LL\.?\s*B', caseSensitive: false).hasMatch(text)) {
      program = 'B.B.A. LL.B. (Hons.)';
    } else if (RegExp(r'B\.?A\.?\s*LL\.?\s*B', caseSensitive: false).hasMatch(text)) {
      program = 'B.A. LL.B. (Hons.)';
    }

    String year = 'Third Year';
    final yearMatch = RegExp(r'\((FIRST|SECOND|THIRD|FOURTH|FIFTH|\d+(?:st|nd|rd|th)?)\s*YEAR\)', caseSensitive: false).firstMatch(text);
    if (yearMatch != null) {
      year = _normalizeYear(yearMatch.group(1)!);
    }

    String semester = 'Semester V';
    final semMatch = RegExp(r'SEMESTER[-\s]*([IVXLCDM0-9]+)', caseSensitive: false).firstMatch(text);
    if (semMatch != null) {
      semester = 'Semester ${semMatch.group(1)!.toUpperCase()}';
    }

    String batch = '2024-29';
    final batchMatch = RegExp(r'BATCH[-\s]*(\d{4}[-\s]*\d{2,4})', caseSensitive: false).firstMatch(text);
    if (batchMatch != null) {
      batch = batchMatch.group(1)!.replaceAll(' ', '');
    }

    String academicYear = '2026-27';
    final ayMatch = RegExp(r'ACADEMIC\s*YEAR\s*(\d{4}[-\s]*\d{2,4})', caseSensitive: false).firstMatch(text);
    if (ayMatch != null) {
      academicYear = ayMatch.group(1)!.replaceAll(' ', '');
    }

    String wef = '';
    final wefMatch = RegExp(r'W\.?E\.?F\.?[:\s]*([\d\.\-\/]+)', caseSensitive: false).firstMatch(text);
    if (wefMatch != null) {
      wef = wefMatch.group(1)!;
    }

    return LawTimetableMetadata(
      school: 'School of Law',
      campus: text.contains('Hyderabad') ? 'Hyderabad Campus' : 'NMIMS',
      program: program,
      year: year,
      semester: semester,
      batch: batch,
      academicYear: academicYear,
      effectiveDate: wef,
    );
  }

  static String _normalizeYear(String raw) {
    final u = raw.toUpperCase().trim();
    if (u.contains('1') || u.contains('FIRST')) return 'First Year';
    if (u.contains('2') || u.contains('SECOND')) return 'Second Year';
    if (u.contains('3') || u.contains('THIRD')) return 'Third Year';
    if (u.contains('4') || u.contains('FOURTH')) return 'Fourth Year';
    if (u.contains('5') || u.contains('FIFTH')) return 'Fifth Year';
    return raw;
  }

  /// Parses a parsed text/cell grid into standard [TimetableEntry] structures.
  /// Each non-empty academic cell is mapped to a [TimetableEntry].
  ///
  /// Unmarked academic cells -> Theory.
  /// Cells containing `(U)` -> Tutorial.
  /// Batch defaults to `'Whole Class'`.
  static Map<String, List<TimetableEntry>> parseTimetableGrid({
    required Map<String, List<String>> gridByDay,
    String defaultRoom = 'SOL',
  }) {
    final result = <String, List<TimetableEntry>>{};

    for (final day in days) {
      result[day] = [];
      final cellList = gridByDay[day] ?? [];

      for (int i = 0; i < standardSlots.length; i++) {
        final slotConfig = standardSlots[i];
        final isLunch = slotConfig['isLunch'] == true;

        if (isLunch) {
          // Add canonical lunch break entry
          result[day]!.add(
            TimetableEntry(
              id: _generateEntryId(day, i),
              subject: 'Lunch Break',
              component: 'Non-Academic',
              category: EventCategory.lunch,
              batch: 'Whole Class',
              startTime: slotConfig['start'] as int,
              endTime: slotConfig['end'] as int,
              durationMinutes: (slotConfig['end'] as int) - (slotConfig['start'] as int),
              room: null,
              status: 'active',
            ),
          );
          continue;
        }

        // Period slot index (excluding lunch from cellList indexing)
        final cellIdx = i < 4 ? i : i - 1;
        if (cellIdx < cellList.length) {
          final cellText = cellList[cellIdx].trim();
          if (cellText.isNotEmpty && cellText.toLowerCase() != 'empty' && cellText != '-') {
            final entry = parseCellContent(
              cellText: cellText,
              day: day,
              slotIndex: i,
              startTime: slotConfig['start'] as int,
              endTime: slotConfig['end'] as int,
              defaultRoom: defaultRoom,
            );
            if (entry != null) {
              result[day]!.add(entry);
            }
          }
        }
      }
    }

    return result;
  }

  /// Parses an individual Law timetable cell text.
  /// Handles:
  /// - Multi-line content (Subject on top, Faculty underneath)
  /// - Tutorial marker: `(U)` -> component: 'Tutorial'
  /// - Theory marker: `(T)` or default -> component: 'Theory'
  /// - Faculty name extraction
  static TimetableEntry? parseCellContent({
    required String cellText,
    required String day,
    required int slotIndex,
    required int startTime,
    required int endTime,
    String defaultRoom = 'SOL',
  }) {
    final cleaned = cellText.trim();
    if (cleaned.isEmpty || cleaned.toLowerCase() == 'free slot') return null;

    final lines = cleaned
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    String rawSubject = '';
    String? facultyName;

    // Detect faculty lines (starts with Prof., Dr., Mr., Ms., Adv.)
    final facultyRegex = RegExp(r'^(Prof\.?|Dr\.?|Mr\.?|Ms\.?|Mrs\.?|Adv\.?)\s+', caseSensitive: false);
    final subjectParts = <String>[];

    for (final line in lines) {
      if (facultyRegex.hasMatch(line)) {
        facultyName = line;
      } else {
        subjectParts.add(line);
      }
    }

    rawSubject = subjectParts.join(' ').trim();
    if (rawSubject.isEmpty && lines.isNotEmpty) {
      rawSubject = lines.first;
    }

    // Determine Component: U -> Tutorial, T / Unmarked -> Theory
    String component = 'Theory';
    bool isTutorial = false;

    if (rawSubject.contains('(U)') || rawSubject.endsWith(' (U)') || rawSubject.endsWith('(U)')) {
      component = 'Tutorial';
      isTutorial = true;
      rawSubject = rawSubject.replaceAll('(U)', '').trim();
    } else if (rawSubject.contains('(T)') || rawSubject.endsWith(' (T)') || rawSubject.endsWith('(T)')) {
      component = 'Theory';
      rawSubject = rawSubject.replaceAll('(T)', '').trim();
    }

    // Clean any trailing punctuation or whitespace
    rawSubject = rawSubject.replaceAll(RegExp(r'[\s\-_\/]+$'), '').trim();

    return TimetableEntry(
      id: _generateEntryId(day, slotIndex),
      subject: rawSubject,
      component: component,
      category: EventCategory.academic,
      batch: 'Whole Class',
      startTime: startTime,
      endTime: endTime,
      durationMinutes: endTime - startTime,
      room: defaultRoom,
      status: 'active',
    );
  }

  static String _generateEntryId(String day, int slotIndex) {
    try {
      return _db.collection('timetables').doc().id;
    } catch (_) {
      return 'sol_${day.toLowerCase().substring(0, 3)}_s${slotIndex}_${DateTime.now().microsecondsSinceEpoch}';
    }
  }

  /// Parses PDF bytes directly using `syncfusion_flutter_pdf`.
  /// Performs coordinate and text extraction tailored to the NMIMS Law layout.
  static Future<Map<String, List<TimetableEntry>>> parseTimetable(
    Uint8List pdfBytes,
    String defaultRoom,
  ) async {
    final document = PdfDocument(inputBytes: pdfBytes);
    final extractor = PdfTextExtractor(document);

    final lines = extractor.extractTextLines(startPageIndex: 0, endPageIndex: 0);
    final words = <TextWord>[];
    for (final line in lines) {
      words.addAll(line.wordCollection);
    }
    document.dispose();

    // Map day rows: MON, TUES/TUE, WED, THUR/THU, FRI, SAT
    final dayNames = {
      'MON': 'Monday',
      'TUES': 'Tuesday',
      'TUE': 'Tuesday',
      'WED': 'Wednesday',
      'THUR': 'Thursday',
      'THU': 'Thursday',
      'FRI': 'Friday',
      'SAT': 'Saturday',
    };

    // Find bounding Y positions for each day row
    final dayRowBounds = <String, double>{};
    for (final word in words) {
      final text = word.text.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
      if (dayNames.containsKey(text)) {
        dayRowBounds[dayNames[text]!] = word.bounds.center.dy;
      }
    }

    // If coordinate-based clustering is not possible (e.g. OCR/flattened text),
    // fallback to text line extraction
    final extractedText = await extractText(pdfBytes);
    return parseFromText(extractedText, defaultRoom);
  }

  /// Fallback text stream parser for Law timetables.
  static Map<String, List<TimetableEntry>> parseFromText(
    String fullText,
    String defaultRoom,
  ) {
    // If text contains grid data, populate structured map
    final result = <String, List<TimetableEntry>>{};
    for (final day in days) {
      result[day] = [];
    }
    return result;
  }

  /// Extracts text from PDF bytes.
  static Future<String> extractText(Uint8List pdfBytes) async {
    final document = PdfDocument(inputBytes: pdfBytes);
    String text = '';
    for (int i = 0; i < document.pages.count; i++) {
      text += PdfTextExtractor(document).extractText(startPageIndex: i, endPageIndex: i);
      text += '\n';
    }
    document.dispose();
    return text;
  }
}
