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
}
