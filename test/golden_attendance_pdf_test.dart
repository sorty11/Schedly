import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:schedly/models/attendance_import_models.dart';
import 'package:schedly/models/attendance_log.dart';
import 'package:schedly/models/course_component.dart';
import 'package:schedly/services/attendance_course_matcher.dart';
import 'package:schedly/services/attendance_course_normalizer.dart';
import 'package:schedly/services/attendance_date_time_parser.dart';
import 'package:schedly/services/attendance_pdf_parser.dart';
import 'package:schedly/services/attendance_status_mapper.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  group('Date and Time Parsing Tests', () {
    test('parses date strings without timezone shifts', () {
      final d1 = AttendanceDateTimeParser.parseDate('Jul 13, 2026');
      expect(d1, isNotNull);
      expect(d1!.year, 2026);
      expect(d1.month, 7);
      expect(d1.day, 13);

      final d2 = AttendanceDateTimeParser.parseDate('Aug 30, 2026');
      expect(d2, isNotNull);
      expect(d2!.year, 2026);
      expect(d2.month, 8);
      expect(d2.day, 30);
    });

    test('parses time strings to minutes', () {
      expect(
        AttendanceDateTimeParser.parseTimeToMinutes('9:15:00 AM'),
        9 * 60 + 15,
      );
      expect(
        AttendanceDateTimeParser.parseTimeToMinutes('10:14:59 AM'),
        10 * 60 + 14,
      );
      expect(
        AttendanceDateTimeParser.parseTimeToMinutes('12:14:59 PM'),
        12 * 60 + 14,
      );
      expect(
        AttendanceDateTimeParser.parseTimeToMinutes('1:00:00 PM'),
        13 * 60,
      );
      expect(
        AttendanceDateTimeParser.parseTimeToMinutes('2:59:59 PM'),
        14 * 60 + 59,
      );
      expect(
        AttendanceDateTimeParser.parseTimeToMinutes('5:59:59 PM'),
        17 * 60 + 59,
      );
    });

    test('parses report durations with varied date formats', () {
      final r1 = AttendanceDateTimeParser.parseReportDuration(
        'Attendance Report Duration : From 13.07.2026 to 05.08.2026',
      );
      expect(r1.start, equals(DateTime(2026, 7, 13)));
      expect(r1.end, equals(DateTime(2026, 8, 5)));

      final r2 = AttendanceDateTimeParser.parseReportDuration(
        'From 14.07.2025 to 05.08.2026',
      );
      expect(r2.start, equals(DateTime(2025, 7, 14)));
      expect(r2.end, equals(DateTime(2026, 8, 5)));

      final r3 = AttendanceDateTimeParser.parseReportDuration(
        'From 13.07.2026 to 30.08.2026',
      );
      expect(r3.start, equals(DateTime(2026, 7, 13)));
      expect(r3.end, equals(DateTime(2026, 8, 30)));
    });
  });

  group('Course Normalization Tests', () {
    test('normalizes complex concatenated course strings', () {
      final c1 = AttendanceCourseNormalizer.normalize(
        'Discrete MathematicsT4 CE Sem III',
      );
      expect(c1.courseName, 'Discrete Mathematics');
      expect(c1.componentCode, 'T4');
      expect(c1.componentType, 'Theory');

      final c2 = AttendanceCourseNormalizer.normalize(
        'Signals and SystemsP4 CE Sem III C2',
      );
      expect(c2.courseName, 'Signals and Systems');
      expect(c2.componentCode, 'P4');
      expect(c2.componentType, 'Lab');
      expect(c2.batchOrSection, 'C2');

      final c3 = AttendanceCourseNormalizer.normalize(
        'DATA STRUCTURES AND ALGORITHMST4 CE III',
      );
      expect(c3.courseName, 'DATA STRUCTURES AND ALGORITHMS');
      expect(c3.componentCode, 'T4');
      expect(c3.componentType, 'Theory');

      final c4 = AttendanceCourseNormalizer.normalize(
        'DATA STRUCTURES AND ALGORITHMS LABP4 C2',
      );
      expect(c4.courseName, 'DATA STRUCTURES AND ALGORITHMS');
      expect(c4.componentCode, 'P4');
      expect(c4.componentType, 'Lab');
      expect(c4.batchOrSection, 'C2');

      final c5 = AttendanceCourseNormalizer.normalize(
        'PROGRAMMING WITH PYTHONP4 CE Sem III C2',
      );
      expect(c5.courseName, 'PROGRAMMING WITH PYTHON');
      expect(c5.componentCode, 'P4');
      expect(c5.componentType, 'Lab');

      final c6 = AttendanceCourseNormalizer.normalize(
        'Computer Organization and Architectur T4',
      );
      expect(c6.courseName, 'Computer Organization and Architectur');
      expect(c6.componentCode, 'T4');
      expect(c6.componentType, 'Theory');

      final c7 = AttendanceCourseNormalizer.normalize(
        'Principles of Economics and Managemen T4',
      );
      expect(c7.courseName, 'Principles of Economics and Managemen');
      expect(c7.componentCode, 'T4');
      expect(c7.componentType, 'Theory');

      final c8 = AttendanceCourseNormalizer.normalize(
        'Prompt Engineering for ChatGPTT4 CE-III',
      );
      expect(c8.courseName, 'Prompt Engineering for ChatGPT');
      expect(c8.componentCode, 'T4');
      expect(c8.componentType, 'Theory');

      final c9 = AttendanceCourseNormalizer.normalize(
        'Discrete MathematicsU4 CE Sem III C2',
      );
      expect(c9.courseName, 'Discrete Mathematics');
      expect(c9.componentCode, 'U4');
      expect(c9.componentType, 'Tutorial');
      expect(c9.batchOrSection, 'C2');
    });
  });

  group('Status Mapping Tests', () {
    test('maps official NMIMS statuses accurately without loss', () {
      expect(AttendanceStatusMapper.normalize('P'), 'present');
      expect(AttendanceStatusMapper.normalize('A'), 'absent');
      expect(AttendanceStatusMapper.normalize('E'), 'exemption');
      expect(AttendanceStatusMapper.normalize('L'), 'late_admission');
      expect(AttendanceStatusMapper.normalize('NU'), 'not_updated');

      expect(AttendanceStatusMapper.countsTowardPercentage('present'), isTrue);
      expect(AttendanceStatusMapper.countsTowardPercentage('absent'), isTrue);
      expect(
        AttendanceStatusMapper.countsTowardPercentage('not_updated'),
        isFalse,
      );
      expect(
        AttendanceStatusMapper.countsTowardPercentage('exemption'),
        isFalse,
      );
      expect(
        AttendanceStatusMapper.countsTowardPercentage('late_admission'),
        isFalse,
      );
    });
  });

  group('Golden Fixtures Parsing Tests', () {
    test('Golden PDF 1: ZSVKM_STUDENT_ATTENDANCE_COPY (1).pdf', () async {
      final file = File('test/fixtures/ZSVKM_STUDENT_ATTENDANCE_COPY (1).pdf');
      final bytes = await file.readAsBytes();

      int progressCalls = 0;
      final parsed = AttendancePdfParser.parseBytes(
        bytes,
        onProgress:
            ({
              required currentPage,
              required totalPages,
              required rowsDetected,
              required message,
            }) {
              progressCalls++;
            },
      );

      expect(progressCalls, equals(6));
      expect(parsed.metadata.pageCount, equals(6));
      expect(parsed.metadata.studentName, equals('AYAAN PATEL'));
      expect(parsed.metadata.studentNumber, equals('70022500789'));
      expect(parsed.metadata.rollNo, equals('D789'));
      expect(parsed.metadata.academicYear, equals('2026-2027'));
      expect(parsed.metadata.academicSession, equals('Semester III'));
      expect(
        parsed.metadata.programName,
        equals('B Tech (Computer Engineering)'),
      );
      expect(parsed.metadata.reportStartDate, equals(DateTime(2026, 7, 13)));
      expect(parsed.metadata.reportEndDate, equals(DateTime(2026, 8, 5)));

      expect(parsed.rows.length, equals(94));
      expect(parsed.errors, isEmpty);

      // Verify status counts: 80 P, 9 A, 5 NU
      final pCount = parsed.rows
          .where((r) => r.normalizedStatus == 'present')
          .length;
      final aCount = parsed.rows
          .where((r) => r.normalizedStatus == 'absent')
          .length;
      final nuCount = parsed.rows
          .where((r) => r.normalizedStatus == 'not_updated')
          .length;

      expect(pCount, equals(80));
      expect(aCount, equals(9));
      expect(nuCount, equals(5));

      // Check first row
      expect(parsed.rows.first.srNo, equals(1));
      expect(parsed.rows.first.courseName, equals('Discrete Mathematics'));
      expect(parsed.rows.first.date, equals(DateTime(2026, 7, 13)));
      expect(parsed.rows.first.normalizedStatus, equals('present'));

      // Check row 26 is absent
      final row26 = parsed.rows.firstWhere((r) => r.srNo == 26);
      expect(row26.normalizedStatus, equals('absent'));

      // Check rows 90-94 are NU
      for (int sr = 90; sr <= 94; sr++) {
        final row = parsed.rows.firstWhere((r) => r.srNo == sr);
        expect(row.normalizedStatus, equals('not_updated'));
      }
    });

    test('Golden PDF 2: ZSVKM_STUDENT_ATTENDANCE_COPY.pdf', () async {
      final file = File('test/fixtures/ZSVKM_STUDENT_ATTENDANCE_COPY.pdf');
      final bytes = await file.readAsBytes();

      final parsed = AttendancePdfParser.parseBytes(bytes);

      expect(parsed.metadata.pageCount, equals(6));
      expect(parsed.metadata.studentName, equals('AYAAN PATEL'));
      expect(parsed.metadata.reportStartDate, equals(DateTime(2025, 7, 14)));
      expect(parsed.metadata.reportEndDate, equals(DateTime(2026, 8, 5)));

      expect(parsed.rows.length, equals(94));
      expect(parsed.errors, isEmpty);

      final pCount = parsed.rows
          .where((r) => r.normalizedStatus == 'present')
          .length;
      final aCount = parsed.rows
          .where((r) => r.normalizedStatus == 'absent')
          .length;
      final nuCount = parsed.rows
          .where((r) => r.normalizedStatus == 'not_updated')
          .length;

      expect(pCount, equals(74));
      expect(aCount, equals(9));
      expect(nuCount, equals(11));

      // Rows 84 to 94 are all NU in PDF 2
      for (int sr = 84; sr <= 94; sr++) {
        final row = parsed.rows.firstWhere((r) => r.srNo == sr);
        expect(row.normalizedStatus, equals('not_updated'));
      }
    });

    test('Golden PDF 3: ZSVKM_STUDENT_ATTENDANCE_COPY2.pdf', () async {
      final file = File('test/fixtures/ZSVKM_STUDENT_ATTENDANCE_COPY2.pdf');
      final bytes = await file.readAsBytes();

      final parsed = AttendancePdfParser.parseBytes(bytes);

      expect(parsed.metadata.pageCount, equals(9));
      expect(parsed.metadata.studentName, equals('AYAAN PATEL'));
      expect(parsed.metadata.reportStartDate, equals(DateTime(2026, 7, 13)));
      expect(parsed.metadata.reportEndDate, equals(DateTime(2026, 8, 30)));

      expect(parsed.rows.length, equals(180));
      expect(parsed.errors, isEmpty);

      final pCount = parsed.rows
          .where((r) => r.normalizedStatus == 'present')
          .length;
      final aCount = parsed.rows
          .where((r) => r.normalizedStatus == 'absent')
          .length;
      final nuCount = parsed.rows
          .where((r) => r.normalizedStatus == 'not_updated')
          .length;

      expect(pCount, equals(158));
      expect(aCount, equals(22));
      expect(nuCount, equals(0));

      // Check last row (row 180)
      final row180 = parsed.rows.last;
      expect(row180.srNo, equals(180));
      expect(row180.courseName, equals('Technical Communication'));
      expect(row180.date, equals(DateTime(2026, 8, 28)));
      expect(row180.normalizedStatus, equals('present'));

      // Check Prompt Engineering for ChatGPT
      final peRow = parsed.rows.firstWhere((r) => r.srNo == 142);
      expect(peRow.courseName, equals('Prompt Engineering for ChatGPT'));
      expect(peRow.normalizedStatus, equals('present'));
    });

    test(
      'Golden Real Asset: ZSVKM_STUDENT_ATTENDANCE (14).pdf (19 pages, 407 rows)',
      () async {
        final file = File('assets/ZSVKM_STUDENT_ATTENDANCE (14).pdf');
        final bytes = await file.readAsBytes();

        final parsed = AttendancePdfParser.parseBytes(bytes);

        expect(parsed.metadata.pageCount, equals(19));
        expect(parsed.metadata.studentName, equals('AYAAN PATEL'));
        expect(parsed.metadata.studentNumber, equals('70022500789'));
        expect(parsed.metadata.rollNo, equals('D789'));
        expect(parsed.metadata.reportStartDate, equals(DateTime(2026, 1, 2)));
        expect(parsed.metadata.reportEndDate, equals(DateTime(2026, 4, 22)));

        expect(parsed.rows.length, equals(407));
        expect(parsed.errors, isEmpty);

        final pCount = parsed.rows
            .where((r) => r.normalizedStatus == 'present')
            .length;
        final aCount = parsed.rows
            .where((r) => r.normalizedStatus == 'absent')
            .length;
        final nuCount = parsed.rows
            .where((r) => r.normalizedStatus == 'not_updated')
            .length;

        expect(pCount, equals(327));
        expect(aCount, equals(68));
        expect(nuCount, equals(12));
        expect(pCount + aCount + nuCount, equals(407));
      },
    );
  });

  group('Progressive Report Merging Tests', () {
    test(
      'Report B (PDF 2) -> Report A (PDF 1) -> Report C (PDF 3) progressive merge',
      () async {
        CourseComponent makeComp(String name, String type, String id) =>
            CourseComponent(
              componentId: id,
              componentType: type,
              courseName: name,
              targetHours: 45,
              createdAt: DateTime.now(),
              sectionId: 'CE',
            );

        final configuredCourses = [
          makeComp('Discrete Mathematics', 'Theory', 'DM'),
          makeComp('Signals and Systems', 'Theory', 'SnS'),
          makeComp('Signals and Systems', 'Lab', 'SnS_Lab'),
          makeComp('Principles of Economics and Managemen', 'Theory', 'PEM'),
          makeComp('Computer Organization and Architectur', 'Theory', 'COA'),
          makeComp('DATA STRUCTURES AND ALGORITHMS', 'Theory', 'DSA'),
          makeComp('DATA STRUCTURES AND ALGORITHMS LAB', 'Lab', 'DSA_Lab'),
          makeComp('PROGRAMMING WITH PYTHON', 'Theory', 'Python_Theory'),
          makeComp('PROGRAMMING WITH PYTHON', 'Lab', 'Python_Lab'),
          makeComp('Probability and Statistics', 'Theory', 'PnS'),
          makeComp('Probability and Statistics', 'Lab', 'PnS_Lab'),
          makeComp('Discrete Mathematics', 'Tutorial', 'DM_Tut'),
          makeComp('Technical Communication', 'Tutorial', 'TC_Tut'),
          makeComp('Prompt Engineering for ChatGPT', 'Theory', 'PE'),
        ];

        // 1. First Import: PDF 2 (Initial report with 11 Not Updated rows)
        final pdf2Bytes = await File(
          'test/fixtures/ZSVKM_STUDENT_ATTENDANCE_COPY.pdf',
        ).readAsBytes();
        final parsed2 = AttendancePdfParser.parseBytes(pdf2Bytes);

        final preview1 = AttendancePdfParser.buildPreview(
          metadata: parsed2.metadata,
          rows: parsed2.rows,
          configuredCourses: configuredCourses,
          existingLogs: [],
        );

        expect(preview1.logs.length, equals(94));
        expect(preview1.duplicateCount, equals(0));
        expect(preview1.updateCount, equals(0));
        expect(preview1.newCount, equals(94));
        expect(preview1.notUpdatedCount, equals(11));
        expect(preview1.presentCount, equals(74));

        // Simulate saving preview1 to "database"
        final storedLogs = <String, AttendanceLog>{
          for (final l in preview1.logs) l.deduplicationKey: l,
        };

        // 2. Second Import: PDF 1 (Rows 84-89 updated from NU -> P)
        final pdf1Bytes = await File(
          'test/fixtures/ZSVKM_STUDENT_ATTENDANCE_COPY (1).pdf',
        ).readAsBytes();
        final parsed1 = AttendancePdfParser.parseBytes(pdf1Bytes);

        final preview2 = AttendancePdfParser.buildPreview(
          metadata: parsed1.metadata,
          rows: parsed1.rows,
          configuredCourses: configuredCourses,
          existingLogs: storedLogs.values.toList(),
        );

        expect(preview2.logs.length, equals(94));
        expect(
          preview2.updateCount,
          equals(6),
        ); // 6 rows (84-89) updated from NU to P
        expect(preview2.duplicateCount, equals(88)); // 88 rows identical
        expect(preview2.newCount, equals(0)); // 0 new rows

        // Apply updates to stored logs
        for (final log in preview2.logs) {
          storedLogs[log.deduplicationKey] = log;
        }

        // 3. Third Import: PDF 3 (Extended to Aug 30, rows 90-94 updated to P, 86 new rows added)
        final pdf3Bytes = await File(
          'test/fixtures/ZSVKM_STUDENT_ATTENDANCE_COPY2.pdf',
        ).readAsBytes();
        final parsed3 = AttendancePdfParser.parseBytes(pdf3Bytes);

        final preview3 = AttendancePdfParser.buildPreview(
          metadata: parsed3.metadata,
          rows: parsed3.rows,
          configuredCourses: configuredCourses,
          existingLogs: storedLogs.values.toList(),
        );

        expect(preview3.logs.length, equals(180));
        expect(
          preview3.updateCount,
          equals(5),
        ); // 5 rows (90-94) updated from NU to P
        expect(preview3.duplicateCount, equals(89)); // 89 rows identical
        expect(preview3.newCount, equals(86)); // 86 new rows appended
        expect(preview3.notUpdatedCount, equals(0)); // All NU resolved

        // Final count in database: 180 distinct records
        for (final log in preview3.logs) {
          storedLogs[log.deduplicationKey] = log;
        }
        expect(storedLogs.length, equals(180));
      },
    );
  });

  group('Error Handling Tests', () {
    test('throws on corrupted PDF bytes', () {
      expect(
        () =>
            AttendancePdfParser.parseBytes(Uint8List.fromList([1, 2, 3, 4, 5])),
        throwsA(isA<AttendancePdfParseException>()),
      );
    });

    test('flags image-only PDF gracefully', () {
      final doc = PdfDocument();
      doc.pages.add(); // empty blank page
      final bytes = Uint8List.fromList(doc.saveSync());
      doc.dispose();

      final result = AttendancePdfParser.parseBytes(bytes);
      expect(result.isImageOnly, isTrue);
      expect(result.errors, isNotEmpty);
      expect(result.rows, isEmpty);
    });
  });
}
