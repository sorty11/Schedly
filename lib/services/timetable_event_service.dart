import 'package:flutter/foundation.dart';
import '../app_settings.dart';
import '../user_roles.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:schedly/models/timetable_entry.dart';
import 'package:schedly/services/app_notification_service.dart';
import 'package:schedly/services/local_notification_service.dart';
import 'package:schedly/timetable_manager.dart';

class TimetableEventService {
  static Future<void> handleModification({
    required String division,
    required String day,
    TimetableEntry? oldEntry,
    TimetableEntry? newEntry,
    bool isCancel = false,
    bool isRestore = false,
    bool isDelete = false,
  }) async {
    String title = '';
    String message = '';
    String type = '';
    bool makeAnnouncement = false;

    // Helper to format date
    String dateContext = day;
    final targetDateStr = newEntry?.validForDate ?? oldEntry?.validForDate;
    if (targetDateStr != null) {
      try {
        final parts = targetDateStr.split('-');
        final y = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        final d = int.parse(parts[2]);
        final dt = DateTime(y, m, d);

        const monthNames = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];
        dateContext = '${dt.day} ${monthNames[dt.month - 1]}';
      } catch (_) {}
    }

    // Determine the nature of the change
    if (isCancel && oldEntry != null) {
      final timeStr = TimetableManager.formatTime(
        oldEntry.startTime,
        oldEntry.endTime,
      );
      title = 'Lecture Cancelled';
      message =
          '${oldEntry.displaySubject} on $dateContext at $timeStr has been cancelled.';
      type = 'cancel';
      makeAnnouncement = true;
    } else if (isRestore && oldEntry != null) {
      final timeStr = TimetableManager.formatTime(
        oldEntry.startTime,
        oldEntry.endTime,
      );
      title = 'Lecture Restored';
      message = '${oldEntry.displaySubject}\n$dateContext • $timeStr';
      type = 'add';
    } else if (isDelete && oldEntry != null) {
      if (oldEntry.isHoliday) {
        title = 'Holiday Removed';
        message = 'The holiday on $dateContext has been removed.';
        type = 'cancel';
      } else if (oldEntry.validForDate != null) {
        title = 'Override Removed';
        message =
            'The schedule override for ${oldEntry.displaySubject} on $dateContext was removed.';
        type = 'cancel';
      } else {
        title = 'Lecture Deleted';
        message =
            '${oldEntry.displaySubject} has been permanently removed from $day.';
        type = 'cancel';
      }
    } else if (oldEntry == null && newEntry != null) {
      if (newEntry.isHoliday) {
        title = 'Holiday Declared';
        message = '${newEntry.displaySubject}\n$dateContext';
        type = 'announcement';
        makeAnnouncement = true;
      } else {
        final timeStr = TimetableManager.formatTime(
          newEntry.startTime,
          newEntry.endTime,
        );
        title = newEntry.validForDate != null
            ? 'Extra Lecture Added'
            : 'New Lecture Added';
        message = '${newEntry.displaySubject}\n$dateContext • $timeStr';
        type = 'add';
        makeAnnouncement = true;
      }
    } else if (oldEntry != null && newEntry != null) {
      bool statusChanged = oldEntry.status != newEntry.status;
      bool subjectChanged = oldEntry.displaySubject != newEntry.displaySubject;
      bool roomChanged = oldEntry.room != newEntry.room;
      bool timeChanged =
          oldEntry.startTime != newEntry.startTime ||
          oldEntry.endTime != newEntry.endTime;
      bool batchChanged = oldEntry.batch != newEntry.batch;
      bool typeChanged = oldEntry.component != newEntry.component;

      if (statusChanged && newEntry.status == 'cancelled') {
        final timeStr = TimetableManager.formatTime(
          oldEntry.startTime,
          oldEntry.endTime,
        );
        title = 'Lecture Cancelled';
        message =
            '${oldEntry.displaySubject} on $dateContext at $timeStr has been cancelled.';
        type = 'cancel';
        makeAnnouncement = true;
      } else if (subjectChanged &&
          !roomChanged &&
          !timeChanged &&
          !batchChanged &&
          !typeChanged) {
        title = 'Lecture Replaced';
        message =
            '${oldEntry.displaySubject} has been replaced with ${newEntry.displaySubject} on $dateContext.';
        type = 'edit';
        makeAnnouncement = true;
      } else if (roomChanged &&
          !subjectChanged &&
          !timeChanged &&
          !batchChanged &&
          !typeChanged) {
        final timeStr = TimetableManager.formatTime(
          newEntry.startTime,
          newEntry.endTime,
        );
        title = 'Room Changed';
        message =
            '${newEntry.displaySubject}\n$dateContext • $timeStr\nRoom changed\n${oldEntry.room ?? 'TBA'} → ${newEntry.room ?? 'TBA'}';
        type = 'room_change';
      } else if (timeChanged &&
          !subjectChanged &&
          !roomChanged &&
          !batchChanged &&
          !typeChanged) {
        final oldTimeStr = TimetableManager.formatTime(
          oldEntry.startTime,
          oldEntry.endTime,
        );
        final newTimeStr = TimetableManager.formatTime(
          newEntry.startTime,
          newEntry.endTime,
        );
        title = 'Lecture Time Updated';
        message =
            '${newEntry.displaySubject} on $dateContext\n$oldTimeStr → $newTimeStr';
        type = 'time_change';
        makeAnnouncement = true;
      } else if (batchChanged &&
          !subjectChanged &&
          !roomChanged &&
          !timeChanged &&
          !typeChanged) {
        title = 'Batch Updated';
        message =
            '${newEntry.displaySubject} on $dateContext\nNow assigned to Batch ${newEntry.batch}';
        type = 'edit';
      } else if (typeChanged &&
          !subjectChanged &&
          !roomChanged &&
          !timeChanged &&
          !batchChanged) {
        title = 'Lecture Updated';
        message =
            '${newEntry.subject} on $dateContext changed from ${oldEntry.component} to ${newEntry.component}.';
        type = 'edit';
      } else if (subjectChanged ||
          roomChanged ||
          timeChanged ||
          batchChanged ||
          typeChanged) {
        title = '${newEntry.displaySubject} updated on $dateContext';
        final List<String> changes = [];
        if (subjectChanged)
          changes.add(
            '• Subject: ${oldEntry.displaySubject} → ${newEntry.displaySubject}',
          );
        if (roomChanged)
          changes.add(
            '• Room: ${oldEntry.room ?? 'TBA'} → ${newEntry.room ?? 'TBA'}',
          );
        if (timeChanged) {
          final oldTimeStr = TimetableManager.formatTime(
            oldEntry.startTime,
            oldEntry.endTime,
          );
          final newTimeStr = TimetableManager.formatTime(
            newEntry.startTime,
            newEntry.endTime,
          );
          changes.add('• Time: $oldTimeStr → $newTimeStr');
        }
        if (batchChanged)
          changes.add('• Batch: ${oldEntry.batch} → ${newEntry.batch}');
        if (typeChanged)
          changes.add('• Type: ${oldEntry.component} → ${newEntry.component}');
        message = changes.join('\n');
        type = 'edit';
        makeAnnouncement = subjectChanged || timeChanged;
      } else {
        return;
      }
    } else {
      return;
    }

