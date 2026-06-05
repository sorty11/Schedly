import 'package:cloud_firestore/cloud_firestore.dart';

import 'timetable_data.dart';
import 'system_update_manager.dart';
import 'services/firestore_service.dart';
import 'services/app_notification_service.dart';

class TimetableManager {
static const List<String> allSlots = [
'9:00 AM - 10:00 AM',
'10:00 AM - 11:00 AM',
'11:00 AM - 12:00 PM',
'12:00 PM - 1:00 PM',
'2:00 PM - 3:00 PM',
'3:00 PM - 4:00 PM',
'4:00 PM - 5:00 PM',
];

static Future<void> addLecture({
required String division,
required String day,
required String subject,
required String time,
required String room,
}) async {
final existing =
await FirebaseFirestore.instance
.collection('timetables')
.doc(division)
.collection(day)
.where(
'time',
isEqualTo: time,
)
.get();


if (existing.docs.isNotEmpty) {
  throw Exception(
    'This slot is already occupied.',
  );
}

await FirestoreService.addLecture(
  division: division,
  day: day,
  subject: subject,
  time: time,
  room: room,
);

SystemUpdateManager.addUpdate(
  title: 'Lecture Added',
  description:
      '$subject added on $day at $time',
  type: 'add',
);

await AppNotificationService
    .createNotification(
  title: 'Lecture Added',
  message:
      '$subject added on $day at $time',
  division: division,
  type: 'add',
);


}

static Future<List<String>>
getAvailableSlots({
required String division,
required String day,
}) async {
final snapshot =
await FirebaseFirestore.instance
.collection('timetables')
.doc(division)
.collection(day)
.get();


final occupiedSlots =
    snapshot.docs
        .where(
          (doc) =>
              doc['cancelled'] != true,
        )
        .map(
          (doc) =>
              doc['time'] as String,
        )
        .toSet();

return allSlots
    .where(
      (slot) =>
          !occupiedSlots.contains(slot),
    )
    .toList();


}
}
