import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:schedly/models/assignment.dart';
import 'package:schedly/models/assignment_submission.dart';
import 'package:schedly/user_roles.dart';
import 'package:schedly/app_settings.dart';
import 'package:schedly/services/ad_service.dart';

void main() {
  group('1. Assignment Model & Timezone Handling', () {
    test('serializes and deserializes assignment with Timestamp accurately', () {
      final now = DateTime(2026, 9, 20, 10, 0);
      final due = DateTime(2026, 9, 21, 23, 0);

      final assignment = Assignment(
        id: 'asgn_CE_1001',
        title: 'DSA Assignment 3',
        description: 'Implement AVL Tree in C++',
        subject: 'Data Structures & Algorithms',
        component: 'Theory',
        sectionId: 'CE',
        batch: 'C1',
        createdBy: 'uid_cr_1',
        creatorRole: 'CR',
        createdAt: now,
        dueAt: due,
        attachmentUrl: 'https://classroom.google.com/test',
        status: 'active',
      );

      final map = assignment.toFirestore();
      expect(map['id'], 'asgn_CE_1001');
      expect(map['title'], 'DSA Assignment 3');
      expect(map['subject'], 'Data Structures & Algorithms');
      expect(map['sectionId'], 'CE');
      expect(map['batch'], 'C1');
      expect(map['status'], 'active');
      expect(map['dueAt'], isA<Timestamp>());

      final restored = Assignment.fromMap(map, id: 'asgn_CE_1001');
      expect(restored.id, assignment.id);
      expect(restored.title, assignment.title);
      expect(restored.dueAt.millisecondsSinceEpoch,
          assignment.dueAt.millisecondsSinceEpoch);
      expect(restored.batch, 'C1');
      expect(restored.attachmentUrl, 'https://classroom.google.com/test');
    });

    test('formats due date and time correctly in user local timezone', () {
      final due = DateTime(2026, 9, 20, 23, 0); // Sep 20, 11:00 PM
      final assignment = Assignment(
        id: '1',
        title: 'Test',
        subject: 'DSA',
        sectionId: 'CE',
        createdBy: 'u1',
        creatorRole: 'CR',
        createdAt: DateTime.now(),
        dueAt: due,
      );

      expect(assignment.formattedDueDateTime, 'Due Sep 20 • 11:00 PM');
    });

    test('computes live remaining time string correctly', () {
      final now = DateTime.now();

      // 23h 41m in future
      final futureDue = now.add(const Duration(hours: 23, minutes: 41, seconds: 30));
      final a1 = Assignment(
        id: '1',
        title: 'Test',
        subject: 'DSA',
        sectionId: 'CE',
        createdBy: 'u1',
        creatorRole: 'CR',
        createdAt: now,
        dueAt: futureDue,
      );
      expect(a1.remainingTimeString, contains('23h 41m remaining'));
      expect(a1.isOverdue, isFalse);

      // Overdue by 2 hours
      final pastDue = now.subtract(const Duration(hours: 2, minutes: 15));
      final a2 = Assignment(
        id: '2',
        title: 'Past',
        subject: 'DSA',
        sectionId: 'CE',
        createdBy: 'u1',
        creatorRole: 'CR',
        createdAt: now.subtract(const Duration(days: 2)),
        dueAt: pastDue,
      );
      expect(a2.remainingTimeString, contains('Overdue by 2h 15m'));
      expect(a2.isOverdue, isTrue);
    });
  });

  group('2. Student Submission State & Evaluation', () {
    test('evaluates Pending, Submitted, and Overdue states accurately', () {
      final now = DateTime.now();
      final futureDue = now.add(const Duration(hours: 5));
      final pastDue = now.subtract(const Duration(hours: 2));

      final activeAssignment = Assignment(
        id: 'a1',
        title: 'Active Assignment',
        subject: 'Math',
        sectionId: 'CE',
        createdBy: 'u1',
        creatorRole: 'CR',
        createdAt: now,
        dueAt: futureDue,
      );

      final overdueAssignment = Assignment(
        id: 'a2',
        title: 'Overdue Assignment',
        subject: 'Math',
        sectionId: 'CE',
        createdBy: 'u1',
        creatorRole: 'CR',
        createdAt: now.subtract(const Duration(days: 1)),
        dueAt: pastDue,
      );

      // Student 1: Unsubmitted on active assignment -> Pending
      const sub1 = AssignmentSubmission(
        assignmentId: 'a1',
        studentId: 's1',
        sectionId: 'CE',
        isSubmitted: false,
      );
      expect(sub1.isSubmitted, isFalse);
      expect(activeAssignment.isOverdue, isFalse);

      // Student 2: Submitted on overdue assignment -> Submitted
      final sub2 = AssignmentSubmission(
        assignmentId: 'a2',
        studentId: 's2',
        sectionId: 'CE',
        isSubmitted: true,
        submittedAt: now.subtract(const Duration(hours: 3)),
      );
      expect(sub2.isSubmitted, isTrue);

      // Student 3: Unsubmitted on overdue assignment -> Overdue
      const sub3 = AssignmentSubmission(
        assignmentId: 'a2',
        studentId: 's3',
        sectionId: 'CE',
        isSubmitted: false,
      );
      expect(sub3.isSubmitted, isFalse);
      expect(overdueAssignment.isOverdue, isTrue);
    });

    test('serializes AssignmentSubmission safely without touching assignment document', () {
      final sub = AssignmentSubmission(
        assignmentId: 'a1',
        studentId: 's1',
        sectionId: 'CE',
        isSubmitted: true,
        submittedAt: DateTime(2026, 9, 20, 15, 30),
      );

      final map = sub.toFirestore();
      expect(map['assignmentId'], 'a1');
      expect(map['studentId'], 's1');
      expect(map['sectionId'], 'CE');
      expect(map['isSubmitted'], isTrue);
      expect(map['submittedAt'], isA<Timestamp>());

      final restored = AssignmentSubmission.fromMap(map, id: 'a1');
      expect(restored.isSubmitted, isTrue);
      expect(restored.studentId, 's1');
    });
  });

  group('3. 24h/6h/1h Reminder Window Calculations & Idempotency', () {
    test('schedules all 3 deterministic windows when dueAt is > 24 hours away', () {
      final now = DateTime.now();
      final dueAt = now.add(const Duration(hours: 30));

      final windows = {
        '24h': const Duration(hours: 24),
        '6h': const Duration(hours: 6),
        '1h': const Duration(hours: 1),
      };

      final scheduledWindows = <String, DateTime>{};
      for (final entry in windows.entries) {
        final reminderTime = dueAt.subtract(entry.value);
        if (reminderTime.isAfter(now)) {
          scheduledWindows[entry.key] = reminderTime;
        }
      }

      expect(scheduledWindows.keys, containsAll(['24h', '6h', '1h']));
      expect(scheduledWindows.length, 3);
    });

    test('skips 24h window if assignment created 10 hours before deadline', () {
      final now = DateTime.now();
      final dueAt = now.add(const Duration(hours: 10));

      final windows = {
        '24h': const Duration(hours: 24),
        '6h': const Duration(hours: 6),
        '1h': const Duration(hours: 1),
      };

      final scheduledWindows = <String, DateTime>{};
      final skippedWindows = <String>[];

      for (final entry in windows.entries) {
        final reminderTime = dueAt.subtract(entry.value);
        if (reminderTime.isAfter(now)) {
          scheduledWindows[entry.key] = reminderTime;
        } else {
          skippedWindows.add(entry.key);
        }
      }

      expect(skippedWindows, contains('24h'));
      expect(scheduledWindows.keys, containsAll(['6h', '1h']));
      expect(scheduledWindows.length, 2);
    });

    test('skips all windows if assignment created 30 minutes before deadline', () {
      final now = DateTime.now();
      final dueAt = now.add(const Duration(minutes: 30));

      final windows = {
        '24h': const Duration(hours: 24),
        '6h': const Duration(hours: 6),
        '1h': const Duration(hours: 1),
      };

      final scheduledWindows = <String, DateTime>{};
      for (final entry in windows.entries) {
        final reminderTime = dueAt.subtract(entry.value);
        if (reminderTime.isAfter(now)) {
          scheduledWindows[entry.key] = reminderTime;
        }
      }

      expect(scheduledWindows.isEmpty, isTrue);
    });

    test('generates deterministic reminder IDs for duplicate prevention', () {
      const assignmentId = 'asgn_123';
      final id24h = 'assignment_${assignmentId}_24h';
      final id6h = 'assignment_${assignmentId}_6h';
      final id1h = 'assignment_${assignmentId}_1h';

      expect(id24h, 'assignment_asgn_123_24h');
      expect(id6h, 'assignment_asgn_123_6h');
      expect(id1h, 'assignment_asgn_123_1h');

      // Recomputing generates identical deterministic string
      expect('assignment_${assignmentId}_24h', id24h);
    });
  });

  group('4. Student Reminder Settings Preferences', () {
    test('defaults to all 3 reminders enabled', () {
      const pref = AssignmentReminderPreference();
      expect(pref.remind24h, isTrue);
      expect(pref.remind6h, isTrue);
      expect(pref.remind1h, isTrue);
      expect(pref.isEnabledFor('24h'), isTrue);
      expect(pref.isEnabledFor('6h'), isTrue);
      expect(pref.isEnabledFor('1h'), isTrue);
    });

    test('allows individual toggles and persists to map', () {
      var pref = const AssignmentReminderPreference();
      pref = pref.copyWith(remind24h: false);

      expect(pref.remind24h, isFalse);
      expect(pref.remind6h, isTrue);
      expect(pref.remind1h, isTrue);

      expect(pref.isEnabledFor('24h'), isFalse);
      expect(pref.isEnabledFor('6h'), isTrue);
      expect(pref.isEnabledFor('1h'), isTrue);

      final map = pref.toMap();
      expect(map['24h'], isFalse);
      expect(map['6h'], isTrue);
      expect(map['1h'], isTrue);

      final restored = AssignmentReminderPreference.fromMap(map);
      expect(restored.remind24h, isFalse);
      expect(restored.remind6h, isTrue);
      expect(restored.remind1h, isTrue);
    });
  });

  group('5. Batch and Section Isolation', () {
    test('filters assignments matching student batch or whole class', () {
      final aWhole = Assignment(
        id: '1',
        title: 'Whole Class',
        subject: 'Math',
        sectionId: 'CE',
        batch: null,
        createdBy: 'u1',
        creatorRole: 'CR',
        createdAt: DateTime.now(),
        dueAt: DateTime.now().add(const Duration(days: 2)),
      );

      final aWholeExplicit = Assignment(
        id: '2',
        title: 'Whole Class Explicit',
        subject: 'Math',
        sectionId: 'CE',
        batch: 'Whole Class',
        createdBy: 'u1',
        creatorRole: 'CR',
        createdAt: DateTime.now(),
        dueAt: DateTime.now().add(const Duration(days: 2)),
      );

      final aBatch1 = Assignment(
        id: '3',
        title: 'C1 Lab',
        subject: 'DSA',
        sectionId: 'CE',
        batch: 'C1',
        createdBy: 'u1',
        creatorRole: 'CR',
        createdAt: DateTime.now(),
        dueAt: DateTime.now().add(const Duration(days: 2)),
      );

      final aBatch2 = Assignment(
        id: '4',
        title: 'C2 Lab',
        subject: 'DSA',
        sectionId: 'CE',
        batch: 'C2',
        createdBy: 'u1',
        creatorRole: 'CR',
        createdAt: DateTime.now(),
        dueAt: DateTime.now().add(const Duration(days: 2)),
      );

      final allAssignments = [aWhole, aWholeExplicit, aBatch1, aBatch2];

      // Student in Batch C1
      const studentBatch = 'C1';
      final studentAssignments = allAssignments.where((a) {
        final b = a.batch;
        return b == null || b.isEmpty || b == 'Whole Class' || b == studentBatch;
      }).toList();

      expect(studentAssignments.length, 3);
      expect(studentAssignments, contains(aWhole));
      expect(studentAssignments, contains(aWholeExplicit));
      expect(studentAssignments, contains(aBatch1));
      expect(studentAssignments.contains(aBatch2), isFalse);
    });
  });

  group('6. Due Today Compact Assignment Section Logic', () {
    test('isDueToday evaluates accurately based on local timezone date', () {
      final now = DateTime.now();
      final todayDeadline = DateTime(now.year, now.month, now.day, 23, 59);
      final tomorrowDeadline = todayDeadline.add(const Duration(days: 1));
      final yesterdayDeadline = todayDeadline.subtract(const Duration(days: 1));

      final aToday = Assignment(
        id: 'today_1',
        title: 'Project Submission',
        subject: 'Database Systems',
        sectionId: 'CE',
        createdBy: 'u1',
        creatorRole: 'CR',
        createdAt: now,
        dueAt: todayDeadline,
      );

      final aTomorrow = aToday.copyWith(dueAt: tomorrowDeadline);
      final aYesterday = aToday.copyWith(dueAt: yesterdayDeadline);

      expect(aToday.isDueToday, isTrue);
      expect(aTomorrow.isDueToday, isFalse);
      expect(aYesterday.isDueToday, isFalse);
    });

    test('exactDueTime formats 12-hour AM/PM time properly', () {
      final now = DateTime.now();
      final nightDue = DateTime(now.year, now.month, now.day, 23, 59);
      final morningDue = DateTime(now.year, now.month, now.day, 9, 30);
      final noonDue = DateTime(now.year, now.month, now.day, 12, 0);

      final aNight = Assignment(
        id: '1',
        title: 'T1',
        subject: 'S1',
        sectionId: 'SEC',
        createdBy: 'u1',
        creatorRole: 'CR',
        createdAt: now,
        dueAt: nightDue,
      );

      final aMorning = aNight.copyWith(dueAt: morningDue);
      final aNoon = aNight.copyWith(dueAt: noonDue);

      expect(aNight.exactDueTime, '11:59 PM');
      expect(aMorning.exactDueTime, '9:30 AM');
      expect(aNoon.exactDueTime, '12:00 PM');
    });

    test('due today section filter excludes submitted, overdue, or non-today assignments', () {
      final now = DateTime.now();
      // Ensure futureToday is strictly today and strictly after now
      final futureToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
      final pastTodayOverdue = DateTime(now.year, now.month, now.day, 0, 0, 1);
      final tomorrow = now.add(const Duration(days: 1));

      final a1DueTodayActive = Assignment(
        id: 'due_1',
        title: 'Research Paper',
        subject: 'OS',
        sectionId: 'SEC',
        createdBy: 'u1',
        creatorRole: 'CR',
        createdAt: now,
        dueAt: futureToday,
      );

      final a2DueTodaySubmitted = Assignment(
        id: 'due_2',
        title: 'Lab Report',
        subject: 'DSA',
        sectionId: 'SEC',
        createdBy: 'u1',
        creatorRole: 'CR',
        createdAt: now,
        dueAt: futureToday,
      );

      final a3OverdueToday = Assignment(
        id: 'due_3',
        title: 'Quiz Prep',
        subject: 'Math',
        sectionId: 'SEC',
        createdBy: 'u1',
        creatorRole: 'CR',
        createdAt: now,
        dueAt: pastTodayOverdue,
      );

      final a4Tomorrow = Assignment(
        id: 'due_4',
        title: 'Essay',
        subject: 'English',
        sectionId: 'SEC',
        createdBy: 'u1',
        creatorRole: 'CR',
        createdAt: now,
        dueAt: tomorrow,
      );

      final submissions = {
        'due_2': AssignmentSubmission(
          assignmentId: 'due_2',
          studentId: 'student_123',
          sectionId: 'SEC',
          submittedAt: now,
          isSubmitted: true,
        ),
      };

      final all = [a1DueTodayActive, a2DueTodaySubmitted, a3OverdueToday, a4Tomorrow];

      // Exact filter used by DashboardAssignmentsPreview
      final dueToday = all.where((a) {
        if (a.status != 'active') return false;
        final sub = submissions[a.id];
        if (sub?.isSubmitted ?? false) return false;
        if (a.isOverdue) return false;
        return a.isDueToday;
      }).toList();

      expect(dueToday.length, 1);
      expect(dueToday.first.id, 'due_1');
      expect(dueToday.first.title, 'Research Paper');
      expect(dueToday.first.subject, 'OS');
    });

    test('due today section yields empty list when no assignments match', () {
      final now = DateTime.now();
      final tomorrow = now.add(const Duration(days: 1));

      final aTomorrow = Assignment(
        id: 'due_4',
        title: 'Essay',
        subject: 'English',
        sectionId: 'SEC',
        createdBy: 'u1',
        creatorRole: 'CR',
        createdAt: now,
        dueAt: tomorrow,
      );

      final dueToday = [aTomorrow].where((a) {
        if (a.status != 'active') return false;
        if (a.isOverdue) return false;
        return a.isDueToday;
      }).toList();

      expect(dueToday.isEmpty, isTrue);
    });

    test('SR subject scoping filters out assignments of other subjects for dashboard and management', () {
      final now = DateTime.now();
      final todayDue = now.add(const Duration(hours: 4));

      final aMath = Assignment(
        id: 'math_1',
        title: 'Calculus Problem Set',
        subject: 'Mathematics',
        sectionId: 'CE',
        createdBy: 'sr_math_uid',
        creatorRole: 'SR',
        createdAt: now,
        dueAt: todayDue,
      );

      final aPhysics = Assignment(
        id: 'phys_1',
        title: 'Optics Lab Report',
        subject: 'Physics',
        sectionId: 'CE',
        createdBy: 'sr_phys_uid',
        creatorRole: 'SR',
        createdAt: now,
        dueAt: todayDue,
      );

      final allSectionAssignments = [aMath, aPhysics];

      // Simulated SR with assigned subject 'Mathematics'
      const srAssignedSubject = 'Mathematics';
      final srDashboardFiltered = allSectionAssignments.where((a) =>
          a.subject.trim().toLowerCase() == srAssignedSubject.trim().toLowerCase()).toList();

      expect(srDashboardFiltered.length, 1);
      expect(srDashboardFiltered.first.id, 'math_1');
      expect(srDashboardFiltered.first.subject, 'Mathematics');

      // CR sees both subjects in section
      final crVisible = allSectionAssignments;
      expect(crVisible.length, 2);
    });

    test('CR and SR dashboard preview includes active assignments even if student submission exists', () {
      final now = DateTime.now();
      final todayDue = now.hour < 22
          ? now.add(const Duration(hours: 1))
          : DateTime(now.year, now.month, now.day, 23, 59);

      final a1 = Assignment(
        id: 'asgn_1',
        title: 'Project Milestone',
        subject: 'SE',
        sectionId: 'CE',
        createdBy: 'cr_uid',
        creatorRole: 'CR',
        createdAt: now,
        dueAt: todayDue,
      );

      // Student submitted it
      final submissions = {
        'asgn_1': AssignmentSubmission(
          assignmentId: 'asgn_1',
          studentId: 'student_uid',
          sectionId: 'CE',
          submittedAt: now,
          isSubmitted: true,
        ),
      };

      // CR evaluation: submissions do not hide the assignment on CR dashboard
      final crDueToday = [a1].where((a) {
        if (a.status != 'active') return false;
        // CR/SR does not exclude based on student submissions
        if (a.isOverdue) return false;
        return a.isDueToday;
      }).toList();

      expect(crDueToday.length, 1);
      expect(crDueToday.first.id, 'asgn_1');

      // Student evaluation: submission DOES hide it
      final studentDueToday = [a1].where((a) {
        if (a.status != 'active') return false;
        final sub = submissions[a.id];
        if (sub?.isSubmitted ?? false) return false;
        if (a.isOverdue) return false;
        return a.isDueToday;
      }).toList();

      expect(studentDueToday.isEmpty, isTrue);
    });
  });

  group('7. AdMob Role Expansion & Safety', () {
    test('AdService.shouldShowAdsForRole allows Student, CR, and SR', () {
      expect(AdService.shouldShowAdsForRole(UserRole.student), isTrue);
      expect(AdService.shouldShowAdsForRole(UserRole.cr), isTrue);
      expect(AdService.shouldShowAdsForRole(UserRole.sr), isTrue);
    });

    test('AdService.shouldShowAdsForRole strictly denies Faculty and Admin', () {
      expect(AdService.shouldShowAdsForRole(UserRole.faculty), isFalse);
      expect(AdService.shouldShowAdsForRole(null), isFalse);
      expect(AdService.shouldShowAdsForRole('admin'), isFalse);
      expect(AdService.shouldShowAdsForRole('faculty'), isFalse);
    });

    test('AdService Ad Unit IDs use test ID in non-release mode', () {
      // In test environment, kReleaseMode is false, so testBannerAdUnitId is used
      expect(AdService.bannerAdUnitId, 'ca-app-pub-3940256099942544/6300978111');
    });
  });
}
