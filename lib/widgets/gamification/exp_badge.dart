import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/theme.dart';

class ExpBadge extends StatelessWidget {
  final int? exp;
  final VoidCallback? onTap;
  final bool showTrophyIcon;

  const ExpBadge({
    super.key,
    this.exp,
    this.onTap,
    this.showTrophyIcon = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final sem = theme.extension<AppSemanticColors>();

    final displayText = exp != null ? '⚡ $exp XP' : '🏆 Top 3';
    final accentColor = showTrophyIcon ? const Color(0xFFE5A93C) : colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs + 2,
          ),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showTrophyIcon) ...[
                const Text('🏆', style: TextStyle(fontSize: 12)),
                const SizedBox(width: AppSpacing.xs),
              ],
              Text(
                displayText,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
