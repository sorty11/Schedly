import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/attendance_log.dart';
import '../models/batch_analytics.dart';
import '../models/timetable_entry.dart';
import '../timetable_manager.dart';

class PdfImportResult {
  final StudentImportInfo? studentInfo;
  final List<AttendanceLog> logs;
  final int processedCount;
  final int skippedCount;
  final List<String> warnings;
  
  PdfImportResult({
    this.studentInfo,
    required this.logs,
    required this.processedCount,
    required this.skippedCount,
    this.warnings = const [],
  });
}

class StudentImportInfo {
  final String name;
  final String studentNumber;
  final String rollNumber;
  final String program;

  StudentImportInfo({
    required this.name,
    required this.studentNumber,
    required this.rollNumber,
    required this.program,
  });
}

class PdfAttendanceImportService {
  static Future<PdfImportResult> parseAttendancePdf({
    required Uint8List pdfBytes,
    required String division,
  }) async {
    // Run text extraction in isolate
    final result = await compute(_parsePdfInIsolate, _IsolateArgs(
      bytes: pdfBytes,
      division: division,
    ));

    if (result.logs.isEmpty) return result;

    // Resolve IDs
    final resolvedLogs = <AttendanceLog>[];
    for (final log in result.logs) {
      final norm = log.rawSubjectText.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
      final id = "${division}_${log.date.year}${log.date.month.toString().padLeft(2, '0')}${log.date.day.toString().padLeft(2, '0')}_${log.startTime}_$norm";

      resolvedLogs.add(AttendanceLog(
        id: id,
        subjectCode: log.rawSubjectText,
        component: log.component,
        rawSubjectText: log.rawSubjectText,
        normalizedSubject: norm,
        canonicalSubjectId: null,
        date: log.date,
        startTime: log.startTime,
        endTime: log.endTime,
        status: log.status,
        source: log.source,
        confidence: log.confidence,
        timetableEntryId: log.timetableEntryId,
      ));
    }

    return PdfImportResult(
      studentInfo: result.studentInfo,
      logs: resolvedLogs,
      processedCount: result.processedCount,
      skippedCount: result.skippedCount,
      warnings: result.warnings,
    );
  }
}

class _IsolateArgs {
  final Uint8List bytes;
  final String division;

  _IsolateArgs({
    required this.bytes,
    required this.division,
  });
}

