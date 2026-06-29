class PeriodConfig {
  final String id;
  final String name; // e.g., 'Period 1', 'Break'
  final int startTime; // minutes from midnight
  final int endTime; // minutes from midnight
  final bool isBreak;

  PeriodConfig({
    required this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    this.isBreak = false,
  });

  factory PeriodConfig.fromJson(Map<String, dynamic> json) {
    return PeriodConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      startTime: json['startTime'] as int,
      endTime: json['endTime'] as int,
      isBreak: json['isBreak'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'startTime': startTime,
      'endTime': endTime,
      'isBreak': isBreak,
    };
  }
}