    try {
      // Primary Notification, Announcement & Outbox
      await AppNotificationService.dispatch(
        title: title,
        message: message,
        division: division,
        type: type,
        priority:
            (type == 'cancel' ||
                type == 'edit' ||
                type == 'time_change' ||
                type == 'room_change')
            ? 'High'
            : 'Normal',
      );

      // Resolve correct UID for outbox
      String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (AppSettings.currentRole == UserRole.faculty &&
          AppSettings.facultyId != null) {
        uid = AppSettings.facultyId!;
      }
      final baseNotificationId = 'tt_${DateTime.now().millisecondsSinceEpoch}';
      final priorityStr =
          (type == 'cancel' ||
              type == 'edit' ||
              type == 'time_change' ||
              type == 'room_change')
          ? 'high'
          : 'normal';

      // Resolve faculty mappings using facultyId or subject assignment
      final subjectToFacMap = await TimetableManager.getSubjectToFacultyIdMap(
        division,
      );
      final oldFacId = oldEntry?.facultyId?.isNotEmpty == true
          ? oldEntry!.facultyId
          : (oldEntry != null ? subjectToFacMap[oldEntry.subjectCode] : null);
      final newFacId = newEntry?.facultyId?.isNotEmpty == true
          ? newEntry!.facultyId
          : (newEntry != null ? subjectToFacMap[newEntry.subjectCode] : null);

      // If assigned to a faculty, also notify the faculty specifically
      if (oldFacId != null && newFacId != null && oldFacId != newFacId) {
        // Old faculty: lecture replaced/removed
        final Map<String, dynamic> oldFacultyPayload = {
          'notificationId': '${baseNotificationId}_fac_old',
          'type': 'cancel',
          'title': 'Lecture Replaced / Removed',
          'body':
              '${oldEntry!.displaySubject} in ${division.replaceAll('_', ' ')} on $dateContext has been replaced.',
          'division': oldFacId,
          'role': 'faculty',
          'priority': priorityStr,
          'processed': false,
          'attempts': 0,
          'nextRetryAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'uid': uid,
        };
        await FirebaseFirestore.instance
            .collection('notification_outbox')
            .add(oldFacultyPayload);

        // New faculty: lecture added/scheduled
        final Map<String, dynamic> newFacultyPayload = {
          'notificationId': '${baseNotificationId}_fac_new',
          'type': 'add',
          'title': 'New Lecture Assigned',
          'body':
              '${newEntry!.displaySubject} in ${division.replaceAll('_', ' ')} on $dateContext has been added.',
          'division': newFacId,
          'role': 'faculty',
          'priority': priorityStr,
          'processed': false,
          'attempts': 0,
          'nextRetryAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'uid': uid,
        };
        await FirebaseFirestore.instance
            .collection('notification_outbox')
            .add(newFacultyPayload);
      } else {
        final targetFacId = newFacId ?? oldFacId;
        if (targetFacId != null && targetFacId.isNotEmpty) {
          final Map<String, dynamic> facultyPayload = {
            'notificationId': '${baseNotificationId}_fac',
            'type': type,
            'title': title,
            'body': message,
            'division': targetFacId,
            'role': 'faculty',
            'priority': priorityStr,
            'processed': false,
            'attempts': 0,
            'nextRetryAt': FieldValue.serverTimestamp(),
            'createdAt': FieldValue.serverTimestamp(),
            'uid': uid,
          };
          await FirebaseFirestore.instance
              .collection('notification_outbox')
              .add(facultyPayload);
        }
      }

      // Automatically manage backend faculty reminders
      if (isCancel ||
          isDelete ||
          type == 'cancel' ||
          type == 'delete' ||
          (newEntry != null && newEntry.isHoliday)) {
        // Cancelled lecture or Holiday: NO reminder (remove existing reminder)
        final targetLecId = oldEntry?.id ?? newEntry?.id;
        if (targetLecId != null) {
          final reminderDocId = '${division}_$targetLecId';
          await FirebaseFirestore.instance
              .collection('faculty_reminders')
              .doc(reminderDocId)
              .delete();
        }
      } else if (newEntry != null && newFacId != null && newFacId.isNotEmpty) {
        // Effective reminder calculation (respects date-specific override time)
        DateTime lectureTime;
        if (targetDateStr != null) {
          try {
            final parts = targetDateStr.split('-');
            lectureTime = DateTime(
              int.parse(parts[0]),
              int.parse(parts[1]),
              int.parse(parts[2]),
              newEntry.startTime ~/ 60,
              newEntry.startTime % 60,
            );
          } catch (_) {
            lectureTime = _getNextOccurrence(day, newEntry.startTime);
          }
        } else {
          lectureTime = _getNextOccurrence(day, newEntry.startTime);
        }

        final scheduledFor = lectureTime.subtract(const Duration(minutes: 5));

        final reminderPayload = {
          'facultyId': newFacId,
          'lectureId': newEntry.id,
          'division': division,
          'title': '📚 Upcoming Class',
          'body':
              '${newEntry.displaySubject}\n${division.replaceAll('_', ' ')}\nRoom ${newEntry.room ?? 'TBA'}\nStarts in 5 minutes.',
          'scheduledFor': Timestamp.fromDate(scheduledFor),
          'processed': false,
          'createdAt': FieldValue.serverTimestamp(),
          'uid': uid,
        };

        // Deterministic ID overwrites existing reminder so replacement lectures follow the new time
        final reminderDocId = '${division}_${newEntry.id}';
        await FirebaseFirestore.instance
            .collection('faculty_reminders')
            .doc(reminderDocId)
            .set(reminderPayload);
      }
    } catch (e) {
      // Non-fatal: push notification outbox failure should never block timetable saves
      debugPrint(
        'OUTBOX WARNING (non-fatal): Failed to write notification outbox: $e',
      );
    }
    // 3. Local Push Notification
    final targetId = newEntry?.id ?? oldEntry?.id ?? '0';
    await LocalNotificationService.notifications.cancel(targetId.hashCode);

    // Only show immediate popup if not deleted/cancelled (for cancel we might want one, but cancel logic has its own if needed)
    // Actually user says: "Every timetable modification must automatically generate Local Notification"
    await LocalNotificationService.showNotification(
      title: title,
      body: message,
    );
  }

  static DateTime _getNextOccurrence(String dayName, int timeInMinutes) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final targetDay = days.indexOf(dayName) + 1; // 1 = Mon, 7 = Sun
    if (targetDay == 0) return DateTime.now(); // Fallback

    final now = DateTime.now();
    int daysToAdd = targetDay - now.weekday;
    if (daysToAdd < 0) {
      daysToAdd += 7;
    }

    final hour = timeInMinutes ~/ 60;
    final minute = timeInMinutes % 60;

    var nextDate = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(Duration(days: daysToAdd));
    nextDate = DateTime(
      nextDate.year,
      nextDate.month,
      nextDate.day,
      hour,
      minute,
    );

    // If it's today but the time has already passed, schedule for next week
    if (daysToAdd == 0 && nextDate.isBefore(now)) {
      nextDate = nextDate.add(const Duration(days: 7));
    }

    return nextDate;
  }
}
