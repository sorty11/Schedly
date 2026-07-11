import 'package:flutter/foundation.dart';
import '../app_settings.dart';
import '../user_roles.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:schedly/models/timetable_entry.dart';
import 'package:schedly/services/app_notification_service.dart';
import 'package:schedly/services/announcement_service.dart';
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
    
    // Determine the nature of the change
    if (isCancel && oldEntry != null) {
      final timeStr = TimetableManager.formatTime(oldEntry.startTime, oldEntry.endTime);
      title = 'Lecture Cancelled';
      message = 'Today\'s ${oldEntry.displaySubject} at $timeStr has been cancelled.';
      type = 'cancel';
      makeAnnouncement = true;
      
      // Local notification handled directly in Cancel button, or we can do it here.
    } else if (isRestore && oldEntry != null) {
      final timeStr = TimetableManager.formatTime(oldEntry.startTime, oldEntry.endTime);
      title = 'Lecture Restored';
      message = '${oldEntry.displaySubject}\n$day • $timeStr';
      type = 'add'; 
    } else if (isDelete && oldEntry != null) {
      title = 'Lecture Deleted';
      message = '${oldEntry.displaySubject} has been permanently removed.';
      type = 'cancel';
    } else if (oldEntry == null && newEntry != null) {
      final timeStr = TimetableManager.formatTime(newEntry.startTime, newEntry.endTime);
      title = 'New lecture added';
      message = '${newEntry.displaySubject}\n$day • $timeStr';
      type = 'add';
      makeAnnouncement = true;
    } else if (oldEntry != null && newEntry != null) {
      // Comparison logic
      final List<String> changes = [];
      bool subjectChanged = oldEntry.displaySubject != newEntry.displaySubject;
      bool roomChanged = oldEntry.room != newEntry.room;
      bool timeChanged = oldEntry.startTime != newEntry.startTime || oldEntry.endTime != newEntry.endTime;
      bool batchChanged = oldEntry.batch != newEntry.batch;
      bool typeChanged = oldEntry.component != newEntry.component; // Theory vs Lab
      
      if (subjectChanged && !roomChanged && !timeChanged && !batchChanged && !typeChanged) {
        title = 'Lecture Replaced';
        message = '${oldEntry.displaySubject} has been replaced with ${newEntry.displaySubject}.';
        type = 'edit';
        makeAnnouncement = true;
      } else if (roomChanged && !subjectChanged && !timeChanged && !batchChanged && !typeChanged) {
        final timeStr = TimetableManager.formatTime(newEntry.startTime, newEntry.endTime);
        title = 'Room Changed';
        message = '${newEntry.displaySubject}\n$day • $timeStr\nRoom changed\n${oldEntry.room ?? 'TBA'} → ${newEntry.room ?? 'TBA'}';
        type = 'room_change';
      } else if (timeChanged && !subjectChanged && !roomChanged && !batchChanged && !typeChanged) {
        final oldTimeStr = TimetableManager.formatTime(oldEntry.startTime, oldEntry.endTime);
        final newTimeStr = TimetableManager.formatTime(newEntry.startTime, newEntry.endTime);
        title = 'Lecture Time Updated';
        message = '${newEntry.displaySubject}\n$oldTimeStr → $newTimeStr';
        type = 'time_change';
        makeAnnouncement = true;
      } else if (batchChanged && !subjectChanged && !roomChanged && !timeChanged && !typeChanged) {
        title = 'Batch Updated';
        message = '${newEntry.displaySubject}\nNow assigned to Batch ${newEntry.batch}';
        type = 'edit';
      } else if (typeChanged && !subjectChanged && !roomChanged && !timeChanged && !batchChanged) {
        title = 'Lecture Updated';
        message = '${newEntry.subject} changed from ${oldEntry.component} to ${newEntry.component}.';
        type = 'edit';
      } else if (subjectChanged || roomChanged || timeChanged || batchChanged || typeChanged) {
        // Multiple changes
        title = '${newEntry.displaySubject} updated';
        if (subjectChanged) changes.add('• Subject: ${oldEntry.displaySubject} → ${newEntry.displaySubject}');
        if (roomChanged) changes.add('• Room: ${oldEntry.room ?? 'TBA'} → ${newEntry.room ?? 'TBA'}');
        if (timeChanged) {
           final oldTimeStr = TimetableManager.formatTime(oldEntry.startTime, oldEntry.endTime);
           final newTimeStr = TimetableManager.formatTime(newEntry.startTime, newEntry.endTime);
           changes.add('• Time: $oldTimeStr → $newTimeStr');
        }
        if (batchChanged) changes.add('• Batch: ${oldEntry.batch} → ${newEntry.batch}');
        if (typeChanged) changes.add('• Type: ${oldEntry.component} → ${newEntry.component}');
        message = changes.join('\n');
        type = 'edit';
        makeAnnouncement = subjectChanged || timeChanged;
      } else {
        // No meaningful change, do nothing
        return;
      }
    } else {
      return;
    }

    // 1. Create Notification (Updates Feed)
    await AppNotificationService.createNotification(
      title: title,
      message: message,
      division: division,
      type: type,
    );

    // 2. Announcements
    if (makeAnnouncement) {
      await AnnouncementService.createAnnouncement(
        title: title,
        message: message,
        priority: 'high',
        sectionId: division,
      );
    }

    // Trigger Render Backend Push Notification via Outbox
    // IMPORTANT: Wrapped in try-catch so outbox failures NEVER block the save operation
    try {
      final baseNotificationId = 'tt_${DateTime.now().millisecondsSinceEpoch}';
      final priority = (type == 'cancel' || type == 'edit' || type == 'time_change' || type == 'room_change') ? 'high' : 'normal';
      // Resolve correct UID for outbox
      String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (AppSettings.currentRole == UserRole.faculty && AppSettings.facultyId != null) {
        uid = AppSettings.facultyId!;
      }

      final Map<String, dynamic> divisionPayload = {
        'notificationId': baseNotificationId,
        'type': type,
        'title': title,
        'body': message,
        'division': division,
        'priority': priority,
        'processed': false,
        'attempts': 0,
        'nextRetryAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'uid': uid,
      };
      
      debugPrint('OUTBOX PAYLOAD (Division): $divisionPayload');
      final outboxRef = FirebaseFirestore.instance.collection('notification_outbox').doc();
      await outboxRef.set(divisionPayload);

      // If assigned to a faculty, also notify the faculty specifically
      debugPrint('[DEBUG_FAC_3] newEntry?.facultyId = ${newEntry?.facultyId} | oldEntry?.facultyId = ${oldEntry?.facultyId}');
      final facultyId = newEntry?.facultyId ?? oldEntry?.facultyId;
      if (facultyId != null && facultyId.isNotEmpty) {
        final Map<String, dynamic> facultyPayload = {
          'notificationId': '${baseNotificationId}_fac',
          'type': type,
          'title': title,
          'body': message,
          'division': facultyId,
          'role': 'faculty',
          'priority': priority,
          'processed': false,
          'attempts': 0,
          'nextRetryAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'uid': uid,
        };
        
        debugPrint('OUTBOX PAYLOAD (Faculty): $facultyPayload');
        final facultyOutboxRef = FirebaseFirestore.instance.collection('notification_outbox').doc();
        await facultyOutboxRef.set(facultyPayload);
      }

      // Automatically create a backend faculty reminder if it's an add or edit
      if (newEntry != null && newEntry.facultyId != null && newEntry.facultyId!.isNotEmpty) {
        // Only schedule if it's not a cancellation/deletion
        if (type != 'cancel' && type != 'delete') {
          final lectureTime = _getNextOccurrence(day, newEntry.startTime);
          final scheduledFor = lectureTime.subtract(const Duration(minutes: 5));
          
          final reminderPayload = {
            'facultyId': newEntry.facultyId,
            'lectureId': newEntry.id,
            'division': division,
            'title': '📚 Upcoming Class',
            'body': '${newEntry.displaySubject}\n${division.replaceAll('_', ' ')}\nRoom ${newEntry.room}\nStarts in 5 minutes.',
            'scheduledFor': Timestamp.fromDate(scheduledFor),
            'processed': false,
            'createdAt': FieldValue.serverTimestamp(),
            'uid': uid,
          };
          
          // Use a deterministic ID so edits overwrite the existing reminder rather than duplicating
          final reminderDocId = '${division}_${newEntry.id}';
          await FirebaseFirestore.instance.collection('faculty_reminders').doc(reminderDocId).set(reminderPayload);
          debugPrint('BACKEND REMINDER created: $reminderDocId for ${newEntry.facultyId} at $scheduledFor');
        }
      }
    } catch (e) {
      // Non-fatal: push notification outbox failure should never block timetable saves
      debugPrint('OUTBOX WARNING (non-fatal): Failed to write notification outbox: $e');
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
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final targetDay = days.indexOf(dayName) + 1; // 1 = Mon, 7 = Sun
    if (targetDay == 0) return DateTime.now(); // Fallback

    final now = DateTime.now();
    int daysToAdd = targetDay - now.weekday;
    if (daysToAdd < 0) {
      daysToAdd += 7;
    }
    
    final hour = timeInMinutes ~/ 60;
    final minute = timeInMinutes % 60;
    
    var nextDate = DateTime(now.year, now.month, now.day).add(Duration(days: daysToAdd));
    nextDate = DateTime(nextDate.year, nextDate.month, nextDate.day, hour, minute);
    
    // If it's today but the time has already passed, schedule for next week
    if (daysToAdd == 0 && nextDate.isBefore(now)) {
      nextDate = nextDate.add(const Duration(days: 7));
    }
    
    return nextDate;
  }
}
