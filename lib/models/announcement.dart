class Announcement {
  final String id;
  final String title;
  final String message;
  final String priority;
  final DateTime createdAt;

  Announcement({
    required this.id,
    required this.title,
    required this.message,
    required this.priority,
    required this.createdAt,
  });
}