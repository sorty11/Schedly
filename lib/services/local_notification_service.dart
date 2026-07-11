import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/faculty_lecture_context.dart';
import '../app_settings.dart';

class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin notifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    if (kIsWeb) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);

    await notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        if (response.payload == 'faculty_dashboard') {
          // Since the app already handles default routing to the dashboard when 
          // a faculty opens it, this just serves as an explicit tap handling stub.
        }
      },
    );

    final androidImplementation = notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidImplementation?.requestNotificationsPermission();
    await androidImplementation?.requestExactAlarmsPermission();

    // Initialize Timezone
    tz.initializeTimeZones();
    try {
      final timeZone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZone.toString()));
    } catch (e) {
      debugPrint('Could not get local timezone: $e');
    }
  }

  static Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'faculty_reminders',
      'Faculty Reminders',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const details = NotificationDetails(android: androidDetails);

    await notifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
      payload: payload,
    );
  }

  static Future<void> schedulePendingReminder(int pendingCount) async {
    // We only want to schedule if there are pending lectures.
    // If pendingCount is 0, we can cancel the existing reminder.
    if (pendingCount == 0) {
      await notifications.cancel(999);
      return;
    }

    // Schedule for 9:00 PM today, or tomorrow if it's past 9 PM
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, 21, 0);

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      'reminders',
      'Reminders',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);

    await notifications.zonedSchedule(
      999, // Unique ID for this reminder
      'Lecture Verification Required',
      'You have $pendingCount pending lectures waiting for verification.',
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // Repeat daily
    );
  }

  static Future<void> scheduleFacultyReminders(List<FacultyLectureContext> todayLectures, int reminderMinutes) async {
    if (kIsWeb) {
      // Backend now handles web reminders automatically via faculty_reminders collection on lecture creation
      return;
    }

    if (reminderMinutes <= 0) {
      debugPrint('Faculty Reminders: Cancelled Reason: Reminders disabled (0 mins)');
      // Cancel all faculty reminders
      final pending = await notifications.pendingNotificationRequests();
      for (final p in pending) {
        if (p.id >= 20000 && p.id < 25000) {
          await notifications.cancel(p.id);
        }
      }
      return;
    }
    
    if (todayLectures.isEmpty) {
      debugPrint('Faculty Reminders: Cancelled Reason: No lectures today');
      final pending = await notifications.pendingNotificationRequests();
      for (final p in pending) {
        if (p.id >= 20000 && p.id < 25000) {
          await notifications.cancel(p.id);
        }
      }
      return;
    }

    final now = tz.TZDateTime.now(tz.local);
    int scheduledCount = 0;
    Set<int> newScheduledIds = {};

    const androidDetails = AndroidNotificationDetails(
      'faculty_reminders',
      'Faculty Reminders',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const details = NotificationDetails(android: androidDetails);

    for (final lecture in todayLectures) {
      if (scheduledCount >= 50) break; // Safety limit

      final startTimeInMins = lecture.entry.startTime;
      final hour = startTimeInMins ~/ 60;
      final minute = startTimeInMins % 60;

      // Deterministic ID based on start time (max 1440 mins/day)
      final int notificationId = 20000 + startTimeInMins;

      // Construct lecture start time today
      final lectureTime = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

      debugPrint('Faculty Reminders: Lecture: ${lecture.entry.subjectCode} at $hour:$minute');
      debugPrint('Faculty Reminders: Current Time: $now');

      // Check if it's already in progress
      if (now.isAfter(lectureTime)) {
        debugPrint('Faculty Reminders: Skipped Reason: Lecture already started');
        continue;
      }

      // Calculate exact reminder time
      final reminderTime = lectureTime.subtract(Duration(minutes: reminderMinutes));
      debugPrint('Faculty Reminders: Reminder Time: $reminderTime');

      final divLabel = lecture.division.replaceAll('_', ' ');
      final roomStr = (lecture.entry.room != null && lecture.entry.room!.isNotEmpty) ? '\nRoom ${lecture.entry.room}' : '';
      final title = '📚 Upcoming Class';
      final body = '${lecture.entry.displaySubject}\n$divLabel$roomStr\nStarts in $reminderMinutes minutes.';

      // Skip if missed (e.g., current time > reminder time)
      if (now.isAfter(reminderTime)) {
        if (now.isBefore(lectureTime)) {
          debugPrint('Faculty Reminders: Showing immediate reminder since we missed exact schedule but class is upcoming');
          await showNotification(title: title, body: body, payload: '/faculty_dashboard');
        } else {
          debugPrint('Faculty Reminders: Skipped Reason: Reminder time has passed');
        }
        continue;
      }

      debugPrint('Faculty Reminders: Scheduled Time: $reminderTime for ID: $notificationId');
      
      await notifications.zonedSchedule(
        notificationId,
        title,
        body,
        reminderTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'faculty_dashboard',
      );

      newScheduledIds.add(notificationId);
      scheduledCount++;
    }
    
    // Clean up outdated reminders
    final pending = await notifications.pendingNotificationRequests();
    for (final p in pending) {
      if (p.id >= 20000 && p.id < 25000 && !newScheduledIds.contains(p.id)) {
        debugPrint('Faculty Reminders: Cancelled Reason: Outdated/Removed lecture (ID: ${p.id})');
        await notifications.cancel(p.id);
      }
    }
  }
}
