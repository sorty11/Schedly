class Lecture {
  final String id;
  String subject;
  String time;
  String room;
  bool cancelled;

  Lecture({
    required this.id,
    required this.subject,
    required this.time,
    required this.room,
    this.cancelled = false,
  });

  factory Lecture.fromMap(
    Map<String, String> map,
  ) {
    return Lecture(
      id: map['id'] ?? '',
      subject: map['subject'] ?? '',
      time: map['time'] ?? '',
      room: map['room'] ?? '',
      cancelled:
          (map['cancelled'] ?? 'false') ==
              'true',
    );
  }

  Map<String, String> toMap() {
    return {
      'id': id,
      'subject': subject,
      'time': time,
      'room': room,
      'cancelled':
          cancelled.toString(),
    };
  }
}