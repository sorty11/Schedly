import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/attendance_log.dart';
import '../models/batch_analytics.dart';
import '../models/timetable_entry.dart';
import '../timetable_manager.dart';

class PdfAttendanceImportService {
  static Future<List<AttendanceLog>> parseAttendancePdf({
    required Uint8List pdfBytes,
    required String division,
    required List<SubjectAnalytics> analytics,
  }) async {
    // We pass lightweight data to isolate to prevent heavy object serialization issues
    final subjectStrings = analytics.expand((a) => a.batches.map((b) => '\${b.subjectCode}_\${b.component}')).toSet().toList();
    
    return await compute(_parsePdfInIsolate, _IsolateArgs(
      bytes: pdfBytes,
      division: division,
      knownSubjects: subjectStrings,
    ));
  }
}

class _IsolateArgs {
  final Uint8List bytes;
  final String division;
  final List<String> knownSubjects;

  _IsolateArgs({
    required this.bytes,
    required this.division,
    required this.knownSubjects,
  });
}

Future<List<AttendanceLog>> _parsePdfInIsolate(_IsolateArgs args) async {
  final document = PdfDocument(inputBytes: args.bytes);
  final extractor = PdfTextExtractor(document);
  final logs = <AttendanceLog>[];
  
  for (int p = 0; p < document.pages.count; p++) {
    final lines = extractor.extractTextLines(startPageIndex: p, endPageIndex: p);
    final words = <TextWord>[];
    for (final line in lines) {
      words.addAll(line.wordCollection);
    }

    if (words.isEmpty) continue;

    // 1. Dynamic Column Detection
    // Look for headers to determine X boundaries
    double? srNoX, courseNameX, dateX, startTimeX, endTimeX, attendanceX;
    
    for (final word in words) {
      final t = word.text.toLowerCase();
      final cx = word.bounds.center.dx;
      
      if (t == 'sr' || t == 'no.') srNoX ??= cx;
      else if (t == 'course') courseNameX ??= cx;
      else if (t == 'date') dateX ??= cx;
      else if (t == 'start') startTimeX ??= cx;
      else if (t == 'end') endTimeX ??= cx;
      else if (t == 'attenda' || t == 'nce' || t == 'attendance') attendanceX ??= cx;
    }

    // Fallbacks if OCR misses headers
    srNoX ??= 30.0;
    courseNameX ??= 150.0;
    dateX ??= 350.0;
    startTimeX ??= 450.0;
    endTimeX ??= 550.0;
    attendanceX ??= 650.0;

    // Column Bounds
    final colSrNo = _Bounds(0, (srNoX + courseNameX) / 2);
    final colCourse = _Bounds((srNoX + courseNameX) / 2, (courseNameX + dateX) / 2);
    final colDate = _Bounds((courseNameX + dateX) / 2, (dateX + startTimeX) / 2);
    final colStart = _Bounds((dateX + startTimeX) / 2, (startTimeX + endTimeX) / 2);
    final colEnd = _Bounds((startTimeX + endTimeX) / 2, (endTimeX + attendanceX) / 2);
    final colStatus = _Bounds((endTimeX + attendanceX) / 2, 9999);

    // 2. Y-Clustering (Find Rows)
    final rowCandidates = <double>[];
    for (final w in words) {
      if (w.bounds.center.dy > 100) { // Ignore top header
        rowCandidates.add(w.bounds.center.dy);
      }
    }
    rowCandidates.sort();
    
    final rowCenters = <double>[];
    for (final y in rowCandidates) {
      if (rowCenters.isEmpty || (y - rowCenters.last).abs() > 6) {
        rowCenters.add(y);
      }
    }

    // Group words into rows
    final rawRows = <Map<String, String>>[];
    for (final y in rowCenters) {
      final rowWords = words.where((w) => (w.bounds.center.dy - y).abs() <= 6).toList();
      if (rowWords.isEmpty) continue;

      rowWords.sort((a, b) => a.bounds.center.dx.compareTo(b.bounds.center.dx));
      
      String srNo = '', course = '', dateStr = '', start = '', end = '', status = '';
      
      for (final w in rowWords) {
        final cx = w.bounds.center.dx;
        final t = w.text;
        
        if (colSrNo.contains(cx)) srNo += '\$t ';
        else if (colCourse.contains(cx)) course += '\$t ';
        else if (colDate.contains(cx)) dateStr += '\$t ';
        else if (colStart.contains(cx)) start += '\$t ';
        else if (colEnd.contains(cx)) end += '\$t ';
        else if (colStatus.contains(cx)) status += '\$t ';
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

    // 3. Row Merging & Cleanup (Handle fragments)
    final mergedRows = <Map<String, String>>[];
    for (final r in rawRows) {
      if (r['course']!.isEmpty && r['date']!.isEmpty && r['status']!.isEmpty) continue; // Noise
      
      if (r['date']!.isEmpty && r['start']!.isEmpty && mergedRows.isNotEmpty) {
        // Probably a fragmented course name or status
        if (r['course']!.isNotEmpty) {
          mergedRows.last['course'] = "\${mergedRows.last['course']} \${r['course']}";
        }
        if (r['status']!.isNotEmpty && mergedRows.last['status']!.isEmpty) {
          mergedRows.last['status'] = r['status']!;
        }
      } else if (r['course']!.isEmpty && r['status']!.isNotEmpty && mergedRows.isNotEmpty && mergedRows.last['status']!.isEmpty) {
        // Stray status
        mergedRows.last['status'] = r['status']!;
      } else if (r['date']!.isNotEmpty) {
        mergedRows.add(r);
      }
    }

    // 4. Processing & Matching
    final dateRegex = RegExp(r'^[A-Z][a-z]{2}\s\d{1,2},\s\d{4}\$');
    final months = {'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6, 'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12};

    for (final r in mergedRows) {
      final dateRaw = r['date']!;
      if (!dateRegex.hasMatch(dateRaw)) continue;

      // Parse Date
      final dParts = dateRaw.split(' ');
      final month = months[dParts[0]] ?? 1;
      final day = int.tryParse(dParts[1].replaceAll(',', '')) ?? 1;
      final year = int.tryParse(dParts[2]) ?? DateTime.now().year;
      final date = DateTime(year, month, day);

      // Parse Times
      final startMins = _parsePdfTime(r['start']!);
      final endMins = _parsePdfTime(r['end']!);
      if (startMins == -1 || endMins == -1) continue;

      final rawSubject = r['course']!;
      final rawStatus = r['status']!;
      
      String status = 'unknown';
      if (rawStatus == 'P') status = 'present';
      else if (rawStatus == 'A') status = 'absent';
      else if (rawStatus == 'NU') status = 'not updated';
      
      if (status == 'unknown' || status == 'not updated') continue; // Ignore these for logs

      // Multi-Stage Matching
      final match = _matchSubject(rawSubject, args.knownSubjects);
      
      logs.add(AttendanceLog(
        id: "\${args.division}_\${year}\${month.toString().padLeft(2, '0')}\${day.toString().padLeft(2, '0')}_\${startMins}_\${match.subjectCode}_\${match.component}",
        subjectCode: match.subjectCode,
        component: match.component,
        rawSubjectText: rawSubject,
        date: date,
        startTime: startMins,
        endTime: endMins,
        status: status,
        source: 'pdf_import',
        confidence: match.confidence,
      ));
    }
  }
  
  document.dispose();
  return logs;
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

class _MatchResult {
  final String subjectCode;
  final String component;
  final MatchConfidence confidence;
  _MatchResult(this.subjectCode, this.component, this.confidence);
}

_MatchResult _matchSubject(String rawSubject, List<String> knownSubjects) {
  // Normalization Engine
  // E.g., "English CommunicationP4 CE D1 Sem II" -> "English Communication"
  String normalized = rawSubject.replaceAll(RegExp(r'\s+'), ' ').trim();
  
  // Strip known batch/semester noise
  normalized = normalized.replaceAll(RegExp(r'[PTU]\d\s*CE[-\s]?D\d?.*\$', caseSensitive: false), '').trim();
  normalized = normalized.replaceAll(RegExp(r'Sem\s*(II|I|III|IV|V|VI|VII|VIII|1|2|3|4|5|6|7|8)', caseSensitive: false), '').trim();
  normalized = normalized.replaceAll(RegExp(r'Batch.*\$', caseSensitive: false), '').trim();
  
  String component = 'Theory';
  if (rawSubject.toUpperCase().contains('P4') || rawSubject.toUpperCase().contains('PRACTICAL') || rawSubject.toUpperCase().contains('LAB')) {
    component = 'Lab';
  } else if (rawSubject.toUpperCase().contains('T4') || rawSubject.toUpperCase().contains('TUTORIAL')) {
    component = 'Tutorial';
  }

  // Stage 1: Exact Match (Normalized)
  for (final ks in knownSubjects) {
    final parts = ks.split('_');
    final ksSubj = parts[0];
    final ksComp = parts.length > 1 ? parts[1] : 'Theory';
    
    if (ksSubj.toLowerCase() == normalized.toLowerCase() && ksComp == component) {
      return _MatchResult(ksSubj, component, MatchConfidence.perfect);
    }
  }

  // Stage 2: Fuzzy Containment Match
  String bestMatchSubj = '';
  int bestScore = 0;
  
  for (final ks in knownSubjects) {
    final parts = ks.split('_');
    final ksSubj = parts[0];
    
    // Check if one contains the other
    if (ksSubj.toLowerCase().contains(normalized.toLowerCase()) || 
        normalized.toLowerCase().contains(ksSubj.toLowerCase())) {
        
        final score = ksSubj.length > normalized.length ? normalized.length : ksSubj.length;
        if (score > bestScore) {
          bestScore = score;
          bestMatchSubj = ksSubj;
        }
    }
  }

  if (bestMatchSubj.isNotEmpty) {
    return _MatchResult(bestMatchSubj, component, MatchConfidence.normalized);
  }
  
  // Stage 3: Extreme fuzzy (word intersection)
  final normWords = normalized.toLowerCase().split(' ').where((w) => w.length > 2).toSet();
  int maxIntersect = 0;
  for (final ks in knownSubjects) {
    final ksWords = ks.split('_')[0].toLowerCase().split(' ').where((w) => w.length > 2).toSet();
    final intersect = normWords.intersection(ksWords).length;
    if (intersect > maxIntersect) {
      maxIntersect = intersect;
      bestMatchSubj = ks.split('_')[0];
    }
  }

  if (maxIntersect > 0) {
    return _MatchResult(bestMatchSubj, component, MatchConfidence.fuzzy);
  }

  // Unmatched
  return _MatchResult(normalized.isEmpty ? rawSubject : normalized, component, MatchConfidence.unmatched);
}
