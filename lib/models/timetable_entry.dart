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
  final String status; // 'active', 'cancelled', 'rescheduled'

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
    this.status = 'active',
  });

  bool get isActive => status == 'active';
  bool get isCancelled => status == 'cancelled';
  bool get isRescheduled => status == 'rescheduled';

  bool get isAcademic => category == EventCategory.academic;

  /// Strips trailing component suffixes (Theory, Lab, Tutorial) from a subject string.
  /// Handles recursive corruption like "CTPS Theory Theory Theory" -> "CTPS".
  static String stripComponentSuffix(String raw) {
    String cleaned = raw.trim();
    // Repeatedly remove trailing Theory/Lab/Tutorial until stable
    while (true) {
      final before = cleaned;
      cleaned = cleaned
          .replaceAll(RegExp(r'\s+Theory$', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s+Lab$', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s+Tutorial$', caseSensitive: false), '')
          .trim();
      if (cleaned == before) break;
    }
    return cleaned.isEmpty ? raw.trim() : cleaned;
  }

  /// Returns the canonical subject code without any component suffix.
  String get subjectCode => stripComponentSuffix(subject);

  String get displaySubject {
    if (!isAcademic) return subject;
    return '$subjectCode $component'.trim();
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
      status: data['status'] ?? (data['isActive'] == false ? 'cancelled' : 'active'),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'subject': subjectCode,
      'component': component,
      'category': category.name.toLowerCase(),
      'batch': batch,
      'startTime': startTime,
      'endTime': endTime,
      'durationMinutes': durationMinutes,
      if (room != null) 'room': room,
      if (facultyId != null) 'facultyId': facultyId,
      'status': status,
      'isActive': status == 'active', // For backwards compatibility if queried
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
    String? status,
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
      status: status ?? this.status,
    );
  }
}
