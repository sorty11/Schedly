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
import 'attendance/academic_grouping_policy.dart';
import 'attendance/attendance_document_profile.dart';
import 'attendance/attendance_reconciliation_report.dart';
import 'attendance/attendance_row_validator.dart';
import 'attendance/extraction_strategy.dart';
import 'attendance/progressive_attendance_reconciler.dart';
import 'attendance/raw_attendance_row.dart';

/// Extracts and parses NMIMS/SVKM student attendance PDF reports.
class AttendancePdfParser {
  /// Parses PDF bytes into rows + metadata. Pure — no Firestore side effects.
  static ({
    AttendanceReportMetadata metadata,
    List<ParsedAttendanceRow> rows,
    List<String> warnings,
    List<String> errors,
    bool isImageOnly,
    AttendanceReconciliationReport? reconciliationReport,
    AttendanceDocumentProfile? profile,
  })
  parseBytes(
    Uint8List bytes, {
    AttendanceParseProgress? onProgress,
    AttendanceDocumentProfile? explicitProfile,
  }) {
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
      final allRawRows = <RawAttendanceRow>[];
      final warnings = <String>[];
      final errors = <String>[];
      var totalTextLength = 0;

      String? studentName;
      String? studentNumber;
      String? rollNo;
      String? academicYearSession;
      String? programName;
      String? durationLine;

      // Sample first 2 pages to detect profile
      final sampleLines = <String>[];
      final detectedHeaderTokens = <String>{};
      for (var page = 0; page < math.min(pageCount, 2); page++) {
        final lines = extractor.extractTextLines(
          startPageIndex: page,
          endPageIndex: page,
        );
        for (final line in lines) {
          final t = line.text.trim();
          if (t.isNotEmpty) sampleLines.add(t);
          for (final w in line.wordCollection) {
            final wt = w.text.trim();
            if (wt.isNotEmpty) detectedHeaderTokens.add(wt);
          }
        }
      }

      final profile = explicitProfile ??
          AttendanceDocumentDetector.detectProfile(
            sampleLines: sampleLines,
            detectedHeaderTokens: detectedHeaderTokens,
          );

      for (var page = 0; page < pageCount; page++) {
        onProgress?.call(
          currentPage: page + 1,
          totalPages: pageCount,
          rowsDetected: allRawRows.length,
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

        // 2. Extraction via Strategy Chain
        final pageRows = ExtractionStrategyChain.execute(
          pageLines: pageLines,
          pageWords: pageWords,
          pageIndex: page,
          profile: profile,
        );

        allRawRows.addAll(pageRows);
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
          reconciliationReport: null,
          profile: profile,
        );
      }

      // 3. Validation & Stage 1 Reconciliation
      final validation = AttendanceRowValidator.validateAll(allRawRows, profile);

      final allRows = <ParsedAttendanceRow>[];
      for (final val in validation.confirmed) {
        final normalized = AttendanceCourseNormalizer.normalize(
          val.rawRow.rawCourseName,
        );
        allRows.add(
          ParsedAttendanceRow(
            srNo: val.rawRow.sourceRowNumber,
            rawCourseName: val.rawRow.rawCourseName,
            courseName: normalized.courseName.isNotEmpty
                ? normalized.courseName
                : val.rawRow.rawCourseName,
            componentCode: normalized.componentCode,
            batchOrSection: normalized.batchOrSection,
            date: val.date!,
            startTimeMinutes: val.startTimeMinutes,
            endTimeMinutes: val.endTimeMinutes,
            rawStatus: val.rawRow.rawStatus.toUpperCase(),
            normalizedStatus: val.normalizedStatus!,
            pageIndex: val.rawRow.pageNumber - 1,
            rawRow: val.rawRow,
          ),
        );
      }

      for (final val in validation.reviewRequired) {
        if (val.diagnostic != null) {
          warnings.add(
            'Page ${val.rawRow.pageNumber}, Row ${val.rawRow.sourceRowNumber}: ${val.diagnostic!.failureDescription}',
          );
        }
        if (val.date != null) {
          final effectiveStatus =
              val.normalizedStatus ?? val.rawRow.rawStatus.toLowerCase();
          final normalized = AttendanceCourseNormalizer.normalize(
            val.rawRow.rawCourseName,
          );
          allRows.add(
            ParsedAttendanceRow(
              srNo: val.rawRow.sourceRowNumber,
              rawCourseName: val.rawRow.rawCourseName,
              courseName: normalized.courseName.isNotEmpty
                  ? normalized.courseName
                  : val.rawRow.rawCourseName,
              componentCode: normalized.componentCode,
              batchOrSection: normalized.batchOrSection,
              date: val.date!,
              startTimeMinutes: val.startTimeMinutes,
              endTimeMinutes: val.endTimeMinutes,
              rawStatus: val.rawRow.rawStatus.toUpperCase(),
              normalizedStatus: effectiveStatus,
              pageIndex: val.rawRow.pageNumber - 1,
              rawRow: val.rawRow,
            ),
          );
        }
      }

      for (final val in validation.rejected) {
        if (val.diagnostic != null) {
          warnings.add(
            'Page ${val.rawRow.pageNumber}, Row ${val.rawRow.sourceRowNumber} REJECTED: ${val.diagnostic!.failureDescription}',
          );
        }
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
        reconciliationReport: validation.report,
        profile: profile,
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
    AttendanceReconciliationReport? reconciliationReport,
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

    final newCount = (logs.length - duplicates - updates).clamp(0, logs.length);
    final finalReport = reconciliationReport?.copyWithStorage(
      newRecords: newCount,
      updatedRecords: updates,
      duplicatesIgnored: duplicates,
      conflicts: 0,
    );

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
      reconciliationReport: finalReport,
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
