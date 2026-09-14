import 'package:cloud_firestore/cloud_firestore.dart';

class Assignment {
  final String id;
  final String title;
  final String description;
  final String subject;
  final String? component; // e.g. 'Theory', 'Lab', null
  final String sectionId; // division / section
  final String? batch; // null or 'Whole Class' or specific batch like 'C1'
  final String createdBy; // UID
  final String creatorRole; // 'CR' or 'SR'
  final DateTime createdAt;
  final DateTime dueAt;
  final String? attachmentUrl;
  final String status; // 'active', 'cancelled', 'deleted'
  final DateTime? updatedAt;

  const Assignment({
    required this.id,
    required this.title,
    this.description = '',
    required this.subject,
    this.component,
    required this.sectionId,
    this.batch,
    required this.createdBy,
    required this.creatorRole,
    required this.createdAt,
    required this.dueAt,
    this.attachmentUrl,
    this.status = 'active',
    this.updatedAt,
  });

  bool get isActive => status == 'active';
  bool get isCancelled => status == 'cancelled';
  bool get isDeleted => status == 'deleted';

  bool get isOverdue => DateTime.now().isAfter(dueAt);

  Duration get remainingDuration => dueAt.difference(DateTime.now());

  /// Returns clean live remaining time string, e.g. "23h 41m remaining"
  String get remainingTimeString {
    final now = DateTime.now();
    if (now.isAfter(dueAt)) {
      final diff = now.difference(dueAt);
      if (diff.inDays > 0) {
        return 'Overdue by ${diff.inDays}d ${diff.inHours % 24}h';
      } else if (diff.inHours > 0) {
        return 'Overdue by ${diff.inHours}h ${diff.inMinutes % 60}m';
      } else if (diff.inMinutes > 0) {
        return 'Overdue by ${diff.inMinutes}m';
      } else {
        return 'Just overdue';
      }
    }

    final diff = dueAt.difference(now);
    if (diff.inDays > 1) {
      return '${diff.inDays}d ${diff.inHours % 24}h remaining';
    } else if (diff.inDays == 1) {
      return '1d ${diff.inHours % 24}h remaining';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ${diff.inMinutes % 60}m remaining';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m remaining';
    } else {
      return '${diff.inSeconds.clamp(0, 60)}s remaining';
    }
  }

  /// Formatted deadline string: "Due Sep 20 • 11:00 PM"
  String get formattedDueDateTime {
    final localDue = dueAt.toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final month = months[localDue.month - 1];
    final day = localDue.day;
    final hour = localDue.hour;
    final minute = localDue.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final displayMinute = minute.toString().padLeft(2, '0');

    return 'Due $month $day • $displayHour:$displayMinute $period';
  }

  /// Exact 12-hour formatted due time: "11:59 PM"
  String get exactDueTime {
    final localDue = dueAt.toLocal();
    final hour = localDue.hour;
    final minute = localDue.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final displayMinute = minute.toString().padLeft(2, '0');
    return '$displayHour:$displayMinute $period';
  }

  /// Whether the deadline falls on TODAY in the user's local timezone
  bool get isDueToday {
    final now = DateTime.now();
    final localDue = dueAt.toLocal();
    return localDue.year == now.year &&
        localDue.month == now.month &&
        localDue.day == now.day;
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'subject': subject,
      if (component != null && component!.isNotEmpty) 'component': component,
      'sectionId': sectionId,
      'division': sectionId,
      if (batch != null && batch != 'Whole Class' && batch!.isNotEmpty)
        'batch': batch,
      'createdBy': createdBy,
      'creatorRole': creatorRole,
      'createdAt': Timestamp.fromDate(createdAt),
      'dueAt': Timestamp.fromDate(dueAt),
      if (attachmentUrl != null && attachmentUrl!.isNotEmpty)
        'attachmentUrl': attachmentUrl,
      'status': status,
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }

  factory Assignment.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return Assignment.fromMap(data, id: doc.id);
  }

  factory Assignment.fromMap(Map<String, dynamic> map, {String? id}) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return DateTime.now();
    }

    return Assignment(
      id: id ?? map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      subject: map['subject']?.toString() ?? '',
      component: map['component']?.toString(),
      sectionId:
          map['sectionId']?.toString() ?? map['division']?.toString() ?? '',
      batch: map['batch']?.toString(),
      createdBy: map['createdBy']?.toString() ?? '',
      creatorRole: map['creatorRole']?.toString() ?? 'CR',
      createdAt: parseDate(map['createdAt']),
      dueAt: parseDate(map['dueAt']),
      attachmentUrl: map['attachmentUrl']?.toString() ?? map['link']?.toString(),
      status: map['status']?.toString() ?? 'active',
      updatedAt: map['updatedAt'] != null ? parseDate(map['updatedAt']) : null,
    );
  }

  Assignment copyWith({
    String? id,
    String? title,
    String? description,
    String? subject,
    String? component,
    String? sectionId,
    String? batch,
    String? createdBy,
    String? creatorRole,
    DateTime? createdAt,
    DateTime? dueAt,
    String? attachmentUrl,
    String? status,
    DateTime? updatedAt,
  }) {
    return Assignment(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      subject: subject ?? this.subject,
      component: component ?? this.component,
      sectionId: sectionId ?? this.sectionId,
      batch: batch ?? this.batch,
      createdBy: createdBy ?? this.createdBy,
      creatorRole: creatorRole ?? this.creatorRole,
      createdAt: createdAt ?? this.createdAt,
      dueAt: dueAt ?? this.dueAt,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
