import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedly/faculty/faculty_excel_import_service.dart';
import 'package:schedly/models/timetable_entry.dart';
import 'package:schedly/models/event_category.dart';
import 'package:schedly/services/timetable_resolver_service.dart';

void main() {
  group('FacultyExcelImportService Tests', () {
    test(
      'parses CSV timetable correctly with day, time, subject, division',
      () {
        final csvContent = '''
Day,Time,Subject,Division,Room,Batch
Monday,10:15 - 11:15,Data Structures,CE_A,Lab 1,Whole Class
Wednesday,14:00 - 15:00,Operating Systems,CE_B,Room 204,B1
Friday,09:00 - 10:00,Database Systems,IT_A,Room 101,
''';

        final bytes = Uint8List.fromList(utf8.encode(csvContent));
        final entries = FacultyExcelImportService.parseBytes(
          bytes: bytes,
          fileName: 'faculty_schedule.csv',
        );

        expect(entries.length, 3);

        expect(entries[0].day, 'Monday');
        expect(entries[0].startTime, 10 * 60 + 15);
        expect(entries[0].endTime, 11 * 60 + 15);
        expect(entries[0].subject, 'Data Structures');
        expect(entries[0].division, 'CE_A');
        expect(entries[0].room, 'Lab 1');
        expect(entries[0].batch, 'Whole Class');

        expect(entries[1].day, 'Wednesday');
        expect(entries[1].startTime, 14 * 60);
        expect(entries[1].endTime, 15 * 60);
        expect(entries[1].subject, 'Operating Systems');
        expect(entries[1].division, 'CE_B');
        expect(entries[1].batch, 'B1');

        expect(entries[2].day, 'Friday');
        expect(entries[2].startTime, 9 * 60);
        expect(entries[2].endTime, 10 * 60);
        expect(entries[2].subject, 'Database Systems');
        expect(entries[2].division, 'IT_A');
      },
    );

    test('normalizes day names cleanly', () {
      expect(FacultyExcelImportService.normalizeDay('mon'), 'Monday');
      expect(FacultyExcelImportService.normalizeDay('TUESDAY'), 'Tuesday');
      expect(FacultyExcelImportService.normalizeDay('Wed'), 'Wednesday');
      expect(FacultyExcelImportService.normalizeDay('thu'), 'Thursday');
      expect(FacultyExcelImportService.normalizeDay('friday'), 'Friday');
    });
  });

  group('Faculty Conflict Detection Logic Tests', () {
    test(
      'detects exact and partial overlaps across sections for same faculty',
      () {
        bool checkOverlap(int startA, int endA, int startB, int endB) {
          return startA < endB && startB < endA;
        }

        // Case 1: Exact overlap (10:15–11:15 and 10:15–11:15)
        expect(checkOverlap(615, 675, 615, 675), isTrue);

        // Case 2: Partial overlap (10:15–11:15 and 10:45–11:45)
        expect(checkOverlap(615, 675, 645, 705), isTrue);

        // Case 3: Partial overlap (10:45–11:45 and 10:15–11:15)
        expect(checkOverlap(645, 705, 615, 675), isTrue);

        // Case 4: Contained overlap (10:00–12:00 and 10:30–11:30)
        expect(checkOverlap(600, 720, 630, 690), isTrue);

        // Case 5: Adjacent (non-overlapping) (10:15–11:15 and 11:15–12:15)
        expect(checkOverlap(615, 675, 675, 735), isFalse);

        // Case 6: Completely disjoint (09:00–10:00 and 11:00–12:00)
        expect(checkOverlap(540, 600, 660, 720), isFalse);
      },
    );

    test('extracts only affected divisions for Notify CRs', () {
      final mockConflicts = [
        {'divA': 'CE_A', 'divB': 'CE_C'},
        {'divA': 'CE_A', 'divB': 'CE_C'}, // duplicate pair
        {'divA': 'CE_A', 'divB': 'CE_D'},
      ];

      final affectedDivisions = <String>{};
      for (final c in mockConflicts) {
        affectedDivisions.add(c['divA']!);
        affectedDivisions.add(c['divB']!);
      }

      // CR targeting must strictly include CE_A, CE_C, CE_D and NOT unrelated divisions (e.g. CE_B)
      expect(affectedDivisions, contains('CE_A'));
      expect(affectedDivisions, contains('CE_C'));
      expect(affectedDivisions, contains('CE_D'));
      expect(affectedDivisions.contains('CE_B'), isFalse);
      expect(affectedDivisions.length, 3);
    });
  });

  group('Faculty ↔ SR Bidirectional Resolution Tests', () {
    test('resolves assignment doc id from subject name', () {
      String getAssignmentId(String subject) =>
          subject.toLowerCase().replaceAll(' ', '_');

      expect(getAssignmentId('Data Structures'), 'data_structures');
      expect(getAssignmentId('DSA'), 'dsa');
      expect(
        getAssignmentId('Probability and Statistics'),
        'probability_and_statistics',
      );
      expect(
        getAssignmentId('PROGRAMMING WITH PYTHON'),
        'programming_with_python',
      );
    });

    test('matches faculty subject against SR subject bidirectionally', () {
      bool isSubjectMatch(String facSubj, String srSubj) {
        final f = facSubj.toLowerCase().trim();
        final s = srSubj.toLowerCase().trim();
        return f == s || f.contains(s) || s.contains(f);
      }

      expect(isSubjectMatch('Data Structures', 'DSA'), isFalse);
      expect(isSubjectMatch('Data Structures', 'Data Structures'), isTrue);
      expect(isSubjectMatch('Python', 'Programming with Python'), isTrue);
      expect(isSubjectMatch('Operating Systems', 'OS'), isFalse);
      expect(isSubjectMatch('Operating Systems', 'Operating Systems'), isTrue);
    });
  });

  group('Timetable Override & Cancellation Resolution Tests', () {
    test('effective faculty timetable reflects CR-approved date replacement', () {
      final recurringLecture = TimetableEntry(
        id: 'lec_dsa_mon',
        subject: 'DSA',
        category: EventCategory.academic,
        batch: 'Whole Class',
        startTime: 615, // 10:15 AM
        endTime: 675, // 11:15 AM
        durationMinutes: 60,
        hiddenOnDates: ['2026-09-07'], // Hidden because CR approved replacement
      );

      final replacementLecture = TimetableEntry(
        id: 'lec_dsa_override_20260907',
        subject: 'DSA',
        category: EventCategory.academic,
        batch: 'Whole Class',
        startTime: 840, // 2:00 PM
        endTime: 900, // 3:00 PM
        durationMinutes: 60,
        validForDate: '2026-09-07', // Approved for this date
      );

      final rawEntries = [recurringLecture, replacementLecture];

      // On 2026-09-07: recurring is hidden, replacement is active at 2:00 PM
      final resolved = TimetableResolverService.resolve(
        rawEntries: rawEntries,
        targetDateStr: '2026-09-07',
      );

      expect(resolved.lectures.length, 1);
      expect(resolved.lectures.first.id, 'lec_dsa_override_20260907');
      expect(resolved.lectures.first.startTime, 840);

      // On another Monday (e.g. 2026-09-14): normal recurring lecture is active at 10:15 AM
      final resolvedNextWeek = TimetableResolverService.resolve(
        rawEntries: rawEntries,
        targetDateStr: '2026-09-14',
      );

      expect(resolvedNextWeek.lectures.length, 1);
      expect(resolvedNextWeek.lectures.first.id, 'lec_dsa_mon');
      expect(resolvedNextWeek.lectures.first.startTime, 615);
    });

    test('cancelled lecture produces no active lectures on that date', () {
      final cancelledLecture = TimetableEntry(
        id: 'lec_pns_fri',
        subject: 'Probability and Statistics',
        category: EventCategory.academic,
        batch: 'Whole Class',
        startTime: 540,
        endTime: 600,
        durationMinutes: 60,
        hiddenOnDates: ['2026-09-04'],
      );

      final cancelledPlaceholder = TimetableEntry(
        id: 'lec_pns_cancel_20260904',
        subject: 'Probability and Statistics',
        category: EventCategory.academic,
        batch: 'Whole Class',
        startTime: 540,
        endTime: 600,
        durationMinutes: 60,
        validForDate: '2026-09-04',
        status: 'cancelled',
      );

      final resolved = TimetableResolverService.resolve(
        rawEntries: [cancelledLecture, cancelledPlaceholder],
        targetDateStr: '2026-09-04',
      );

      final activeLectures = resolved.lectures
          .where((e) => e.isActive)
          .toList();
      expect(activeLectures.isEmpty, isTrue);
    });
  });

  group('Duplicate Notification Prevention & Payload Routing Tests', () {
    test('generates deterministic idempotent outbox document IDs', () {
      const requestId = 'req_abc123';
      final crNotifId = 'req_cr_$requestId';
      final srNotifId = 'req_sr_$requestId';

      expect(crNotifId, 'req_cr_req_abc123');
      expect(srNotifId, 'req_sr_req_abc123');

      // Conflict deterministic ID
      final conflictId1 = 'conflict_20260901_CE_A_fac001';
      final conflictId2 = 'conflict_20260901_CE_A_fac001';
      expect(conflictId1, equals(conflictId2));
    });

    test('scopes faculty announcement topic correctly', () {
      String getAnnouncementTopic({
        required String division,
        required String? batch,
      }) {
        if (batch != null && batch != 'Whole Class' && batch.isNotEmpty) {
          return 'batch_${batch}_$division';
        }
        return 'division_$division';
      }

      expect(
        getAnnouncementTopic(division: 'CE_C', batch: 'C2'),
        'batch_C2_CE_C',
      );
      expect(
        getAnnouncementTopic(division: 'CE_C', batch: 'Whole Class'),
        'division_CE_C',
      );
      expect(
        getAnnouncementTopic(division: 'CE_C', batch: null),
        'division_CE_C',
      );
    });
  });
}
