import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/design_tokens.dart';
import 'workspace_surface.dart';

enum SchedlyCardVariant { standard, elevated, tinted, neumorphic }

class SchedlyCard extends StatelessWidget {
  final SchedlyCardVariant variant;
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? borderRadius;
  final Color? borderColor;
  final Color? customBackgroundColor;

  const SchedlyCard({
    super.key,
    this.variant = SchedlyCardVariant.standard,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.margin,
    this.borderRadius = AppRadius.lg,
    this.borderColor,
    this.customBackgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final semanticColors = Theme.of(context).extension<AppSemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color backgroundColor;
    Color? surfaceBorderColor;

    switch (variant) {
      case SchedlyCardVariant.standard:
        backgroundColor = isDark ? AppColors.surfaceDark : Colors.white;
        surfaceBorderColor = semanticColors.borderSubtle;
        break;
      case SchedlyCardVariant.elevated:
        backgroundColor = isDark ? AppColors.surfaceDark : Colors.white;
        surfaceBorderColor = semanticColors.borderSubtle;
        break;
      case SchedlyCardVariant.tinted:
        backgroundColor = semanticColors.surfaceTinted;
        surfaceBorderColor = Colors.transparent;
        break;
      case SchedlyCardVariant.neumorphic: // Legacy support
        backgroundColor = isDark ? AppColors.surfaceDark : Colors.white;
        surfaceBorderColor = semanticColors.borderSubtle;
        break;
    }

    if (customBackgroundColor != null) {
      backgroundColor = customBackgroundColor!;
    }

    if (borderColor != null) {
      surfaceBorderColor = borderColor!;
    }

    return WorkspaceSurface(
      margin: margin,
      padding: padding,
      borderRadius: borderRadius ?? AppRadius.lg,
      backgroundColor: backgroundColor,
      borderColor: surfaceBorderColor,
      isInteractive: onTap != null,
      onTap: onTap,
      child: child,
    );
  }
}
