import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/assignment.dart';
import '../models/assignment_submission.dart';
import '../app_settings.dart';
import '../user_roles.dart';

class AssignmentService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── STREAM ASSIGNMENTS FOR SECTION ──────────────────────────────────────────
  static Stream<List<Assignment>> streamAssignments({
    required String sectionId,
    String? studentBatch,
    bool isCRorSR = false,
  }) {
    if (sectionId.isEmpty) {
      return Stream.value([]);
    }

    return _db
        .collection('sections')
        .doc(sectionId)
        .collection('assignments')
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => Assignment.fromFirestore(doc))
              .where((a) => a.status == 'active')
              .toList();

          // Sort in memory by deadline ascending
          list.sort((a, b) => a.dueAt.compareTo(b.dueAt));

          // If student, filter out other batches
          if (!isCRorSR && studentBatch != null && studentBatch.trim().isNotEmpty) {
            final userBatch = studentBatch.trim().toUpperCase();
            return list.where((a) {
              final b = a.batch?.trim();
              if (b == null || b.isEmpty || b.toUpperCase() == 'WHOLE CLASS') {
                return true;
              }
              return b.toUpperCase() == userBatch;
            }).toList();
          }

          return list;
        });
  }

  // ─── STREAM STUDENT SUBMISSIONS ──────────────────────────────────────────────
  static Stream<Map<String, AssignmentSubmission>> streamSubmissions({
    required String studentId,
  }) {
    if (studentId.isEmpty) {
      return Stream.value({});
    }

    return _db
        .collection('users')
        .doc(studentId)
        .collection('assignment_submissions')
        .snapshots()
        .map((snapshot) {
          final map = <String, AssignmentSubmission>{};
          for (final doc in snapshot.docs) {
            final sub = AssignmentSubmission.fromFirestore(doc);
            map[sub.assignmentId] = sub;
          }
          return map;
        });
  }

  // ─── VALIDATE AND CREATE ASSIGNMENT (CR / SR) ───────────────────────────────
  static Future<Assignment> createAssignment({
    required String title,
    required String subject,
    String? component,
    String description = '',
    required DateTime dueAt,
    required String sectionId,
    String? batch,
    String? attachmentUrl,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Authentication required to create assignments');
    }

    final trimmedTitle = title.trim();
    final trimmedSubject = subject.trim();

    if (trimmedTitle.isEmpty) {
      throw ArgumentError('Assignment title is required');
    }
    if (trimmedSubject.isEmpty) {
      throw ArgumentError('Subject is required');
    }

    final now = DateTime.now();
    if (!dueAt.isAfter(now)) {
      throw ArgumentError('Deadline must be in the future');
    }

    final role = AppSettings.currentRole;
    if (role != UserRole.cr && role != UserRole.sr) {
      throw Exception('Only authorized CR or SR can create assignments');
    }

    // If SR, ensure subject matches their assigned subject
    if (role == UserRole.sr) {
      final srSub = AppSettings.srSubject?.trim().toLowerCase();
      if (srSub == null || srSub.isEmpty || srSub != trimmedSubject.toLowerCase()) {
        throw Exception('SR can only create assignments for their assigned subject: ${AppSettings.srSubject}');
      }
    }

    final creatorRole = role == UserRole.cr ? 'CR' : 'SR';
    // Generate clean unique ID
    final assignmentId = 'asgn_${sectionId}_${DateTime.now().millisecondsSinceEpoch}';

    final assignment = Assignment(
      id: assignmentId,
      title: trimmedTitle,
      description: description.trim(),
      subject: trimmedSubject,
      component: component,
      sectionId: sectionId,
      batch: (batch == null || batch == 'Whole Class' || batch.isEmpty)
          ? null
          : batch.trim(),
      createdBy: user.uid,
      creatorRole: creatorRole,
      createdAt: now,
      dueAt: dueAt,
      attachmentUrl: attachmentUrl?.trim(),
      status: 'active',
    );

    // 1. Ensure user role and division are synced in Firestore for CR/SR
    try {
      await _db.collection('users').doc(user.uid).set({
        'role': creatorRole,
        'division': sectionId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[ASSIGNMENT] Non-fatal user role sync warning: $e');
    }

    // 2. Save assignment to section's assignments collection
    await _db
        .collection('sections')
        .doc(sectionId)
        .collection('assignments')
        .doc(assignmentId)
        .set(assignment.toFirestore());

    // 3. Schedule deterministic reminders into notification_outbox
    try {
      await scheduleDeterministicReminders(assignment: assignment);
    } catch (e) {
      debugPrint('[ASSIGNMENT] Non-fatal reminder scheduling warning: $e');
    }

    debugPrint('[ASSIGNMENT] Created assignment $assignmentId with deadline: ${assignment.formattedDueDateTime}');
    return assignment;
  }

  // ─── UPDATE ASSIGNMENT (CR / SR) ─────────────────────────────────────────────
  static Future<void> updateAssignment({
    required Assignment existing,
    required String title,
    required String subject,
    String? component,
    String description = '',
    required DateTime dueAt,
    String? batch,
    String? attachmentUrl,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Authentication required');
    }

    final trimmedTitle = title.trim();
    final trimmedSubject = subject.trim();

    if (trimmedTitle.isEmpty) throw ArgumentError('Title is required');
    if (trimmedSubject.isEmpty) throw ArgumentError('Subject is required');

    final now = DateTime.now();
    if (!dueAt.isAfter(now)) {
      throw ArgumentError('Deadline must be in the future');
    }

    final role = AppSettings.currentRole;
    if (role != UserRole.cr && role != UserRole.sr) {
      throw Exception('Unauthorized');
    }

    final updated = existing.copyWith(
      title: trimmedTitle,
      subject: trimmedSubject,
      component: component,
      description: description.trim(),
      dueAt: dueAt,
      batch: (batch == null || batch == 'Whole Class' || batch.isEmpty) ? null : batch.trim(),
      attachmentUrl: attachmentUrl?.trim(),
      updatedAt: now,
    );

    await _db
        .collection('sections')
        .doc(existing.sectionId)
        .collection('assignments')
        .doc(existing.id)
        .set(updated.toFirestore(), SetOptions(merge: true));

    // If deadline changed, recalculate reminders
    if (existing.dueAt.millisecondsSinceEpoch != dueAt.millisecondsSinceEpoch) {
      await scheduleDeterministicReminders(assignment: updated);
    }
  }

  // ─── CANCEL OR DELETE ASSIGNMENT ─────────────────────────────────────────────
  static Future<void> cancelAssignment(Assignment assignment) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Authentication required');

    final role = AppSettings.currentRole;
    if (role != UserRole.cr && role != UserRole.sr) {
      throw Exception('Unauthorized');
    }

    await _db
        .collection('sections')
        .doc(assignment.sectionId)
        .collection('assignments')
        .doc(assignment.id)
        .update({
          'status': 'cancelled',
          'updatedAt': FieldValue.serverTimestamp(),
        });

    // Invalidate future reminders
    await cancelDeterministicReminders(assignment.id);
  }

  // ─── DETERMINISTIC REMINDER SCHEDULING (24h, 6h, 1h) ─────────────────────────
  static Future<void> scheduleDeterministicReminders({
    required Assignment assignment,
  }) async {
    final now = DateTime.now();
    final dueAt = assignment.dueAt;
    final windows = {
      '24h': const Duration(hours: 24),
      '6h': const Duration(hours: 6),
      '1h': const Duration(hours: 1),
    };

    final batch = _db.batch();

    for (final entry in windows.entries) {
      final windowName = entry.key;
      final duration = entry.value;
      final reminderTime = dueAt.subtract(duration);
      final docId = 'assignment_${assignment.id}_$windowName';
      final outboxRef = _db.collection('notification_outbox').doc(docId);

      // Only schedule if reminder window has NOT already passed
      if (reminderTime.isAfter(now)) {
        final timeRemainingLabel = windowName == '24h'
            ? '24 hours'
            : (windowName == '6h' ? '6 hours' : '1 hour');

        batch.set(outboxRef, {
          'notificationId': docId,
          'type': 'assignment_reminder',
          'assignmentId': assignment.id,
          'window': windowName,
          'title': '⏰ ${assignment.subject}: ${assignment.title}',
          'body': 'Due ${assignment.formattedDueDateTime} ($timeRemainingLabel remaining).',
          'division': assignment.sectionId,
          if (assignment.batch != null && assignment.batch!.isNotEmpty)
            'batch': assignment.batch,
          'subject': assignment.subject,
          'dueAt': Timestamp.fromDate(dueAt),
          'nextRetryAt': Timestamp.fromDate(reminderTime),
          'processed': false,
          'attempts': 0,
          'uid': assignment.createdBy,
          'createdAt': FieldValue.serverTimestamp(),
          'deepLink': '/assignment/${assignment.id}',
        }, SetOptions(merge: true));

        debugPrint('[REMINDER_SCHEDULED] Window: $windowName at $reminderTime (Doc: $docId)');
      } else {
        // If window already passed, ensure any existing doc is marked cancelled
        batch.set(outboxRef, {
          'processed': true,
          'status': 'CANCELLED',
          'reason': 'window_passed',
          'cancelledAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        debugPrint('[REMINDER_SKIPPED] Window: $windowName already in past for dueAt: $dueAt');
      }
    }

    try {
      await batch.commit();
    } catch (e) {
      debugPrint('[REMINDER_SCHEDULE_ERROR] Failed to commit reminder batch: $e');
    }
  }

  // ─── CANCEL DETERMINISTIC REMINDERS ──────────────────────────────────────────
  static Future<void> cancelDeterministicReminders(String assignmentId) async {
    const windows = ['24h', '6h', '1h'];
    final batch = _db.batch();

    for (final window in windows) {
      final docId = 'assignment_${assignmentId}_$window';
      final ref = _db.collection('notification_outbox').doc(docId);
      batch.set(ref, {
        'processed': true,
        'status': 'CANCELLED',
        'reason': 'assignment_cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    try {
      await batch.commit();
      debugPrint('[REMINDERS_CANCELLED] Cancelled reminders for $assignmentId');
    } catch (e) {
      debugPrint('[REMINDERS_CANCEL_ERROR] $e');
    }
  }

  // ─── MARK AS SUBMITTED / PENDING (STUDENT ONLY) ──────────────────────────────
  static Future<void> setSubmissionState({
    required String assignmentId,
    required String sectionId,
    required bool isSubmitted,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Authentication required');
    final uid = user.uid;

    final sub = AssignmentSubmission(
      assignmentId: assignmentId,
      studentId: uid,
      sectionId: sectionId,
      isSubmitted: isSubmitted,
      submittedAt: isSubmitted ? DateTime.now() : null,
    );

    final batch = _db.batch();

    // 1. User private collection for fast single-stream lookups
    final userSubRef = _db
        .collection('users')
        .doc(uid)
        .collection('assignment_submissions')
        .doc(assignmentId);
    batch.set(userSubRef, sub.toFirestore(), SetOptions(merge: true));

    // 2. Assignment subcollection so CR/worker can check without touching assignment doc
    final sectionSubRef = _db
        .collection('sections')
        .doc(sectionId)
        .collection('assignments')
        .doc(assignmentId)
        .collection('submissions')
        .doc(uid);
    batch.set(sectionSubRef, sub.toFirestore(), SetOptions(merge: true));

    await batch.commit();
    debugPrint('[SUBMISSION] Set submission status for assignment $assignmentId to $isSubmitted for student $uid');
  }

  // ─── REMINDER PREFERENCES ───────────────────────────────────────────────────
  static Future<AssignmentReminderPreference> loadReminderPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final r24 = prefs.getBool('pref_assignment_reminder_24h') ?? true;
    final r6 = prefs.getBool('pref_assignment_reminder_6h') ?? true;
    final r1 = prefs.getBool('pref_assignment_reminder_1h') ?? true;
    return AssignmentReminderPreference(
      remind24h: r24,
      remind6h: r6,
      remind1h: r1,
    );
  }

  static Future<void> saveReminderPreferences(
    AssignmentReminderPreference pref,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pref_assignment_reminder_24h', pref.remind24h);
    await prefs.setBool('pref_assignment_reminder_6h', pref.remind6h);
    await prefs.setBool('pref_assignment_reminder_1h', pref.remind1h);

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await _db.collection('users').doc(user.uid).set({
          'assignmentReminderPreferences': pref.toMap(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('[PREF_SYNC_ERROR] Failed to sync reminder prefs to firestore: $e');
      }
    }
  }
}
