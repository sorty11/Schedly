import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/design_tokens.dart';

class SchedlyBottomSheet extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final bool showCloseButton;
  final Widget child;
  final double? maxHeight;
  final EdgeInsetsGeometry? padding;

  const SchedlyBottomSheet({
    super.key,
    this.title,
    this.subtitle,
    this.showCloseButton = true,
    required this.child,
    this.maxHeight = 0.9,
    this.padding,
  });

  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    String? title,
    String? subtitle,
    bool showCloseButton = true,
    double? maxHeight = 0.9,
    EdgeInsetsGeometry? padding,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SchedlyBottomSheet(
        title: title,
        subtitle: subtitle,
        showCloseButton: showCloseButton,
        maxHeight: maxHeight,
        padding: padding,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final semanticColors = Theme.of(context).extension<AppSemanticColors>()!;
    final textTheme = Theme.of(context).textTheme;
    final screenHeight = MediaQuery.of(context).size.height;
    final maxH = maxHeight != null
        ? screenHeight * maxHeight!
        : screenHeight * 0.9;

    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: BoxDecoration(
        color: semanticColors.surfaceElevated,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppRadius.x2l),
          topRight: Radius.circular(AppRadius.x2l),
        ),
        border: Border(
          top: BorderSide(color: semanticColors.borderSubtle, width: 0.8),
          left: BorderSide(color: semanticColors.borderSubtle, width: 0.8),
          right: BorderSide(color: semanticColors.borderSubtle, width: 0.8),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xs),
            width: 40,
            height: 4.5,
            decoration: BoxDecoration(
              color: semanticColors.onSurfaceFaint.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
          ),
          if (title != null || showCloseButton)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.x2l,
                vertical: AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      if (title != null)
                        Expanded(
                          child: Text(title!, style: textTheme.headlineSmall),
                        ),
                      if (showCloseButton) ...[
                        if (title != null) const SizedBox(width: AppSpacing.md),
                        IconButton(
                          icon: Icon(
                            Icons.close,
                            size: AppIconSize.lg,
                            color: semanticColors.onSurfaceMuted,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          splashRadius: AppTouchTarget.comfortable / 2,
                        ),
                      ],
                    ],
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle!,
                      style: textTheme.bodySmall?.copyWith(
                        color: semanticColors.onSurfaceMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          if (title != null || showCloseButton)
            Divider(
              height: 1,
              thickness: 1,
              color: semanticColors.borderSubtle,
            ),
          // Child content
          Flexible(
            child: SingleChildScrollView(
              padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
