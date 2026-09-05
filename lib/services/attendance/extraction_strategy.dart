import 'dart:math' as math;
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../attendance_date_time_parser.dart';
import 'attendance_document_profile.dart';
import 'raw_attendance_row.dart';

abstract class ExtractionStrategy {
  String get name;

  List<RawAttendanceRow> extract({
    required List<TextLine> pageLines,
    required List<TextWord> pageWords,
    required int pageIndex,
    required AttendanceDocumentProfile profile,
  });
}

/// Strategy A: Dynamic coordinate clustering and boundary detection.
/// Derives column boundaries from header bounds or horizontal gap clustering.
class DynamicCoordinateExtractionStrategy implements ExtractionStrategy {
  @override
  String get name => 'DynamicCoordinateClustering';

  static final _rowLineRegex = RegExp(
    r'^\s*(\d+)\s+(.+?)\s+([A-Z][a-z]{2}\s+\d{1,2},\s+\d{4})\s+'
    r'(\d{1,2}:\d{2}:\d{2}\s*[AP]M)\s+(\d{1,2}:\d{2}:\d{2}\s*[AP]M)\s+'
    r'(P|A|E|L|NU)\s*$',
    caseSensitive: false,
  );

  @override
  List<RawAttendanceRow> extract({
    required List<TextLine> pageLines,
    required List<TextWord> pageWords,
    required int pageIndex,
    required AttendanceDocumentProfile profile,
  }) {
    if (pageWords.isEmpty) return [];

    // 1. Detect header bounds dynamically
    double? headerMaxY;
    final headerWords = <TextWord>[];

    for (final w in pageWords) {
      final t = w.text.trim().toLowerCase();
      final cy = w.bounds.center.dy;
      if (t == 'sr' ||
          t == 'no.' ||
          t == 'course' ||
          t == 'date' ||
          t == 'attenda' ||
          t == 'attendance' ||
          t == 'status' ||
          t == 'start' ||
          t == 'end' ||
          t == 'from' ||
          t == 'to') {
        if (pageIndex == 0 && cy > 180 && cy < 360) {
          headerWords.add(w);
          headerMaxY = headerMaxY == null
              ? w.bounds.bottom
              : math.max(headerMaxY, w.bounds.bottom);
        } else if (pageIndex > 0 && cy < 80) {
          headerWords.add(w);
          headerMaxY = headerMaxY == null
              ? w.bounds.bottom
              : math.max(headerMaxY, w.bounds.bottom);
        }
      }
    }

    final tableTopY = headerMaxY != null
        ? headerMaxY + 2.0
        : (pageIndex == 0 ? 320.0 : 45.0);

    // 2. Detect footer boundary dynamically
    double tableBottomY = 750.0;
    for (final w in pageWords) {
      final t = w.text.trim().toLowerCase();
      final cy = w.bounds.center.dy;
      if (cy > tableTopY) {
        if (t.contains('present') ||
            t.contains('sap') ||
            t.contains('system-generated') ||
            t.contains('query') ||
            t.contains('signature') ||
            t == 'ps:') {
          tableBottomY = math.min(tableBottomY, w.bounds.top - 2.0);
        }
      }
    }

    final tableWords = pageWords.where((w) {
      final cy = w.bounds.center.dy;
      return cy > tableTopY && cy < tableBottomY && w.text.trim().isNotEmpty;
    }).toList();

    if (tableWords.isEmpty) return [];

    // 3. Cluster words into visual rows by dy (within 6.0 pt)
    tableWords.sort((a, b) => a.bounds.center.dy.compareTo(b.bounds.center.dy));

    final rowClusters = <List<TextWord>>[];
    for (final w in tableWords) {
      final y = w.bounds.center.dy;
      if (rowClusters.isEmpty) {
        rowClusters.add([w]);
      } else {
        final clusterY = rowClusters.last.first.bounds.center.dy;
        if ((y - clusterY).abs() <= 6.0) {
          rowClusters.last.add(w);
        } else {
          rowClusters.add([w]);
        }
      }
    }

    // 4. Determine column boundaries dynamically from headers if available
    double colSrMax = 55.0;
    double colCourseMax = 325.0;
    double colDateMax = 390.0;
    double colStartMax = 460.0;
    double colEndMax = 535.0;

    if (profile.profileId != 'nmims_sap' && headerWords.isNotEmpty) {
      for (final hw in headerWords) {
        final text = hw.text.trim().toLowerCase();
        final right = hw.bounds.right;
        if (text == 'no.' || text == 'sr') {
          colSrMax = math.max(colSrMax, right + 10);
        } else if (text == 'course' || text == 'subject') {
          colCourseMax = math.max(colCourseMax, right + 15);
        } else if (text == 'date') {
          colDateMax = math.max(colDateMax, right + 15);
        } else if (text == 'start' || text == 'from') {
          colStartMax = math.max(colStartMax, right + 15);
        } else if (text == 'end' || text == 'to') {
          colEndMax = math.max(colEndMax, right + 15);
        }
      }
    }

    final rows = <RawAttendanceRow>[];
    var rowIndex = 1;

    for (final cluster in rowClusters) {
      cluster.sort((a, b) => a.bounds.center.dx.compareTo(b.bounds.center.dx));

      final srWords = <String>[];
      final courseWords = <String>[];
      final dateWords = <String>[];
      final startWords = <String>[];
      final endWords = <String>[];
      final statusWords = <String>[];

      for (final w in cluster) {
        final cx = w.bounds.center.dx;
        final t = w.text;
        if (cx < colSrMax) {
          srWords.add(t);
        } else if (cx < colCourseMax) {
          courseWords.add(t);
        } else if (cx < colDateMax) {
          dateWords.add(t);
        } else if (cx < colStartMax) {
          startWords.add(t);
        } else if (cx < colEndMax) {
          endWords.add(t);
        } else {
          statusWords.add(t);
        }
      }

      var srStr = srWords.join(' ').trim();
      var courseStr = courseWords.join(' ').trim();
      var dateStr = dateWords.join(' ').trim();
      var startStr = startWords.join(' ').trim();
      var endStr = endWords.join(' ').trim();
      var statusStr = statusWords.join(' ').trim();

      final fullLine = cluster.map((w) => w.text).join(' ').trim();

      final srNo = int.tryParse(srStr);
      final date = AttendanceDateTimeParser.parseDate(dateStr);
      final startMins = AttendanceDateTimeParser.parseTimeToMinutes(startStr);
      final endMins = AttendanceDateTimeParser.parseTimeToMinutes(endStr);
      final rawStatus = statusStr.toUpperCase();
      final normalizedStatus = profile.mapStatus(rawStatus);

      // Fallback regex if coordinate clustering split boundary awkwardly or fields are invalid
      if (courseStr.isEmpty ||
          srNo == null ||
          date == null ||
          (profile.supportsTimeColumns && (startMins == null || endMins == null)) ||
          normalizedStatus == null) {
        final match = _rowLineRegex.firstMatch(fullLine);
        if (match != null) {
          srStr = match.group(1)!;
          courseStr = match.group(2)!.trim();
          dateStr = match.group(3)!.trim();
          startStr = match.group(4)!.trim();
          endStr = match.group(5)!.trim();
          statusStr = match.group(6)!.trim().toUpperCase();
        }
      }

      final parsedSr = int.tryParse(srStr) ?? rowIndex;

      rows.add(
        RawAttendanceRow(
          pageNumber: pageIndex + 1,
          sourceRowNumber: parsedSr,
          rawCourseName: courseStr,
          rawDate: dateStr,
          rawStartTime: startStr.isNotEmpty ? startStr : null,
          rawEndTime: endStr.isNotEmpty ? endStr : null,
          rawStatus: statusStr,
          rawText: fullLine,
        ),
      );

      rowIndex++;
    }

    return rows;
  }
}

