import 'lecture.dart';

class Timetable {
  final String division;
  final Map<String, List<Lecture>> days;

  Timetable({
    required this.division,
    required this.days,
  });

  List<Lecture> getLecturesForDay(
    String day,
  ) {
    return days[day] ?? [];
  }
}