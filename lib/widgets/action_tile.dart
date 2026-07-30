import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/design_tokens.dart';
import 'workspace_surface.dart';

class ActionTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool useTintedBackground;

  const ActionTile({
    super.key,
    required this.icon,
    this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.useTintedBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    final semanticColors = Theme.of(context).extension<AppSemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultIconColor = isDark ? AppColors.onSurfaceDark : AppColors.onSurface;
    final effectiveIconColor = iconColor ?? defaultIconColor;

    return WorkspaceSurface(
      onTap: onTap,
      isInteractive: onTap != null,
      backgroundColor: useTintedBackground ? semanticColors.surfaceTinted : Colors.transparent,
      borderColor: Colors.transparent,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: effectiveIconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: AppIconSize.md,
              color: effectiveIconColor,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.onSurfaceDark : AppColors.onSurface,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: semanticColors.onSurfaceMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          trailing ??
              Icon(
                Icons.chevron_right,
                size: AppIconSize.md,
                color: semanticColors.onSurfaceFaint,
              ),
        ],
      ),
    );
  }
}
