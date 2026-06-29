import 'package:cloud_firestore/cloud_firestore.dart';
import 'event_category.dart';
import 'timetable_entry.dart';

class LogAudit {
  final String markedBy;
  final String markedByUid;
  final DateTime clientTimestamp;
  final DateTime? serverTimestamp;
  final bool verifiedByFaculty;

  LogAudit({
    required this.markedBy,
    required this.markedByUid,
    required this.clientTimestamp,
    this.serverTimestamp,
    this.verifiedByFaculty = false,
  });

  factory LogAudit.fromMap(Map<String, dynamic> data) {
    return LogAudit(
      markedBy: data['markedBy'] ?? 'Unknown',
      markedByUid: data['markedByUid'] ?? '',
      clientTimestamp: data['clientTimestamp'] != null 
          ? DateTime.parse(data['clientTimestamp']) 
          : DateTime.now(),
      serverTimestamp: data['serverTimestamp'] != null 
          ? (data['serverTimestamp'] as Timestamp).toDate() 
          : null,
      verifiedByFaculty: data['verifiedByFaculty'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'markedBy': markedBy,
      'markedByUid': markedByUid,
      'clientTimestamp': clientTimestamp.toIso8601String(),
      'serverTimestamp': FieldValue.serverTimestamp(),
      'verifiedByFaculty': verifiedByFaculty,
    };
  }
}

class ConductLog {
  final String id;
  final String date; // YYYY-MM-DD format
  final TimetableEntry originalSlot;
  final String? actualSubject;
  final String? actualComponent;
  final String? actualBatch;
  final EventCategory? actualCategory;
  final int durationMinutes;
  final String status; // 'conducted', 'cancelled', 'rescheduled', 'pending'
  final LogAudit audit;

  ConductLog({
    required this.id,
    required this.date,
    required this.originalSlot,
    this.actualSubject,
    this.actualComponent,
    this.actualBatch,
    this.actualCategory,
    required this.durationMinutes,
    required this.status,
    required this.audit,
  });

  factory ConductLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    
    // Fallback logic for legacy data if needed, but since we are wiping old logs, 
    // we assume the data conforms to the new schema.
    final origData = data['originalSlot'] as Map<String, dynamic>? ?? {};
    final origSlot = TimetableEntry(
      id: 'embedded_slot',
      subject: origData['subject'] ?? '',
      component: origData['component'] ?? 'Theory',
      category: EventCategoryExtension.fromString(origData['category'] ?? 'academic'),
      batch: origData['batch'] ?? 'Whole Class',
      startTime: origData['startTime'] ?? 0,
      endTime: origData['endTime'] ?? 0,
      durationMinutes: origData['durationMinutes'] ?? 0,
      isActive: true,
    );

    return ConductLog(
      id: doc.id,
      date: data['date'] ?? '',
      originalSlot: origSlot,
      actualSubject: data['actualSubject'],
      actualComponent: data['actualComponent'],
      actualBatch: data['actualBatch'],
      actualCategory: data['actualCategory'] != null 
          ? EventCategoryExtension.fromString(data['actualCategory']) 
          : null,
      durationMinutes: data['durationMinutes'] ?? origSlot.durationMinutes,
      status: data['status'] ?? 'pending',
      audit: LogAudit.fromMap(data['audit'] as Map<String, dynamic>? ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'date': date,
      'originalSlot': {
        'subject': originalSlot.subject,
        'component': originalSlot.component,
        'category': originalSlot.category.name.toLowerCase(),
        'batch': originalSlot.batch,
        'startTime': originalSlot.startTime,
        'endTime': originalSlot.endTime,
        'durationMinutes': originalSlot.durationMinutes,
      },
      if (actualSubject != null) 'actualSubject': actualSubject,
      if (actualComponent != null) 'actualComponent': actualComponent,
      if (actualBatch != null) 'actualBatch': actualBatch,
      if (actualCategory != null) 'actualCategory': actualCategory!.name.toLowerCase(),
      'durationMinutes': durationMinutes,
      'status': status,
      'audit': audit.toMap(),
    };
  }
}
