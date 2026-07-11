import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../theme/theme.dart';
import '../models/faculty_request.dart';
import '../models/timetable_entry.dart';
import '../models/event_category.dart';
import '../services/timetable_event_service.dart';
import '../widgets/app_dialogs.dart';

class CRFacultyRequestsPage extends StatefulWidget {
  final String division;

  const CRFacultyRequestsPage({super.key, required this.division});

  @override
  State<CRFacultyRequestsPage> createState() => _CRFacultyRequestsPageState();
}

class _CRFacultyRequestsPageState extends State<CRFacultyRequestsPage> {
  Future<void> _approveRequest(FacultyRequest request) async {
    final isCancel = request.type == FacultyRequestType.cancel;
    final confirmed = await _showConfirmDialog(
      title: isCancel ? 'Approve Cancellation?' : 'Approve Extra Lecture?',
      message: isCancel
          ? 'This will cancel the lecture and notify students.'
          : 'This will add the extra lecture to the timetable.',
      confirmLabel: 'Yes, Approve',
      confirmColor: Theme.of(context).extension<AppSemanticColors>()!.conducted,
    );
    if (!confirmed) return;

    try {
      final docRef = FirebaseFirestore.instance
          .collection('sections')
          .doc(widget.division)
          .collection('faculty_requests')
          .doc(request.id);

      final batch = FirebaseFirestore.instance.batch();
      batch.update(docRef, {
        'status': FacultyRequestStatus.approved.name,
        'resolvedAt': FieldValue.serverTimestamp(),
      });

      if (request.type == FacultyRequestType.cancel) {
        if (request.originalLectureId != null) {
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

      try {
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
        
        await FirebaseFirestore.instance.collection('notification_outbox').add({
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
        });
      } catch (outboxErr) {
        debugPrint('OUTBOX WARNING (non-fatal, approve): $outboxErr');
      }

      if (mounted) {
        AppDialogs.showSnackBar(
          context: context,
          message: 'Request approved. Timetable updated.',
        );
      }
    } catch (e) {
      if (mounted) {
        AppDialogs.showError(
          context: context,
          title: 'Approval Failed',
          message: e.toString().replaceAll('Exception: ', ''),
        );
      }
    }
  }

  Future<void> _denyRequest(FacultyRequest request) async {
    final confirmed = await _showConfirmDialog(
      title: 'Deny Request?',
      message: 'The faculty will be notified that their request was denied.',
      confirmLabel: 'Yes, Deny',
      confirmColor: Theme.of(context).extension<AppSemanticColors>()!.cancelled,
    );
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

      if (mounted) {
        AppDialogs.showSnackBar(context: context, message: 'Request denied.');
      }
    } catch (e) {
      if (mounted) {
        AppDialogs.showError(
          context: context,
          title: 'Error',
          message: e.toString().replaceAll('Exception: ', ''),
        );
      }
    }
  }

  Future<bool> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
  }) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          title: Text(
            title,
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          content: Text(
            message,
            style: GoogleFonts.inter(fontSize: 14, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: confirmColor),
              child: Text(
                confirmLabel,
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Faculty Requests',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 20),
        ),
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
          // Loading state
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final docs = snapshot.data!.docs;

          // Empty state
          if (docs.isEmpty) {
            return _EmptyState(sem: sem, colorScheme: colorScheme);
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.x2l),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.lg),
            itemBuilder: (context, index) {
              final request = FacultyRequest.fromFirestore(docs[index]);
              return _RequestCard(
                request: request,
                isDark: isDark,
                sem: sem,
                colorScheme: colorScheme,
                formatTime: _formatTime,
                onApprove: () => _approveRequest(request),
                onDeny: () => _denyRequest(request),
              );
            },
          );
        },
      ),
    );
  }
}

// ── Request Card ───────────────────────────────────────────────────────────────
class _RequestCard extends StatelessWidget {
  final FacultyRequest request;
  final bool isDark;
  final AppSemanticColors sem;
  final ColorScheme colorScheme;
  final String Function(int?) formatTime;
  final VoidCallback onApprove;
  final VoidCallback onDeny;

  const _RequestCard({
    required this.request,
    required this.isDark,
    required this.sem,
    required this.colorScheme,
    required this.formatTime,
    required this.onApprove,
    required this.onDeny,
  });

  @override
  Widget build(BuildContext context) {
    final isCancel = request.type == FacultyRequestType.cancel;
    final accentColor = isCancel ? sem.cancelled : colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? sem.surfaceElevated : colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
        boxShadow: isDark ? null : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Type header ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
            ),
            child: Row(
              children: [
                Icon(
                  isCancel ? Icons.cancel_outlined : Icons.add_circle_outline_rounded,
                  color: accentColor,
                  size: 18,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  isCancel ? 'Cancellation Request' : 'Extra Lecture Request',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                Text(
                    DateFormat('MMM d, hh:mm a').format(request.createdAt),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: sem.onSurfaceMuted,
                    ),
                  ),
              ],
            ),
          ),

          // ── Body ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Faculty + subject
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          request.facultyName.isNotEmpty
                              ? request.facultyName[0].toUpperCase()
                              : 'F',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.primary,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Prof. ${request.facultyName}',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            request.subject,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: sem.onSurfaceMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                // Details grid
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    if (request.date != null)
                      _DetailChip(
                        icon: Icons.calendar_today_rounded,
                        label: DateFormat('EEE, MMM d').format(request.date!),
                        sem: sem,
                      ),
                    if (!isCancel && request.startTime != null && request.endTime != null)
                      _DetailChip(
                        icon: Icons.access_time_rounded,
                        label: '${formatTime(request.startTime)} – ${formatTime(request.endTime)}',
                        sem: sem,
                      ),
                    if (request.room != null && request.room!.isNotEmpty)
                      _DetailChip(
                        icon: Icons.room_rounded,
                        label: request.room!,
                        sem: sem,
                      ),
                  ],
                ),

                if (request.reason != null && request.reason!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: isDark ? sem.surfaceElevated2 : const Color(0xFFF8F8FC),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: sem.borderSubtle),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.format_quote_rounded, size: 16, color: sem.onSurfaceMuted),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            request.reason!,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              color: sem.onSurfaceMuted,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: AppSpacing.lg),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onDeny,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: sem.cancelled,
                          side: BorderSide(color: sem.cancelled.withValues(alpha: 0.5)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                          ),
                        ),
                        child: Text(
                          'Deny',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: FilledButton(
                        onPressed: onApprove,
                        style: FilledButton.styleFrom(
                          backgroundColor: isCancel ? sem.conducted : colorScheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                          ),
                        ),
                        child: Text(
                          'Approve',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Detail Chip ────────────────────────────────────────────────────────────────
class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final AppSemanticColors sem;

  const _DetailChip({
    required this.icon,
    required this.label,
    required this.sem,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: isDark ? sem.surfaceElevated2 : const Color(0xFFF0F0F8),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: sem.onSurfaceMuted),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: sem.onSurfaceMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty State ────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final AppSemanticColors sem;
  final ColorScheme colorScheme;

  const _EmptyState({required this.sem, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x4l),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.x2l),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_outline_rounded,
                size: 48,
                color: colorScheme.primary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'All caught up!',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'No pending faculty requests.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: sem.onSurfaceMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
