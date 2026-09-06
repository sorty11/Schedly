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

/// Helper model for detected grid columns in Law PDF.
class _LawColumn {
  final int index; // 0 to 7 (or lunch)
  final double xStart;
  final double xEnd;
  final int startTime;
  final int endTime;
  final bool isLunch;

  _LawColumn({
    required this.index,
    required this.xStart,
    required this.xEnd,
    required this.startTime,
    required this.endTime,
    this.isLunch = false,
  });
}

/// Helper model for detected day rows in Law PDF.
class _LawDayRow {
  final String dayName;
  final double yTop;
  final double yBottom;

  _LawDayRow({
    required this.dayName,
    required this.yTop,
    required this.yBottom,
  });
}

/// Dedicated parser for NMIMS School of Law (SOL) timetable PDFs.
///
/// Designed to strictly preserve existing STME V6 timetable architecture.
/// Uses Syncfusion coordinate clustering to deterministically extract
/// rows, columns, subject names, components ((U) vs Theory), and lunch breaks.
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

  /// Parses PDF bytes directly using `syncfusion_flutter_pdf` coordinates.
  /// Dynamically locates the TIME header, day rows (MON-SAT), and period columns.
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

    // 1. Identify Day Labels and Row Bounds (Y-coordinates)
    final dayMap = {
      'MON': 'Monday',
      'TUES': 'Tuesday',
      'TUE': 'Tuesday',
      'WED': 'Wednesday',
      'THUR': 'Thursday',
      'THU': 'Thursday',
      'FRI': 'Friday',
      'SAT': 'Saturday',
    };

    final dayWordPositions = <String, double>{};
    for (final w in words) {
      final t = w.text.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
      if (dayMap.containsKey(t)) {
        final dName = dayMap[t]!;
        if (!dayWordPositions.containsKey(dName)) {
          dayWordPositions[dName] = w.bounds.center.dy;
        }
      }
    }

    // Sort days by Y coordinate (top to bottom)
    final sortedDays = dayWordPositions.keys.toList()
      ..sort((a, b) => dayWordPositions[a]!.compareTo(dayWordPositions[b]!));

    final dayRows = <_LawDayRow>[];
    for (int i = 0; i < sortedDays.length; i++) {
      final dName = sortedDays[i];
      final cy = dayWordPositions[dName]!;
      final double prevY;
      final double nextY;
      if (sortedDays.length > 1) {
        final rowSpacing = i == 0
            ? dayWordPositions[sortedDays[1]]! - cy
            : cy - dayWordPositions[sortedDays[i - 1]]!;
        prevY = i == 0 ? cy - rowSpacing * 1.2 : dayWordPositions[sortedDays[i - 1]]!;
        nextY = i == sortedDays.length - 1 ? cy + rowSpacing * 1.2 : dayWordPositions[sortedDays[i + 1]]!;
      } else {
        prevY = cy - 60;
        nextY = cy + 60;
      }

      final yTop = (prevY + cy) / 2;
      final yBottom = (cy + nextY) / 2;

      dayRows.add(_LawDayRow(dayName: dName, yTop: yTop, yBottom: yBottom));
    }

    // 2. Identify Period Columns (X-coordinates)
    // Find time header row containing "9.10" or "9:10"
    final timeHeaderWords = words.where((w) {
      final t = w.text;
      return t.contains('9.10') ||
          t.contains('9:10') ||
          t.contains('10.11') ||
          t.contains('10:11') ||
          t.contains('11.12') ||
          t.contains('12.13') ||
          t.toUpperCase().contains('LUNCH') ||
          t.contains('2-3') ||
          t.contains('3.01') ||
          t.contains('4.02') ||
          t.contains('5.03');
    }).toList();

    // Group time header words into 9 column centers
    timeHeaderWords.sort((a, b) => a.bounds.center.dx.compareTo(b.bounds.center.dx));

    final colCenters = <double>[];
    for (final w in timeHeaderWords) {
      final x = w.bounds.center.dx;
      if (colCenters.isEmpty || (x - colCenters.last).abs() > 30) {
        colCenters.add(x);
      }
    }

    final columns = <_LawColumn>[];
    if (colCenters.length >= 8) {
      // Build column bounds from centers with seamless transitions
      final colSpacing = colCenters.length > 1
          ? (colCenters.last - colCenters.first) / (colCenters.length - 1)
          : 80.0;

      for (int i = 0; i < standardSlots.length; i++) {
        final slotConfig = standardSlots[i];
        final isLunch = slotConfig['isLunch'] == true;

        final double xStart;
        final double xEnd;

        if (i < colCenters.length) {
          final cx = colCenters[i];
          final prevX = i == 0 ? cx - colSpacing * 1.2 : colCenters[i - 1];
          final nextX = i == colCenters.length - 1 ? cx + colSpacing * 1.2 : colCenters[i + 1];

          xStart = (prevX + cx) / 2;
          xEnd = (cx + nextX) / 2;
        } else {
          xStart = colCenters.last + (i - colCenters.length + 1) * colSpacing;
          xEnd = xStart + colSpacing;
        }

        columns.add(
          _LawColumn(
            index: i,
            xStart: xStart,
            xEnd: xEnd,
            startTime: slotConfig['start'] as int,
            endTime: slotConfig['end'] as int,
            isLunch: isLunch,
          ),
        );
      }
    } else {
      // Fallback to proportional grid layout if headers are partially obscured
      // Table left typically at ~45, right ~765, total ~720 across 10 cols
      const left = 95.0; // after Day col
      const right = 765.0;
      final slotWidth = (right - left) / 9.0;
      for (int i = 0; i < standardSlots.length; i++) {
        final slotConfig = standardSlots[i];
        columns.add(
          _LawColumn(
            index: i,
            xStart: left + i * slotWidth,
            xEnd: left + (i + 1) * slotWidth,
            startTime: slotConfig['start'] as int,
            endTime: slotConfig['end'] as int,
            isLunch: slotConfig['isLunch'] == true,
          ),
        );
      }
    }

    // 3. Extract Grid Cells per Day and Column
    final result = <String, List<TimetableEntry>>{};
    for (final day in days) {
      result[day] = [];
    }

    for (final row in dayRows) {
      final dayName = row.dayName;
      if (!result.containsKey(dayName)) continue;

      for (final col in columns) {
        if (col.isLunch) {
          result[dayName]!.add(
            TimetableEntry(
              id: _generateEntryId(dayName, col.index),
              subject: 'Lunch Break',
              component: 'Non-Academic',
              category: EventCategory.lunch,
              batch: 'Whole Class',
              startTime: col.startTime,
              endTime: col.endTime,
              durationMinutes: col.endTime - col.startTime,
              room: null,
              status: 'active',
            ),
          );
          continue;
        }

        // Find words strictly inside (xStart, xEnd) and (yTop, yBottom)
        final cellWords = words.where((w) {
          final cx = w.bounds.center.dx;
          final cy = w.bounds.center.dy;
          return cx >= col.xStart && cx < col.xEnd && cy >= row.yTop && cy < row.yBottom;
        }).toList();

        if (cellWords.isNotEmpty) {
          cellWords.sort((a, b) {
            if ((a.bounds.center.dy - b.bounds.center.dy).abs() > 3) {
              return a.bounds.center.dy.compareTo(b.bounds.center.dy);
            }
            return a.bounds.center.dx.compareTo(b.bounds.center.dx);
          });

          // Join lines based on vertical gaps
          final cellText = _reconstructCellText(cellWords);

          final entry = parseCellContent(
            cellText: cellText,
            day: dayName,
            slotIndex: col.index,
            startTime: col.startTime,
            endTime: col.endTime,
            defaultRoom: defaultRoom,
          );

          if (entry != null) {
            result[dayName]!.add(entry);
          }
        }
      }
    }

    return result;
  }

  static String _reconstructCellText(List<TextWord> words) {
    if (words.isEmpty) return '';
    final lines = <List<String>>[];
    double? lastY;

    for (final w in words) {
      final t = w.text.trim();
      if (t.isEmpty) continue;
      final y = w.bounds.center.dy;
      if (lastY == null || (y - lastY).abs() > 4) {
        lines.add([t]);
        lastY = y;
      } else {
        lines.last.add(t);
      }
    }

    return lines.map((l) => l.join(' ')).join('\n');
  }

  /// Parses a cell's text into a schema-compliant [TimetableEntry].
  ///
  /// - Unmarked academic cell -> 'Theory'
  /// - `(U)` suffix -> 'Tutorial'
  /// - Strips `(U)` and `(T)` from subject string
  /// - Strips trailing faculty lines (starts with Prof., Dr., etc.)
  /// - Defaults batch to 'Whole Class'
  static TimetableEntry? parseCellContent({
    required String cellText,
    required String day,
    required int slotIndex,
    required int startTime,
    required int endTime,
    String defaultRoom = 'SOL',
  }) {
    final cleaned = cellText.trim();
    if (cleaned.isEmpty || cleaned.toLowerCase() == 'free slot' || cleaned == '-') {
      return null;
    }

    final lines = cleaned
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    // Faculty regex (e.g. Prof. Anurag, Dr. Nishit)
    final facultyRegex = RegExp(
      r'^(Prof\.?|Dr\.?|Mr\.?|Ms\.?|Mrs\.?|Adv\.?)\s+',
      caseSensitive: false,
    );

    final subjectParts = <String>[];
    for (final line in lines) {
      if (!facultyRegex.hasMatch(line)) {
        subjectParts.add(line);
      }
    }

    String rawSubject = subjectParts.join(' ').trim();
    if (rawSubject.isEmpty && lines.isNotEmpty) {
      rawSubject = lines.first;
    }

    if (rawSubject.isEmpty || rawSubject.toLowerCase() == 'lunch') return null;

    // Determine Component: (U) -> Tutorial, (T) or unmarked -> Theory
    String component = 'Theory';
    if (rawSubject.contains('(U)') || rawSubject.endsWith(' (U)')) {
      component = 'Tutorial';
      rawSubject = rawSubject.replaceAll('(U)', '').trim();
    } else if (rawSubject.contains('(T)') || rawSubject.endsWith(' (T)')) {
      component = 'Theory';
      rawSubject = rawSubject.replaceAll('(T)', '').trim();
    }

    rawSubject = rawSubject.replaceAll(RegExp(r'[\s\-_\/]+$'), '').replaceAll(RegExp(r'\s+'), ' ').trim();

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

  /// Extracts full text from PDF bytes.
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
