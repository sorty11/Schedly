import 'dart:math' as math;
import 'dart:typed_data';

import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../models/attendance_import_models.dart';
import '../models/attendance_log.dart';
import '../models/course_component.dart';
import 'attendance_course_matcher.dart';
import 'attendance_course_normalizer.dart';
import 'attendance_date_time_parser.dart';
import 'attendance_status_mapper.dart';

/// Extracts and parses NMIMS/SVKM student attendance PDF reports.
class AttendancePdfParser {
  static final _rowLineRegex = RegExp(
    r'^\s*(\d+)\s+(.+?)\s+([A-Z][a-z]{2}\s+\d{1,2},\s+\d{4})\s+'
    r'(\d{1,2}:\d{2}:\d{2}\s*[AP]M)\s+(\d{1,2}:\d{2}:\d{2}\s*[AP]M)\s+'
    r'(P|A|E|L|NU)\s*$',
    caseSensitive: false,
  );

  /// Parses PDF bytes into rows + metadata. Pure — no Firestore side effects.
  static ({
    AttendanceReportMetadata metadata,
    List<ParsedAttendanceRow> rows,
    List<String> warnings,
    List<String> errors,
    bool isImageOnly,
  })
  parseBytes(Uint8List bytes, {AttendanceParseProgress? onProgress}) {
    PdfDocument? document;
    try {
      document = PdfDocument(inputBytes: bytes);
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('password') || msg.contains('encrypted')) {
        throw AttendancePdfParseException(
          'PDF is password-protected. Please export an unprotected copy.',
          details: [e.toString()],
        );
      }
      throw AttendancePdfParseException(
        'Could not open PDF. The file may be corrupted.',
        details: [e.toString()],
      );
    }

