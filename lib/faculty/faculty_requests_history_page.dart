import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../theme/theme.dart';
import '../app_settings.dart';
import '../models/faculty_request.dart';
import '../widgets/animations/animated_card.dart';
import '../widgets/animations/staggered_list_item.dart';
import '../widgets/animations/floating_empty_state.dart';

class FacultyRequestsHistoryPage extends StatefulWidget {
  const FacultyRequestsHistoryPage({super.key});

  @override
  State<FacultyRequestsHistoryPage> createState() =>
      _FacultyRequestsHistoryPageState();
}

class _FacultyRequestsHistoryPageState
    extends State<FacultyRequestsHistoryPage> {
  final DateFormat _dateFormat = DateFormat('EEE, MMM d, yyyy');

  String _formatTime(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final period = h >= 12 ? 'PM' : 'AM';
    final displayH = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '${displayH.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final uid = AppSettings.facultyId;
    final divisions = AppSettings.facultyAssignedDivisions ?? [];

    if (uid == null || divisions.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Lecture Requests',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
        ),
        body: const FloatingEmptyState(
          icon: Icons.history_edu_outlined,
          title: 'No Requests Found',
          subtitle: 'You have not submitted any lecture requests yet.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Lecture Requests History',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 20),
        ),
      ),
      body: StreamBuilder<List<FacultyRequest>>(
        stream: _streamAllMyRequests(divisions, uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final requests = snapshot.data ?? [];
          if (requests.isEmpty) {
            return const FloatingEmptyState(
              icon: Icons.history_edu_outlined,
              title: 'No Requests Found',
              subtitle: 'You have not submitted any lecture requests yet.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.x2l),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              final req = requests[index];
              final isPending = req.status == FacultyRequestStatus.pending;
              final isApproved = req.status == FacultyRequestStatus.approved;
              final statusColor = isPending
                  ? sem.warning
                  : (isApproved ? sem.conducted : sem.cancelled);
              final statusText = isPending
                  ? 'Pending CR Decision'
                  : (isApproved ? 'Approved by CR' : 'Denied by CR');

              final isExtra = req.type == FacultyRequestType.addExtra;

              return StaggeredListItem(
                index: index,
                child: AnimatedCard(
                  borderRadius: AppRadius.xl,
                  backgroundColor: sem.surfaceElevated,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      border: Border.all(color: sem.borderSubtle, width: 1),
                    ),
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: AppSpacing.xs,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    (isExtra
                                            ? colorScheme.primary
                                            : sem.cancelled)
                                        .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.sm,
                                ),
                              ),
                              child: Text(
                                isExtra ? 'Extra Lecture' : 'Cancellation',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isExtra
                                      ? colorScheme.primary
                                      : sem.cancelled,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.full,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isPending
                                        ? Icons.hourglass_top_rounded
                                        : (isApproved
                                              ? Icons.check_circle_rounded
                                              : Icons.cancel_rounded),
                                    size: 12,
                                    color: statusColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    statusText,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: statusColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          req.subject,
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Section ${req.division.replaceAll('_', ' ')}${req.batch != null && req.batch != 'Whole Class' && req.batch!.isNotEmpty ? ' • Batch ${req.batch}' : ''}',
                          style: TextStyle(
                            fontSize: 13,
                            color: sem.onSurfaceMuted,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 14,
                              color: sem.onSurfaceMuted,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              req.date != null
                                  ? _dateFormat.format(req.date!)
                                  : 'N/A',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.lg),
                            Icon(
                              Icons.schedule_rounded,
                              size: 14,
                              color: sem.onSurfaceMuted,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              (req.startTime != null && req.endTime != null)
                                  ? '${_formatTime(req.startTime!)} - ${_formatTime(req.endTime!)}'
                                  : 'N/A',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        if (req.reason != null && req.reason!.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Reason: "${req.reason}"',
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: sem.onSurfaceMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Stream<List<FacultyRequest>> _streamAllMyRequests(
    List<String> divisions,
    String facultyId,
  ) {
    // Stream requests from all assigned divisions for this faculty
    final streams = divisions.map((div) {
      return FirebaseFirestore.instance
          .collection('sections')
          .doc(div)
          .collection('faculty_requests')
          .where('facultyId', isEqualTo: facultyId)
          .snapshots()
          .map(
            (snap) => snap.docs
                .map((doc) => FacultyRequest.fromFirestore(doc))
                .toList(),
          );
    }).toList();

    return Stream.multi((controller) {
      final List<List<FacultyRequest>> latest = List.generate(
        streams.length,
        (_) => [],
      );
      final subs = <dynamic>[];

      for (int i = 0; i < streams.length; i++) {
        final sub = streams[i].listen((data) {
          latest[i] = data;
          final all = latest.expand((e) => e).toList();
          all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          controller.add(all);
        }, onError: controller.addError);
        subs.add(sub);
      }

      controller.onCancel = () {
        for (final s in subs) {
          s.cancel();
        }
      };
    });
  }
}
