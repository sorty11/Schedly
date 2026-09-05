import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedly/models/attendance_import_models.dart';
import 'package:schedly/models/attendance_log.dart';
import 'package:schedly/models/attendance_record.dart';
import 'package:schedly/models/course_component.dart';
import 'package:schedly/services/attendance_pdf_parser.dart';
import 'package:schedly/services/progress_calculator_service.dart';

void main() {
  group('Data Science Golden Attendance PDF Grouping & Integrity Tests', () {
    test(
      '1. Real 227-row DS PDF produces exactly 10 unique cards with DSA split and all others merged',
      () async {
        final bytes = await File(
          'test/fixtures/ZSVKM_DATA_SCIENCE_ATTENDANCE.pdf',
        ).readAsBytes();
        final parsed = AttendancePdfParser.parseBytes(bytes);

        // Verify exact raw row counts
        expect(parsed.rows.length, equals(227));
        final rawStatusCounts = <String, int>{};
        for (final r in parsed.rows) {
          rawStatusCounts[r.rawStatus] =
              (rawStatusCounts[r.rawStatus] ?? 0) + 1;
        }
        expect(rawStatusCounts['P'], equals(189));
        expect(rawStatusCounts['A'], equals(32));
        expect(
          rawStatusCounts['NU'],
          equals(6),
        ); // NU preserved, not counted as absent

        final preview = AttendancePdfParser.buildPreview(
          metadata: parsed.metadata,
          rows: parsed.rows,
          configuredCourses: [],
          existingLogs: [],
        );

        expect(preview.logs.length, equals(227));
        expect(preview.presentCount, equals(189));
        expect(preview.absentCount, equals(32));
        expect(preview.notUpdatedCount, equals(6));

        // Emulate AttendancePage grouping using AttendanceLog canonical rules
        final uniqueLogs = <String, AttendanceLog>{};
        for (final log in preview.logs) {
          if (log.subjectCode.isEmpty) continue;
          final key = log.deduplicationKey;
          final existing = uniqueLogs[key];
          if (existing == null || log.importedAt.isAfter(existing.importedAt)) {
            uniqueLogs[key] = log;
          }
        }
        final deduplicatedLogs = uniqueLogs.values.toList();
        expect(deduplicatedLogs.length, equals(227));

        final aggregatedLogs =
            <
              String,
              ({
                String subjectCode,
                String component,
                int present,
                int absent,
                int cancelled,
              })
            >{};

        for (final log in deduplicatedLogs) {
          final canonSubj = AttendanceLog.canonicalSubjectCode(log.subjectCode);
          final displayComponent = AttendanceLog.canonicalComponent(
            canonSubj,
            log.component,
          );
          final groupKey = AttendanceLog.canonicalGroupKey(
            canonSubj,
            log.component,
          );

          final cur =
              aggregatedLogs[groupKey] ??
              (
                subjectCode: canonSubj,
                component: displayComponent,
                present: 0,
                absent: 0,
                cancelled: 0,
              );

          int p = cur.present;
          int a = cur.absent;
          if (log.status == 'present') {
            p++;
          } else if (log.status == 'absent') {
            a++;
          }

          aggregatedLogs[groupKey] = (
            subjectCode: canonSubj,
            component: displayComponent,
            present: p,
            absent: a,
            cancelled: cur.cancelled,
          );
        }

        // Exactly 10 unique cards: DSA Theory, DSA Lab, and 8 other Merged courses
        expect(
          aggregatedLogs.length,
          equals(10),
          reason: 'Must produce exactly 10 unique cards',
        );

        // 1. DSA Theory (26 total, 25 Present, 1 Absent)
        expect(aggregatedLogs['DSA_Theory']!.present, equals(25));
        expect(aggregatedLogs['DSA_Theory']!.absent, equals(1));
        expect(aggregatedLogs['DSA_Theory']!.component, equals('Theory'));

        // 2. DSA Lab (14 total, 11 Present, 3 Absent)
        expect(aggregatedLogs['DSA_Lab']!.present, equals(11));
        expect(aggregatedLogs['DSA_Lab']!.absent, equals(3));
        expect(aggregatedLogs['DSA_Lab']!.component, equals('Lab'));

        // 3. Digital Circuits and Computer Architecture (Merged Theory + Lab: 40 total, 37 Present, 3 Absent)
        expect(
          aggregatedLogs['Digital Circuits and Computer Architecture_Merged']!
              .present,
          equals(37),
        );
        expect(
          aggregatedLogs['Digital Circuits and Computer Architecture_Merged']!
              .absent,
          equals(3),
        );
        expect(
          aggregatedLogs['Digital Circuits and Computer Architecture_Merged']!
              .component,
          equals('Merged'),
        );

        // 4. Software Engineering (Merged Theory + Lab: 31 total, 22 Present, 9 Absent)
        expect(
          aggregatedLogs['Software Engineering_Merged']!.present,
          equals(22),
        );
        expect(
          aggregatedLogs['Software Engineering_Merged']!.absent,
          equals(9),
        );
        expect(
          aggregatedLogs['Software Engineering_Merged']!.component,
          equals('Merged'),
        );

        // 5. Probability and Statistics (Merged Theory + Lab: 34 total, 28 Present, 6 Absent)
        expect(aggregatedLogs['PnS_Merged']!.present, equals(28));
        expect(aggregatedLogs['PnS_Merged']!.absent, equals(6));
        expect(aggregatedLogs['PnS_Merged']!.component, equals('Merged'));

        // 6. Programming with Python (Merged Theory + Lab: 24 total, 21 Present, 3 Absent)
        expect(aggregatedLogs['Python_Merged']!.present, equals(21));
        expect(aggregatedLogs['Python_Merged']!.absent, equals(3));
        expect(aggregatedLogs['Python_Merged']!.component, equals('Merged'));

        // 7. Website Designing and Development (Merged Theory + Lab: 24 total, 24 Present, 0 Absent)
        expect(
          aggregatedLogs['Website Designing and Development_Merged']!.present,
          equals(24),
        );
        expect(
          aggregatedLogs['Website Designing and Development_Merged']!.absent,
          equals(0),
        );
        expect(
          aggregatedLogs['Website Designing and Development_Merged']!.component,
          equals('Merged'),
        );

        // 8. Interpersonal Skills (Merged: 16 total, 12 Present, 4 Absent)
        expect(
          aggregatedLogs['Interpersonal Skills_Merged']!.present,
          equals(12),
        );
        expect(
          aggregatedLogs['Interpersonal Skills_Merged']!.absent,
          equals(4),
        );
        expect(
          aggregatedLogs['Interpersonal Skills_Merged']!.component,
          equals('Merged'),
        );

        // 9. Technical Communication (Merged: 7 total, 6 Present, 1 Absent)
        expect(aggregatedLogs['TC_Merged']!.present, equals(6));
        expect(aggregatedLogs['TC_Merged']!.absent, equals(1));
        expect(aggregatedLogs['TC_Merged']!.component, equals('Merged'));

        // 10. Prompt Engineering for ChatGPT (Merged: 5 total, 3 Present, 2 Absent)
        expect(
          aggregatedLogs['Prompt Engineering for ChatGPT_Merged']!.present,
          equals(3),
        );
        expect(
          aggregatedLogs['Prompt Engineering for ChatGPT_Merged']!.absent,
          equals(2),
        );
        expect(
          aggregatedLogs['Prompt Engineering for ChatGPT_Merged']!.component,
          equals('Merged'),
        );

        final totalConducted = aggregatedLogs.values.fold<int>(
          0,
          (sum, c) => sum + c.present + c.absent,
        );
        expect(totalConducted, equals(221));
      },
    );

    test(
      '2. Interpersonal Skills overlapping records (14 vs 16) deduplicate to exactly ONE card with 16',
      () {
        final oldRecord = AttendanceRecord(
          id: 'DS_Interpersonal Skills_Merged',
          division: 'DS',
          subjectCode: 'Interpersonal Skills',
          component: 'Merged',
          present: 10,
          absent: 4, // total 14
          updatedAt: DateTime(2026, 8, 1),
        );

        final newRecord = AttendanceRecord(
          id: 'DS_Interpersonal Skills_Lab',
          division: 'DS',
          subjectCode: 'Interpersonal Skills',
          component: 'Lab',
          present: 12,
          absent: 4, // total 16
          updatedAt: DateTime(2026, 8, 20),
        );

        final rawRecords = [oldRecord, newRecord];

        // Emulate AttendancePage fallback aggregation when no logs exist
        final recordsByGroup = <String, List<AttendanceRecord>>{};
        for (final r in rawRecords) {
          final canonSubj = AttendanceLog.canonicalSubjectCode(r.subjectCode);
          final groupKey = AttendanceLog.canonicalGroupKey(
            canonSubj,
            r.component,
          );
          recordsByGroup.putIfAbsent(groupKey, () => []).add(r);
        }

        final records = <String, AttendanceRecord>{};
        for (final entry in recordsByGroup.entries) {
          final groupKey = entry.key;
          final recList = entry.value;
          final first = recList.first;
          final canonSubj = AttendanceLog.canonicalSubjectCode(
            first.subjectCode,
          );
          final displayComponent = AttendanceLog.canonicalComponent(
            canonSubj,
            first.component,
          );

          final distinctComponents = recList
              .map((r) => AttendanceLog.normalizeComponent(r.component))
              .toSet();
          final hasMerged =
              distinctComponents.contains('Merged') ||
              recList.any((r) => r.component == 'Merged');

          int totalPresent = 0;
          int totalAbsent = 0;

          if (hasMerged || distinctComponents.length == 1) {
            // Overlapping snapshots: pick the most complete/latest snapshot
            recList.sort((a, b) {
              final cmp = b.total.compareTo(a.total);
              if (cmp != 0) return cmp;
              return b.updatedAt.compareTo(a.updatedAt);
            });
            final best = recList.first;
            totalPresent = best.present;
            totalAbsent = best.absent;
          } else {
            for (final r in recList) {
              totalPresent += r.present;
              totalAbsent += r.absent;
            }
          }

          records[groupKey] = AttendanceRecord(
            id: '${first.division}_${canonSubj}_$displayComponent',
            division: first.division,
            subjectCode: canonSubj,
            component: displayComponent,
            present: totalPresent,
            absent: totalAbsent,
          );
        }

        // Assert exactly ONE card generated with 16 total (12 Present, 4 Absent), NEVER 30 total
        expect(records.length, equals(1));
        expect(records.containsKey('Interpersonal Skills_Merged'), isTrue);
        final card = records['Interpersonal Skills_Merged']!;
        expect(card.total, equals(16));
        expect(card.present, equals(12));
        expect(card.absent, equals(4));
        expect(card.component, equals('Merged'));
      },
    );

    test(
      '3. Multi-section course hours: Section A vs Section B isolation and skip calculation',
      () {
        // Section A: Data Science (Digital Circuits, Interpersonal Skills, DSA Theory & Lab)
        final sectionACourses = [
          CourseComponent(
            componentId: 'DCCA_T',
            courseCode: 'DCCA',
            courseName: 'Digital Circuits and Computer Architecture',
            componentType: 'Theory',
            targetHours: 60,
            createdAt: DateTime.now(),
            sectionId: 'DS_A',
          ),
          CourseComponent(
            componentId: 'IPS_P',
            courseCode: 'IPS',
            courseName: 'Interpersonal Skills',
            componentType: 'Lab',
            targetHours: 30,
            createdAt: DateTime.now(),
            sectionId: 'DS_A',
          ),
          CourseComponent(
            componentId: 'DSA_T',
            courseCode: 'DSA',
            courseName: 'DATA STRUCTURES AND ALGORITHMS',
            componentType: 'Theory',
            targetHours: 45,
            createdAt: DateTime.now(),
            sectionId: 'DS_A',
          ),
          CourseComponent(
            componentId: 'DSA_P',
            courseCode: 'DSA',
            courseName: 'DATA STRUCTURES AND ALGORITHMS',
            componentType: 'Lab',
            targetHours: 30,
            createdAt: DateTime.now(),
            sectionId: 'DS_A',
          ),
        ];

        // Section B: AI & ML (Advanced Machine Learning, Cloud Computing, DSA combined)
        final sectionBCourses = [
          CourseComponent(
            componentId: 'AML_T',
            courseCode: 'AML',
            courseName: 'Advanced Machine Learning',
            componentType: 'Theory',
            targetHours: 50,
            createdAt: DateTime.now(),
            sectionId: 'AIML_B',
          ),
          CourseComponent(
            componentId: 'CC_T',
            courseCode: 'CC',
            courseName: 'Cloud Computing',
            componentType: 'Theory',
            targetHours: 40,
            createdAt: DateTime.now(),
            sectionId: 'AIML_B',
          ),
          CourseComponent(
            componentId: 'DSA_Combined',
            courseCode: 'DSA',
            courseName: 'DATA STRUCTURES AND ALGORITHMS',
            componentType: 'Theory',
            targetHours: 75,
            createdAt: DateTime.now(),
            sectionId: 'AIML_B',
          ),
        ];

        final calcA = ProgressCalculatorService(
          weeklyTimetable: {},
          courseComponents: sectionACourses,
          subjectMetadata: {},
          semesterStartDate: DateTime(2026, 7, 1),
        );

        final calcB = ProgressCalculatorService(
          weeklyTimetable: {},
          courseComponents: sectionBCourses,
          subjectMetadata: {},
          semesterStartDate: DateTime(2026, 7, 1),
        );

        // Section A: Verify configured targetHours
        expect(
          calcA.getFixedTotalCourseHours(
            'Digital Circuits and Computer Architecture',
            'Merged',
          ),
          equals(60),
        );
        expect(
          calcA.getFixedTotalCourseHours('Interpersonal Skills', 'Merged'),
          equals(30),
        );
        expect(calcA.getFixedTotalCourseHours('DSA', 'Theory'), equals(45));
        expect(calcA.getFixedTotalCourseHours('DSA', 'Lab'), equals(30));

        // Section A: Skip calculation (80% rule)
        // DCCA: 60 * 0.20 = 12 allowed absent. If absent = 3 -> 12 - 3 = 9 skips left.
        expect(
          calcA.getRemainingSkips(
            'Digital Circuits and Computer Architecture',
            'Merged',
            3,
          ),
          equals(9),
        );
        // DSA Theory: 45 * 0.20 = 9 allowed absent. If absent = 1 -> 9 - 1 = 8 skips left.
        expect(calcA.getRemainingSkips('DSA', 'Theory', 1), equals(8));
        // DSA Lab: 30 * 0.20 = 6 allowed absent. If absent = 3 -> 6 - 3 = 3 skips left.
        expect(calcA.getRemainingSkips('DSA', 'Lab', 3), equals(3));

        // Section B: Verify configured targetHours
        expect(
          calcB.getFixedTotalCourseHours('Advanced Machine Learning', 'Merged'),
          equals(50),
        );
        expect(
          calcB.getFixedTotalCourseHours('Cloud Computing', 'Merged'),
          equals(40),
        );
        expect(calcB.getFixedTotalCourseHours('DSA', 'Theory'), equals(75));

        // Section B: Skip calculation (80% rule)
        // AML: 50 * 0.20 = 10 allowed absent. If absent = 2 -> 10 - 2 = 8 skips left.
        expect(
          calcB.getRemainingSkips('Advanced Machine Learning', 'Merged', 2),
          equals(8),
        );
        // Cloud Computing: 40 * 0.20 = 8 allowed absent. If absent = 5 -> 8 - 5 = 3 skips left.
        expect(
          calcB.getRemainingSkips('Cloud Computing', 'Merged', 5),
          equals(3),
        );

        // Section isolation: Section B courses should NOT be found in Section A
        expect(
          calcA.getFixedTotalCourseHours('Advanced Machine Learning', 'Merged'),
          equals(0),
        );
        // Section A courses should NOT be found in Section B
        expect(
          calcB.getFixedTotalCourseHours(
            'Digital Circuits and Computer Architecture',
            'Merged',
          ),
          equals(0),
        );
      },
    );
  });
}
