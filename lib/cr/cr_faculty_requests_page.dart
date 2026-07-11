import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../theme/theme.dart';
import '../models/faculty_request.dart';
import '../models/timetable_entry.dart';
import '../models/event_category.dart';
import '../widgets/animations/animated_button.dart';

class CRFacultyRequestsPage extends StatefulWidget {
  final String division;

  const CRFacultyRequestsPage({super.key, required this.division});

  @override
  State<CRFacultyRequestsPage> createState() => _CRFacultyRequestsPageState();
}

class _CRFacultyRequestsPageState extends State<CRFacultyRequestsPage> {
  Future<void> _approveRequest(FacultyRequest request) async {
    final confirmed = await _showConfirmDialog('Approve Request', 'Are you sure you want to approve this request? It will automatically update the timetable.');
    if (!confirmed) return;

    try {
      final docRef = FirebaseFirestore.instance
          .collection('sections')
          .doc(widget.division)
          .collection('faculty_requests')
          .doc(request.id);

      // Perform timetable update
      final batch = FirebaseFirestore.instance.batch();
      batch.update(docRef, {
        'status': FacultyRequestStatus.approved.name,
        'resolvedAt': FieldValue.serverTimestamp(),
      });

      if (request.type == FacultyRequestType.cancel) {
        if (request.originalLectureId != null) {
          // Assume the lecture is today for simplicity, or we would need the day in the request.
          // Since our FacultyRequest only stores 'date', we format it to EEEE.
          final dayStr = DateFormat('EEEE').format(request.date ?? DateTime.now());
          final lecRef = FirebaseFirestore.instance
              .collection('timetables')
              .doc(widget.division)
              .collection(dayStr)
              .doc(request.originalLectureId);
              
          batch.update(lecRef, {'status': 'cancelled', 'isActive': false});
        }
      } else if (request.type == FacultyRequestType.addExtra) {
        final dayStr = DateFormat('EEEE').format(request.date ?? DateTime.now());
        final newLecRef = FirebaseFirestore.instance
            .collection('timetables')
            .doc(widget.division)
            .collection(dayStr)
            .doc();
            
        final entry = TimetableEntry(
          id: newLecRef.id,
          subject: request.subject,
          category: EventCategoryExtension.inferFromSubject(request.subject),
          batch: request.batch ?? 'Whole Class',
          startTime: request.startTime ?? 0,
          endTime: request.endTime ?? 60,
          durationMinutes: (request.endTime ?? 60) - (request.startTime ?? 0),
          room: request.room,
          facultyId: request.facultyId,
        );
        
        batch.set(newLecRef, entry.toFirestore());
      }

      await batch.commit();

      final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';

      // Notify Faculty & Students — wrapped in try-catch so failures never block approval
      try {
        debugPrint('[FAC_REQ_1] request.facultyId = ${request.facultyId}');
        await FirebaseFirestore.instance.collection('notification_outbox').add({
          'division': widget.division,
          'role': 'student',
          'title': 'Timetable Update',
          'body': '${request.type == FacultyRequestType.cancel ? 'Cancelled' : 'Extra'} ${request.subject} lecture by Prof. ${request.facultyName}.',
          'createdAt': FieldValue.serverTimestamp(),
          'uid': uid,
          'type': request.type == FacultyRequestType.cancel ? 'cancel' : 'add',
          'processed': false,
          'attempts': 0,
          'nextRetryAt': FieldValue.serverTimestamp(),
        });
        
        final facultyPayload = {
          'division': request.facultyId,
          'role': 'faculty',
          'title': 'Request Approved',
          'body': 'Your request for ${request.subject} has been approved by the CR.',
          'createdAt': FieldValue.serverTimestamp(),
          'uid': uid,
          'type': 'add',
          'processed': false,
          'attempts': 0,
          'nextRetryAt': FieldValue.serverTimestamp(),
        };
        debugPrint('[FAC_REQ_2] Faculty payload = $facultyPayload');
        await FirebaseFirestore.instance.collection('notification_outbox').add(facultyPayload);
      } catch (outboxErr) {
        debugPrint('OUTBOX WARNING (non-fatal, approve): $outboxErr');
      }

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request approved and timetable updated.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _denyRequest(FacultyRequest request) async {
    final confirmed = await _showConfirmDialog('Deny Request', 'Are you sure you want to deny this request?');
    if (!confirmed) return;

    try {
      await FirebaseFirestore.instance
          .collection('sections')
          .doc(widget.division)
          .collection('faculty_requests')
          .doc(request.id)
          .update({
        'status': FacultyRequestStatus.denied.name,
        'resolvedAt': FieldValue.serverTimestamp(),
      });

      final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';

      // Notify Faculty — wrapped in try-catch so failures never block denial
      try {
        await FirebaseFirestore.instance.collection('notification_outbox').add({
          'division': request.facultyId,
          'role': 'faculty',
          'title': 'Request Denied',
          'body': 'Your request for ${request.subject} was denied by the CR.',
          'createdAt': FieldValue.serverTimestamp(),
          'uid': uid,
          'type': 'cancel',
          'processed': false,
          'attempts': 0,
          'nextRetryAt': FieldValue.serverTimestamp(),
        });
      } catch (outboxErr) {
        debugPrint('OUTBOX WARNING (non-fatal, deny): $outboxErr');
      }

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request denied.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<bool> _showConfirmDialog(String title, String message) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
        ],
      ),
    ) ?? false;
  }