Future<PdfImportResult> _parsePdfInIsolate(_IsolateArgs args) async {
  final document = PdfDocument(inputBytes: args.bytes);
  final extractor = PdfTextExtractor(document);
  final logs = <AttendanceLog>[];
  
  String studentName = '';
  String studentNumber = '';
  String rollNumber = '';
  String programName = '';
  
  int totalProcessed = 0;
  int totalSkipped = 0;
  final warnings = <String>[];
  
  for (int p = 0; p < document.pages.count; p++) {
    final lines = extractor.extractTextLines(startPageIndex: p, endPageIndex: p);
    final words = <TextWord>[];
    for (final line in lines) {
      words.addAll(line.wordCollection);
    }

    if (words.isEmpty) continue;

    // --- Module 2: Student Information Extraction ---
    if (p == 0) {
      final headerWords = words.where((w) => w.bounds.center.dy < 120).toList();
      headerWords.sort((a, b) {
        final dyDiff = a.bounds.center.dy.compareTo(b.bounds.center.dy);
        if (dyDiff != 0 && (a.bounds.center.dy - b.bounds.center.dy).abs() > 5) return dyDiff;
        return a.bounds.center.dx.compareTo(b.bounds.center.dx);
      });
      
      String headerText = headerWords.map((w) => w.text).join(' ');
      
      // Basic Regex Extractors
      final nameMatch = RegExp(r'Student Name\s*:?\s*([^Student]+)', caseSensitive: false).firstMatch(headerText);
      final numMatch = RegExp(r'Student No\.?\s*:?\s*(\d+)', caseSensitive: false).firstMatch(headerText);
      final rollMatch = RegExp(r'Roll No\.?\s*:?\s*([A-Z0-9]+)', caseSensitive: false).firstMatch(headerText);
      final progMatch = RegExp(r'Program\s*:?\s*(B\.Tech[^Semester]+)', caseSensitive: false).firstMatch(headerText);
      
      if (nameMatch != null) studentName = nameMatch.group(1)?.trim() ?? '';
      if (numMatch != null) studentNumber = numMatch.group(1)?.trim() ?? '';
      if (rollMatch != null) rollNumber = rollMatch.group(1)?.trim() ?? '';
      if (progMatch != null) programName = progMatch.group(1)?.trim() ?? '';
    }

    // --- Robust PDF Parser Pipeline ---
    print('DEBUG [Page $p]: Characters extracted: ${words.length} words');

    // 1. Line Grouping First
    final rowCandidates = <double>[];
    for (final w in words) {
      rowCandidates.add(w.bounds.center.dy);
    }
    rowCandidates.sort();
    
    final rowCenters = <double>[];
    for (final y in rowCandidates) {
      if (rowCenters.isEmpty || (y - rowCenters.last).abs() > 6) {
        rowCenters.add(y);
      }
    }

    final linesData = <List<TextWord>>[];
    for (final y in rowCenters) {
      final lineWords = words.where((w) => (w.bounds.center.dy - y).abs() <= 6).toList();
      if (lineWords.isNotEmpty) {
        lineWords.sort((a, b) => a.bounds.center.dx.compareTo(b.bounds.center.dx));
        linesData.add(lineWords);
      }
    }
    print('DEBUG [Page $p]: Y-lines detected: ${linesData.length}');

    // 2. Deterministic Header Detection & Column Bounds
    int headerLineIdx = -1;
    double? srNoX, courseNameX, dateX, startTimeX, endTimeX, attendanceX;
    
    for (int i = 0; i < linesData.length; i++) {
      final text = linesData[i].map((w) => w.text.toLowerCase()).join(' ');
      if (text.contains('course') && (text.contains('date') || text.contains('start'))) {
        headerLineIdx = i;
        for (final w in linesData[i]) {
          final t = w.text.toLowerCase();
          final cx = w.bounds.center.dx;
          if (t == 'sr' || t == 'no.') srNoX ??= cx;
          else if (t == 'course') courseNameX ??= cx;
          else if (t == 'date') dateX ??= cx;
          else if (t == 'start') startTimeX ??= cx;
          else if (t == 'end') endTimeX ??= cx;
          else if (t == 'attenda' || t == 'nce' || t == 'attendance') attendanceX ??= cx;
        }
        break;
      }
    }

    if (headerLineIdx == -1) {
      warnings.add('Could not find table header on page $p.');
      continue;
    }
    
    // Fallbacks if OCR misses specific headers inside the detected line
    srNoX ??= 30.0;
    courseNameX ??= 150.0;
    dateX ??= 350.0;
    startTimeX ??= 450.0;
    endTimeX ??= 550.0;
    attendanceX ??= endTimeX + 70.0; // Dynamic fallback instead of hardcoded 650.0
    
    final colSrNo = _Bounds(0, (srNoX + courseNameX) / 2);
    final colCourse = _Bounds((srNoX + courseNameX) / 2, (courseNameX + dateX) / 2);
    final colDate = _Bounds((courseNameX + dateX) / 2, (dateX + startTimeX) / 2);
    final colStart = _Bounds((dateX + startTimeX) / 2, (startTimeX + endTimeX) / 2);
    final colEnd = _Bounds((startTimeX + endTimeX) / 2, (endTimeX + attendanceX) / 2);
    final colStatus = _Bounds((endTimeX + attendanceX) / 2, 9999);

    // 3. Extract Rows (Only from lines below the header)
    final rawRows = <Map<String, String>>[];
    for (int i = headerLineIdx + 1; i < linesData.length; i++) {
      String srNo = '', course = '', dateStr = '', start = '', end = '', status = '';
      
      for (final w in linesData[i]) {
        final cx = w.bounds.center.dx;
        final t = w.text;
        
        if (colSrNo.contains(cx)) srNo += '$t ';
        else if (colCourse.contains(cx)) course += '$t ';
        else if (colDate.contains(cx)) dateStr += '$t ';
        else if (colStart.contains(cx)) start += '$t ';
        else if (colEnd.contains(cx)) end += '$t ';
        else if (colStatus.contains(cx)) status += '$t ';
      }

      rawRows.add({
        'srNo': srNo.trim(),
        'course': course.trim(),
        'date': dateStr.trim(),
        'start': start.trim(),
        'end': end.trim(),
        'status': status.trim(),
      });
    }

    // Row Merging & Cleanup (Handle fragments)
    final mergedRows = <Map<String, String>>[];
    for (final r in rawRows) {
      if (r['course']!.isEmpty && r['date']!.isEmpty && r['status']!.isEmpty) continue;
      
      if (r['date']!.isEmpty && r['start']!.isEmpty && mergedRows.isNotEmpty) {
        if (r['course']!.isNotEmpty) {
          mergedRows.last['course'] = "${mergedRows.last['course']} ${r['course']}";
        }
        if (r['status']!.isNotEmpty && mergedRows.last['status']!.isEmpty) {
          mergedRows.last['status'] = r['status']!;
        }
      } else if (r['course']!.isEmpty && r['status']!.isNotEmpty && mergedRows.isNotEmpty && mergedRows.last['status']!.isEmpty) {
        mergedRows.last['status'] = r['status']!;
      } else if (r['date']!.isNotEmpty) {
        mergedRows.add(r);
      }
    }

    // 4. Processing & Matching with Fault Tolerance
    final dateRegex = RegExp(r'([A-Za-z]{3,9})\s*(\d{1,2})\s*,?\s*(\d{4})');
    final months = {'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6, 'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12, 'january': 1, 'february': 2, 'march': 3, 'april': 4, 'june': 6, 'july': 7, 'august': 8, 'september': 9, 'october': 10, 'november': 11, 'december': 12};

    for (int i = 0; i < mergedRows.length; i++) {
      final r = mergedRows[i];
      try {
        final dateRaw = r['date']!;
        final dateMatch = dateRegex.firstMatch(dateRaw);
        if (dateMatch == null) {
          warnings.add('Skipped row on page $p due to invalid date format: "$dateRaw"');
          totalSkipped++;
          continue;
        }

        // Parse Date
        final monthStr = dateMatch.group(1)!.toLowerCase();
        final day = int.parse(dateMatch.group(2)!);
        final year = int.parse(dateMatch.group(3)!);
        final month = months[monthStr] ?? (months.entries.where((e) => monthStr.startsWith(e.key)).firstOrNull?.value ?? 1);
        final date = DateTime(year, month, day);

        // Parse Times
        final startMins = _parsePdfTime(r['start']!);
        final endMins = _parsePdfTime(r['end']!);
        if (startMins == -1 || endMins == -1) {
          warnings.add('Skipped row on page $p due to invalid time: Start="${r['start']}", End="${r['end']}"');
          totalSkipped++;
          continue;
        }

        final rawSubject = r['course']!;
        final rawStatus = r['status']!.toUpperCase();
        
        String status = 'unknown';
        if (rawStatus.endsWith(' P')) status = 'present';
        else if (rawStatus.endsWith(' A')) status = 'absent';
        else if (rawStatus.endsWith(' NU')) status = 'not updated';
        else if (rawStatus == 'P') status = 'present';
        else if (rawStatus == 'A') status = 'absent';
        else if (rawStatus == 'NU') status = 'not updated';
        
        if (status == 'unknown' || status == 'not updated') {
          warnings.add('Skipped row on page $p due to unknown status: "$rawStatus"');
          totalSkipped++;
          continue;
        }

        // Component detection inside isolate
        String component = 'Theory';
        if (rawSubject.toUpperCase().contains('P4') || rawSubject.toUpperCase().contains('PRACTICAL') || rawSubject.toUpperCase().contains('LAB')) {
          component = 'Lab';
        } else if (rawSubject.toUpperCase().contains('T4') || rawSubject.toUpperCase().contains('TUTORIAL')) {
          component = 'Tutorial';
        }

        logs.add(AttendanceLog(
          id: 'temp_${logs.length}',
          subjectCode: rawSubject,
          component: component,
          rawSubjectText: rawSubject,
          date: date,
          startTime: startMins,
          endTime: endMins,
          status: status,
          source: 'pdf_import',
          confidence: MatchConfidence.unknown,
        ));
        totalProcessed++;
      } catch (e) {
        warnings.add('Malformed row skipped on page $p. Error: $e');
        totalSkipped++;
      }
    }
  }
  
  document.dispose();
  final info = studentName.isNotEmpty ? StudentImportInfo(
    name: studentName,
    studentNumber: studentNumber,
    rollNumber: rollNumber,
    program: programName,
  ) : null;
  return PdfImportResult(
    studentInfo: info,
    logs: logs,
    processedCount: totalProcessed,
    skippedCount: totalSkipped,
    warnings: warnings,
  );
}

class _Bounds {
  final double min;
  final double max;
  _Bounds(this.min, this.max);
  bool contains(double v) => v >= min && v < max;
}

int _parsePdfTime(String t) {
  t = t.trim().toUpperCase();
  if (t.isEmpty) return -1;
  final isPM = t.contains('PM');
  final clean = t.replaceAll(RegExp(r'[A-Z\s]'), '');
  final parts = clean.split(':');
  if (parts.isEmpty) return -1;
  
  int h = int.tryParse(parts[0]) ?? 0;
  int m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
  
  if (isPM && h < 12) h += 12;
  if (!isPM && h == 12) h = 0;
  
  return h * 60 + m;
}

// Match logic moved to SubjectAliasService
