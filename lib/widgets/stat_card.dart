import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/design_tokens.dart';
import 'animations/counting_text.dart';
import 'workspace_surface.dart';

class StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData? icon;
  final Color? iconColor;
  final double? trend;
  final bool useNeumorphism; // Kept for backwards compatibility but ignored
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.value,
    required this.label,
    this.icon,
    this.iconColor,
    this.trend,
    this.useNeumorphism = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final semanticColors = Theme.of(context).extension<AppSemanticColors>()!;

    final trendColor = trend != null
        ? (trend! >= 0 ? semanticColors.success : semanticColors.error)
        : null;

    final trendIcon = trend != null
        ? (trend! >= 0
              ? Icons.arrow_upward_rounded
              : Icons.arrow_downward_rounded)
        : null;

    final match = RegExp(r'^([^0-9.-]*)([0-9.-]+)(.*)$').firstMatch(value);
    final isNumeric = match != null;
    Widget valueWidget;

    final valueStyle = TextStyle(
      fontFamily: 'Outfit',
      fontSize: value.length > 5 ? 28 : 36,
      fontWeight: FontWeight.w800,
      color: Theme.of(context).brightness == Brightness.dark
          ? AppColors.onSurfaceDark
          : AppColors.onSurface,
      height: 1,
    );

    if (isNumeric) {
      final prefix = match.group(1) ?? '';
      final numStr = match.group(2) ?? '0';
      final suffix = match.group(3) ?? '';
      final numericValue = double.tryParse(numStr) ?? 0.0;

      valueWidget = CountingText(
        value: numericValue,
        prefix: prefix,
        suffix: suffix,
        style: valueStyle,
      );
    } else {
      valueWidget = Text(value, style: valueStyle);
    }

    return WorkspaceSurface(
      onTap: onTap,
      isInteractive: onTap != null,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: semanticColors.onSurfaceMuted,
                ),
              ),
              if (icon != null)
                Icon(
                  icon,
                  color: iconColor ?? semanticColors.onSurfaceMuted,
                  size: AppIconSize.md,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          valueWidget,
          if (trend != null) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(trendIcon, color: trendColor, size: AppIconSize.sm),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  '${trend!.abs().toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: trendColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
