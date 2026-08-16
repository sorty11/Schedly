import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/design_tokens.dart';

enum LectureStatus { conducted, cancelled, rescheduled, pending }

class StatusBadge extends StatelessWidget {
  final LectureStatus status;
  final bool compact;

  const StatusBadge({super.key, required this.status, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final semanticColors = Theme.of(context).extension<AppSemanticColors>()!;

    Color statusColor;
    IconData icon;
    String label;

    switch (status) {
      case LectureStatus.conducted:
        statusColor = semanticColors.conducted;
        icon = Icons.check_circle_rounded;
        label = 'Conducted';
        break;
      case LectureStatus.cancelled:
        statusColor = semanticColors.cancelled;
        icon = Icons.cancel_rounded;
        label = 'Cancelled';
        break;
      case LectureStatus.rescheduled:
        statusColor = semanticColors.rescheduled;
        icon = Icons.schedule_rounded;
        label = 'Rescheduled';
        break;
      case LectureStatus.pending:
        statusColor = semanticColors.pending;
        icon = Icons.access_time_rounded;
        label = 'Pending';
        break;
    }

    if (compact) {
      return Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppIconSize.sm, color: statusColor),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: statusColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