    try {
      if (document.pages.count == 0) {
        throw AttendancePdfParseException('PDF is empty.');
      }

      if (document.pages.count > 0 &&
          PdfDocumentHelper.checkIfPasswordProtected(document)) {
        throw AttendancePdfParseException(
          'PDF is password-protected. Please export an unprotected copy.',
        );
      }

      final extractor = PdfTextExtractor(document);
      final pageCount = document.pages.count;
      final allRows = <ParsedAttendanceRow>[];
      final warnings = <String>[];
      final errors = <String>[];
      var totalTextLength = 0;

      String? studentName;
      String? studentNumber;
      String? rollNo;
      String? academicYearSession;
      String? programName;
      String? durationLine;

      for (var page = 0; page < pageCount; page++) {
        onProgress?.call(
          currentPage: page + 1,
          totalPages: pageCount,
          rowsDetected: allRows.length,
          message: 'Parsing page ${page + 1} of $pageCount…',
        );

        final pageLines = extractor.extractTextLines(
          startPageIndex: page,
          endPageIndex: page,
        );

        final pageWords = <TextWord>[];
        for (final line in pageLines) {
          final text = line.text.trim();
          if (text.isNotEmpty) {
            totalTextLength += text.length;
          }
          pageWords.addAll(line.wordCollection);
        }

        // 1. Metadata extraction from page 0
        if (page == 0) {
          final meta = _extractMetadata(pageWords, pageLines);
          studentName ??= meta.studentName;
          studentNumber ??= meta.studentNumber;
          rollNo ??= meta.rollNo;
          academicYearSession ??= meta.academicYearSession;
          programName ??= meta.programName;
          durationLine ??= meta.durationLine;
        }

        // 2. Positional row extraction
        final pageRows = _extractRowsFromPage(
          pageWords: pageWords,
          pageIndex: page,
          warnings: warnings,
        );

        allRows.addAll(pageRows);
      }

      final isImageOnly = totalTextLength < 50;
      if (isImageOnly) {
        return (
          metadata: AttendanceReportMetadata(pageCount: pageCount),
          rows: <ParsedAttendanceRow>[],
          warnings: warnings,
          errors: [
            'This PDF appears to be image-only with no extractable text. OCR is not supported.',
          ],
          isImageOnly: true,
        );
      }

      if (allRows.isEmpty) {
        errors.add(
          'No attendance rows found. The report format may be unsupported.',
        );
      }

      final duration = durationLine != null
          ? AttendanceDateTimeParser.parseReportDuration(durationLine)
          : (start: null, end: null);

      final yearSession = _splitYearSession(academicYearSession ?? '');

      final metadata = AttendanceReportMetadata(
        studentName: studentName ?? '',
        studentNumber: studentNumber ?? '',
        rollNo: rollNo ?? '',
        academicYear: yearSession.year,
        academicSession: yearSession.session,
        programName: programName ?? '',
        reportStartDate: duration.start,
        reportEndDate: duration.end,
        pageCount: pageCount,
      );

      allRows.sort((a, b) => a.srNo.compareTo(b.srNo));

      return (
        metadata: metadata,
        rows: allRows,
        warnings: warnings,
        errors: errors,
        isImageOnly: false,
      );
    } finally {
      document.dispose();
    }
  }

  /// Builds import preview with course matching and deduplication analysis.
  static AttendanceImportPreview buildPreview({
    required AttendanceReportMetadata metadata,
    required List<ParsedAttendanceRow> rows,
    required List<CourseComponent> configuredCourses,
    required List<AttendanceLog> existingLogs,
    List<String> parseWarnings = const [],
    List<String> parseErrors = const [],
    bool isImageOnly = false,
    int totalPagesParsed = 0,
  }) {
    final matcher = AttendanceCourseMatcher(configuredCourses);
    final existingByKey = {
      for (final log in existingLogs) log.deduplicationKey: log,
    };

    final logs = <AttendanceLog>[];
    final unresolvedRows = <ParsedAttendanceRow>[];
    final warnings = [...parseWarnings];

    var present = 0, absent = 0, exemption = 0, late = 0, notUpdated = 0;
    var duplicates = 0, updates = 0, unmatched = 0;

    final seenInPreview = <String>{};

    for (final row in rows) {
      switch (row.normalizedStatus) {
        case 'present':
          present++;
        case 'absent':
          absent++;
        case 'exemption':
          exemption++;
        case 'late_admission':
          late++;
        case 'not_updated':
          notUpdated++;
      }

      final match = matcher.match(
        courseName: row.courseName,
        componentType: AttendanceCourseNormalizer.normalize(
          row.rawCourseName,
        ).componentType,
        rawCourseName: row.rawCourseName,
      );

      if (!match.isResolved) {
        unmatched++;
        unresolvedRows.add(row);
        if (match.warning != null && !warnings.contains(match.warning!)) {
          warnings.add(match.warning!);
        }
      }

      final logKey = _logDeduplicationKey(
        row: row,
        subjectCode: match.subjectCode,
        component: match.component,
      );

      if (seenInPreview.contains(logKey)) {
        duplicates++;
        continue;
      }
      seenInPreview.add(logKey);

      final existing = existingByKey[logKey];
      if (existing != null) {
        if (existing.status == row.normalizedStatus) {
          duplicates++;
        } else {
          updates++;
        }
      }

      logs.add(
        AttendanceLog(
          id: logKey,
          subjectCode: match.subjectCode,
          component: match.component,
          rawSubjectText: row.rawCourseName,
          normalizedSubject: row.courseName,
          canonicalSubjectId: match.isResolved ? match.subjectCode : null,
          date: row.date,
          startTime: row.startTimeMinutes,
          endTime: row.endTimeMinutes,
          status: row.normalizedStatus,
          source: 'pdf_import',
          confidence: match.confidence,
          importedAt: DateTime.now(),
        ),
      );
    }

    return AttendanceImportPreview(
      metadata: metadata,
      logs: logs,
      unresolvedRows: unresolvedRows,
      presentCount: present,
      absentCount: absent,
      exemptionCount: exemption,
      lateAdmissionCount: late,
      notUpdatedCount: notUpdated,
      duplicateCount: duplicates,
      updateCount: updates,
      unmatchedCourseCount: unmatched,
      warnings: warnings,
      errors: parseErrors,
      isImageOnly: isImageOnly,
      totalPagesParsed: totalPagesParsed,
    );
  }

  static String _logDeduplicationKey({
    required ParsedAttendanceRow row,
    required String subjectCode,
    required String component,
  }) {
    return AttendanceLog.buildDeduplicationKey(
      date: row.date,
      startTime: row.startTimeMinutes,
      endTime: row.endTimeMinutes,
      subjectCode: subjectCode,
      component: component,
    );
  }

  /// Extracts rows from a page using visual position and coordinate reconstruction.
  static List<ParsedAttendanceRow> _extractRowsFromPage({
    required List<TextWord> pageWords,
    required int pageIndex,
    required List<String> warnings,
  }) {
    if (pageWords.isEmpty) return [];

    // Find table header words on this page
    double? headerMaxY;
    for (final w in pageWords) {
      final t = w.text.trim().toLowerCase();
      final cy = w.bounds.center.dy;
      if (t == 'sr' ||
          t == 'no.' ||
          t == 'course' ||
          t == 'date' ||
          t == 'attenda' ||
          t == 'attendance' ||
          t == 'nce') {
        if (pageIndex == 0 && cy > 200 && cy < 340) {
          headerMaxY = headerMaxY == null
              ? w.bounds.bottom
              : math.max(headerMaxY, w.bounds.bottom);
        } else if (pageIndex > 0 && cy < 60) {
          headerMaxY = headerMaxY == null
              ? w.bounds.bottom
              : math.max(headerMaxY, w.bounds.bottom);
        }
      }
    }

    final tableTopY = headerMaxY != null
        ? headerMaxY + 2.0
        : (pageIndex == 0 ? 320.0 : 45.0);

    // Find footer boundary
    double tableBottomY = 740.0;
    for (final w in pageWords) {
      final t = w.text.trim().toLowerCase();
      final cy = w.bounds.center.dy;
      if (cy > tableTopY) {
        if (t.contains('present') ||
            t.contains('sap') ||
            t.contains('system-generated') ||
            t.contains('query') ||
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

    // Cluster words into visual rows by dy (within 6.0 pt)
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

    final rows = <ParsedAttendanceRow>[];

    // Standard column boundary thresholds:
    // Col 1 (Sr No): < 55.0
    // Col 2 (Course Name): 55.0 <= cx < 325.0
    // Col 3 (Date): 325.0 <= cx < 390.0
    // Col 4 (Start Time): 390.0 <= cx < 460.0
    // Col 5 (End Time): 460.0 <= cx < 535.0
    // Col 6 (Attendance): 535.0 <= cx
    const colSrMax = 55.0;
    const colCourseMax = 325.0;
    const colDateMax = 390.0;
    const colStartMax = 460.0;
    const colEndMax = 535.0;

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

      int? srNo = int.tryParse(srStr);
      DateTime? date = AttendanceDateTimeParser.parseDate(dateStr);
      int? startMins = AttendanceDateTimeParser.parseTimeToMinutes(startStr);
      int? endMins = AttendanceDateTimeParser.parseTimeToMinutes(endStr);
      String rawStatus = statusStr.toUpperCase();
      String? normalizedStatus = AttendanceStatusMapper.normalize(rawStatus);

      // Fallback: if coordinate division was slightly misaligned, use full reconstructed row regex
      if (srNo == null ||
          date == null ||
          startMins == null ||
          endMins == null ||
          normalizedStatus == null) {
        final fullLine = cluster.map((w) => w.text).join(' ').trim();
        final match = _rowLineRegex.firstMatch(fullLine);
        if (match != null) {
          srNo = int.tryParse(match.group(1)!);
          courseStr = match.group(2)!.trim();
          date = AttendanceDateTimeParser.parseDate(match.group(3)!);
          startMins = AttendanceDateTimeParser.parseTimeToMinutes(
            match.group(4)!,
          );
          endMins = AttendanceDateTimeParser.parseTimeToMinutes(
            match.group(5)!,
          );
          rawStatus = match.group(6)!.trim().toUpperCase();
          normalizedStatus = AttendanceStatusMapper.normalize(rawStatus);
        }
      }

      if (srNo == null ||
          date == null ||
          startMins == null ||
          endMins == null) {
        continue;
      }

      if (normalizedStatus == null) {
        warnings.add(
          'Page ${pageIndex + 1}, Sr No. $srNo: Unknown attendance status "$rawStatus".',
        );
      }

      final effectiveStatus = normalizedStatus ?? rawStatus.toLowerCase();
      final normalized = AttendanceCourseNormalizer.normalize(courseStr);

      rows.add(
        ParsedAttendanceRow(
          srNo: srNo,
          rawCourseName: courseStr,
          courseName: normalized.courseName.isNotEmpty
              ? normalized.courseName
              : courseStr,
          componentCode: normalized.componentCode,
          batchOrSection: normalized.batchOrSection,
          date: date,
          startTimeMinutes: startMins,
          endTimeMinutes: endMins,
          rawStatus: rawStatus,
          normalizedStatus: effectiveStatus,
          pageIndex: pageIndex,
        ),
      );
    }

    return rows;
  }

  static ({
    String? studentName,
    String? studentNumber,
    String? rollNo,
    String? academicYearSession,
    String? programName,
    String? durationLine,
  })
  _extractMetadata(List<TextWord> words, List<TextLine> lines) {
    String? studentName;
    String? studentNumber;
    String? rollNo;
    String? academicYearSession;
    String? programName;
    String? durationLine;

    final headerWords = words.where((w) => w.bounds.center.dy < 300).toList()
      ..sort((a, b) => a.bounds.center.dy.compareTo(b.bounds.center.dy));

    final headerRows = <List<TextWord>>[];
    for (final w in headerWords) {
      if (headerRows.isEmpty ||
          (w.bounds.center.dy - headerRows.last.first.bounds.center.dy).abs() >
              6.0) {
        headerRows.add([w]);
      } else {
        headerRows.last.add(w);
      }
    }

    for (final row in headerRows) {
      row.sort((a, b) => a.bounds.center.dx.compareTo(b.bounds.center.dx));
      final rowText = row.map((w) => w.text).join(' ').trim();
      final valueWords = row
          .where((w) => w.bounds.center.dx >= 170)
          .map((w) => w.text)
          .join(' ')
          .trim();

      if (rowText.toLowerCase().contains('student name')) {
        studentName ??= valueWords.isNotEmpty
            ? valueWords
            : _extractLabeledValue(rowText, 'Student Name');
      } else if (rowText.toLowerCase().contains('student number')) {
        studentNumber ??= valueWords.isNotEmpty
            ? valueWords
            : _extractLabeledValue(rowText, 'Student Number');
      } else if (rowText.toLowerCase().contains('roll no')) {
        rollNo ??= valueWords.isNotEmpty
            ? valueWords.replaceAll(RegExp(r'^[\s.:]+'), '').trim()
            : (_extractLabeledValue(rowText, 'Roll No.') ??
                  _extractLabeledValue(rowText, 'Roll No'));
      } else if (rowText.toLowerCase().contains('academic year')) {
        academicYearSession ??= valueWords.isNotEmpty
            ? valueWords
            : _extractLabeledValue(rowText, 'Academic Year & Academic Session');
      } else if (rowText.toLowerCase().contains('program name')) {
        programName ??= valueWords.isNotEmpty
            ? valueWords
            : _extractLabeledValue(rowText, 'Program Name');
      } else if (rowText.toLowerCase().contains('attendance report duration')) {
        durationLine ??= valueWords.isNotEmpty
            ? valueWords
            : _extractLabeledValue(rowText, 'Attendance Report Duration');
      }
    }

    // Line fallback
    for (final line in lines) {
      final text = line.text.trim();
      studentName ??= _extractLabeledValue(text, 'Student Name');
      studentNumber ??= _extractLabeledValue(text, 'Student Number');
      rollNo ??=
          _extractLabeledValue(text, 'Roll No.') ??
          _extractLabeledValue(text, 'Roll No');
      academicYearSession ??= _extractLabeledValue(
        text,
        'Academic Year & Academic Session',
      );
      programName ??= _extractLabeledValue(text, 'Program Name');
      if (durationLine == null &&
          text.toLowerCase().contains('attendance report duration')) {
        durationLine =
            _extractLabeledValue(text, 'Attendance Report Duration') ?? text;
      }
    }

    rollNo = rollNo?.replaceAll(RegExp(r'^[\s.:]+|[\s.:]+$'), '').trim();

    return (
      studentName: studentName,
      studentNumber: studentNumber,
      rollNo: rollNo,
      academicYearSession: academicYearSession,
      programName: programName,
      durationLine: durationLine,
    );
  }

  static String? _extractLabeledValue(String line, String label) {
    final lower = line.toLowerCase();
    final labelLower = label.toLowerCase();
    final idx = lower.indexOf(labelLower);
    if (idx < 0) return null;

    if (idx == 0) {
      var val = line.substring(label.length).trim();
      val = val.replaceAll(RegExp(r'^[\s.:]+'), '').trim();
      return val.isNotEmpty ? val : null;
    }

    var val = line.substring(0, idx).trim();
    val = val.replaceAll(RegExp(r'[\s.:]+$'), '').trim();
    return val.isNotEmpty ? val : null;
  }

  static ({String year, String session}) _splitYearSession(String raw) {
    final parts = raw.split(',');
    if (parts.length >= 2) {
      return (
        year: parts[0].trim(),
        session: parts.sublist(1).join(',').trim(),
      );
    }
    return (year: raw.trim(), session: '');
  }
}

/// Syncfusion helper — password check wrapper.
class PdfDocumentHelper {
  static bool checkIfPasswordProtected(PdfDocument document) {
    try {
      return document.security.userPassword.isNotEmpty ||
          document.security.ownerPassword.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
