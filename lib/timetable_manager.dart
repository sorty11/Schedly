import 'timetable_data.dart';

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

  static void addLecture({
    required String division,
    required String day,
    required String subject,
    required String time,
    required String room,
  }) {
    final dayLectures =
        TimetableData.timetable[division]?[day];

    if (dayLectures == null) return;

    dayLectures.add({
      'id':
          '${DateTime.now().millisecondsSinceEpoch}',
      'subject': subject,
      'time': time,
      'room': room,
      'cancelled': 'false',
    });
  }

  static List<String> getAvailableSlots({
    required String division,
    required String day,
  }) {
    final dayLectures =
        TimetableData.timetable[division]?[day] ??
            [];

    final occupiedSlots = dayLectures
        .where(
          (lecture) =>
              lecture['cancelled'] != 'true',
        )
        .map(
          (lecture) => lecture['time'] ?? '',
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