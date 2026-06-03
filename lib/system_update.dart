class SystemUpdate {
  final String title;
  final String description;
  final String type;
  final DateTime createdAt;

  bool isRead;

  SystemUpdate({
    required this.title,
    required this.description,
    required this.type,
    required this.createdAt,
    this.isRead = false,
  });
}