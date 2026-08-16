import 'package:flutter/material.dart';
import '../../theme/theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'staggered_list_item.dart';
import 'animated_button.dart';

class FloatingEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onAction;
  final String? actionLabel;

  const FloatingEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semanticColors = theme.extension<AppSemanticColors>()!;
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x3l),
          child:
              Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Clean icon container
                      StaggeredListItem(
                        index: 0,
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF2E2E2E)
                                : const Color(0xFFF3F4F6),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            icon,
                            size: 28,
                            color: semanticColors.onSurfaceMuted,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // Title
                      StaggeredListItem(
                        index: 1,
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                            height: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),

                      // Subtitle
                      StaggeredListItem(
                        index: 2,
                        child: Text(
                          subtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: semanticColors.onSurfaceMuted,
                            height: 1.5,
                          ),
                        ),
                      ),

                      // Optional action button
                      if (onAction != null && actionLabel != null) ...[
                        const SizedBox(height: AppSpacing.x2l),
                        StaggeredListItem(
                          index: 3,
                          child: AnimatedButton(
                            onPressed: onAction,
                            backgroundColor: colorScheme.surface,
                            foregroundColor: colorScheme.onSurface,
                            borderRadius: AppRadius.md,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                              vertical: AppSpacing.md,
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: semanticColors.borderSubtle,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg,
                                vertical: AppSpacing.sm,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.add_rounded, size: 18),
                                  const SizedBox(width: AppSpacing.sm),
                                  Text(
                                    actionLabel!,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  )
                  .animate(
                    onPlay: (controller) => controller.repeat(reverse: true),
                  )
                  .moveY(
                    begin: 0,
                    end: -4,
                    duration: 2500.ms,
                    curve: Curves.easeInOutSine,
                  ),
        ),
      ),
    );
  }
}