/// Strategy C: Line-pattern regex reconstruction when words or coordinates are unclustered.
class LinePatternExtractionStrategy implements ExtractionStrategy {
  @override
  String get name => 'LinePatternReconstruction';

  static final _generalLineRegex = RegExp(
    r'^\s*(\d+)?\s*(.+?)\s+([A-Z][a-z]{2}\s+\d{1,2},\s+\d{4}|\d{1,2}[./\-]\d{1,2}[./\-]\d{4})\s*'
    r'(?:(\d{1,2}:\d{2}(?::\d{2})?\s*[AP]M)\s+(\d{1,2}:\d{2}(?::\d{2})?\s*[AP]M))?\s*'
    r'([A-Za-z0-9_\-]+)\s*$',
    caseSensitive: false,
  );

  @override
  List<RawAttendanceRow> extract({
    required List<TextLine> pageLines,
    required List<TextWord> pageWords,
    required int pageIndex,
    required AttendanceDocumentProfile profile,
  }) {
    final rows = <RawAttendanceRow>[];
    var rowIndex = 1;

    for (final line in pageLines) {
      final text = line.text.trim();
      if (text.isEmpty) continue;

      final match = _generalLineRegex.firstMatch(text);
      if (match != null) {
        final srStr = match.group(1);
        final courseStr = match.group(2)!.trim();
        final dateStr = match.group(3)!.trim();
        final startStr = match.group(4)?.trim();
        final endStr = match.group(5)?.trim();
        final statusStr = match.group(6)!.trim();

        rows.add(
          RawAttendanceRow(
            pageNumber: pageIndex + 1,
            sourceRowNumber: int.tryParse(srStr ?? '') ?? rowIndex,
            rawCourseName: courseStr,
            rawDate: dateStr,
            rawStartTime: startStr,
            rawEndTime: endStr,
            rawStatus: statusStr,
            rawText: text,
            extractionConfidence: 0.85,
          ),
        );
        rowIndex++;
      }
    }

    return rows;
  }
}

/// Strategy chain: Tries coordinate clustering first, then falls back to line pattern matching.
class ExtractionStrategyChain {
  static final List<ExtractionStrategy> _strategies = [
    DynamicCoordinateExtractionStrategy(),
    LinePatternExtractionStrategy(),
  ];

  static List<RawAttendanceRow> execute({
    required List<TextLine> pageLines,
    required List<TextWord> pageWords,
    required int pageIndex,
    required AttendanceDocumentProfile profile,
  }) {
    for (final strategy in _strategies) {
      final rows = strategy.extract(
        pageLines: pageLines,
        pageWords: pageWords,
        pageIndex: pageIndex,
        profile: profile,
      );
      if (rows.isNotEmpty) {
        return rows;
      }
    }
    return [];
  }
}