  String _formatTime(int? minutesFromMidnight) {
    if (minutesFromMidnight == null) return '';
    int hour = minutesFromMidnight ~/ 60;
    int minute = minutesFromMidnight % 60;
    final ampm = hour >= 12 ? 'PM' : 'AM';
    if (hour > 12) hour -= 12;
    if (hour == 0) hour = 12;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Requests', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('sections')
            .doc(widget.division)
            .collection('faculty_requests')
            .where('status', isEqualTo: 'pending')
            .orderBy('createdAt', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline_rounded, size: 64, color: colorScheme.primary.withValues(alpha: 0.3)),
                  const SizedBox(height: AppSpacing.md),
                  Text('All caught up!', style: TextStyle(color: sem.onSurfaceMuted, fontSize: 18, fontWeight: FontWeight.w600)),
                  Text('No pending faculty requests.', style: TextStyle(color: sem.onSurfaceMuted)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.xl),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final request = FacultyRequest.fromFirestore(docs[index]);
              final isCancel = request.type == FacultyRequestType.cancel;
              final accentColor = isCancel ? sem.cancelled : colorScheme.primary;

              return Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isCancel ? Icons.cancel_outlined : Icons.add_circle_outline_rounded,
                            color: accentColor,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            isCancel ? 'Cancellation Request' : 'Extra Lecture Request',
                            style: TextStyle(fontWeight: FontWeight.w800, color: accentColor, fontSize: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      
                      Text('Prof. ${request.facultyName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(request.subject, style: TextStyle(color: sem.onSurfaceMuted, fontSize: 14)),
                      
                      const SizedBox(height: AppSpacing.md),
                      
                      if (request.date != null)
                        _buildInfoRow(Icons.calendar_today_rounded, DateFormat('MMM d, yyyy (EEEE)').format(request.date!)),
                      
                      if (!isCancel && request.startTime != null && request.endTime != null)
                        _buildInfoRow(Icons.access_time_rounded, '${_formatTime(request.startTime)} - ${_formatTime(request.endTime)}'),
                        
                      if (request.room != null && request.room!.isNotEmpty)
                        _buildInfoRow(Icons.room_rounded, 'Room: ${request.room}'),
                        
                      if (request.reason != null && request.reason!.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
                          ),
                          child: Text('"${request.reason}"', style: const TextStyle(fontStyle: FontStyle.italic)),
                        ),
                      ],
                      
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        children: [
                          Expanded(
                            child: AnimatedButton(
                              onPressed: () => _denyRequest(request),
                              backgroundColor: sem.surfaceElevated2,
                              foregroundColor: colorScheme.onSurface,
                              child: const Text('Deny'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: AnimatedButton(
                              onPressed: () => _approveRequest(request),
                              backgroundColor: accentColor,
                              child: const Text('Approve'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Theme.of(context).extension<AppSemanticColors>()!.onSurfaceMuted),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(color: Theme.of(context).extension<AppSemanticColors>()!.onSurfaceMuted)),
        ],
      ),
    );
  }
}
