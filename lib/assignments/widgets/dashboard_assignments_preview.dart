import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/assignment.dart';
import '../../models/assignment_submission.dart';
import '../../services/assignment_service.dart';
import '../../theme/theme.dart';
import '../../app_settings.dart';
import '../../user_roles.dart';
import '../assignments_page.dart';

/// Compact "Due Today" assignment section for the student dashboard.
class DashboardAssignmentsPreview extends StatelessWidget {
  final String division;
  final String? studentBatch;

  const DashboardAssignmentsPreview({
    super.key,
    required this.division,
    this.studentBatch,
  });

  @override
  Widget build(BuildContext context) {
    final role = AppSettings.currentRole;
    // Displayed for Student, CR, and SR roles. Explicitly excluded for Faculty/Admin.
    if (role != UserRole.student && role != UserRole.cr && role != UserRole.sr) {
      return const SizedBox.shrink();
    }

    if (division.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final sem = theme.extension<AppSemanticColors>()!;
    final isDark = theme.brightness == Brightness.dark;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isCRorSR = role == UserRole.cr || role == UserRole.sr;

    return StreamBuilder<List<Assignment>>(
      stream: AssignmentService.streamAssignments(
        sectionId: division,
        studentBatch: studentBatch,
        isCRorSR: isCRorSR,
      ),
      builder: (context, assignSnap) {
        final rawAssignments = assignSnap.data ?? [];
        if (rawAssignments.isEmpty) return const SizedBox.shrink();

        // For SR, restrict to their assigned subject scope
        final assignments = role == UserRole.sr && AppSettings.srSubject != null && AppSettings.srSubject!.trim().isNotEmpty
            ? rawAssignments.where((a) => a.subject.trim().toLowerCase() == AppSettings.srSubject!.trim().toLowerCase()).toList()
            : rawAssignments;

        if (assignments.isEmpty) return const SizedBox.shrink();

        return StreamBuilder<Map<String, AssignmentSubmission>>(
          stream: uid.isNotEmpty
              ? AssignmentService.streamSubmissions(studentId: uid)
              : Stream.value({}),
          builder: (context, subSnap) {
            final submissions = subSnap.data ?? {};

            // Filter strictly for assignments DUE TODAY:
            // 1. Must be active
            // 2. Must not be submitted (for students)
            // 3. Must not be overdue
            // 4. Must fall on TODAY in local timezone
            final dueTodayAssignments = assignments.where((a) {
              if (a.status != 'active') return false;
              if (role == UserRole.student) {
                final sub = submissions[a.id];
                if (sub?.isSubmitted ?? false) return false;
              }
              if (a.isOverdue) return false;
              return a.isDueToday;
            }).toList();

            // If no assignments due today, hide section completely
            if (dueTodayAssignments.isEmpty) return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.x2l,
                vertical: AppSpacing.sm,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? sem.surfaceElevated2 : colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: sem.warning.withValues(alpha: 0.35),
                    width: 1,
                  ),
                  boxShadow: isDark
                      ? null
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.md,
                        AppSpacing.md,
                        AppSpacing.xs,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.xs),
                            decoration: BoxDecoration(
                              color: sem.warning.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Icon(
                              Icons.schedule_rounded,
                              size: 16,
                              color: sem.warning,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            'Due Today',
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: sem.warning.withValues(alpha: 0.15),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.full),
                            ),
                            child: Text(
                              '${dueTodayAssignments.length}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: sem.warning,
                              ),
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      AssignmentsPage(division: division),
                                ),
                              );
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'View All',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 13,
                                  color: colorScheme.primary,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // Assignment items list
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xs,
                      ),
                      itemCount: dueTodayAssignments.length,
                      separatorBuilder: (_, __) => const Divider(
                        height: 1,
                        indent: AppSpacing.lg,
                        endIndent: AppSpacing.lg,
                      ),
                      itemBuilder: (context, index) {
                        final a = dueTodayAssignments[index];
                        return InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    AssignmentsPage(division: division),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                              vertical: AppSpacing.sm,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 1.5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: colorScheme.primary
                                                  .withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                AppRadius.xs,
                                              ),
                                            ),
                                            child: Text(
                                              a.subject,
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: colorScheme.primary,
                                              ),
                                            ),
                                          ),
                                          if (a.batch != null &&
                                              a.batch!.isNotEmpty) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 5,
                                                vertical: 1,
                                              ),
                                              decoration: BoxDecoration(
                                                color: sem.borderSubtle,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                  AppRadius.xs,
                                                ),
                                              ),
                                              child: Text(
                                                a.batch!,
                                                style: GoogleFonts.inter(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: sem.onSurfaceMuted,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        a.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.access_time_rounded,
                                            size: 12,
                                            color: sem.onSurfaceMuted,
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            'Due ${a.exactDueTime}',
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: sem.onSurfaceMuted,
                                            ),
                                          ),
                                          Text(
                                            '  •  ',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: sem.borderSubtle,
                                            ),
                                          ),
                                          Icon(
                                            Icons.hourglass_top_rounded,
                                            size: 12,
                                            color: sem.warning,
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            a.remainingTimeString,
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: sem.warning,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 18,
                                  color: sem.onSurfaceFaint,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
