import 'package:cloud_firestore/cloud_firestore.dart';
import 'event_category.dart';
import '../timetable_manager.dart';

class TimetableEntry {
  final String id;
  final String subject;
  final String component; // 'Theory', 'Lab', 'Tutorial'
  final EventCategory category;
  final String batch;
  final int startTime; // Minutes from midnight
  final int endTime; // Minutes from midnight
  final int durationMinutes;
  final String? room;
  final String? facultyId;
  final bool isActive;

  TimetableEntry({
    required this.id,
    required this.subject,
    this.component = 'Theory',
    required this.category,
    required this.batch,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    this.room,
    this.facultyId,
    this.isActive = true,
  });

  bool get isAcademic => category == EventCategory.academic;

  String get displaySubject {
    if (!isAcademic) return subject;
    return '$subject $component'.trim();
  }

  factory TimetableEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // 1. Detect Version
    final isV2 = data.containsKey('startTime') && data.containsKey('endTime');

    // 2. Parse Subject & Category
    final rawSubject = data['subject'] as String? ?? 'Free Slot';
    EventCategory parsedCategory;
    if (isV2 && data.containsKey('category')) {
      parsedCategory = EventCategoryExtension.fromString(data['category']);
    } else {
      parsedCategory = EventCategoryExtension.inferFromSubject(rawSubject);
    }

    // 3. Parse Time
    int parsedStart = 0;
    int parsedEnd = 0;
    int parsedDuration = 0;

    if (isV2) {
      parsedStart = data['startTime'] ?? 0;
      parsedEnd = data['endTime'] ?? 0;
      parsedDuration = data['durationMinutes'] ?? 0;
    } else if (data.containsKey('time')) {
      final timeStr = data['time'] as String;
      final parts = timeStr.split('-');
      if (parts.length == 2) {
        parsedStart = TimetableManager.parseTime(parts[0].trim());
        parsedEnd = TimetableManager.parseTime(parts[1].trim());
        parsedDuration = parsedEnd - parsedStart;
        if (parsedDuration < 0) parsedDuration += 24 * 60;
      }
    }

    return TimetableEntry(
      id: doc.id,
      subject: rawSubject,
      component: data['component'] ?? 'Theory',
      category: parsedCategory,
      batch: data['batch'] ?? 'Whole Class',
      startTime: parsedStart,
      endTime: parsedEnd,
      durationMinutes: parsedDuration,
      room: data['room'],
      facultyId: data['facultyId'],
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'subject': subject,
      'component': component,
      'category': category.name.toLowerCase(),
      'batch': batch,
      'startTime': startTime,
      'endTime': endTime,
      'durationMinutes': durationMinutes,
      if (room != null) 'room': room,
      if (facultyId != null) 'facultyId': facultyId,
      'isActive': isActive,
    };
  }

  TimetableEntry copyWith({
    String? id,
    String? subject,
    String? component,
    EventCategory? category,
    String? batch,
    int? startTime,
    int? endTime,
    int? durationMinutes,
    String? room,
    String? facultyId,
    bool? isActive,
  }) {
    return TimetableEntry(
      id: id ?? this.id,
      subject: subject ?? this.subject,
      component: component ?? this.component,
      category: category ?? this.category,
      batch: batch ?? this.batch,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      room: room ?? this.room,
      facultyId: facultyId ?? this.facultyId,
      isActive: isActive ?? this.isActive,
    );
  }
}
