import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/assignment.dart';
import '../../models/assignment_submission.dart';
import '../../services/assignment_service.dart';
import '../../theme/theme.dart';
import '../../widgets/animations/animated_card.dart';
import '../../widgets/app_dialogs.dart';

class AssignmentCard extends StatefulWidget {
  final Assignment assignment;
  final AssignmentSubmission? submission;
  final bool canManage;
  final VoidCallback? onEdit;
  final VoidCallback? onCancel;

  const AssignmentCard({
    super.key,
    required this.assignment,
    this.submission,
    this.canManage = false,
    this.onEdit,
    this.onCancel,
  });

  @override
  State<AssignmentCard> createState() => _AssignmentCardState();
}

class _AssignmentCardState extends State<AssignmentCard> {
  Timer? _timer;
  bool _isToggling = false;

  @override
  void initState() {
    super.initState();
    // Refresh remaining time every 30 seconds
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool get _isSubmitted => widget.submission?.isSubmitted ?? false;
  bool get _isOverdue => !_isSubmitted && widget.assignment.isOverdue;

  SubmissionStatus get _status {
    if (_isSubmitted) return SubmissionStatus.submitted;
    if (_isOverdue) return SubmissionStatus.overdue;
    return SubmissionStatus.pending;
  }

  Future<void> _toggleSubmission() async {
    if (_isToggling) return;
    setState(() => _isToggling = true);

    try {
      final newState = !_isSubmitted;
      await AssignmentService.setSubmissionState(
        assignmentId: widget.assignment.id,
        sectionId: widget.assignment.sectionId,
        isSubmitted: newState,
      );
      if (mounted) {
        AppDialogs.showSnackBar(
          context: context,
          message: newState
              ? 'Marked as submitted!'
              : 'Marked as pending',
        );
      }
    } catch (e) {
      if (mounted) {
        AppDialogs.showSnackBar(
          context: context,
          message: 'Failed to update submission: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isToggling = false);
    }
  }

  Future<void> _launchLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        if (mounted) {
          AppDialogs.showSnackBar(
            context: context,
            message: 'Could not open link',
            isError: true,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final sem = theme.extension<AppSemanticColors>()!;
    final isDark = theme.brightness == Brightness.dark;

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    switch (_status) {
      case SubmissionStatus.submitted:
        statusColor = sem.success;
        statusLabel = 'Submitted';
        statusIcon = Icons.check_circle_rounded;
        break;
      case SubmissionStatus.overdue:
        statusColor = sem.cancelled;
        statusLabel = 'Overdue';
        statusIcon = Icons.error_outline_rounded;
        break;
      case SubmissionStatus.pending:
        statusColor = sem.pending;
        statusLabel = 'Pending';
        statusIcon = Icons.schedule_rounded;
        break;
    }

    final hasBatch = widget.assignment.batch != null &&
        widget.assignment.batch!.isNotEmpty &&
        widget.assignment.batch != 'Whole Class';

    final subjectColor = AppTheme.lectureTypeColor(
      context,
      subject: widget.assignment.subject,
      component: widget.assignment.component,
    );

    final cardBg = isDark
        ? sem.surfaceElevated2
        : colorScheme.surface;

    final cardBorder = isDark
        ? sem.borderSubtle
        : colorScheme.outlineVariant.withValues(alpha: 0.45);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AnimatedCard(
        backgroundColor: cardBg,
        borderRadius: AppRadius.xl,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(
              color: cardBorder,
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
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Row: Subject Badge + Status Badge + Manage Menu ───
              Row(
                children: [
                  // Subject chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: subjectColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      border: Border.all(
                        color: subjectColor.withValues(alpha: 0.25),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      widget.assignment.subject.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: subjectColor,
                      ),
                    ),
                  ),
                  if (hasBatch) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm + 1,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? sem.surfaceElevated
                            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        border: Border.all(
                          color: isDark ? sem.borderSubtle : colorScheme.outlineVariant.withValues(alpha: 0.3),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        widget.assignment.batch!,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: sem.onSurfaceMuted,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),

                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm + 4,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 12, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          statusLabel,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // CR/SR Manage menu
                  if (widget.canManage) ...[
                    const SizedBox(width: AppSpacing.xs),
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert_rounded,
                        size: 20,
                        color: sem.onSurfaceMuted,
                      ),
                      padding: EdgeInsets.zero,
                      onSelected: (val) {
                        if (val == 'edit') widget.onEdit?.call();
                        if (val == 'cancel') widget.onCancel?.call();
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 16),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'cancel',
                          child: Row(
                            children: [
                              Icon(Icons.cancel_outlined,
                                  size: 16, color: sem.cancelled),
                              const SizedBox(width: 8),
                              Text('Cancel Assignment',
                                  style: TextStyle(color: sem.cancelled)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // ── Title ────────────────────────────────────────────────────
              Text(
                widget.assignment.title,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: colorScheme.onSurface,
                  height: 1.25,
                ),
              ),

              // ── Description ──────────────────────────────────────────────
              if (widget.assignment.description.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  widget.assignment.description,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: sem.onSurfaceMuted,
                    height: 1.45,
                  ),
                ),
              ],

              // ── Link / Attachment ─────────────────────────────────────────
              if (widget.assignment.attachmentUrl != null &&
                  widget.assignment.attachmentUrl!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                InkWell(
                  onTap: () => _launchLink(widget.assignment.attachmentUrl!),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.link_rounded,
                          size: 16,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            widget.assignment.attachmentUrl!,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.primary,
                              decoration: TextDecoration.underline,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),

              // ── Footer: Deadline info + Mark Submitted button ─────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Due date + live remaining time
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 13,
                              color: sem.onSurfaceMuted,
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                widget.assignment.formattedDueDateTime,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 13,
                              color: _isOverdue
                                  ? sem.cancelled
                                  : (_isSubmitted
                                      ? sem.success
                                      : colorScheme.primary),
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                _isSubmitted
                                    ? 'Done'
                                    : widget.assignment.remainingTimeString,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _isOverdue
                                      ? sem.cancelled
                                      : (_isSubmitted
                                          ? sem.success
                                          : colorScheme.primary),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),

                  // "Mark as Submitted" Action button
                  SizedBox(
                    height: 38,
                    child: _isSubmitted
                        ? OutlinedButton.icon(
                            onPressed: _isToggling ? null : _toggleSubmission,
                            icon: Icon(
                              Icons.check_circle,
                              size: 16,
                              color: sem.success,
                            ),
                            label: Text(
                              'Submitted',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: sem.success,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: sem.success, width: 1.2),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                              ),
                            ),
                          )
                        : FilledButton.icon(
                            onPressed: _isToggling ? null : _toggleSubmission,
                            icon: const Icon(Icons.check_rounded, size: 16),
                            label: Text(
                              'Mark Submitted',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: colorScheme.primary,
                              foregroundColor: colorScheme.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
