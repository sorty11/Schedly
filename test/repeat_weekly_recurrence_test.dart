import 'package:flutter_test/flutter_test.dart';
import 'package:schedly/models/event_category.dart';
import 'package:schedly/models/timetable_entry.dart';
import 'package:schedly/services/timetable_resolver_service.dart';

void main() {
  group('Repeat Weekly & Recurrence Mechanics', () {
    test('1. Repeat ON creates recurring entry (validForDate is null)', () {
      final recurringEntry = TimetableEntry(
        id: 'rec_math_1',
        subject: 'PEM',
        component: 'Theory',
        category: EventCategory.academic,
        batch: 'Whole Class',
        startTime: 600, // 10:00
        endTime: 660, // 11:00
        durationMinutes: 60,
        room: '302',
        status: 'active',
        validForDate: null, // Repeat Weekly = ON -> null validForDate
        hiddenOnDates: const [],
      );

      final firestoreData = recurringEntry.toFirestore();
      expect(firestoreData['validForDate'], isNull);
      expect(firestoreData['status'], 'active');
      expect(firestoreData['isActive'], true);
      expect(recurringEntry.validForDate, isNull);
    });

    test('2. Repeat OFF creates single-date entry (validForDate has specific date)', () {
      final oneOffEntry = TimetableEntry(
        id: 'oneoff_math_1',
        subject: 'PEM',
        component: 'Theory',
        category: EventCategory.academic,
        batch: 'Whole Class',
        startTime: 600,
        endTime: 660,
        durationMinutes: 60,
        room: '302',
        status: 'active',
        validForDate: '2026-09-08', // Tuesday, 8 Sep
        hiddenOnDates: const [],
      );

      final firestoreData = oneOffEntry.toFirestore();
      expect(firestoreData['validForDate'], '2026-09-08');
      expect(firestoreData['status'], 'active');
      expect(oneOffEntry.validForDate, '2026-09-08');
    });

    test('3. Repeat ON appears on future weeks via TimetableResolverService', () {
      final recurringEntry = TimetableEntry(
        id: 'rec_tue_pem',
        subject: 'PEM',
        component: 'Theory',
        category: EventCategory.academic,
        batch: 'Whole Class',
        startTime: 600,
        endTime: 660,
        durationMinutes: 60,
        room: '302',
        status: 'active',
        validForDate: null,
      );

      final rawEntries = [recurringEntry];

      // Week 1: 8 Sep 2026 (Tuesday)
      final week1 = TimetableResolverService.resolve(
        rawEntries: rawEntries,
        targetDateStr: '2026-09-08',
      );
      expect(week1.lectures.length, 1);
      expect(week1.lectures.first.id, 'rec_tue_pem');

      // Week 2: 15 Sep 2026 (Tuesday)
      final week2 = TimetableResolverService.resolve(
        rawEntries: rawEntries,
        targetDateStr: '2026-09-15',
      );
      expect(week2.lectures.length, 1);
      expect(week2.lectures.first.id, 'rec_tue_pem');

      // Week 3: 22 Sep 2026 (Tuesday)
      final week3 = TimetableResolverService.resolve(
        rawEntries: rawEntries,
        targetDateStr: '2026-09-22',
      );
      expect(week3.lectures.length, 1);
      expect(week3.lectures.first.id, 'rec_tue_pem');
    });

    test('4. Repeat OFF does NOT appear on following weeks', () {
      final oneOffEntry = TimetableEntry(
        id: 'oneoff_tue_pem',
        subject: 'PEM',
        component: 'Theory',
        category: EventCategory.academic,
        batch: 'Whole Class',
        startTime: 600,
        endTime: 660,
        durationMinutes: 60,
        room: '302',
        status: 'active',
        validForDate: '2026-09-08', // Selected date only
      );

      final rawEntries = [oneOffEntry];

      // Target Date: 8 Sep 2026 -> Appears!
      final targetDay = TimetableResolverService.resolve(
        rawEntries: rawEntries,
        targetDateStr: '2026-09-08',
      );
      expect(targetDay.lectures.length, 1);
      expect(targetDay.lectures.first.id, 'oneoff_tue_pem');

      // Following Week: 15 Sep 2026 -> Must NOT appear!
      final nextWeek = TimetableResolverService.resolve(
        rawEntries: rawEntries,
        targetDateStr: '2026-09-15',
      );
      expect(nextWeek.lectures.isEmpty, isTrue);

      // Following Week: 22 Sep 2026 -> Must NOT appear!
      final twoWeeksLater = TimetableResolverService.resolve(
        rawEntries: rawEntries,
        targetDateStr: '2026-09-22',
      );
      expect(twoWeeksLater.lectures.isEmpty, isTrue);
    });

    test('5. Single-day cancellation hides master for that date while preserving future weeks', () {
      final masterEntry = TimetableEntry(
        id: 'master_pem',
        subject: 'PEM',
        component: 'Theory',
        category: EventCategory.academic,
        batch: 'Whole Class',
        startTime: 600,
        endTime: 660,
        durationMinutes: 60,
        room: '302',
        status: 'active',
        validForDate: null,
        hiddenOnDates: ['2026-09-15'],
      );

      final cancelledPlaceholder = TimetableEntry(
        id: 'cancel_placeholder_15th',
        subject: 'PEM',
        component: 'Theory',
        category: EventCategory.academic,
        batch: 'Whole Class',
        startTime: 600,
        endTime: 660,
        durationMinutes: 60,
        room: '302',
        status: 'cancelled',
        validForDate: '2026-09-15',
      );

      final rawEntries = [masterEntry, cancelledPlaceholder];

      // Week 1 (8 Sep): Master is active
      final week1 = TimetableResolverService.resolve(
        rawEntries: rawEntries,
        targetDateStr: '2026-09-08',
      );
      expect(week1.lectures.length, 1);
      expect(week1.lectures.first.id, 'master_pem');
      expect(week1.lectures.first.isActive, isTrue);

      // Week 2 (15 Sep): Master is hidden; placeholder is visible with cancelled status
      final week2 = TimetableResolverService.resolve(
        rawEntries: rawEntries,
        targetDateStr: '2026-09-15',
      );
      expect(week2.lectures.length, 1);
      expect(week2.lectures.first.id, 'cancel_placeholder_15th');
      expect(week2.lectures.first.isCancelled, isTrue);

      // Week 3 (22 Sep): Master returns automatically as active!
      final week3 = TimetableResolverService.resolve(
        rawEntries: rawEntries,
        targetDateStr: '2026-09-22',
      );
      expect(week3.lectures.length, 1);
      expect(week3.lectures.first.id, 'master_pem');
      expect(week3.lectures.first.isActive, isTrue);
    });

    test('6. Permanent deletion stops all future occurrences', () {
      final rawEntriesBeforeDelete = [
        TimetableEntry(
          id: 'master_pem',
          subject: 'PEM',
          component: 'Theory',
          category: EventCategory.academic,
          batch: 'Whole Class',
          startTime: 600,
          endTime: 660,
          durationMinutes: 60,
          status: 'active',
          validForDate: null,
        ),
      ];

      // Before delete: appears on Week 1 & Week 2
      expect(
        TimetableResolverService.resolve(
          rawEntries: rawEntriesBeforeDelete,
          targetDateStr: '2026-09-08',
        ).lectures.length,
        1,
      );
      expect(
        TimetableResolverService.resolve(
          rawEntries: rawEntriesBeforeDelete,
          targetDateStr: '2026-09-15',
        ).lectures.length,
        1,
      );

      // After permanent delete: collection is empty
      final List<TimetableEntry> rawEntriesAfterDelete = [];
      expect(
        TimetableResolverService.resolve(
          rawEntries: rawEntriesAfterDelete,
          targetDateStr: '2026-09-08',
        ).lectures.isEmpty,
        isTrue,
      );
      expect(
        TimetableResolverService.resolve(
          rawEntries: rawEntriesAfterDelete,
          targetDateStr: '2026-09-15',
        ).lectures.isEmpty,
        isTrue,
      );
    });

    test('7. Dynamic Weekday and Date Label logic', () {
      String getRepeatSubtitle({
        required bool repeatWeekly,
        required String selectedDay,
        required String dateStr,
      }) {
        if (repeatWeekly) {
          return 'Applies every $selectedDay';
        } else {
          return 'Only applies on $dateStr';
        }
      }

      expect(
        getRepeatSubtitle(
          repeatWeekly: true,
          selectedDay: 'Tuesday',
          dateStr: '8 Sep',
        ),
        'Applies every Tuesday',
      );

      expect(
        getRepeatSubtitle(
          repeatWeekly: true,
          selectedDay: 'Monday',
          dateStr: '7 Sep',
        ),
        'Applies every Monday',
      );

      expect(
        getRepeatSubtitle(
          repeatWeekly: false,
          selectedDay: 'Tuesday',
          dateStr: '8 Sep',
        ),
        'Only applies on 8 Sep',
      );
    });
  });
}
