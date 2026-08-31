import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:schedly/models/attendance_import_models.dart';
import 'package:schedly/models/attendance_log.dart';
import 'package:schedly/models/attendance_record.dart';
import 'package:schedly/models/course_component.dart';
import 'package:schedly/services/attendance_course_matcher.dart';
import 'package:schedly/services/attendance_course_normalizer.dart';
import 'package:schedly/services/attendance_pdf_parser.dart';

void main() {
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
    makeComp('Discrete Mathematics', 'Tutorial', 'DM_Tut'),
    makeComp('Signals and Systems', 'Theory', 'SnS'),
    makeComp('Signals and Systems', 'Lab', 'SnS_Lab'),
    makeComp('Principles of Economics and Managemen', 'Theory', 'PEM'),
    makeComp('Computer Organization and Architectur', 'Theory', 'COA'),
    makeComp('DATA STRUCTURES AND ALGORITHMS', 'Theory', 'DSA'),
    makeComp('DATA STRUCTURES AND ALGORITHMS', 'Lab', 'DSA_Lab'),
    makeComp('PROGRAMMING WITH PYTHON', 'Theory', 'Python'),
    makeComp('PROGRAMMING WITH PYTHON', 'Lab', 'Python_Lab'),
    makeComp('Probability and Statistics', 'Theory', 'PnS'),
    makeComp('Probability and Statistics', 'Lab', 'PnS_Lab'),
    makeComp('Technical Communication', 'Tutorial', 'TC'),
    makeComp('Prompt Engineering for ChatGPT', 'Theory', 'PE'),
  ];

  group('Component Attendance Grouping & Independence Tests', () {
    // 1. DSA Theory and DSA Lab create separate attendance groups.
    test('1. DSA Theory and DSA Lab create separate attendance groups', () {
      final normTheory = AttendanceCourseNormalizer.normalize(
        'DATA STRUCTURES AND ALGORITHMST4 CE III',
      );
      final normLab = AttendanceCourseNormalizer.normalize(
        'DATA STRUCTURES AND ALGORITHMS LABP4 C2',
      );

      expect(normTheory.courseName, equals('DATA STRUCTURES AND ALGORITHMS'));
      expect(normTheory.componentType, equals('Theory'));

      expect(normLab.courseName, equals('DATA STRUCTURES AND ALGORITHMS'));
      expect(normLab.componentType, equals('Lab'));

      final matcher = AttendanceCourseMatcher(configuredCourses);
      final matchTheory = matcher.match(
        courseName: normTheory.courseName,
        componentType: normTheory.componentType,
        rawCourseName: 'DATA STRUCTURES AND ALGORITHMST4 CE III',
      );
      final matchLab = matcher.match(
        courseName: normLab.courseName,
        componentType: normLab.componentType,
        rawCourseName: 'DATA STRUCTURES AND ALGORITHMS LABP4 C2',
      );

      final theoryGroupKey =
          '${matchTheory.subjectCode}_${matchTheory.component}';
      final labGroupKey = '${matchLab.subjectCode}_${matchLab.component}';

      expect(theoryGroupKey, isNot(equals(labGroupKey)));
      expect(theoryGroupKey, equals('DSA_Theory'));
      expect(labGroupKey, equals('DSA_Lab'));
    });

    // 2. Signals and Systems Theory and Lab aggregate into ONE SnS Merged group.
    test(
      '2. Signals and Systems components aggregate into ONE SnS Merged group',
      () {
        final normTheory = AttendanceCourseNormalizer.normalize(
          'Signals and SystemsT4 CE Sem III',
        );
        final normLab = AttendanceCourseNormalizer.normalize(
          'Signals and SystemsP4 CE Sem III C2',
        );

        final matcher = AttendanceCourseMatcher(configuredCourses);
        final m1 = matcher.match(
          courseName: normTheory.courseName,
          componentType: normTheory.componentType,
          rawCourseName: 'Signals and SystemsT4 CE Sem III',
        );
        final m2 = matcher.match(
          courseName: normLab.courseName,
          componentType: normLab.componentType,
          rawCourseName: 'Signals and SystemsP4 CE Sem III C2',
        );

        expect(m1.subjectCode, equals('SnS'));
        expect(m2.subjectCode, equals('SnS'));

        // SnS is not DSA, so both belong to the same merged card
        expect(AttendanceLog.isDsa(m1.subjectCode), isFalse);
        expect(AttendanceLog.isDsa(m2.subjectCode), isFalse);
        final groupKey1 = '${m1.subjectCode}_Merged';
        final groupKey2 = '${m2.subjectCode}_Merged';
        expect(groupKey1, equals(groupKey2));
        expect(groupKey1, equals('SnS_Merged'));
      },
    );

    // 3. Probability and Statistics Theory and Practical aggregate into ONE PnS Merged group.
    test(
      '3. Probability and Statistics components aggregate into ONE PnS Merged group',
      () {
        final normTheory = AttendanceCourseNormalizer.normalize(
          'Probability and StatisticsT4 CE Sem III',
        );
        final normLab = AttendanceCourseNormalizer.normalize(
          'Probability and StatisticsP4 CE III C2',
        );

        final matcher = AttendanceCourseMatcher(configuredCourses);
        final m1 = matcher.match(
          courseName: normTheory.courseName,
          componentType: normTheory.componentType,
          rawCourseName: 'Probability and StatisticsT4 CE Sem III',
        );
        final m2 = matcher.match(
          courseName: normLab.courseName,
          componentType: normLab.componentType,
          rawCourseName: 'Probability and StatisticsP4 CE III C2',
        );

        expect(m1.subjectCode, equals('PnS'));
        expect(m2.subjectCode, equals('PnS'));
        expect(AttendanceLog.isDsa(m1.subjectCode), isFalse);

        final groupKey1 = '${m1.subjectCode}_Merged';
        final groupKey2 = '${m2.subjectCode}_Merged';
        expect(groupKey1, equals(groupKey2));
        expect(groupKey1, equals('PnS_Merged'));
      },
    );

    // 4. Two DSA Lab periods on the same day aggregate into the SAME Lab component.
    test(
      '4. Two DSA Lab periods on same day aggregate into the SAME Lab component',
      () {
        final log1 = AttendanceLog(
          id: 'CE_2026-8-12_780_839_DSA_Lab',
          subjectCode: 'DSA',
          component: 'Lab',
          rawSubjectText: 'DATA STRUCTURES AND ALGORITHMS LABP4 C2',
          date: DateTime(2026, 8, 12),
          startTime: 780,
          endTime: 839,
          status: 'present',
          source: 'pdf_import',
          confidence: MatchConfidence.exact,
        );

        final log2 = AttendanceLog(
          id: 'CE_2026-8-12_840_899_DSA_Lab',
          subjectCode: 'DSA',
          component: 'Lab',
          rawSubjectText: 'DATA STRUCTURES AND ALGORITHMS LABP4 C2',
          date: DateTime(2026, 8, 12),
          startTime: 840,
          endTime: 899,
          status: 'present',
          source: 'pdf_import',
          confidence: MatchConfidence.exact,
        );

        // Deduplication keys are different because of start time
        expect(log1.deduplicationKey, isNot(equals(log2.deduplicationKey)));

        // But their aggregation group key is identical
        final groupKey1 = '${log1.subjectCode}_${log1.component}';
        final groupKey2 = '${log2.subjectCode}_${log2.component}';
        expect(groupKey1, equals(groupKey2));
        expect(groupKey1, equals('DSA_Lab'));
      },
    );

    // 5. Two DSA Theory lectures aggregate into the SAME Theory component.
    test(
      '5. Two DSA Theory lectures aggregate into the SAME Theory component',
      () {
        final log1 = AttendanceLog(
          id: 'CE_2026-8-10_555_615_DSA_Theory',
          subjectCode: 'DSA',
          component: 'Theory',
          rawSubjectText: 'DATA STRUCTURES AND ALGORITHMST4 CE III',
          date: DateTime(2026, 8, 10),
          startTime: 555,
          endTime: 615,
          status: 'present',
          source: 'pdf_import',
          confidence: MatchConfidence.exact,
        );

        final log2 = AttendanceLog(
          id: 'CE_2026-8-11_555_615_DSA_Theory',
          subjectCode: 'DSA',
          component: 'Theory',
          rawSubjectText: 'DATA STRUCTURES AND ALGORITHMST4 CE III',
          date: DateTime(2026, 8, 11),
          startTime: 555,
          endTime: 615,
          status: 'absent',
          source: 'pdf_import',
          confidence: MatchConfidence.exact,
        );

        expect(log1.deduplicationKey, isNot(equals(log2.deduplicationKey)));
        final groupKey1 = '${log1.subjectCode}_${log1.component}';
        final groupKey2 = '${log2.subjectCode}_${log2.component}';
        expect(groupKey1, equals('DSA_Theory'));
        expect(groupKey2, equals('DSA_Theory'));
      },
    );

    // 6. Attendance percentage is independently calculated for DSA Theory vs Lab.
    test(
      '6. Attendance percentage is independently calculated for DSA Theory vs Lab',
      () {
        final theoryRecord = AttendanceRecord(
          id: 'CE_DSA_Theory',
          division: 'CE',
          subjectCode: 'DSA',
          component: 'Theory',
          present: 18,
          absent: 3,
        );

        final labRecord = AttendanceRecord(
          id: 'CE_DSA_Lab',
          division: 'CE',
          subjectCode: 'DSA',
          component: 'Lab',
          present: 12,
          absent: 2,
        );

        expect(theoryRecord.total, equals(21));
        expect(theoryRecord.present, equals(18));
        expect(theoryRecord.absent, equals(3));
        expect(theoryRecord.percentage * 100, closeTo(85.7, 0.1));

        expect(labRecord.total, equals(14));
        expect(labRecord.present, equals(12));
        expect(labRecord.absent, equals(2));
        expect(labRecord.percentage * 100, closeTo(85.7, 0.1));
      },
    );

    // 7. "Can miss N more" is independently calculated for DSA Theory vs Lab.
    test(
      '7. "Can miss N more" is independently calculated for DSA Theory vs Lab',
      () {
        final theoryRecord = AttendanceRecord(
          id: 'CE_DSA_Theory',
          division: 'CE',
          subjectCode: 'DSA',
          component: 'Theory',
          present: 18,
          absent: 3,
        );

        final labRecord = AttendanceRecord(
          id: 'CE_DSA_Lab',
          division: 'CE',
          subjectCode: 'DSA',
          component: 'Lab',
          present: 12,
          absent: 2,
        );

        // Formula: (present / 0.80).floor() - total
        // Theory: (18 / 0.80).floor() - 21 = 22 - 21 = 1 more allowed
        // Lab: (12 / 0.80).floor() - 14 = 15 - 14 = 1 more allowed
        expect(theoryRecord.canMiss, equals(1));
        expect(labRecord.canMiss, equals(1));
      },
    );

    // 8. Deduplication differentiates DSA components while merging other courses.
    test(
      '8. Deduplication differentiates DSA components while merging other courses',
      () {
        final date = DateTime(2026, 8, 10);
        final dsaTheoryKey = AttendanceLog.buildDeduplicationKey(
          date: date,
          startTime: 555,
          endTime: 614,
          subjectCode: 'DSA',
          component: 'Theory',
        );

        final dsaLabKey = AttendanceLog.buildDeduplicationKey(
          date: date,
          startTime: 555,
          endTime: 614,
          subjectCode: 'DSA',
          component: 'Lab',
        );

        expect(dsaTheoryKey, contains('_DSA_Theory'));
        expect(dsaLabKey, contains('_DSA_Lab'));
        expect(dsaTheoryKey, isNot(equals(dsaLabKey)));

        final snsKey = AttendanceLog.buildDeduplicationKey(
          date: date,
          startTime: 555,
          endTime: 614,
          subjectCode: 'SnS',
          component: 'Theory',
        );
        expect(snsKey, endsWith('_SnS'));
      },
    );

    // 9. Python Theory and Lab merge under ONE Python Merged card.
    test('9. Python Theory and Lab merge under ONE Python Merged card', () {
      final row1 = AttendanceCourseNormalizer.normalize(
        'PROGRAMMING WITH PYTHONT4 CE Sem III',
      );
      final row2 = AttendanceCourseNormalizer.normalize(
        'PROGRAMMING WITH PYTHONP4 CE Sem III C2',
      );

      final matcher = AttendanceCourseMatcher(configuredCourses);
      final m1 = matcher.match(
        courseName: row1.courseName,
        componentType: row1.componentType,
        rawCourseName: 'PROGRAMMING WITH PYTHONT4 CE Sem III',
      );
      final m2 = matcher.match(
        courseName: row2.courseName,
        componentType: row2.componentType,
        rawCourseName: 'PROGRAMMING WITH PYTHONP4 CE Sem III C2',
      );

      expect(m1.subjectCode, equals('Python'));
      expect(m2.subjectCode, equals('Python'));
      expect(AttendanceLog.isDsa(m1.subjectCode), isFalse);

      final key1 = '${m1.subjectCode}_Merged';
      final key2 = '${m2.subjectCode}_Merged';
      expect(key1, equals('Python_Merged'));
      expect(key2, equals('Python_Merged'));
    });

    // 10. Single-component courses retain their single component card.
    test('10. Single-component courses retain their single component card', () {
      final norm = AttendanceCourseNormalizer.normalize(
        'Principles of Economics and Managemen T4',
      );
      expect(norm.courseName, equals('Principles of Economics and Managemen'));
      expect(norm.componentType, equals('Theory'));

      final matcher = AttendanceCourseMatcher(configuredCourses);
      final m = matcher.match(
        courseName: norm.courseName,
        componentType: norm.componentType,
        rawCourseName: 'Principles of Economics and Managemen T4',
      );

      expect(m.subjectCode, equals('PEM'));
      expect(m.component, equals('Theory'));
    });
  });

  group('Golden 9-Page Reference PDF Exact Counts Validation', () {
    test(
      'Real 180-row PDF (ZSVKM_STUDENT_ATTENDANCE_COPY2.pdf) matches exact golden counts',
      () async {
        final bytes = await File(
          'test/fixtures/ZSVKM_STUDENT_ATTENDANCE_COPY2.pdf',
        ).readAsBytes();
        final parsed = AttendancePdfParser.parseBytes(bytes);

        expect(parsed.rows.length, equals(180));

        final preview = AttendancePdfParser.buildPreview(
          metadata: parsed.metadata,
          rows: parsed.rows,
          configuredCourses: configuredCourses,
          existingLogs: [],
        );

        // Assert 180/180 total records extracted
        expect(preview.logs.length, equals(180));
        if (preview.logs.length == 146) {
          fail(
            'CRITICAL BUG: Expected 180 records, but got 146! 34 records were lost.',
          );
        }

        // Aggregate by the user's rule:
        // ONLY DSA is split into Theory and Lab.
        // All other multi-component courses are merged under one card.
        final compsBySubject = <String, Set<String>>{};
        for (final log in preview.logs) {
          compsBySubject
              .putIfAbsent(log.subjectCode, () => {})
              .add(log.component);
        }

        final cards = <String, ({int total, int present, int absent})>{};
        for (final log in preview.logs) {
          final isDsa = AttendanceLog.isDsa(log.subjectCode);
          final hasMultiple =
              (compsBySubject[log.subjectCode]?.length ?? 0) > 1;

          final String cardKey;
          if (isDsa) {
            cardKey = '${log.subjectCode}_${log.component}';
          } else if (hasMultiple) {
            cardKey = '${log.subjectCode}_Merged';
          } else {
            cardKey = '${log.subjectCode}_${log.component}';
          }

          final cur = cards[cardKey] ?? (total: 0, present: 0, absent: 0);
          final p = log.status == 'present' ? 1 : 0;
          final a = log.status == 'absent' ? 1 : 0;
          cards[cardKey] = (
            total: cur.total + 1,
            present: cur.present + p,
            absent: cur.absent + a,
          );
        }

        print('=== FINAL CARD AGGREGATES ===');
        for (final e in cards.entries) {
          final p = e.value.present;
          final t = e.value.total;
          final pct = (p / t * 100).toStringAsFixed(1);
          print(
            '${e.key}: Total ${e.value.total}, Present ${e.value.present}, Absent ${e.value.absent}, Pct: $pct%',
          );
        }

        // 1. DSA Theory: 21 total, 18 Present, 3 Absent, 85.7%
        expect(cards['DSA_Theory']?.total, equals(21));
        expect(cards['DSA_Theory']?.present, equals(18));
        expect(cards['DSA_Theory']?.absent, equals(3));
        expect(
          cards['DSA_Theory']!.present / cards['DSA_Theory']!.total * 100,
          closeTo(85.7, 0.1),
        );

        // 2. DSA Lab: 14 total, 12 Present, 2 Absent, 85.7%
        expect(cards['DSA_Lab']?.total, equals(14));
        expect(cards['DSA_Lab']?.present, equals(12));
        expect(cards['DSA_Lab']?.absent, equals(2));
        expect(
          cards['DSA_Lab']!.present / cards['DSA_Lab']!.total * 100,
          closeTo(85.7, 0.1),
        );

        // 3. Python MERGED: 21 total, 19 Present, 2 Absent, 90.5%
        expect(cards['Python_Merged']?.total, equals(21));
        expect(cards['Python_Merged']?.present, equals(19));
        expect(cards['Python_Merged']?.absent, equals(2));
        expect(
          cards['Python_Merged']!.present / cards['Python_Merged']!.total * 100,
          closeTo(90.5, 0.1),
        );

        // 4. Signals & Systems MERGED: 27 total, 23 Present, 4 Absent, 85.2%
        expect(cards['SnS_Merged']?.total, equals(27));
        expect(cards['SnS_Merged']?.present, equals(23));
        expect(cards['SnS_Merged']?.absent, equals(4));
        expect(
          cards['SnS_Merged']!.present / cards['SnS_Merged']!.total * 100,
          closeTo(85.2, 0.1),
        );

        // 5. Probability & Statistics MERGED: 29 total, 26 Present, 3 Absent, 89.7%
        expect(cards['PnS_Merged']?.total, equals(29));
        expect(cards['PnS_Merged']?.present, equals(26));
        expect(cards['PnS_Merged']?.absent, equals(3));
        expect(
          cards['PnS_Merged']!.present / cards['PnS_Merged']!.total * 100,
          closeTo(89.7, 0.1),
        );

        // 6. Discrete Mathematics MERGED: 20 total, 16 Present, 4 Absent, 80.0%
        expect(cards['DM_Merged']?.total, equals(20));
        expect(cards['DM_Merged']?.present, equals(16));
        expect(cards['DM_Merged']?.absent, equals(4));
        expect(
          cards['DM_Merged']!.present / cards['DM_Merged']!.total * 100,
          closeTo(80.0, 0.1),
        );

        // 7. Computer Organization and Architecture: 21 total, 19 Present, 2 Absent, 90.5%
        expect(cards['COA_Theory']?.total, equals(21));
        expect(cards['COA_Theory']?.present, equals(19));
        expect(cards['COA_Theory']?.absent, equals(2));
        expect(
          cards['COA_Theory']!.present / cards['COA_Theory']!.total * 100,
          closeTo(90.5, 0.1),
        );

        // 8. Principles of Economics and Management: 16 total, 15 Present, 1 Absent, 93.75%
        expect(cards['PEM_Theory']?.total, equals(16));
        expect(cards['PEM_Theory']?.present, equals(15));
        expect(cards['PEM_Theory']?.absent, equals(1));
        expect(
          cards['PEM_Theory']!.present / cards['PEM_Theory']!.total * 100,
          closeTo(93.75, 0.1),
        );

        // 9. Prompt Engineering for ChatGPT: 4 total, 4 Present, 0 Absent, 100%
        expect(cards['PE_Theory']?.total, equals(4));
        expect(cards['PE_Theory']?.present, equals(4));
        expect(cards['PE_Theory']?.absent, equals(0));
        expect(
          cards['PE_Theory']!.present / cards['PE_Theory']!.total * 100,
          closeTo(100.0, 0.1),
        );

        // 10. Technical Communication: 7 total, 6 Present, 1 Absent, 85.7%
        expect(cards['TC_Tutorial']?.total, equals(7));
        expect(cards['TC_Tutorial']?.present, equals(6));
        expect(cards['TC_Tutorial']?.absent, equals(1));
        expect(
          cards['TC_Tutorial']!.present / cards['TC_Tutorial']!.total * 100,
          closeTo(85.7, 0.1),
        );

        // Assert total sum across all cards = 180!
        final totalSum = cards.values.fold<int>(0, (sum, c) => sum + c.total);
        expect(totalSum, equals(180));
      },
    );

    test(
      'Deduplication reconciles dirty database containing duplicate records down to exactly 180',
      () async {
        final bytes = await File(
          'test/fixtures/ZSVKM_STUDENT_ATTENDANCE_COPY2.pdf',
        ).readAsBytes();
        final parsed = AttendancePdfParser.parseBytes(bytes);

        final preview = AttendancePdfParser.buildPreview(
          metadata: parsed.metadata,
          rows: parsed.rows,
          configuredCourses: configuredCourses,
          existingLogs: [],
        );

        // Simulate a dirty store with 7 duplicates (COA +1, PEM +1, PnS +2, Python +1, SnS +2)
        final dirtyLogs = List<AttendanceLog>.from(preview.logs);

        final coaSample = preview.logs.firstWhere(
          (l) => l.subjectCode == 'COA',
        );
        dirtyLogs.add(
          AttendanceLog(
            id: 'old_random_id_coa',
            subjectCode: 'Computer Organization and Architectur',
            component: coaSample.component,
            rawSubjectText: coaSample.rawSubjectText,
            date: coaSample.date,
            startTime: coaSample.startTime,
            endTime: coaSample.endTime,
            status: coaSample.status,
            source: 'pdf_import',
            confidence: MatchConfidence.exact,
          ),
        );

        final pemSample = preview.logs.firstWhere(
          (l) => l.subjectCode == 'PEM',
        );
        dirtyLogs.add(
          AttendanceLog(
            id: 'old_random_id_pem',
            subjectCode: 'Principles of Economics and Managemen',
            component: pemSample.component,
            rawSubjectText: pemSample.rawSubjectText,
            date: pemSample.date,
            startTime: pemSample.startTime,
            endTime: pemSample.endTime,
            status: pemSample.status,
            source: 'pdf_import',
            confidence: MatchConfidence.exact,
          ),
        );

        final pnsSamples = preview.logs
            .where((l) => l.subjectCode == 'PnS')
            .take(2)
            .toList();
        for (var i = 0; i < pnsSamples.length; i++) {
          final s = pnsSamples[i];
          dirtyLogs.add(
            AttendanceLog(
              id: 'old_random_id_pns_$i',
              subjectCode: 'Probability and Statistics',
              component: s.component,
              rawSubjectText: s.rawSubjectText,
              date: s.date,
              startTime: s.startTime,
              endTime: s.endTime,
              status: s.status,
              source: 'pdf_import',
              confidence: MatchConfidence.exact,
            ),
          );
        }

        final pythonSample = preview.logs.firstWhere(
          (l) => l.subjectCode == 'Python',
        );
        dirtyLogs.add(
          AttendanceLog(
            id: 'old_random_id_python',
            subjectCode: 'PROGRAMMING WITH PYTHON',
            component: pythonSample.component,
            rawSubjectText: pythonSample.rawSubjectText,
            date: pythonSample.date,
            startTime: pythonSample.startTime,
            endTime: pythonSample.endTime,
            status: pythonSample.status,
            source: 'pdf_import',
            confidence: MatchConfidence.exact,
          ),
        );

        final snsSamples = preview.logs
            .where((l) => l.subjectCode == 'SnS')
            .take(2)
            .toList();
        for (var i = 0; i < snsSamples.length; i++) {
          final s = snsSamples[i];
          dirtyLogs.add(
            AttendanceLog(
              id: 'old_random_id_sns_$i',
              subjectCode: 'Signals and Systems',
              component: s.component,
              rawSubjectText: s.rawSubjectText,
              date: s.date,
              startTime: s.startTime,
              endTime: s.endTime,
              status: s.status,
              source: 'pdf_import',
              confidence: MatchConfidence.exact,
            ),
          );
        }

        expect(dirtyLogs.length, equals(187)); // 180 + 7 duplicates!

        // Now verify that stable deduplication reduces 187 back to EXACTLY 180
        final uniqueLogs = <String, AttendanceLog>{};
        for (final log in dirtyLogs) {
          final key = log.deduplicationKey;
          uniqueLogs[key] = log;
        }
        expect(uniqueLogs.length, equals(180));
      },
    );
  });

  group('Daily Attendance PDF Snapshots & Progressive Merge Tests', () {
    // 1. Same PDF uploaded twice -> no duplicates
    test('1. Same PDF uploaded twice produces no duplicates', () async {
      final bytes = await File(
        'test/fixtures/ZSVKM_STUDENT_ATTENDANCE_COPY2.pdf',
      ).readAsBytes();
      final parsed = AttendancePdfParser.parseBytes(bytes);

      // First upload
      final snapshot1 = AttendancePdfParser.buildPreview(
        metadata: parsed.metadata,
        rows: parsed.rows,
        configuredCourses: configuredCourses,
        existingLogs: [],
      );
      expect(snapshot1.logs.length, equals(180));
      expect(snapshot1.newCount, equals(180));
      expect(snapshot1.duplicateCount, equals(0));

      // Second upload of the same PDF
      final snapshot2 = AttendancePdfParser.buildPreview(
        metadata: parsed.metadata,
        rows: parsed.rows,
        configuredCourses: configuredCourses,
        existingLogs: snapshot1.logs,
      );
      expect(snapshot2.newCount, equals(0));
      expect(snapshot2.duplicateCount, equals(180));
      expect(snapshot2.updateCount, equals(0));

      // Combined unique store remains exactly 180
      final store = {for (final l in snapshot1.logs) l.deduplicationKey: l};
      for (final l in snapshot2.logs) {
        store[l.deduplicationKey] = l;
      }
      expect(store.length, equals(180));
    });

    // 2. Older PDF then newer PDF -> union of lectures
    test(
      '2. Older PDF then newer PDF produces clean union of lectures',
      () async {
        final bytesOld = await File(
          'test/fixtures/ZSVKM_STUDENT_ATTENDANCE_COPY (1).pdf',
        ).readAsBytes();
        final bytesNew = await File(
          'test/fixtures/ZSVKM_STUDENT_ATTENDANCE_COPY2.pdf',
        ).readAsBytes();

        final parsedOld = AttendancePdfParser.parseBytes(bytesOld);
        final parsedNew = AttendancePdfParser.parseBytes(bytesNew);

        expect(parsedOld.rows.length, equals(94));
        expect(parsedNew.rows.length, equals(180));

        // Day 1 import
        final previewOld = AttendancePdfParser.buildPreview(
          metadata: parsedOld.metadata,
          rows: parsedOld.rows,
          configuredCourses: configuredCourses,
          existingLogs: [],
        );
        expect(previewOld.logs.length, equals(94));

        // Day 2 import (newer snapshot)
        final previewNew = AttendancePdfParser.buildPreview(
          metadata: parsedNew.metadata,
          rows: parsedNew.rows,
          configuredCourses: configuredCourses,
          existingLogs: previewOld.logs,
        );

        expect(previewNew.newCount, equals(86)); // 180 - 94 = 86 new lectures
        expect(previewNew.duplicateCount + previewNew.updateCount, equals(94));

        final store = {for (final l in previewOld.logs) l.deduplicationKey: l};
        for (final l in previewNew.logs) {
          store[l.deduplicationKey] = l;
        }
        expect(store.length, equals(180));
      },
    );

    // 3. NU -> P: one updated record
    test('3. Status update from NU (not_updated) to P (present)', () {
      final date = DateTime(2026, 8, 27);
      final oldLog = AttendanceLog(
        id: 'old_python_1',
        subjectCode: 'Python',
        component: 'Theory',
        rawSubjectText: 'PROGRAMMING WITH PYTHON',
        date: date,
        startTime: 675, // 11:15 AM
        endTime: 734, // 12:14 PM
        status: 'not_updated',
        source: 'pdf_import',
        confidence: MatchConfidence.exact,
      );

      final newRow = ParsedAttendanceRow(
        srNo: 155,
        date: date,
        startTimeMinutes: 675,
        endTimeMinutes: 734,
        rawCourseName: 'PROGRAMMING WITH PYTHON',
        courseName: 'PROGRAMMING WITH PYTHON',
        componentCode: 'T4',
        rawStatus: 'P',
        normalizedStatus: 'present',
        pageIndex: 7,
      );

      final preview = AttendancePdfParser.buildPreview(
        metadata: AttendanceReportMetadata(
          studentName: 'Test',
          studentNumber: '1',
          programName: 'CE',
          pageCount: 1,
        ),
        rows: [newRow],
        configuredCourses: configuredCourses,
        existingLogs: [oldLog],
      );

      expect(preview.newCount, equals(0));
      expect(preview.updateCount, equals(1));
      expect(preview.duplicateCount, equals(0));

      final store = {oldLog.deduplicationKey: oldLog};
      for (final l in preview.logs) {
        store[l.deduplicationKey] = l;
      }
      expect(store.length, equals(1));
      expect(store.values.first.status, equals('present'));
    });

    // 4. NU -> A: one updated record
    test('4. Status update from NU (not_updated) to A (absent)', () {
      final date = DateTime(2026, 8, 27);
      final oldLog = AttendanceLog(
        id: 'old_python_2',
        subjectCode: 'Python',
        component: 'Theory',
        rawSubjectText: 'PROGRAMMING WITH PYTHON',
        date: date,
        startTime: 675,
        endTime: 734,
        status: 'not_updated',
        source: 'pdf_import',
        confidence: MatchConfidence.exact,
      );

      final newRow = ParsedAttendanceRow(
        srNo: 155,
        date: date,
        startTimeMinutes: 675,
        endTimeMinutes: 734,
        rawCourseName: 'PROGRAMMING WITH PYTHON',
        courseName: 'PROGRAMMING WITH PYTHON',
        componentCode: 'T4',
        rawStatus: 'A',
        normalizedStatus: 'absent',
        pageIndex: 7,
      );

      final preview = AttendancePdfParser.buildPreview(
        metadata: AttendanceReportMetadata(
          studentName: 'Test',
          studentNumber: '1',
          programName: 'CE',
          pageCount: 1,
        ),
        rows: [newRow],
        configuredCourses: configuredCourses,
        existingLogs: [oldLog],
      );

      expect(preview.updateCount, equals(1));
      final store = {oldLog.deduplicationKey: oldLog};
      for (final l in preview.logs) {
        store[l.deduplicationKey] = l;
      }
      expect(store.length, equals(1));
      expect(store.values.first.status, equals('absent'));
    });

    // 5. Existing P remains P if newer PDF still says P
    test('5. Existing P remains P without creating duplicates', () {
      final date = DateTime(2026, 8, 20);
      final existingLog = AttendanceLog(
        id: 'p_log',
        subjectCode: 'COA',
        component: 'Theory',
        rawSubjectText: 'Computer Organization and Architecture',
        date: date,
        startTime: 555,
        endTime: 614,
        status: 'present',
        source: 'pdf_import',
        confidence: MatchConfidence.exact,
      );

      final row = ParsedAttendanceRow(
        srNo: 42,
        date: date,
        startTimeMinutes: 555,
        endTimeMinutes: 614,
        rawCourseName: 'Computer Organization and Architecture',
        courseName: 'Computer Organization and Architecture',
        componentCode: 'T4',
        rawStatus: 'P',
        normalizedStatus: 'present',
        pageIndex: 2,
      );

      final preview = AttendancePdfParser.buildPreview(
        metadata: AttendanceReportMetadata(
          studentName: 'Test',
          studentNumber: '1',
          programName: 'CE',
          pageCount: 1,
        ),
        rows: [row],
        configuredCourses: configuredCourses,
        existingLogs: [existingLog],
      );

      expect(preview.duplicateCount, equals(1));
      expect(preview.newCount, equals(0));
      expect(preview.updateCount, equals(0));
    });

    // 6. Existing lecture absent from newer PDF -> DO NOT delete
    test('6. Existing lecture absent from newer PDF is safely retained', () {
      final datePast = DateTime(
        2026,
        7,
        5,
      ); // Earlier date outside current report range
      final historicalLog = AttendanceLog(
        id: 'hist_log_1',
        subjectCode: 'PEM',
        component: 'Theory',
        rawSubjectText: 'Principles of Economics and Management',
        date: datePast,
        startTime: 615,
        endTime: 674,
        status: 'present',
        source: 'pdf_import',
        confidence: MatchConfidence.exact,
      );

      final store = <String, AttendanceLog>{
        historicalLog.deduplicationKey: historicalLog,
      };

      // Newer PDF only has lectures from Aug 1 to Aug 30
      final newRows = <ParsedAttendanceRow>[
        ParsedAttendanceRow(
          srNo: 1,
          date: DateTime(2026, 8, 10),
          startTimeMinutes: 555,
          endTimeMinutes: 614,
          rawCourseName: 'Principles of Economics and Management',
          courseName: 'Principles of Economics and Management',
          componentCode: 'T4',
          rawStatus: 'P',
          normalizedStatus: 'present',
          pageIndex: 1,
        ),
      ];

      final preview = AttendancePdfParser.buildPreview(
        metadata: AttendanceReportMetadata(
          studentName: 'Test',
          studentNumber: '1',
          programName: 'CE',
          pageCount: 1,
        ),
        rows: newRows,
        configuredCourses: configuredCourses,
        existingLogs: store.values.toList(),
      );

      // Merge new snapshot into store
      for (final l in preview.logs) {
        store[l.deduplicationKey] = l;
      }

      // Both historical lecture AND new lecture are present!
      expect(store.length, equals(2));
      expect(store.containsKey(historicalLog.deduplicationKey), isTrue);
    });

    // 7. Sr No changes but lecture identity remains same -> update/dedup, not duplicate
    test('7. Sr No change between PDF reports does not duplicate lecture', () {
      final date = DateTime(2026, 8, 14);
      final logDay1 = AttendanceLog(
        id: 'day1_sr_85',
        subjectCode: 'SnS',
        component: 'Theory',
        rawSubjectText: 'Signals and Systems',
        date: date,
        startTime: 615,
        endTime: 674,
        status: 'present',
        source: 'pdf_import',
        confidence: MatchConfidence.exact,
      );

      // In Day 2 report, the exact same lecture has Sr No 92 because prior rows shifted
      final rowDay2 = ParsedAttendanceRow(
        srNo: 92, // Changed from 85 to 92!
        date: date,
        startTimeMinutes: 615,
        endTimeMinutes: 674,
        rawCourseName: 'Signals and Systems',
        courseName: 'Signals and Systems',
        componentCode: 'T4',
        rawStatus: 'P',
        normalizedStatus: 'present',
        pageIndex: 5,
      );

      final preview = AttendancePdfParser.buildPreview(
        metadata: AttendanceReportMetadata(
          studentName: 'Test',
          studentNumber: '1',
          programName: 'CE',
          pageCount: 1,
        ),
        rows: [rowDay2],
        configuredCourses: configuredCourses,
        existingLogs: [logDay1],
      );

      expect(preview.duplicateCount, equals(1));
      expect(preview.newCount, equals(0));
    });

    // 8. DSA Theory and DSA Lab remain separate under progressive snapshots
    test(
      '8. DSA Theory and DSA Lab remain separate under progressive snapshots',
      () {
        final dsaTheoryKey = AttendanceLog.buildDeduplicationKey(
          date: DateTime(2026, 8, 11),
          startTime: 555,
          endTime: 614,
          subjectCode: 'DSA',
          component: 'Theory',
        );
        final dsaLabKey = AttendanceLog.buildDeduplicationKey(
          date: DateTime(2026, 8, 11),
          startTime: 555,
          endTime: 614,
          subjectCode: 'DSA',
          component: 'Lab',
        );

        expect(dsaTheoryKey, isNot(equals(dsaLabKey)));
        expect(dsaTheoryKey, contains('_DSA_Theory'));
        expect(dsaLabKey, contains('_DSA_Lab'));
      },
    );

    // 9. Python T4 + P4 remain merged under progressive snapshots
    test('9. Python T4 + P4 remain merged under progressive snapshots', () {
      final t4Key = AttendanceLog.buildDeduplicationKey(
        date: DateTime(2026, 8, 12),
        startTime: 555,
        endTime: 614,
        subjectCode: 'Python',
        component: 'Theory',
      );
      final p4Key = AttendanceLog.buildDeduplicationKey(
        date: DateTime(2026, 8, 12),
        startTime: 615,
        endTime: 674,
        subjectCode: 'Python',
        component: 'Lab',
      );

      // Both belong to Python without component suffix
      expect(t4Key, endsWith('_Python'));
      expect(p4Key, endsWith('_Python'));
    });

    // 10. SnS T4 + P4 remain merged under progressive snapshots
    test('10. SnS T4 + P4 remain merged under progressive snapshots', () {
      final k1 = AttendanceLog.buildDeduplicationKey(
        date: DateTime(2026, 8, 13),
        startTime: 555,
        endTime: 614,
        subjectCode: 'SnS',
        component: 'Theory',
      );
      final k2 = AttendanceLog.buildDeduplicationKey(
        date: DateTime(2026, 8, 13),
        startTime: 615,
        endTime: 674,
        subjectCode: 'SnS',
        component: 'Lab',
      );
      expect(k1, endsWith('_SnS'));
      expect(k2, endsWith('_SnS'));
    });

    // 11. PnS T4 + P4 remain merged under progressive snapshots
    test('11. PnS T4 + P4 remain merged under progressive snapshots', () {
      final k1 = AttendanceLog.buildDeduplicationKey(
        date: DateTime(2026, 8, 14),
        startTime: 555,
        endTime: 614,
        subjectCode: 'PnS',
        component: 'Theory',
      );
      final k2 = AttendanceLog.buildDeduplicationKey(
        date: DateTime(2026, 8, 14),
        startTime: 615,
        endTime: 674,
        subjectCode: 'PnS',
        component: 'Lab',
      );
      expect(k1, endsWith('_PnS'));
      expect(k2, endsWith('_PnS'));
    });

    // 12. DM T4 + U4 remain merged under progressive snapshots
    test('12. DM T4 + U4 remain merged under progressive snapshots', () {
      final k1 = AttendanceLog.buildDeduplicationKey(
        date: DateTime(2026, 8, 15),
        startTime: 555,
        endTime: 614,
        subjectCode: 'DM',
        component: 'Theory',
      );
      final k2 = AttendanceLog.buildDeduplicationKey(
        date: DateTime(2026, 8, 15),
        startTime: 615,
        endTime: 674,
        subjectCode: 'DM',
        component: 'Tutorial',
      );
      expect(k1, endsWith('_DM'));
      expect(k2, endsWith('_DM'));
    });

    // 13. Final 180-row PDF still produces exactly 180 unique lectures
    test(
      '13. Final 180-row PDF still produces exactly 180 unique lectures with exact counts',
      () async {
        final bytes = await File(
          'test/fixtures/ZSVKM_STUDENT_ATTENDANCE_COPY2.pdf',
        ).readAsBytes();
        final parsed = AttendancePdfParser.parseBytes(bytes);

        final preview = AttendancePdfParser.buildPreview(
          metadata: parsed.metadata,
          rows: parsed.rows,
          configuredCourses: configuredCourses,
          existingLogs: [],
        );

        expect(preview.logs.length, equals(180));

        final uniqueStore = <String, AttendanceLog>{};
        for (final log in preview.logs) {
          uniqueStore[log.deduplicationKey] = log;
        }
        expect(uniqueStore.length, equals(180));

        // Assert exact subject counts
        final subjectCounts = <String, int>{};
        for (final log in uniqueStore.values) {
          final key = AttendanceLog.isDsa(log.subjectCode)
              ? '${log.subjectCode}_${log.component}'
              : log.subjectCode;
          subjectCounts[key] = (subjectCounts[key] ?? 0) + 1;
        }

        expect(subjectCounts['DSA_Theory'], equals(21));
        expect(subjectCounts['DSA_Lab'], equals(14));
        expect(subjectCounts['COA'], equals(21));
        expect(subjectCounts['PEM'], equals(16));
        expect(subjectCounts['PnS'], equals(29));
        expect(subjectCounts['Python'], equals(21));
        expect(subjectCounts['SnS'], equals(27));
        expect(subjectCounts['DM'], equals(20));
        expect(subjectCounts['TC'], equals(7));
        expect(subjectCounts['PE'], equals(4));
      },
    );
  });
}
